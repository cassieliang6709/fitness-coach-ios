import RiveRuntime
import SwiftUI

/// Kept separate so Rive's eager file loader is only constructed when the
/// bundle really contains `mascot.riv`.
struct LocalRiveMascot: View {
    let pose: MascotPose
    let size: CGFloat

    @StateObject private var model = RiveViewModel(
        fileName: "mascot",
        fit: .contain,
        autoPlay: true,
        loadCdn: false
    )

    var body: some View {
        model.view()
            .frame(width: size, height: size)
            .onAppear(perform: applyPose)
            .onChange(of: pose) { _, _ in applyPose() }
            .accessibilityHidden(true)
    }

    private func applyPose() {
        let index = MascotPose.allCases.firstIndex(of: pose) ?? 0
        model.setInput("Action", value: Double(index))
    }
}
