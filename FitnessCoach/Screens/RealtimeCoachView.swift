import SwiftUI

/// The live MiniMax conversation embedded directly in a workout screen.
/// There is intentionally no standalone realtime destination: the current
/// exercise card and the coach's spoken guidance belong in one place.
struct RealtimeCoachPanel: View {
    let session: RealtimeSession

    var body: some View {
        VStack(spacing: 0) {
            statusStrip
                .padding(.horizontal, Theme.pagePadding)
                .padding(.bottom, 12)

            if let issue = session.microphoneIssue {
                Label(issue, systemImage: "mic.slash")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.horizontal, Theme.pagePadding)
                    .padding(.bottom, 12)
            }

            transcript
                .frame(maxHeight: .infinity)
                .layoutPriority(1)
        }
        .animation(.easeInOut(duration: 0.2), value: session.status)
    }

    private var statusStrip: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(session.status.label)
                .font(Theme.caption)
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(2)
                .accessibilityIdentifier("realtime-status")

            Spacer(minLength: 8)

            if let latency = session.lastLatencyMs {
                Text("\(latency) ms")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .monospacedDigit()
            }

            if case .failed = session.status {
                Button("重连") { session.retry() }
                    .font(Theme.caption)
                    .foregroundStyle(Theme.primary)
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 40)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surface)
        )
    }

    private var statusColor: Color {
        switch session.status {
        case .idle, .connecting: return Theme.secondaryText
        case .ready: return Theme.success
        case .listening, .speaking: return Theme.primary
        case .thinking: return Theme.active
        case .failed: return .red
        }
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if session.messages.isEmpty {
                        Text("按住下方按钮说话，教练会结合当前动作实时回应。")
                            .font(Theme.body)
                            .foregroundStyle(Theme.secondaryText)
                            .padding(.top, 24)
                    }

                    ForEach(session.messages) { message in
                        ChatBubble(
                            message: ChatMessage(
                                id: message.id.uuidString,
                                role: message.role == .user ? .user : .assistant,
                                content: message.text
                            ),
                            accessibilityIdentifier: message.role == .user
                                ? "realtime-user-message" : "realtime-coach-message"
                        )
                        .id(message.id)
                    }
                }
                .padding(.horizontal, Theme.pagePadding)
                .padding(.bottom, 12)
            }
            .onChange(of: session.messages.last?.text) {
                guard let last = session.messages.last else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }
}

/// Shared text and push-to-talk controls for the embedded live coach.
struct RealtimeCoachControls: View {
    let session: RealtimeSession
    @Binding var draft: String

    var body: some View {
        VStack(spacing: 12) {
            #if DEBUG
            testAudioRow
            #endif
            contextField
            talkButton
        }
    }

    #if DEBUG
    /// Bundled speech fixtures for repeatable end-to-end realtime QA.
    private var testAudioRow: some View {
        HStack(spacing: 8) {
            Text("测试语音")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.secondaryText)

            ForEach(Self.testAudioClips, id: \.resource) { clip in
                Button(clip.title) {
                    session.injectTestAudio(resource: clip.resource)
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.secondaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Theme.surface))
                .overlay(Capsule().strokeBorder(Theme.border, lineWidth: 1))
                .buttonStyle(.plain)
                .disabled(!session.status.isConnected)
                .accessibilityIdentifier("inject-audio-\(clip.resource)")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private static let testAudioClips: [(title: String, resource: String)] = [
        ("背", "01_back"),
        ("累", "02_tired"),
        ("弃", "03_giveup"),
    ]
    #endif

    private var contextField: some View {
        HStack(spacing: 8) {
            TextField("补充一句文字上下文…", text: $draft)
                .font(Theme.body)
                .submitLabel(.send)
                .onSubmit(submit)
                .accessibilityIdentifier("realtime-text-input")

            Button(action: submit) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle().fill(canSend ? Theme.primary : Theme.primary.opacity(0.35)))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("realtime-send-button")
            .disabled(!canSend)
        }
        .padding(.horizontal, 12)
        .frame(height: Theme.tapTarget)
        .background(Capsule(style: .continuous).fill(Theme.surface))
        .overlay(Capsule(style: .continuous).strokeBorder(Theme.border, lineWidth: 1))
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && session.status.isConnected
    }

    private func submit() {
        guard canSend else { return }
        session.send(text: draft)
        draft = ""
    }

    private var talkButton: some View {
        let isTalking = session.status == .listening

        return HStack(spacing: 10) {
            Image(systemName: isTalking ? "waveform" : "mic.fill")
                .font(.system(size: 17, weight: .semibold))
            Text(isTalking ? "松开发送" : "按住说话")
                .font(.system(size: 17, weight: .semibold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(
            RoundedRectangle(cornerRadius: Theme.buttonRadius, style: .continuous)
                .fill(isTalking ? Theme.active : Theme.primary)
        )
        .opacity(session.status.isConnected ? 1 : 0.4)
        .scaleEffect(isTalking ? 0.98 : 1)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !isTalking else { return }
                    session.beginSpeaking()
                }
                .onEnded { _ in
                    session.endSpeaking()
                }
        )
        .disabled(!session.status.isConnected)
        .accessibilityLabel("按住说话")
    }
}
