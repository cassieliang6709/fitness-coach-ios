import SwiftUI

struct ChatBubble: View {
    let message: ChatMessage

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser {
                Spacer(minLength: 40)
            } else {
                Mascot(pose: .listening, size: 26)
            }

            Text(message.content)
                .font(Theme.body)
                .foregroundStyle(isUser ? .white : Theme.mainText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(isUser ? Theme.primary : Theme.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(isUser ? .clear : Theme.border, lineWidth: 1)
                )

            if !isUser {
                Spacer(minLength: 40)
            }
        }
    }
}

/// Three-dot "coach is typing" indicator.
struct TypingBubble: View {
    @State private var phase = 0

    private let timer = Timer.publish(every: 0.28, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Mascot(pose: .listening, size: 26)

            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Theme.secondaryText.opacity(phase == index ? 0.85 : 0.3))
                        .frame(width: 6, height: 6)
                        .animation(.easeInOut(duration: 0.22), value: phase)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Theme.border, lineWidth: 1)
            )

            Spacer(minLength: 40)
        }
        .onReceive(timer) { _ in
            phase = (phase + 1) % 3
        }
    }
}
