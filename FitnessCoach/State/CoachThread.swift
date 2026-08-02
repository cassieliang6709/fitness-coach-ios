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
    /// Supplies the live training state sent with every request.
    var contextProvider: (@MainActor () -> CoachContext)?
    /// Active memory chips, sent so the coach knows the user's history.
    var memoryProvider: (@MainActor () -> [String])?
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

    var isLive: Bool { api != nil }

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

    // MARK: - Live turn

    /// One round trip to the Worker. Streams text into a single growing bubble,
    /// executes any tool calls, and — if tools ran — sends their results back so
    /// the coach can close the turn.
    private func runLiveTurn(userText: String, depth: Int = 0) async {
        guard let api, let context = contextProvider?() else { return }

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
