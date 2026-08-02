import RiveRuntime
import SwiftUI

/// A real state-machine integration check using Rive's MIT-licensed `skills`
/// sample. It proves the runtime and app wiring; it is not our final mascot.
struct RiveLabView: View {
    @Binding var path: [Route]

    @State private var selectedLevel = DemoLevel.beginner
    @StateObject private var model = RiveViewModel(
        fileName: "rive-skills-demo",
        stateMachineName: "Designer's Test",
        fit: .contain,
        autoPlay: true,
        loadCdn: false
    )

    var body: some View {
        MobileAppShell {
            PageHeader(
                title: "Rive 动作实验",
                subtitle: "官方人物状态机 · 本地实时渲染",
                style: .large,
                onBack: { path.removeLast() }
            )

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.cardSpacing) {
                    VStack(spacing: 12) {
                        model.view()
                            .frame(height: 280)
                            .accessibilityIdentifier("rive-state-machine-canvas")

                        Text("当前状态：\(selectedLevel.title)")
                            .font(Theme.bodyStrong)
                            .foregroundStyle(Theme.mainText)
                            .accessibilityIdentifier("rive-current-state")
                    }
                    .frame(maxWidth: .infinity)
                    .card(filled: Theme.surface, padding: 12)

                    HStack(spacing: 8) {
                        ForEach(DemoLevel.allCases) { level in
                            Button(level.title) {
                                selectedLevel = level
                                model.setInput("Level", value: level.riveValue)
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(selectedLevel == level ? Color.white : Theme.primary)
                            .frame(maxWidth: .infinity, minHeight: 42)
                            .background(
                                Capsule().fill(
                                    selectedLevel == level ? Theme.primary : Theme.lightOrange
                                )
                            )
                            .accessibilityIdentifier("rive-level-\(level.rawValue)")
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Label("已经验证", systemImage: "checkmark.seal.fill")
                            .font(Theme.bodyStrong)
                            .foregroundStyle(Theme.primary)

                        Text(
                            "同一个 .riv 文件、同一套人物骨骼，通过状态机输入切换动作等级。按钮改变的是 Rive 文件里的 Level 数字输入，不是 SwiftUI 假动画。"
                        )
                        .font(Theme.body)
                        .foregroundStyle(Theme.mainText)
                        .fixedSize(horizontal: false, vertical: true)

                        Text("最终吉祥物需在 Rive Editor 中按图层拆分并绑定骨骼；本页官方人物仅用于验证技术链路。")
                            .font(Theme.caption)
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .card(filled: Theme.lightOrange.opacity(0.55), padding: 14)
                }
                .padding(.horizontal, Theme.pagePadding)
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            model.setInput("Level", value: selectedLevel.riveValue)
        }
    }
}

private enum DemoLevel: String, CaseIterable, Identifiable {
    case beginner
    case intermediate
    case expert

    var id: Self { self }

    var title: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .expert: return "Expert"
        }
    }

    var riveValue: Double {
        switch self {
        case .beginner: return 0
        case .intermediate: return 1
        case .expert: return 2
        }
    }
}
