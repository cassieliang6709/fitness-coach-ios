import SwiftUI

/// /workout/realtime — end-to-end voice with MiniMax through the Coach Gateway.
///
/// Deliberately plain next to the other coaching pages: this is the screen that
/// answers "does the realtime path work at all", so connection state, latency
/// and the raw transcript are all visible rather than styled away.
struct RealtimeCoachView: View {
    @Binding var path: [Route]

    @State private var session = RealtimeSession()
    @State private var draft = ""

    var body: some View {
        MobileAppShell {
            PageHeader(
                title: "实时语音陪练",
                style: .navBar,
                onBack: {
                    session.disconnect()
                    path.removeLast()
                }
            )

            statusStrip
                .padding(.horizontal, Theme.pagePadding)
                .padding(.bottom, 12)

            transcript
                .frame(maxHeight: .infinity)
                .layoutPriority(1)
        } bottom: {
            BottomBar {
                VStack(spacing: 12) {
                    contextField
                    talkButton
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: session.status)
        .onAppear { session.connect() }
        .onDisappear { session.disconnect() }
    }

    // MARK: - Status

    private var statusStrip: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(session.status.label)
                .font(Theme.caption)
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(2)

            Spacer(minLength: 8)

            if let latency = session.lastLatencyMs {
                Text("\(latency) ms")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .monospacedDigit()
            }

            if case .failed = session.status {
                Button("重连") { session.connect() }
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

    // MARK: - Transcript

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if session.messages.isEmpty {
                        Text("按住下面的按钮说话，松开后教练会用语音回你。")
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
                            )
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

    // MARK: - Input

    /// Typed context for the same session — the gym-vision result and the user's
    /// time budget belong here, not in a second conversation.
    private var contextField: some View {
        HStack(spacing: 8) {
            TextField("补充一句文字上下文…", text: $draft)
                .font(Theme.body)
                .submitLabel(.send)
                .onSubmit(submit)

            Button(action: submit) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(canSend ? Theme.primary : Theme.primary.opacity(0.35)))
            }
            .buttonStyle(.plain)
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

    /// Push-to-talk. A drag gesture with zero distance rather than a Button,
    /// because a Button's action only fires on release — the mic has to open on
    /// touch-down.
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
