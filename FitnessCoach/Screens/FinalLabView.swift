import SwiftUI

struct FinalLabView: View {
    private enum Stage {
        case alex
        case personal
    }

    private struct Option: Identifiable {
        let id: String
        let role: String
    }

    @Environment(LabProgress.self) private var progress
    @Binding var path: [Route]

    @State private var stage: Stage = .alex
    @State private var selection: Set<String> = []
    @State private var critique: String?

    private let options: [Option] = [
        Option(id: "machine-chest-press", role: "Push"),
        Option(id: "lat-pulldown", role: "Pull"),
        Option(id: "leg-press", role: "Knee"),
        Option(id: "bodyweight-good-morning", role: "Hip"),
        Option(id: "dead-bug", role: "Core"),
        Option(id: "jumping-jack", role: "Impact cardio"),
    ]

    var body: some View {
        MobileAppShell {
            PageHeader(
                title: "FINAL LAB · 07",
                style: .navBar,
                onBack: { path.removeLast() }
            ) {
                Text(stage == .alex ? "CASE" : "YOURS")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.primary)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    LabNotebookLabel(text: stage == .alex ? "PROGRAM A HUMAN" : "NOW BUILD YOURS")

                    Text(stage == .alex ? "这次，Vance 不先给答案" : "设计你的第一次训练")
                        .font(.system(size: 29, weight: .bold))
                        .foregroundStyle(Theme.mainText)

                    Text(intro)
                        .font(Theme.body)
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    if stage == .alex {
                        alexCard
                    }

                    optionList

                    if let critique {
                        HStack(alignment: .top, spacing: 10) {
                            Mascot(
                                pose: critique == successMessage ? .thumbsUp : .listening, size: 42)
                            Text(critique)
                                .font(Theme.body)
                                .foregroundStyle(Theme.mainText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(
                                    critique == successMessage
                                        ? Theme.success.opacity(0.1) : Theme.lightOrange
                                )
                        )
                    }
                }
                .padding(.horizontal, Theme.pagePadding)
                .padding(.top, 22)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
        } bottom: {
            BottomBar {
                PrimaryButton(
                    title: stage == .alex ? "请 Vance 检查" : "批准我的计划",
                    enabled: selection.count >= 3,
                    action: submit
                )
                .accessibilityIdentifier("final-lab-submit")
            }
        }
        .background(Theme.labBackground)
        .accessibilityIdentifier("final-lab")
    }

    private var intro: String {
        switch stage {
        case .alex:
            return "先为 Alex 选 3–5 个动作。完成后，Vance 只指出最重要的一个问题。"
        case .personal:
            return "选择一个 Push、一个 Pull 和一个 Legs / Hip；核心或低强度有氧可以作为可选项。"
        }
    }

    private var alexCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Alex")
                .font(Theme.cardTitle)
                .foregroundStyle(Theme.mainText)
            Text("初学者 · 建立全身力量 · 每周 3 天")
                .font(Theme.body)
                .foregroundStyle(Theme.secondaryText)
            Label("膝盖偶尔不适", systemImage: "exclamationmark.shield.fill")
                .font(Theme.caption)
                .foregroundStyle(Theme.warning)
        }
        .card(filled: Theme.surface)
    }

    private var optionList: some View {
        VStack(spacing: 10) {
            ForEach(availableOptions) { option in
                let exercise = ExerciseCatalog.exercise(id: option.id)
                Button {
                    toggle(option.id)
                } label: {
                    HStack(spacing: 12) {
                        if let exercise {
                            ExerciseArtwork(exercise: exercise, size: 48)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(exercise?.name ?? option.id)
                                .font(Theme.bodyStrong)
                                .foregroundStyle(Theme.mainText)
                            Text(option.role)
                                .font(Theme.caption)
                                .foregroundStyle(Theme.secondaryText)
                        }

                        Spacer()

                        Image(
                            systemName: selection.contains(option.id)
                                ? "checkmark.circle.fill" : "circle"
                        )
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(
                            selection.contains(option.id) ? Theme.primary : Theme.secondaryText
                        )
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 66)
                    .background(
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .fill(
                                selection.contains(option.id) ? Theme.lightOrange : Theme.background
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .strokeBorder(
                                selection.contains(option.id) ? Theme.primary : Theme.border,
                                lineWidth: 1.25
                            )
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("final-option-\(option.id)")
            }
        }
    }

    private var availableOptions: [Option] {
        if stage == .personal {
            return options.filter { $0.id != "jumping-jack" }
        }
        return options
    }

    private var successMessage: String {
        "有推、有拉、有腿部，数量也适合第一次训练。这份计划可以开始测试。"
    }

    private func toggle(_ id: String) {
        if selection.contains(id) {
            selection.remove(id)
        } else if selection.count < 5 {
            selection.insert(id)
        }
        critique = nil
    }

    private func submit() {
        if stage == .alex {
            let result = critiqueAlex()
            critique = result
            guard result == successMessage else { return }

            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(650))
                stage = .personal
                selection = []
                critique = nil
            }
            return
        }

        guard personalPlanIsBalanced else {
            critique = "还需要至少一个 Push、一个 Pull，以及一个 Legs / Hip。"
            return
        }

        let names: [String] =
            availableOptions
            .filter { selection.contains($0.id) }
            .compactMap { ExerciseCatalog.exercise(id: $0.id)?.name }
        progress.save(personalPlan: names)
        progress.complete(day: 7)
        path.append(.labLicense)
    }

    private func critiqueAlex() -> String {
        if selection.contains("jumping-jack") {
            return "开合跳与 Alex 的膝盖反馈冲突。移除高冲击动作，再试一次。"
        }
        if !selection.contains("machine-chest-press") {
            return "还没有 Push。加入一个推类动作试试。"
        }
        if !selection.contains("lat-pulldown") {
            return "你安排了推，但还没有 Pull。加入一个背部动作试试。"
        }
        if !selection.contains("leg-press") && !selection.contains("bodyweight-good-morning") {
            return "还缺少 Legs / Hip。加入一个腿部或髋主导动作。"
        }
        return successMessage
    }

    private var personalPlanIsBalanced: Bool {
        selection.contains("machine-chest-press")
            && selection.contains("lat-pulldown")
            && (selection.contains("leg-press") || selection.contains("bodyweight-good-morning"))
    }
}
