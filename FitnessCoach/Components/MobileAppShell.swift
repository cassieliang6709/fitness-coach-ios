import SwiftUI

/// Page scaffold: white canvas, page-level padding constant, fade-in on entry,
/// and an optional pinned bottom bar for the single primary CTA.
struct MobileAppShell<Content: View, Bottom: View>: View {
    @ViewBuilder var content: Content
    @ViewBuilder var bottom: Bottom

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Wrapped in its own stack: a frame applied straight to the
                // ViewBuilder tuple would stretch every child, not the group.
                VStack(spacing: 0) {
                    content
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                bottom
            }
        }
        .fadeIn()
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }
}

extension MobileAppShell where Bottom == EmptyView {
    init(@ViewBuilder content: () -> Content) {
        self.init(content: content, bottom: { EmptyView() })
    }
}

/// Bottom container for the page's one strong action.
struct BottomBar<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            Divider().overlay(Theme.border)
            content
                .padding(.horizontal, Theme.pagePadding)
                .padding(.top, 12)
                .padding(.bottom, 8)
        }
        .background(Theme.background)
    }
}
