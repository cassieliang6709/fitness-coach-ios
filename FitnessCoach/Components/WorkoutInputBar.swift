import SwiftUI

/// Bottom control cluster shared by both coach pages:
/// keyboard/voice switch · mic · end workout.
struct WorkoutInputBar: View {
    @Bindable var thread: CoachThread
    let onEnd: () -> Void

    @State private var draft = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(spacing: 10) {
            if let error = thread.lastError {
                CoachErrorBanner(
                    message: error,
                    onRetry: thread.canRetryLastTurn ? { thread.retryLastTurn() } : nil,
                    onDismiss: { thread.dismissError() }
                )
                .transition(.opacity)
            }

            if let label = thread.voiceState.label {
                VStack(spacing: 4) {
                    Text(label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.primary)

                    // Live transcript: without it the user can't tell whether
                    // the mic actually heard them.
                    if !thread.partialTranscript.isEmpty {
                        Text(thread.partialTranscript)
                            .font(Theme.body)
                            .foregroundStyle(Theme.mainText)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .transition(.opacity)
                    }
                }
                .transition(.opacity)
            }

            if let notice = thread.voiceNotice {
                Text(notice)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }

            switch thread.inputMode {
            case .voice:
                voiceRow
            case .text:
                textRow
            }
        }
        .padding(.horizontal, Theme.pagePadding)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(Theme.background)
        .overlay(alignment: .top) {
            Divider().overlay(Theme.border)
        }
        .animation(.easeInOut(duration: 0.2), value: thread.inputMode)
        .animation(.easeInOut(duration: 0.2), value: thread.voiceState)
        .animation(.easeInOut(duration: 0.15), value: thread.partialTranscript)
        .animation(.easeInOut(duration: 0.2), value: thread.voiceNotice)
        .animation(.easeInOut(duration: 0.2), value: thread.lastError)
    }

    // MARK: - Rows

    private var voiceRow: some View {
        HStack {
            InputModeSwitcher(mode: $thread.inputMode)

            Spacer()

            VoiceInputButton(state: thread.voiceState) {
                if thread.voiceState == .idle {
                    thread.beginVoiceTurn()
                } else {
                    thread.cancelVoiceTurn()
                }
            }

            Spacer()

            IconButton(
                symbol: "xmark",
                tint: Theme.secondaryText,
                background: Theme.surface,
                action: onEnd
            )
            .accessibilityLabel("结束训练")
        }
    }

    private var textRow: some View {
        HStack(spacing: 10) {
            InputModeSwitcher(mode: $thread.inputMode)

            HStack(spacing: 8) {
                TextField(thread.suggestedUserText ?? "说点什么…", text: $draft)
                    .font(Theme.body)
                    .focused($fieldFocused)
                    .submitLabel(.send)
                    .onSubmit(submit)

                Button(action: submit) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle().fill(canSend ? Theme.primary : Theme.primary.opacity(0.35))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("workout-send-button")
                .disabled(!canSend)
            }
            .padding(.horizontal, 12)
            .frame(height: Theme.tapTarget)
            .background(Capsule(style: .continuous).fill(Theme.surface))
            .overlay(Capsule(style: .continuous).strokeBorder(Theme.border, lineWidth: 1))

            IconButton(
                symbol: "xmark",
                tint: Theme.secondaryText,
                background: Theme.surface,
                action: onEnd
            )
            .accessibilityLabel("结束训练")
        }
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !thread.isBusy
    }

    private func submit() {
        guard canSend else { return }
        thread.send(text: draft)
        draft = ""
    }
}

/// Toggles between voice and keyboard entry.
struct InputModeSwitcher: View {
    @Binding var mode: InputMode

    var body: some View {
        IconButton(
            symbol: mode == .voice ? "keyboard" : "waveform",
            tint: Theme.secondaryText,
            background: Theme.surface
        ) {
            mode = mode == .voice ? .text : .voice
        }
        .accessibilityLabel(mode == .voice ? "切换到文字输入" : "切换到语音输入")
    }
}

/// Big orange mic. Breathing rings while listening. Tapping mid-sentence ends
/// the turn early; the recognizer also stops on its own after a short pause.
struct VoiceInputButton: View {
    let state: VoiceState
    let action: () -> Void

    @State private var breathing = false

    private var listening: Bool { state == .listening }

    var body: some View {
        Button(action: action) {
            ZStack {
                if listening {
                    Circle()
                        .fill(Theme.primary.opacity(0.14))
                        .frame(width: 96, height: 96)
                        .scaleEffect(breathing ? 1.08 : 0.92)
                    Circle()
                        .fill(Theme.primary.opacity(0.18))
                        .frame(width: 82, height: 82)
                        .scaleEffect(breathing ? 1.05 : 0.95)
                }

                Circle()
                    .fill(state == .idle ? Theme.primary : Theme.active)
                    .frame(width: 66, height: 66)
                    .scaleEffect(listening && breathing ? 1.03 : 1)

                Image(systemName: symbol)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white)
            }
            .frame(width: 96, height: 96)
        }
        .buttonStyle(.plain)
        .onChange(of: listening) { _, isListening in
            if isListening {
                withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                    breathing = true
                }
            } else {
                withAnimation(.easeOut(duration: 0.2)) { breathing = false }
            }
        }
        .accessibilityLabel(state == .idle ? "开始语音" : "结束语音")
    }

    private var symbol: String {
        switch state {
        case .idle, .listening: return "mic.fill"
        case .processing: return "ellipsis"
        case .speaking: return "waveform"
        }
    }
}
