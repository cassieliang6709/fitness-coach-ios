import AVFoundation
import Foundation
import Observation

/// Live voice conversation with MiniMax Realtime, through the Coach Gateway.
///
/// This is a second, parallel coaching path — `CoachThread` still runs on-device
/// speech recognition into the Cloudflare Worker. Here the gateway owns the
/// whole loop: it holds the MiniMax key, injects the Vance prompt, and streams
/// transcription, text and 24 kHz PCM back over one WebSocket. The app only
/// moves audio and draws state.
///
/// Push-to-talk only for now. The handoff's automatic VAD needs calibration
/// against real gym recordings before it can be a default, and a held button
/// removes that variable from the first end-to-end test.
@MainActor
@Observable
final class RealtimeSession {

    enum Status: Equatable {
        case idle
        case connecting
        /// Connected, mic closed, waiting for the user to hold the button.
        case ready
        case listening
        /// Audio committed, waiting on the model.
        case thinking
        case speaking
        case failed(String)

        var label: String {
            switch self {
            case .idle: return "未连接"
            case .connecting: return "连接中…"
            case .ready: return "按住说话"
            case .listening: return "在听…"
            case .thinking: return "教练在想…"
            case .speaking: return "教练在说…"
            case .failed(let message): return message
            }
        }

        var isConnected: Bool {
            switch self {
            case .ready, .listening, .thinking, .speaking: return true
            case .idle, .connecting, .failed: return false
            }
        }
    }

    private(set) var status: Status = .idle
    private(set) var messages: [RealtimeMessage] = []
    /// Capture can be unavailable in a Simulator even while the WebSocket,
    /// typed turns and model audio are healthy. Keep that distinct from a
    /// failed realtime connection so text remains usable for local testing.
    private(set) var microphoneIssue: String?
    /// Round-trip from releasing the button to the first audio byte. The whole
    /// point of the realtime path is that this number is small, so it is on
    /// screen rather than buried in the gateway's timing log.
    private(set) var lastLatencyMs: Int?

    let voice = RealtimeWire.defaultVoice

    private var coachingStyle: AIStyle = .practical
    private var coachingState = CoachContext(
        phase: "planning", exercise: "尚未生成计划", prescription: "按用户记忆生成"
    )
    private var coachingMemories: [String] = []

    private let audio = RealtimeAudioEngine()
    private let conversationId = UUID().uuidString.lowercased()
    private var socket: URLSessionWebSocketTask?
    private var receiveLoop: Task<Void, Never>?
    private var playbackWatch: Task<Void, Never>?

    /// Chunks appended since the last commit. The gateway rejects an empty
    /// commit with an error that also poisons the upstream session, so the
    /// client refuses to send one in the first place.
    private var pendingChunks = 0
    private var turnStartedAt: Date?
    private var speechStartedAt: Date?
    private var localTranscriptMessageId: UUID?

    /// Below this a "hold to talk" press is a mis-tap, not speech. Matches the
    /// handoff's 550 ms minimum for the web VAD.
    private let minimumSpeechDuration: TimeInterval = 0.55

    /// Automatic retries since the last clean turn. A dead or misconfigured
    /// upstream drops the socket the moment it is opened, so an uncapped retry
    /// hammers the gateway several times a second and buries the real error.
    private var reconnectAttempts = 0
    private let maximumReconnectAttempts = 3
    private var reconnectTask: Task<Void, Never>?
    private var connectionWatchdog: Task<Void, Never>?
    private var isRequestingMicrophoneAccess = false
    #if DEBUG
    private var audioInjectionTask: Task<Void, Never>?
    #endif

    /// The gateway explains *why* upstream failed in an `error` frame and then
    /// drops the socket. Kept so the close, which carries no detail, reports
    /// that reason instead of a generic "disconnected".
    private var lastUpstreamError: String?

    // MARK: - Connection

    /// Supplies the live workout snapshot before the socket opens. The
    /// gateway turns this into MiniMax's server-owned Vance instructions.
    func configure(style: AIStyle, state: CoachContext, memories: [String]) {
        coachingStyle = style
        coachingState = state
        coachingMemories = memories
        if socket != nil {
            sendSessionConfiguration()
        }
    }

    func connect() {
        guard !status.isConnected, status != .connecting else { return }

        guard let request = Self.gatewayRequest(conversationId: conversationId) else {
            status = .failed("网关地址未配置")
            return
        }

        status = .connecting

        Task {
            do {
                try audio.start()
            } catch {
                status = .failed(error.localizedDescription)
                return
            }

            let task = URLSession.shared.webSocketTask(with: request)
            socket = task
            task.resume()

            sendSessionConfiguration()
            startReceiveLoop(on: task)
            startConnectionWatchdog()
        }
    }

    /// User-initiated close: also clears the retry budget, so leaving the screen
    /// and coming back starts fresh rather than inheriting a spent one.
    func disconnect() {
        reconnectTask?.cancel()
        reconnectTask = nil
        reconnectAttempts = 0
        isRequestingMicrophoneAccess = false
        teardown()
        status = .idle
    }

    /// Drops the socket and audio without touching `status` or the retry budget.
    private func teardown() {
        connectionWatchdog?.cancel()
        connectionWatchdog = nil
        #if DEBUG
        audioInjectionTask?.cancel()
        audioInjectionTask = nil
        #endif
        receiveLoop?.cancel()
        receiveLoop = nil
        playbackWatch?.cancel()
        playbackWatch = nil
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        audio.stop()
        pendingChunks = 0
        speechStartedAt = nil
        closeOpenUserTranscript()
    }

    /// A stalled handshake produces no receive-loop error on some hotspot and
    /// tunnel combinations. Convert that silent stall into the same bounded
    /// reconnect path used for an explicit disconnect.
    private func startConnectionWatchdog() {
        connectionWatchdog?.cancel()
        connectionWatchdog = Task { [weak self] in
            try? await Task.sleep(for: .seconds(8))
            guard let self, !Task.isCancelled, status == .connecting else { return }
            reconnect(reason: "网关连接超时")
        }
    }

    /// A failed upstream turn cannot be resumed — MiniMax rejects further
    /// appends on a session that already errored — so recovery is a full
    /// reconnect under the same conversation id.
    ///
    /// Gives up after a few tries and leaves the manual 重连 button as the way
    /// back: if the gateway's upstream is wrong or its key is rejected, every
    /// retry fails identically and silently retrying forever hides that.
    private func reconnect(reason: String) {
        guard reconnectAttempts < maximumReconnectAttempts else {
            teardown()
            status = .failed("\(reason)（已重试 \(maximumReconnectAttempts) 次，请检查网关）")
            return
        }

        let attempt = reconnectAttempts + 1
        teardown()
        reconnectAttempts = attempt
        status = .failed(reason)

        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400 * (1 << (attempt - 1))))
            guard let self, !Task.isCancelled, case .failed = status else { return }
            connect()
        }
    }

    /// Manual retry from the failure banner, which also restores the retry
    /// budget the automatic path spent.
    func retry() {
        reconnectAttempts = 0
        connect()
    }

    // MARK: - Talking

    func beginSpeaking() {
        guard (status == .ready || status == .speaking), !isRequestingMicrophoneAccess else { return }
        isRequestingMicrophoneAccess = true

        Task { [weak self] in
            guard let self else { return }
            guard await requestMicrophoneAccess() else {
                isRequestingMicrophoneAccess = false
                guard status != .idle else { return }
                microphoneIssue = "请允许麦克风后再按住说话"
                return
            }
            isRequestingMicrophoneAccess = false
            startSpeaking()
        }
    }

    private func startSpeaking() {
        guard status == .ready || status == .speaking else { return }

        // Barge-in: whatever the coach is saying stops the instant the user
        // presses, and its audio is dropped rather than resumed afterwards.
        audio.stopPlayback()
        playbackWatch?.cancel()
        playbackWatch = nil
        closeOpenCoachMessage()

        pendingChunks = 0
        speechStartedAt = .now
        closeOpenUserTranscript()
        localTranscriptMessageId = nil
        status = .listening

        do {
            try audio.startCapture(
                onChunk: { [weak self] chunk in
                    // Hops off the audio thread; at ~10 chunks a second the main-actor
                    // round trip is not worth a dedicated queue.
                    Task { @MainActor [weak self] in
                        self?.appendAudio(chunk)
                    }
                },
                onTranscript: { [weak self] transcript, isFinal in
                    Task { @MainActor [weak self] in
                        self?.updateUserTranscript(transcript, isFinal: isFinal)
                    }
                })
            microphoneIssue = nil
        } catch {
            #if targetEnvironment(simulator)
            microphoneIssue = "模拟器没有可用麦克风输入；可先用文字测试实时对话。"
            #else
            microphoneIssue = error.localizedDescription
            #endif
            // Do not close the healthy realtime socket: text messages still
            // exercise the same MiniMax conversation and playback path.
            status = .ready
            return
        }
        send(RealtimeWire.audioClear)
        send(RealtimeWire.vad(stage: "enabled"))
    }

    func endSpeaking() {
        guard status == .listening else { return }
        audio.stopCapture()

        let held = speechStartedAt.map { Date.now.timeIntervalSince($0) } ?? 0
        speechStartedAt = nil

        guard pendingChunks > 0, held >= minimumSpeechDuration else {
            send(RealtimeWire.audioClear)
            send(
                RealtimeWire.vad(
                    stage: "speech_discarded", metrics: ["speechMs": Int(held * 1000)]))
            pendingChunks = 0
            status = .ready
            return
        }

        send(
            RealtimeWire.vad(stage: "speech_committed", metrics: ["speechMs": Int(held * 1000)]))
        send(RealtimeWire.audioCommit)
        send(RealtimeWire.responseCreate(voice: voice))
        pendingChunks = 0
        turnStartedAt = .now
        lastLatencyMs = nil
        status = .thinking
    }

    /// Typed input on the same session — used to hand the coach context (the
    /// confirmed equipment from gym vision, the user's time budget) without
    /// making them say it out loud.
    func send(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, status.isConnected else { return }

        audio.stopPlayback()
        closeOpenCoachMessage()
        closeOpenUserTranscript()
        messages.append(RealtimeMessage(role: .user, text: trimmed, isComplete: true))

        send(RealtimeWire.userText(trimmed))
        send(RealtimeWire.responseCreate(voice: voice))
        turnStartedAt = .now
        lastLatencyMs = nil
        status = .thinking
    }

    #if DEBUG
    /// Replays a bundled voice fixture at human speed through the same append,
    /// commit and response path as the microphone. Only the PCM source differs;
    /// Gateway and MiniMax behavior remain fully live.
    func injectTestAudio(resource: String) {
        guard status.isConnected else { return }
        guard let url = Bundle.main.url(forResource: resource, withExtension: "m4a") else {
            microphoneIssue = "找不到测试语音：\(resource).m4a"
            return
        }
        guard let pcm = RealtimeAudioEngine.decodeTestAudio(at: url), !pcm.isEmpty else {
            microphoneIssue = "测试语音解码失败：\(resource).m4a"
            return
        }

        audioInjectionTask?.cancel()
        audio.stopPlayback()
        playbackWatch?.cancel()
        playbackWatch = nil
        closeOpenCoachMessage()
        closeOpenUserTranscript()
        localTranscriptMessageId = nil
        pendingChunks = 0
        speechStartedAt = .now
        microphoneIssue = nil
        status = .listening
        send(RealtimeWire.audioClear)
        send(RealtimeWire.vad(stage: "enabled"))

        // 250 ms at 24 kHz, mono Int16. This is still paced at the recording's
        // real duration, while avoiding dozens of main-actor WebSocket sends
        // competing with XCTest accessibility snapshots on a physical phone.
        let chunkDuration = Duration.milliseconds(250)
        let chunkBytes = 6_000 * MemoryLayout<Int16>.size
        audioInjectionTask = Task { [weak self] in
            guard let self else { return }
            var offset = 0
            while offset < pcm.count, !Task.isCancelled {
                let end = min(offset + chunkBytes, pcm.count)
                appendAudio(pcm.subdata(in: offset..<end))
                offset = end
                try? await Task.sleep(for: chunkDuration)
            }
            guard !Task.isCancelled else { return }
            audioInjectionTask = nil
            endSpeaking()
        }
    }
    #endif

    private func appendAudio(_ chunk: Data) {
        guard status == .listening else { return }
        pendingChunks += 1
        send(RealtimeWire.audioAppend(base64: chunk.base64EncodedString()))
    }

    // MARK: - Socket

    private func send(_ event: [String: Any]) {
        guard let socket, let text = RealtimeWire.encode(event) else { return }
        socket.send(.string(text)) { _ in
            // Send failures surface as a receive-loop error a moment later,
            // which is the one place reconnection is handled.
        }
    }

    private func sendSessionConfiguration() {
        send(
            RealtimeWire.sessionUpdate(
                voice: voice,
                style: coachingStyle,
                state: coachingState,
                memories: coachingMemories
            )
        )
    }

    private func startReceiveLoop(on task: URLSessionWebSocketTask) {
        receiveLoop = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    let message = try await task.receive()
                    guard let self else { return }
                    switch message {
                    case .string(let text):
                        handle(text)
                    case .data(let data):
                        handle(String(decoding: data, as: UTF8.self))
                    @unknown default:
                        break
                    }
                } catch {
                    guard let self, !Task.isCancelled else { return }
                    let reason = lastUpstreamError
                        ?? "连接已断开：\(error.localizedDescription)"
                    reconnect(reason: reason)
                    return
                }
            }
        }
    }

    private func handle(_ text: String) {
        guard let event = RealtimeServerEvent.decode(text) else { return }

        // A *non-error* event is the only honest sign the connection is usable:
        // `.ready` is set optimistically before the socket can fail, and the
        // gateway's own failure notice arrives as a normal frame, so counting
        // any traffic as success makes the retry budget reset forever.
        if event.type != "error" {
            reconnectAttempts = 0
            lastUpstreamError = nil
            // `resume()` only starts the handshake; it does not mean the
            // socket has reached the Gateway.  Waiting for the first server
            // event prevents taps and audio fixtures from being queued into a
            // connection that never opened (especially visible on a phone
            // moving through a tunnel or hotspot).
            if status == .connecting {
                connectionWatchdog?.cancel()
                connectionWatchdog = nil
                status = .ready
            }
        }

        switch event.type {
        case "conversation.item.created":
            if let transcript = event.inputTranscript, !transcript.isEmpty {
                updateUserTranscript(transcript, isFinal: true)
            }

        case "response.text.delta", "response.audio_transcript.delta":
            // A delayed tail from the previous response must not leak into a
            // barge-in turn after the user has started talking.
            guard status != .listening else { return }
            appendCoachText(event.delta ?? "")

        case "response.audio.delta":
            guard status != .listening else { return }
            guard let delta = event.delta, let pcm = Data(base64Encoded: delta) else { return }
            noteFirstOutput()
            audio.enqueue(pcm16: pcm)
            status = .speaking
            watchPlayback()

        case "response.done":
            closeOpenUserTranscript()
            closeOpenCoachMessage()
            // Cloud or tunnel buffering can deliver the previous turn's done
            // after a new push-to-talk turn has begun. Do not let it replace
            // `.listening`, otherwise all remaining microphone chunks drop.
            guard status != .listening else { return }
            // Audio keeps playing after the model is done generating, so the
            // status only drops back to ready once the queue drains.
            if audio.isPlaying {
                status = .speaking
                watchPlayback()
            } else {
                status = .ready
            }

        case "error":
            let message = event.error?.message ?? "实时会话出错"
            lastUpstreamError = message
            // Anything the upstream says about the audio buffer means this
            // session is unusable; everything else is a recoverable turn error.
            if message.contains("input_audio") || event.error?.code?.contains("input_audio") == true
            {
                reconnect(reason: message)
            } else {
                status = .failed(message)
            }

        default:
            break
        }
    }

    // MARK: - Transcript

    private func updateUserTranscript(_ transcript: String, isFinal: Bool) {
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            if isFinal { closeOpenUserTranscript() }
            return
        }

        if let id = localTranscriptMessageId,
            let index = messages.firstIndex(where: { $0.id == id })
        {
            messages[index].text = text
            messages[index].isComplete = isFinal
        } else {
            let message = RealtimeMessage(role: .user, text: text, isComplete: isFinal)
            localTranscriptMessageId = message.id
            messages.append(message)
        }
    }

    private func closeOpenUserTranscript() {
        guard let id = localTranscriptMessageId,
            let index = messages.firstIndex(where: { $0.id == id })
        else { return }
        messages[index].isComplete = true
    }

    private func appendCoachText(_ delta: String) {
        guard !delta.isEmpty else { return }
        noteFirstOutput()

        if let index = messages.indices.last, messages[index].role == .coach,
            !messages[index].isComplete
        {
            messages[index].text += delta
        } else {
            messages.append(RealtimeMessage(role: .coach, text: delta, isComplete: false))
        }
    }

    private func closeOpenCoachMessage() {
        guard let index = messages.indices.last, !messages[index].isComplete else { return }
        messages[index].isComplete = true
    }

    private func noteFirstOutput() {
        guard let start = turnStartedAt else { return }
        lastLatencyMs = Int(Date.now.timeIntervalSince(start) * 1000)
        turnStartedAt = nil
    }

    /// `AVAudioPlayerNode` has no "queue emptied" callback worth relying on, so
    /// the tail of a reply is detected by polling the scheduled-buffer count.
    private func watchPlayback() {
        playbackWatch?.cancel()
        playbackWatch = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(120))
                guard let self, !Task.isCancelled else { return }
                guard status == .speaking else { return }
                if !audio.isPlaying {
                    status = .ready
                    return
                }
            }
        }
    }

    // MARK: - Configuration

    private func requestMicrophoneAccess() async -> Bool {
        if AVAudioApplication.shared.recordPermission == .granted { return true }
        return await AVAudioApplication.requestRecordPermission()
    }

    /// `REALTIME_GATEWAY_HOST` comes from `Secrets.xcconfig` via Info.plist and
    /// is host[:port] only — a full URL cannot live in an xcconfig, where "//"
    /// starts a comment.
    ///
    /// The scheme is inferred rather than configured: a loopback or private-LAN
    /// address is the developer's Mac running `node server.mjs` over plain ws,
    /// anything else is a deployed gateway that must be wss.
    static func gatewayURL(conversationId: String) -> URL? {
        let host =
            (Bundle.main.infoDictionary?["REALTIME_GATEWAY_HOST"] as? String)?
            .trimmingCharacters(in: .whitespaces) ?? ""
        guard !host.isEmpty else { return nil }

        let scheme = isLocalHost(host) ? "ws" : "wss"
        return URL(string: "\(scheme)://\(host)/realtime?conversationId=\(conversationId)")
    }

    /// Gateway can be exposed through a temporary or deployed TLS tunnel for
    /// real-device testing. It has its own app-facing secret, so a Worker-key
    /// rotation cannot silently authenticate the realtime provider path.
    static func gatewayRequest(conversationId: String) -> URLRequest? {
        guard let url = gatewayURL(conversationId: conversationId) else { return nil }
        var request = URLRequest(url: url)
        let secret =
            (Bundle.main.infoDictionary?["REALTIME_GATEWAY_SECRET"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !secret.isEmpty, !secret.contains("$(") {
            request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private static func isLocalHost(_ host: String) -> Bool {
        let name: String
        if host.hasPrefix("["), let closingBracket = host.firstIndex(of: "]") {
            name = String(host[host.index(after: host.startIndex)..<closingBracket])
        } else {
            name = host.split(separator: ":").first.map(String.init) ?? host
        }
        if name == "localhost" || name == "127.0.0.1" || name == "::1"
            || name.hasSuffix(".local")
        { return true }
        // IPv6 unique-local and link-local ranges, including Xcode's wired
        // CoreDevice tunnel used for deterministic physical-device testing.
        let lowercaseName = name.lowercased()
        if lowercaseName.hasPrefix("fc") || lowercaseName.hasPrefix("fd")
            || lowercaseName.hasPrefix("fe80:")
        { return true }
        if name.hasPrefix("192.168.") || name.hasPrefix("10.") { return true }
        // 172.16.0.0 – 172.31.255.255
        if name.hasPrefix("172.") {
            let second = name.split(separator: ".").dropFirst().first.flatMap { Int($0) } ?? 0
            return (16...31).contains(second)
        }
        return false
    }
}
