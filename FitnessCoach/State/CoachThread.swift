import Foundation
import Observation
import os

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
    /// Finished workout summaries. Kept separate from long-term memories so
    /// the model never has to invent an answer about the user's last session.
    var historyProvider: (@MainActor () -> [String])?
    /// Executes a coach action against session state and returns the tool
    /// result string the model sees next turn.
    var actionHandler: (@MainActor (CoachAction) -> String)?
    /// Receives a plan the Worker composed and stored. Unlike `actionHandler`
    /// this returns nothing — the plan was already applied server-side, so
    /// there is no tool result the model is waiting on.
    var planHandler: (@MainActor (PlanWire) -> Void)?

    /// Real dictation. Nil (simulator, UI tests, denied permission) falls back
    /// to the scripted turns so the flow is always walkable.
    var speech: SpeechRecognizer?

    /// Live partial transcript, shown under the mic while the user talks.
    var partialTranscript: String { speech?.transcript ?? "" }

    /// Short note about the last voice attempt, shown next to the mic. Every
    /// path that ends a turn without words sets one — a mic that silently does
    /// nothing reads as a broken button.
    private(set) var voiceNotice: String?

    private let opening: [CoachLine]
    private let script: [ScriptedTurn]
    private var usedTurns: Set<String> = []
    private var work: Task<Void, Never>?
    private let onEffect: (TurnEffect) -> Void
    private let speaker = CoachSpeechPlayer()

    /// API-shaped history. Separate from `messages` because Claude needs the
    /// tool_use / tool_result blocks that never render as bubbles.
    private var wire: [WireMessage] = []

    /// What went wrong on the last turn, shown as a banner over the input.
    private(set) var lastError: String?
    /// The words to re-send when the user taps 重试. Nil when a retry would
    /// repeat something that already took effect — see `report(_:retrying:)`.
    private var retryText: String?
    /// A half-streamed reply left behind by a failed turn. Dropped on retry so
    /// the coach doesn't answer twice under a truncated first attempt.
    private var partialBubbleID: String?

    var canRetryLastTurn: Bool { retryText != nil && !isBusy && work == nil }

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
        voiceNotice = nil
        clearError()

        if let speech {
            work = Task {
                // Re-asked on every attempt, not just the first: the status is
                // cached by the system once decided, so this costs nothing and
                // picks up a permission the user granted in Settings after a
                // denial. Without it one refusal disabled the mic for good.
                if speech.availability != .ready { await speech.requestAccess() }
                guard case .ready = speech.availability else {
                    // No recognizer for the locale, or permission refused —
                    // degrade, don't dead-end.
                    voiceNotice = speechFailureMessage
                    finishWork()
                    await degradeVoiceTurn()
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

    private var speechFailureMessage: String {
        if case .unavailable(let reason) = speech?.availability { return reason }
        return "语音暂时不可用"
    }

    /// Dictation is off for this run. A demo has no microphone at all and the
    /// script is the whole point, but a live coach must never be handed a
    /// scripted line as if the user had spoken it — the reply would answer a
    /// question they never asked. Point them at the keyboard instead.
    private func degradeVoiceTurn() async {
        guard !isLive else {
            inputMode = .text
            voiceState = .idle
            return
        }
        await runScriptedVoiceTurn()
    }

    /// Opens the mic and hands the final transcript to the coach.
    private func listen(with speech: SpeechRecognizer) {
        voiceState = .listening
        speech.start { [weak self] transcript in
            guard let self else { return }
            guard !transcript.isEmpty else {
                // Nothing heard. Say why — a mic that closes in silence looks
                // like a dead button, which is how this read in the gym.
                self.voiceNotice = self.speech?.lastFailure ?? "没听清，再说一次或者直接打字"
                self.voiceState = .idle
                return
            }
            self.voiceNotice = nil
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

    // MARK: - Plan

    /// True while a plan asked for by a button is in flight, so the plan page
    /// can show progress without keeping its own copy of the request state.
    private(set) var isGeneratingPlan = false

    /// Why the last plan request failed. Narrower than `lastError` on purpose:
    /// a speech-playback failure belongs in the chat banner, not on the plan
    /// page as though the plan itself were broken.
    private(set) var planFailure: String?

    /// A plan asked for by tapping rather than by talking.
    ///
    /// The prompt is synthetic, so it enters the model's context without
    /// becoming a user bubble — but everything the coach says back is shown
    /// like any other turn. That is the point of routing this through the same
    /// path as the chat: the button used to open its own stream and keep only
    /// the `plan` event, so a reply that asked a question instead of returning
    /// a plan disappeared, and the page just said "还没有可用计划".
    func requestPlan(replacingCurrent: Bool) {
        guard isLive else { return }
        guard !isBusy, work == nil else {
            let busy = "教练正在回复，稍等一下再生成"
            report(busy)
            planFailure = busy
            return
        }

        voiceNotice = nil
        clearError()
        planFailure = nil
        isGeneratingPlan = true

        let prompt =
            replacingCurrent
            ? "请根据我的目标、场地和身体状况，直接换一份不同的今日训练计划。"
            : "请根据我的目标、场地和身体状况，直接生成今天的训练计划。"

        work = Task {
            await runLiveTurn(userText: prompt)
            // A turn that answered with a question rather than a plan is not a
            // failure — the reply is on screen. Only a real error carries over.
            planFailure = lastError
            isGeneratingPlan = false
            finishWork()
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
        voiceNotice = nil
        speech?.cancel()
        speaker.stop()
        work?.cancel()
        work = nil
        voiceState = .idle
        isTyping = false
    }

    /// Text path: the user's own words, then the next scripted coach reply.
    func send(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isBusy, work == nil else { return }
        voiceNotice = nil
        // Moving on drops the offer to retry the turn before it.
        clearError()
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
        let replies =
            turn?.replies
            ?? [
                CoachLine(
                    core: script.isEmpty
                        ? "教练服务尚未配置，暂时不能生成真实回复。"
                        : "收到。按当前配置继续。"
                )
            ]
        work = Task {
            await deliver(replies)
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
        clearError()
        isTyping = true

        var streamed = ""
        var bubbleID: String?
        var toolUses: [WireBlock] = []
        var toolResults: [WireBlock] = []
        var refused = false
        var generatedPlanTitle: String?

        let request = CoachTurnRequest(
            style: style.rawValue,
            state: context,
            memories: memoryProvider?() ?? [],
            history: historyProvider?() ?? [],
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

                case .plan(let wire):
                    // Executed server-side, so there is no tool result to send
                    // back — the Worker already validated and stored it.
                    planHandler?(wire)
                    generatedPlanTitle = wire.title

                case .planError(let reason):
                    append(.init(role: .assistant, content: "这份计划没排成：\(reason)"))

                case .done:
                    break
                }
            }
        } catch {
            isTyping = false
            // Re-sending is only safe while nothing has taken effect yet. A
            // stream that died after a tool call or a stored plan has already
            // changed state, and running the turn again would change it twice.
            let untouched = toolResults.isEmpty && generatedPlanTitle == nil
            report(
                (error as? LocalizedError)?.errorDescription ?? "连接教练失败",
                retrying: untouched ? userText : nil,
                discarding: untouched ? bubbleID : nil
            )
            // Drop the unanswered user turn so the next attempt isn't malformed.
            if wire.last?.role == "user" { wire.removeLast() }
            return
        }

        isTyping = false

        if refused {
            let fallback = "这个问题我不方便回答。如果有伤病顾虑,请咨询医生。"
            append(.init(role: .assistant, content: fallback))
            if wire.last?.role == "user" { wire.removeLast() }
            await speak(fallback)
            return
        }

        // A plan-only tool turn may contain no text blocks at all. Without a
        // local confirmation, the plan is applied successfully but the user
        // sees a silent conversation and has no route into the result.
        if let generatedPlanTitle {
            let confirmation =
                "计划已生成：\(generatedPlanTitle)。可以直接查看动作、训练部位和安排原因。"
            append(.init(role: .assistant, content: confirmation))
            append(.init(role: .assistant, kind: .generatedPlan, content: generatedPlanTitle))
            streamed = [streamed, confirmation].filter { !$0.isEmpty }.joined(separator: " ")
        }

        // Record what the assistant actually said, including tool calls.
        var assistantBlocks: [WireBlock] = []
        if !streamed.isEmpty { assistantBlocks.append(.text(streamed)) }
        assistantBlocks.append(contentsOf: toolUses)
        guard !assistantBlocks.isEmpty else { return }
        wire.append(WireMessage(role: "assistant", content: assistantBlocks))

        // Every tool_use must be answered before the next user turn, so close
        // the loop immediately. One hop only — the coach shouldn't chain tools.
        guard !toolResults.isEmpty, depth == 0 else {
            await speak(streamed)
            return
        }
        wire.append(WireMessage(role: "user", content: toolResults))
        // Reuse the pre-tool snapshot: re-reading state here would show the
        // change the tools just made, and the coach would contradict itself
        // ("changed it to 10 kg" → "no need, you're already at 10 kg").
        let followup = await continueAfterTools(context: context)
        await speak([streamed, followup].filter { !$0.isEmpty }.joined(separator: " "))
    }

    /// Second leg of a tool turn: the tool results are already queued in `wire`.
    private func continueAfterTools(context: CoachContext) async -> String {
        guard let api else { return "" }
        isTyping = true

        var streamed = ""
        var bubbleID: String?

        let request = CoachTurnRequest(
            style: style.rawValue,
            state: context,
            memories: memoryProvider?() ?? [],
            history: historyProvider?() ?? [],
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
            // No retry offered: the tools for this turn have already run, so
            // re-sending would apply them a second time.
            report((error as? LocalizedError)?.errorDescription ?? "连接教练失败")
        }

        isTyping = false
        if !streamed.isEmpty {
            wire.append(WireMessage(role: "assistant", content: [.text(streamed)]))
        }
        return streamed
    }

    private func update(id: String, content: String) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index].content = content
    }

    // MARK: - Failures

    /// Records a failure for the banner. `retrying` carries the user's words
    /// only when re-sending them is side-effect free; `discarding` names a
    /// half-streamed reply to drop if that retry happens.
    private func report(
        _ message: String,
        retrying userText: String? = nil,
        discarding bubbleID: String? = nil
    ) {
        lastError = message
        retryText = userText
        partialBubbleID = bubbleID
    }

    /// Re-sends the turn that failed. The user's own bubble is still on screen
    /// from the first attempt, so this goes straight to the wire rather than
    /// through `send(text:)`, which would post it twice.
    func retryLastTurn() {
        guard let text = retryText, !isBusy, work == nil else { return }
        if let partialBubbleID {
            messages.removeAll { $0.id == partialBubbleID }
        }
        clearError()
        work = Task {
            await runLiveTurn(userText: text)
            finishWork()
        }
    }

    func dismissError() {
        clearError()
    }

    private func clearError() {
        lastError = nil
        retryText = nil
        partialBubbleID = nil
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
            let rendered = line.rendered(for: style)
            append(.init(role: .assistant, content: rendered))
            CoachLog.thread.info("deliver: \(rendered)")
            await speak(rendered)
            try? await Task.sleep(for: .seconds(0.25))
        }
    }

    /// TTS is best-effort: a speech outage must never erase or fail a text
    /// reply the user already received. Cancelling the turn stops playback.
    private func speak(_ text: String) async {
        guard api != nil else { return CoachLog.voice.info("skip: no api") }
        guard !text.isEmpty else { return CoachLog.voice.info("skip: empty text") }
        guard !Task.isCancelled else { return CoachLog.voice.info("skip: cancelled before") }
        guard let api else { return }

        voiceState = .processing
        defer { voiceState = .idle }
        do {
            CoachLog.voice.info("synthesize: \(text.count) chars")
            let audio = try await api.synthesizeSpeech(text)
            CoachLog.voice.info("synthesized: \(audio.count) bytes")
            guard !Task.isCancelled else {
                return CoachLog.voice.info("skip: cancelled after synthesis")
            }
            voiceState = .speaking
            try await speaker.play(audio)
            CoachLog.voice.info("played")
        } catch is CancellationError {
            CoachLog.voice.info("cancelled during playback")
            speaker.stop()
        } catch {
            CoachLog.voice.error("failed: \(String(describing: error))")
            // The words already landed as a bubble, so there is nothing to
            // re-send — only the audio was lost.
            report((error as? LocalizedError)?.errorDescription ?? "语音播放失败")
        }
    }

    private func append(_ message: ChatMessage) {
        messages.append(message)
    }
}
