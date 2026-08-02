import AVFoundation
import Foundation

@MainActor
final class RealtimeCoachClient {

    enum Event {
        case connected
        case userTranscript(String)
        case assistantDelta(String)
        case audio(Data)
        case discardedInput
        case done
        case failed(String)
    }

    var onEvent: ((Event) -> Void)?
    private(set) var isRecording = false

    private let config: VanceGatewayConfig
    private let conversationID = UUID().uuidString
    private let voiceID: String
    private let session = URLSession(configuration: .default)
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 24_000,
        channels: 1,
        interleaved: false
    )!

    private var socket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var replySource: String?
    private var recordedChunks = 0
    private var playerConnected = false

    init(config: VanceGatewayConfig, voiceID: String = "male-qn-jingying") {
        self.config = config
        self.voiceID = voiceID
    }

    deinit {
        receiveTask?.cancel()
        socket?.cancel(with: .goingAway, reason: nil)
    }

    func startVoiceTurn(context: CoachContext, style: AIStyle, memories: [String]) async throws {
        try await prepareConnection(context: context, style: style, memories: memories)
        try configureAudioSession()
        replySource = nil
        recordedChunks = 0
        try await send(["type": "input_audio_buffer.clear"])

        let input = engine.inputNode
        input.removeTap(onBus: 0)
        let sourceFormat = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 2_048, format: sourceFormat) { [weak self] buffer, format in
            guard let payload = Self.makePCM16Payload(buffer: buffer, sourceRate: format.sampleRate) else { return }
            Task { @MainActor [weak self] in
                await self?.appendAudio(payload)
            }
        }
        connectPlayerIfNeeded()
        engine.prepare()
        try engine.start()
        isRecording = true
    }

    func stopVoiceTurn() {
        guard isRecording else { return }
        stopInputEngine()
        guard recordedChunks > 0 else {
            onEvent?(.discardedInput)
            return
        }
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.send(["type": "input_audio_buffer.commit"])
            } catch {
                self.fail(error)
            }
        }
    }

    func cancelVoiceTurn() {
        guard isRecording else { return }
        stopInputEngine()
        Task { [weak self] in try? await self?.send(["type": "input_audio_buffer.clear"]) }
    }

    func sendText(_ text: String, context: CoachContext, style: AIStyle, memories: [String]) async throws {
        try await prepareConnection(context: context, style: style, memories: memories)
        replySource = nil
        try await send([
            "type": "conversation.item.create",
            "item": [
                "type": "message",
                "role": "user",
                "status": "completed",
                "content": [["type": "input_text", "text": text]],
            ],
        ])
        try await createResponse()
    }

    func disconnect() {
        stopInputEngine()
        receiveTask?.cancel()
        receiveTask = nil
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
    }

    private func prepareConnection(context: CoachContext, style: AIStyle, memories: [String]) async throws {
        try await connectIfNeeded()
        try await sendConfigure(context: context, style: style, memories: memories)
    }

    private func connectIfNeeded() async throws {
        if socket != nil { return }
        guard let url = config.webSocketURL(path: "/realtime?conversationId=\(conversationID)") else {
            throw VanceGatewayError.notConfigured
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(config.sharedSecret)", forHTTPHeaderField: "Authorization")
        let task = session.webSocketTask(with: request)
        socket = task
        task.resume()
        receiveTask = Task { [weak self] in await self?.receiveLoop() }
    }

    private func sendConfigure(context: CoachContext, style: AIStyle, memories: [String]) async throws {
        let stateData = try JSONEncoder().encode(context)
        let state = try JSONSerialization.jsonObject(with: stateData)
        try await send([
            "type": "vance.session.configure",
            "session": [
                "voiceId": voiceID,
                "style": style.rawValue,
                "state": state,
                "memories": memories,
            ],
        ])
    }

    private func appendAudio(_ payload: String) async {
        guard isRecording else { return }
        do {
            try await send(["type": "input_audio_buffer.append", "audio": payload])
            recordedChunks += 1
        } catch {
            fail(error)
        }
    }

    private func createResponse() async throws {
        try await send([
            "type": "response.create",
            "response": ["modalities": ["audio", "text"], "voice": voiceID],
        ])
    }

    private func send(_ object: [String: Any]) async throws {
        guard let socket else { throw VanceGatewayError.notConfigured }
        let data = try JSONSerialization.data(withJSONObject: object)
        guard let text = String(data: data, encoding: .utf8) else { throw VanceGatewayError.invalidResponse }
        try await socket.send(.string(text))
    }

    private func receiveLoop() async {
        guard let socket else { return }
        do {
            while !Task.isCancelled {
                let message = try await socket.receive()
                switch message {
                case .string(let text): handleServerMessage(Data(text.utf8))
                case .data(let data): handleServerMessage(data)
                @unknown default: break
                }
            }
        } catch {
            guard !Task.isCancelled else { return }
            fail(VanceGatewayError.upstream("实时连接已断开"))
        }
    }

    private func handleServerMessage(_ data: Data) {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let type = object["type"] as? String
        else { return }

        switch type {
        case "session.updated": onEvent?(.connected)
        case "input_audio_buffer.committed":
            Task { [weak self] in
                do { try await self?.createResponse() } catch { self?.fail(error) }
            }
        case "conversation.item.created":
            if let transcript = audioTranscript(in: object), !transcript.isEmpty {
                onEvent?(.userTranscript(transcript))
            }
        case "response.text.delta", "response.audio_transcript.delta":
            guard replySource == nil || replySource == type else { return }
            replySource = type
            if let delta = object["delta"] as? String, !delta.isEmpty { onEvent?(.assistantDelta(delta)) }
        case "response.audio.delta":
            if let encoded = object["delta"] as? String, let audio = Data(base64Encoded: encoded) {
                play(audio)
                onEvent?(.audio(audio))
            }
        case "response.done": onEvent?(.done)
        case "error":
            let error = (object["error"] as? [String: Any])?["message"] as? String ?? "实时教练返回错误"
            fail(VanceGatewayError.upstream(error))
        default: break
        }
    }

    private func audioTranscript(in object: [String: Any]) -> String? {
        guard let item = object["item"] as? [String: Any], let content = item["content"] as? [[String: Any]] else { return nil }
        return content.first(where: { ($0["type"] as? String) == "input_audio" })?["transcript"] as? String
    }

    private func fail(_ error: Error) {
        stopInputEngine()
        let message = (error as? LocalizedError)?.errorDescription ?? "实时连接失败"
        onEvent?(.failed(message))
        disconnect()
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
        try session.setPreferredSampleRate(24_000)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func stopInputEngine() {
        isRecording = false
        engine.inputNode.removeTap(onBus: 0)
        if engine.isRunning { engine.stop() }
    }

    private func connectPlayerIfNeeded() {
        guard !playerConnected else { return }
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: targetFormat)
        playerConnected = true
    }

    private func play(_ audio: Data) {
        guard audio.count.isMultiple(of: 2) else { return }
        connectPlayerIfNeeded()
        let frames = AVAudioFrameCount(audio.count / 2)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frames), let output = buffer.int16ChannelData?[0] else { return }
        audio.withUnsafeBytes { bytes in
            guard let source = bytes.baseAddress else { return }
            output.update(from: source.assumingMemoryBound(to: Int16.self), count: Int(frames))
        }
        buffer.frameLength = frames
        if !engine.isRunning {
            do { try engine.start() } catch { fail(error); return }
        }
        if !player.isPlaying { player.play() }
        player.scheduleBuffer(buffer)
    }

    private static func makePCM16Payload(buffer: AVAudioPCMBuffer, sourceRate: Double) -> String? {
        guard let input = buffer.floatChannelData?[0], sourceRate > 0 else { return nil }
        let inputCount = Int(buffer.frameLength)
        guard inputCount > 0 else { return nil }
        let outputCount = max(1, Int((Double(inputCount) * 24_000 / sourceRate).rounded(.down)))
        var output = Data(count: outputCount * MemoryLayout<Int16>.size)
        output.withUnsafeMutableBytes { raw in
            let destination = raw.bindMemory(to: Int16.self)
            for index in 0..<outputCount {
                let sourceIndex = min(inputCount - 1, Int(Double(index) * sourceRate / 24_000))
                let sample = max(-1, min(1, input[sourceIndex]))
                destination[index] = Int16(sample * (sample < 0 ? 32_768 : 32_767))
            }
        }
        return output.base64EncodedString()
    }
}
