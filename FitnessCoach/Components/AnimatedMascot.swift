import SwiftUI

/// Gives still artwork a small amount of life without presenting it as an
/// exercise demonstration. Real movement instruction uses reviewed animation
/// assets; this view is only a decorative coach presence.
struct AnimatedMascot: View {
    let pose: MascotPose
    var size: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var floating = false

    var body: some View {
        Mascot(pose: pose, size: size)
            .scaleEffect(floating && !reduceMotion ? 1.025 : 0.985)
            .rotationEffect(.degrees(floating && !reduceMotion ? 1.2 : -1.2))
            .offset(y: floating && !reduceMotion ? -3 : 2)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.25).repeatForever(autoreverses: true)) {
                    floating = true
                }
            }
    }
}
