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

    private let opening: [CoachLine]
    private let script: [ScriptedTurn]
    private var cursor = 0
    private var work: Task<Void, Never>?
    private let onEffect: (TurnEffect) -> Void

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
    var suggestedUserText: String? {
        cursor < script.count ? script[cursor].userText : nil
    }

    // MARK: - Lifecycle

    func startIfNeeded() {
        guard messages.isEmpty, work == nil else { return }
        work = Task { [opening] in
            await deliver(opening)
            work = nil
        }
    }

    /// Voice path: listen → process → scripted user turn → coach reply.
    func beginVoiceTurn() {
        guard !isBusy, work == nil else { return }
        voiceState = .listening
        work = Task {
            try? await Task.sleep(for: .seconds(2))
            if Task.isCancelled { return finishWork() }
            voiceState = .processing
            try? await Task.sleep(for: .seconds(0.6))
            if Task.isCancelled { return finishWork() }
            guard let turn = consumeTurn() else {
                voiceState = .idle
                return finishWork()
            }
            append(.init(role: .user, content: turn.userText))
            voiceState = .speaking
            apply(turn.effect)
            await deliver(turn.replies)
            voiceState = .idle
            finishWork()
        }
    }

    func cancelVoiceTurn() {
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
        let turn = consumeTurn()
        apply(turn?.effect)
        work = Task {
            await deliver(turn?.replies ?? [CoachLine(core: "收到。按当前配置继续。")])
            finishWork()
        }
    }

    // MARK: - Internals

    private func finishWork() {
        work = nil
    }

    private func consumeTurn() -> ScriptedTurn? {
        guard cursor < script.count else { return nil }
        defer { cursor += 1 }
        return script[cursor]
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
