import Foundation
import Observation

/// One coaching conversation. Both the strength and cardio pages drive an
/// instance of this, so the chat UI is written once.
@MainActor
@Observable
final class CoachThread {

    private(set) var messages: [ChatMessage] = []
    private(set) var isTyping = false
    private(set) var voiceState: VoiceState = .idle
    var inputMode: InputMode = .voice
    var style: AIStyle = .practical

    /// Set when the coach is live. Nil keeps the thread on the scripted path,
    /// which is what demos and UI tests run on.
    var api: CoachAPI?
    /// MiniMax-backed Vance realtime transport. It owns audio input/output;
    /// the existing SSE API remains the fallback for text-only deployments.
    var realtime: RealtimeCoachClient?
    /// Kimi-backed gym equipment recognition. Its result stays in this same
    /// thread and becomes context for the next realtime turn.
    var vision: GymVisionAPI?
    /// Kimi-backed asynchronous memory extraction. It never sits on the
    /// request/response path of a coaching turn.
    var memorySummarizer: MemorySummaryAPI?
    /// Supplies the live training state sent with every request.
    var contextProvider: (@MainActor () -> CoachContext)?
    /// Active memory chips, sent so the coach knows the user's history.
    var memoryProvider: (@MainActor () -> [String])?
    /// Existing non-location memories used only for Kimi's dedupe pass.
    var memorySummaryProvider: (@MainActor () -> [String])?
    /// Commits sanitized Kimi summary output to the local SwiftData store.
    var memoryUpdateHandler: (@MainActor ([MemorySummary.Update]) -> Void)?
    /// Commits the high-confidence photo facts and optional device location.
    var gymObservationHandler: (@MainActor (GymVisionResult, GymLocationSnapshot?) -> Void)?
    /// Persists the user-authorized location even if Kimi cannot recognize the
    /// image or the network request fails.
    var gymLocationHandler: (@MainActor (GymLocationSnapshot) -> Void)?
    /// Stores local, stage-level timings for each equipment-recognition turn.
    var gymVisionTimingHandler: (@MainActor (GymVisionTiming) -> Void)?
    /// Executes a coach action against session state and returns the tool
    /// result string the model sees next turn.
    var actionHandler: (@MainActor (CoachAction) -> String)?

    /// Real dictation. Nil (simulator, UI tests, denied permission) falls back
    /// to the scripted turns so the flow is always walkable.
    var speech: SpeechRecognizer?

    /// Live partial transcript, shown under the mic while the user talks.
    var partialTranscript: String { speech?.transcript ?? "" }

    private let opening: [CoachLine]
    private let script: [ScriptedTurn]
    private var usedTurns: Set<String> = []
    private var work: Task<Void, Never>?
    private let onEffect: (TurnEffect) -> Void

    /// API-shaped history. Separate from `messages` because Claude needs the
    /// tool_use / tool_result blocks that never render as bubbles.
    private var wire: [WireMessage] = []
    private(set) var lastError: String?
    private var realtimeBubbleID: String?
    private var recognizedEquipment: [String] = []
    private(set) var isVisionRecognizing = false
    private var memorySummaryWork: Task<Void, Never>?
    /// Converged location awaiting the user's map confirmation. Reading it in a
    /// view's body presents the picker; `confirmLocation`/`dismissLocationPicker`
    /// clear it so the sheet never re-presents after a swipe-down.
    private(set) var pendingLocationSnapshot: GymLocationSnapshot?
    /// The last successful recognition, kept so a later confirmed location can
    /// be attached to the same equipment observation.
    private var lastVisionResult: GymVisionResult?

    var isLive: Bool { api != nil || realtime != nil }

    init(
        opening: [CoachLine],
        script: [ScriptedTurn],
        onEffect: @escaping (TurnEffect) -> Void
    ) {
        self.opening = opening
        self.script = script
        self.onEffect = onEffect
    }

    var isBusy: Bool { voiceState != .idle || isTyping }

    /// Hint shown next to the text field so the demo stays walkable.
    var suggestedUserText: String? { nextTurn?.userText }

    /// Scripted turns the user hasn't spent yet — the home suggestion chips.
    var remainingSuggestions: [String] {
        script.filter { !usedTurns.contains($0.id) }.map(\.userText)
    }

    private var nextTurn: ScriptedTurn? {
        script.first { !usedTurns.contains($0.id) }
    }

    // MARK: - Lifecycle

    func startIfNeeded() {
        guard messages.isEmpty, work == nil else { return }
        work = Task { [opening] in
            await deliver(opening)
            work = nil
        }
    }

    /// Coach speaks unprompted — used when the session moves to a new movement.
    func announce(_ line: CoachLine) {
        let previous = work
        work = Task {
            _ = await previous?.value
            await deliver([line])
            finishWork()
        }
    }

    /// Voice path. Uses the microphone when dictation is available; otherwise
    /// replays the next scripted turn so demos and the simulator still work.
    func beginVoiceTurn() {
        guard !isBusy, work == nil else { return }

        if let realtime {
            guard let context = currentContext() else { return }
            voiceState = .listening
            work = Task { [weak self, realtime] in
                do {
                    try await realtime.startVoiceTurn(
                        context: context,
                        style: self?.style ?? .practical,
                        memories: self?.memoryProvider?() ?? []
                    )
                } catch {
                    self?.handleRealtimeFailure(error)
                }
            }
            return
        }

        if let speech {
            work = Task {
                if speech.availability == .unknown { await speech.requestAccess() }
                guard case .ready = speech.availability else {
                    // Permission denied or no recognizer — degrade, don't dead-end.
                    lastError = speechFailureMessage
                    finishWork()
                    await runScriptedVoiceTurn()
                    return
                }
                listen(with: speech)
                finishWork()
            }
            return
        }

        work = Task {
            finishWork()
            await runScriptedVoiceTurn()
        }
    }

    private var speechFailureMessage: String? {
        if case .unavailable(let reason) = speech?.availability { return reason }
        return nil
    }

    /// Opens the mic and hands the final transcript to the coach.
    private func listen(with speech: SpeechRecognizer) {
        voiceState = .listening
        speech.start { [weak self] transcript in
            guard let self else { return }
            guard !transcript.isEmpty else {
                // Said nothing — just close the turn.
                self.voiceState = .idle
                return
            }
            self.voiceState = .processing
            self.append(.init(role: .user, content: transcript))
            self.scheduleMemorySummary(transcript: ["用户：\(transcript)"])
            self.work = Task {
                self.voiceState = .speaking
                if self.isLive {
                    await self.runLiveTurn(userText: transcript)
                } else {
                    await self.deliver([CoachLine(core: "收到。按当前配置继续。")])
                }
                self.voiceState = .idle
                self.finishWork()
            }
        }
    }

    /// The pre-recorded path: a 2s pause, then the next scripted user line.
    private func runScriptedVoiceTurn() async {
        voiceState = .listening
        try? await Task.sleep(for: .seconds(2))
        voiceState = .processing
        try? await Task.sleep(for: .seconds(0.6))
        guard let turn = consumeTurn() else {
            voiceState = .idle
            return
        }
        append(.init(role: .user, content: turn.userText))
        scheduleMemorySummary(transcript: ["用户：\(turn.userText)"])
        voiceState = .speaking
        if isLive {
            await runLiveTurn(userText: turn.userText)
        } else {
            apply(turn.effect)
            await deliver(turn.replies)
        }
        voiceState = .idle
    }

    /// Tapping the mic while listening ends the sentence early; tapping during
    /// processing or playback aborts the turn.
    func cancelVoiceTurn() {
        if let realtime, realtime.isRecording {
            realtime.cancelVoiceTurn()
            voiceState = .idle
            isTyping = false
            finishWork()
            return
        }
        if let speech, speech.isRecording {
            speech.stop()
            return
        }
        speech?.cancel()
        work?.cancel()
        work = nil
        voiceState = .idle
        isTyping = false
    }

    /// Text path: the user's own words, then the next scripted coach reply.
    func send(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isBusy, work == nil else { return }
        append(.init(role: .user, content: trimmed))
        scheduleMemorySummary(transcript: ["用户：\(trimmed)"])

        if let realtime {
            guard let context = currentContext() else { return }
            voiceState = .processing
            isTyping = true
            work = Task { [weak self, realtime] in
                do {
                    try await realtime.sendText(
                        trimmed,
                        context: context,
                        style: self?.style ?? .practical,
                        memories: self?.memoryProvider?() ?? []
                    )
                } catch {
                    self?.handleRealtimeFailure(error)
                }
            }
            return
        }

        if isLive {
            work = Task {
                await runLiveTurn(userText: trimmed)
                finishWork()
            }
            return
        }

        let turn = consumeTurn(matching: trimmed)
        apply(turn?.effect)
        work = Task {
            await deliver(turn?.replies ?? [CoachLine(core: "收到。按当前配置继续。")])
            finishWork()
        }
    }

    func configureRealtime(_ client: RealtimeCoachClient) {
        realtime = client
        client.onEvent = { [weak self] event in self?.handleRealtimeEvent(event) }
    }

    func configureVision(_ client: GymVisionAPI) {
        vision = client
    }

    func configureMemorySummarizer(_ client: MemorySummaryAPI) {
        memorySummarizer = client
    }

    /// The user confirmed a POI (or accepted the current location) on the map.
    /// The confirmed snapshot is persisted once, then the picker is dismissed.
    func confirmLocation(_ snapshot: GymLocationSnapshot) {
        guard pendingLocationSnapshot != nil else { return }
        pendingLocationSnapshot = nil
        gymLocationHandler?(snapshot)
        if let result = lastVisionResult {
            gymObservationHandler?(result, snapshot)
        }
    }

    /// Dismiss the location picker without persisting. The photo's equipment is
    /// still recognized; only the location is skipped.
    func dismissLocationPicker() {
        pendingLocationSnapshot = nil
    }

    /// Keeps photo recognition as a turn in the existing conversation. It
    /// intentionally renders only high-confidence device names and leaves the
    /// actual exercise guidance to the following voice turn. The location is
    /// only persisted after the user confirms it on the map.
    func recognizeGymEquipment(
        imageData: Data,
        mimeType: String,
        locationTask: Task<GymLocationLookup, Never>,
        captureTiming: GymVisionCaptureTiming
    ) async {
        guard !isVisionRecognizing, let vision, let context = currentContext() else { return }
        isVisionRecognizing = true
        let photoMessage = ChatMessage(role: .user, content: "📷 已上传健身房照片，正在识别器械与定位…")
        append(photoMessage)

        defer { isVisionRecognizing = false }
        do {
            let recognition = try await vision.recognize(
                imageData: imageData,
                mimeType: mimeType,
                conversationID: UUID().uuidString,
                goal: "减脂与基础体能",
                userPlan: "阶段：\(context.phase)；当前计划：\(context.exercise)；安排：\(context.prescription)"
            )
            let result = recognition.result
            update(id: photoMessage.id, content: "📷 已上传健身房照片")
            recognizedEquipment = result.equipment.map(\.name)
            lastVisionResult = result

            let reply: String
            if recognizedEquipment.isEmpty {
                reply = "这张照片里没有能确认的器械。请靠近设备或换个角度再拍。"
            } else {
                reply = "已确认设备：\(recognizedEquipment.joined(separator: "、"))。接下来直接和我说话，我会结合它们继续。"
            }
            append(.init(role: .assistant, content: reply))

            // Equipment is persisted immediately; the location waits for the
            // user's map confirmation so a wrong GPS fix never lands in memory.
            gymObservationHandler?(result, nil)
            let locationLookup = await locationTask.value
            if let snapshot = locationLookup.snapshot {
                pendingLocationSnapshot = snapshot
            }

            let timing = GymVisionTiming(
                capturedAt: captureTiming.startedAt,
                imageBytes: captureTiming.imageBytes,
                jpegElapsedMilliseconds: captureTiming.jpegElapsedMilliseconds,
                clientRequestElapsedMilliseconds: recognition.clientRequestElapsedMilliseconds,
                gatewayElapsedMilliseconds: result.timing?.gatewayElapsedMilliseconds,
                kimiElapsedMilliseconds: result.timing?.kimiElapsedMilliseconds,
                locationElapsedMilliseconds: locationLookup.elapsedMilliseconds,
                succeeded: true
            )
            gymVisionTimingHandler?(timing)
        } catch {
            update(id: photoMessage.id, content: "📷 器械照片未识别")
            let message = (error as? LocalizedError)?.errorDescription ?? "器械识别暂不可用"
            append(.init(role: .assistant, content: message))
            let failedRequestElapsedMilliseconds = Int(Date().timeIntervalSince(captureTiming.startedAt) * 1_000) - captureTiming.jpegElapsedMilliseconds
            let locationLookup = await locationTask.value
            if let snapshot = locationLookup.snapshot {
                pendingLocationSnapshot = snapshot
            }
            let timing = GymVisionTiming(
                capturedAt: captureTiming.startedAt,
                imageBytes: captureTiming.imageBytes,
                jpegElapsedMilliseconds: captureTiming.jpegElapsedMilliseconds,
                clientRequestElapsedMilliseconds: failedRequestElapsedMilliseconds,
                gatewayElapsedMilliseconds: nil,
                kimiElapsedMilliseconds: nil,
                locationElapsedMilliseconds: locationLookup.elapsedMilliseconds,
                succeeded: false
            )
            gymVisionTimingHandler?(timing)
        }
    }

    private func appendLocationMessage(for location: GymLocationSnapshot?) {
        let name = location?.displayName ?? "未能获取明确地点"
        append(.init(role: .assistant, content: "地点：\(name)"))
    }

    private func currentContext() -> CoachContext? {
        guard var context = contextProvider?() else { return nil }
        context.availableEquipment = recognizedEquipment.isEmpty ? nil : recognizedEquipment
        return context
    }

    /// Snapshot the small, untrusted event payload before starting an async
    /// network wait. UI updates are handed back through the main-actor closure,
    /// so an unavailable Kimi endpoint can never stall the live coach.
    private func scheduleMemorySummary(transcript: [String]) {
        guard
            let memorySummarizer,
            let memoryUpdateHandler
        else { return }
        let memories = memorySummaryProvider?() ?? memoryProvider?() ?? []
        // Keep one current summary worker per coaching thread. A newer user
        // turn supersedes stale context instead of building a request queue.
        memorySummaryWork?.cancel()
        memorySummaryWork = Task(priority: .background) {
            guard !Task.isCancelled else { return }
            do {
                let summary = try await memorySummarizer.summarize(
                    transcript: transcript,
                    existingMemories: memories
                )
                guard !Task.isCancelled, !summary.updates.isEmpty else { return }
                memoryUpdateHandler(summary.updates)
            } catch {
                // Summaries are an enhancement. The next turn and local data
                // remain usable when Kimi is offline or times out.
            }
        }
    }

    private func handleRealtimeEvent(_ event: RealtimeCoachClient.Event) {
        switch event {
        case .connected:
            return
        case .userTranscript(let text):
            guard !text.isEmpty else { return }
            append(.init(role: .user, content: text))
            scheduleMemorySummary(transcript: ["用户：\(text)"])
        case .assistantDelta(let delta):
            voiceState = .speaking
            isTyping = false
            if let realtimeBubbleID {
                update(id: realtimeBubbleID, content: messageContent(id: realtimeBubbleID) + delta)
            } else {
                let message = ChatMessage(role: .assistant, content: delta)
                realtimeBubbleID = message.id
                append(message)
            }
        case .audio:
            voiceState = .speaking
        case .discardedInput:
            voiceState = .idle
            isTyping = false
            finishWork()
        case .done:
            realtimeBubbleID = nil
            voiceState = .idle
            isTyping = false
            finishWork()
        case .failed(let message):
            handleRealtimeFailure(VanceGatewayError.upstream(message))
        }
    }

    private func handleRealtimeFailure(_ error: Error) {
        realtimeBubbleID = nil
        voiceState = .idle
        isTyping = false
        lastError = (error as? LocalizedError)?.errorDescription ?? "实时教练连接失败"
        append(.init(role: .assistant, content: "实时连接暂不可用，先按当前配置继续。"))
        finishWork()
    }

    private func messageContent(id: String) -> String {
        messages.first(where: { $0.id == id })?.content ?? ""
    }

    // MARK: - Live turn

    /// One round trip to the Worker. Streams text into a single growing bubble,
    /// executes any tool calls, and — if tools ran — sends their results back so
    /// the coach can close the turn.
    private func runLiveTurn(userText: String, depth: Int = 0) async {
        guard let api, let context = currentContext() else { return }

        wire.append(.user(userText))
        lastError = nil
        isTyping = true

        var streamed = ""
        var bubbleID: String?
        var toolUses: [WireBlock] = []
        var toolResults: [WireBlock] = []
        var refused = false

        let request = CoachTurnRequest(
            style: style.rawValue,
            state: context,
            memories: memoryProvider?() ?? [],
            messages: wire
        )

        do {
            for try await event in api.stream(request) {
                switch event {
                case .text(let delta):
                    isTyping = false
                    streamed += delta
                    if let bubbleID {
                        update(id: bubbleID, content: streamed)
                    } else {
                        let message = ChatMessage(role: .assistant, content: streamed)
                        bubbleID = message.id
                        append(message)
                    }

                case .action(let id, let name, let input, let action):
                    toolUses.append(.toolUse(id: id, name: name, input: input))
                    let outcome = action.flatMap { actionHandler?($0) } ?? "已忽略：无法识别的操作。"
                    toolResults.append(.toolResult(id: id, content: outcome))

                case .refusal:
                    refused = true

                case .done:
                    break
                }
            }
        } catch {
            isTyping = false
            lastError = (error as? LocalizedError)?.errorDescription ?? "连接教练失败"
            // Drop the unanswered user turn so the next attempt isn't malformed.
            if wire.last?.role == "user" { wire.removeLast() }
            append(.init(role: .assistant, content: "网络不稳,先按当前配置继续。"))
            return
        }

        isTyping = false

        if refused {
            append(.init(role: .assistant, content: "这个问题我不方便回答。如果有伤病顾虑,请咨询医生。"))
            if wire.last?.role == "user" { wire.removeLast() }
            return
        }

        // Record what the assistant actually said, including tool calls.
        var assistantBlocks: [WireBlock] = []
        if !streamed.isEmpty { assistantBlocks.append(.text(streamed)) }
        assistantBlocks.append(contentsOf: toolUses)
        guard !assistantBlocks.isEmpty else { return }
        wire.append(WireMessage(role: "assistant", content: assistantBlocks))

        // Every tool_use must be answered before the next user turn, so close
        // the loop immediately. One hop only — the coach shouldn't chain tools.
        guard !toolResults.isEmpty, depth == 0 else { return }
        wire.append(WireMessage(role: "user", content: toolResults))
        // Reuse the pre-tool snapshot: re-reading state here would show the
        // change the tools just made, and the coach would contradict itself
        // ("changed it to 10 kg" → "no need, you're already at 10 kg").
        await continueAfterTools(context: context)
    }

    /// Second leg of a tool turn: the tool results are already queued in `wire`.
    private func continueAfterTools(context: CoachContext) async {
        guard let api else { return }
        isTyping = true

        var streamed = ""
        var bubbleID: String?

        let request = CoachTurnRequest(
            style: style.rawValue,
            state: context,
            memories: memoryProvider?() ?? [],
            messages: wire
        )

        do {
            for try await event in api.stream(request) {
                if case .text(let delta) = event {
                    isTyping = false
                    streamed += delta
                    if let bubbleID {
                        update(id: bubbleID, content: streamed)
                    } else {
                        let message = ChatMessage(role: .assistant, content: streamed)
                        bubbleID = message.id
                        append(message)
                    }
                }
            }
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? "连接教练失败"
        }

        isTyping = false
        if !streamed.isEmpty {
            wire.append(WireMessage(role: "assistant", content: [.text(streamed)]))
        }
    }

    private func update(id: String, content: String) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index].content = content
    }

    // MARK: - Internals

    private func finishWork() {
        work = nil
    }

    /// Typed or tapped text wins when it names a scripted turn — otherwise the
    /// suggestion chips would answer in the order they were written rather than
    /// the order they were tapped. Voice turns pass nothing and stay in order.
    private func consumeTurn(matching text: String? = nil) -> ScriptedTurn? {
        let match =
            text.flatMap { wanted in
                script.first { $0.userText == wanted && !usedTurns.contains($0.id) }
            } ?? nextTurn

        guard let match else { return nil }
        usedTurns.insert(match.id)
        return match
    }

    private func apply(_ effect: TurnEffect?) {
        guard let effect else { return }
        onEffect(effect)
    }

    private func deliver(_ lines: [CoachLine]) async {
        for line in lines {
            isTyping = true
            try? await Task.sleep(for: .seconds(0.9))
            if Task.isCancelled {
                isTyping = false
                return
            }
            isTyping = false
            append(.init(role: .assistant, content: line.rendered(for: style)))
            try? await Task.sleep(for: .seconds(0.25))
        }
    }

    private func append(_ message: ChatMessage) {
        messages.append(message)
    }
}
