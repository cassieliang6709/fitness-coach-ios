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

            if thread.isHolding {
                PushToTalkHint(
                    holding: true,
                    willCancel: thread.isCancelingHold,
                    transcript: thread.partialTranscript
                )
            } else if let label = thread.voiceState.label {
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
        .animation(.easeInOut(duration: 0.2), value: thread.isHolding)
    }

    // MARK: - Rows

    private var voiceRow: some View {
        HStack {
            InputModeSwitcher(mode: $thread.inputMode)

            Spacer()

            PushToTalkButton(thread: thread)

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

