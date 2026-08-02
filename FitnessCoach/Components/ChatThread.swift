import SwiftUI

/// Scrolling conversation. Auto-sticks to the newest message and to the
/// typing indicator.
struct ChatThread: View {
    let messages: [ChatMessage]
    let isTyping: Bool

    private let bottomAnchor = "chat-bottom"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(messages) { message in
                        ChatBubble(message: message)
                            .id(message.id)
                            .transition(
                                .asymmetric(
                                    insertion: .opacity.combined(with: .offset(y: 6)),
                                    removal: .opacity
                                )
                            )
                    }

                    if isTyping {
                        TypingBubble()
                            .transition(.opacity)
                    }

                    Color.clear
                        .frame(height: 1)
                        .id(bottomAnchor)
                }
                .padding(.horizontal, Theme.pagePadding)
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .animation(.easeOut(duration: 0.22), value: messages.count)
            .animation(.easeOut(duration: 0.22), value: isTyping)
            .onChange(of: messages.count) { scrollToBottom(proxy) }
            .onChange(of: isTyping) { scrollToBottom(proxy) }
            .onAppear { scrollToBottom(proxy, animated: false) }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool = true) {
        guard animated else {
            proxy.scrollTo(bottomAnchor, anchor: .bottom)
            return
        }
        withAnimation(.easeOut(duration: 0.25)) {
            proxy.scrollTo(bottomAnchor, anchor: .bottom)
        }
    }
}
