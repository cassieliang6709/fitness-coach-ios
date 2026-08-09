import SwiftUI

struct FinalLabView: View {
    private enum Stage: Int {
        case alexWeek
        case alexWorkout
        case personalWeek
        case personalWorkout

        var progress: String { "\(rawValue + 1) / 4" }
    }

    private struct Option: Identifiable {
        let id: String
        let title: String
        let detail: String
        var exerciseID: String?
    }

    @Environment(LabProgress.self) private var progress
    @Binding var path: [Route]

    @State private var stage: Stage = .alexWeek
    @State private var selection: Set<String> = []
    @State private var critique: String?
    @State private var selectedSchedule: String?

    private let alexWeekOptions: [Option] = [
        Option(id: "strength-2", title: "2 次全身力量", detail: "给第一次四周留出观察和恢复空间"),
        Option(id: "strength-3", title: "3 次全身力量", detail: "时间允许时也可以成立"),
        Option(id: "cardio-2", title: "2 次单车或快走", detail: "Alex 愿意做的中等强度有氧"),
        Option(id: "daily-hiit", title: "每天高强度跑步", detail: "高疲劳，也忽略了他的膝盖反馈"),
        Option(id: "recovery-day", title: "至少 1 个不训练日", detail: "给训练和生活留出恢复空间"),
    ]

    private let exerciseOptions: [Option] = [
        Option(
            id: "machine-chest-press", title: "坐姿推胸", detail: "Push",
            exerciseID: "machine-chest-press"),
        Option(id: "lat-pulldown", title: "高位下拉", detail: "Pull", exerciseID: "lat-pulldown"),
        Option(
            id: "seated-cable-row", title: "坐姿绳索划船", detail: "Pull", exerciseID: "seated-cable-row"),
        Option(id: "leg-press", title: "坐姿腿推", detail: "Knee", exerciseID: "leg-press"),
        Option(
            id: "bodyweight-good-morning", title: "徒手早安式", detail: "Hip",
            exerciseID: "bodyweight-good-morning"),
        Option(id: "dead-bug", title: "死虫式", detail: "Core", exerciseID: "dead-bug"),
        Option(
            id: "stationary-bike", title: "固定单车 10 分钟", detail: "Aerobic",
            exerciseID: "stationary-bike"),
        Option(
            id: "jumping-jack", title: "高强度开合跳", detail: "Impact cardio", exerciseID: "jumping-jack"
        ),
    ]

    private let scheduleOptions: [Option] = [
        Option(
            id: "starter",
            title: "2 次全身力量 + 2–4 个短有氧块",
            detail: "每次力量约 30–45 分钟；有氧从 10–20 分钟开始"
        ),
        Option(
            id: "steady",
            title: "3 次力量 + 2 次中等强度有氧",
            detail: "适合已经有一些活动习惯、恢复也稳定的人"
        ),
        Option(
            id: "flexible",
            title: "2 次短力量 + 3 个可移动有氧块",
            detail: "时间经常变化时，保留完整周和忙碌周两个版本"
        ),
    ]

    var body: some View {
        MobileAppShell {
            PageHeader(
                title: "FINAL LAB · 07",
                style: .navBar,
                onBack: { path.removeLast() }
            ) {
                Text(stage.progress)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.primary)
                    .monospacedDigit()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    LabNotebookLabel(text: stageLabel)

                    Text(title)
                        .font(.system(size: 29, weight: .bold))
                        .foregroundStyle(Theme.mainText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(intro)
                        .font(Theme.body)
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    contextCard
                    optionList
                    feedback
                }
                .padding(.horizontal, Theme.pagePadding)
                .padding(.top, 22)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
        } bottom: {
            BottomBar {
                PrimaryButton(
                    title: submitTitle,
                    enabled: canSubmit,
                    action: submit
                )
                .accessibilityIdentifier("final-lab-submit")
            }
        }
        .background(Theme.labBackground)
        .accessibilityIdentifier("final-lab")
    }

    private var stageLabel: String {
        switch stage {
        case .alexWeek: return "CASE FILE · ALEX"
        case .alexWorkout: return "BUILD A SESSION"
        case .personalWeek: return "NOW BUILD YOUR WEEK"
        case .personalWorkout: return "WORKOUT A"
        }
    }

    private var title: String {
        switch stage {
        case .alexWeek: return "先替 Alex 排一周"
        case .alexWorkout: return "再排他的第一节训练"
        case .personalWeek: return "轮到你的完整周"
        case .personalWorkout: return "选择第一节训练的动作"
        }
    }

    private var intro: String {
        switch stage {
        case .alexWeek:
            return "选择 3–4 项。Vance 会一起判断这组安排，而不是逐项打勾。"
        case .alexWorkout:
            return "选择 4–5 项，让 Alex 能在 45 分钟内完成。"
        case .personalWeek:
            return "你在 Day 1 记录了「\(progress.availability)」。选一个最接近现实的起点。"
        case .personalWorkout:
            return "保留 Push、Pull 和至少一个下半身任务。核心或短有氧可以按时间加入。"
        }
    }

    @ViewBuilder
    private var contextCard: some View {
        switch stage {
        case .alexWeek, .alexWorkout:
            VStack(alignment: .leading, spacing: 8) {
                Text("Alex")
                    .font(Theme.cardTitle)
                    .foregroundStyle(Theme.mainText)
                Text("初学者 · 建立全身力量 · 每周 3 天 × 45 分钟")
                    .font(Theme.body)
                    .foregroundStyle(Theme.secondaryText)
                Label("膝盖偶尔不适 · 不喜欢跑步", systemImage: "exclamationmark.shield.fill")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.warning)
            }
            .card(filled: Theme.surface)
        case .personalWeek, .personalWorkout:
            VStack(alignment: .leading, spacing: 8) {
                Text("你的训练 brief")
                    .font(Theme.cardTitle)
                    .foregroundStyle(Theme.mainText)
                Label(progress.leadGoal, systemImage: "scope")
                Label(progress.supportGoal, systemImage: "plus.circle")
                Label(progress.availability, systemImage: "calendar")
            }
            .font(Theme.body)
            .foregroundStyle(Theme.secondaryText)
            .card(filled: Theme.surface)
        }
    }

    private var optionList: some View {
        VStack(spacing: 10) {
            ForEach(currentOptions) { option in
                Button {
                    toggle(option)
                } label: {
                    HStack(spacing: 12) {
                        if let exerciseID = option.exerciseID,
                            let exercise = ExerciseCatalog.exercise(id: exerciseID)
                        {
                            ExerciseArtwork(exercise: exercise, size: 48)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(option.title)
                                .font(Theme.bodyStrong)
                                .foregroundStyle(Theme.mainText)
                                .multilineTextAlignment(.leading)
                            Text(option.detail)
                                .font(Theme.caption)
                                .foregroundStyle(Theme.secondaryText)
                                .multilineTextAlignment(.leading)
                        }

                        Spacer(minLength: 4)

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
                    .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
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

    @ViewBuilder
    private var feedback: some View {
        if let critique {
            HStack(alignment: .top, spacing: 10) {
                Mascot(pose: critique == successMessage ? .thumbsUp : .listening, size: 42)
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

    private var currentOptions: [Option] {
        switch stage {
        case .alexWeek: return alexWeekOptions
        case .alexWorkout: return exerciseOptions
        case .personalWeek: return scheduleOptions
        case .personalWorkout: return exerciseOptions.filter { $0.id != "jumping-jack" }
        }
    }

    private var submitTitle: String {
        switch stage {
        case .alexWeek, .alexWorkout: return "请 Vance 检查"
        case .personalWeek: return "使用这个完整周"
        case .personalWorkout: return "保存第一版计划"
        }
    }

    private var canSubmit: Bool {
        switch stage {
        case .alexWeek: return selection.count >= 3
        case .alexWorkout: return selection.count >= 4
        case .personalWeek: return selection.count == 1
        case .personalWorkout: return selection.count >= 3
        }
    }

    private var successMessage: String {
        switch stage {
        case .alexWeek:
            return "这周同时保留了全身力量和 Alex 愿意做的有氧，也没有把七天都塞满。"
        case .alexWorkout:
            return "这节训练覆盖了推、拉和下半身，也能在 45 分钟内完成。接下来给它一个容易执行的起始剂量。"
        case .personalWeek, .personalWorkout:
            return ""
        }
    }

    private func toggle(_ option: Option) {
        if stage == .personalWeek {
            selection = selection.contains(option.id) ? [] : [option.id]
        } else if stage == .alexWeek && option.id.hasPrefix("strength-") {
            selection.remove("strength-2")
            selection.remove("strength-3")
            selection.insert(option.id)
        } else if selection.contains(option.id) {
            selection.remove(option.id)
        } else if selection.count < maxSelection {
            selection.insert(option.id)
        }
        critique = nil
    }

    private var maxSelection: Int {
        switch stage {
        case .alexWeek: return 4
        case .alexWorkout, .personalWorkout: return 5
        case .personalWeek: return 1
        }
    }

    private func submit() {
        switch stage {
        case .alexWeek:
            reviewAlexWeek()
        case .alexWorkout:
            reviewAlexWorkout()
        case .personalWeek:
            guard let id = selection.first,
                let option = scheduleOptions.first(where: { $0.id == id })
            else { return }
            selectedSchedule = option.title
            stage = .personalWorkout
            selection = []
            critique = nil
        case .personalWorkout:
            savePersonalPlan()
        }
    }

    private func reviewAlexWeek() {
        if selection.contains("daily-hiit") {
            critique = "每天高强度跑步忽略了 Alex 的膝盖反馈和个人喜好。换成他愿意做的单车或快走。"
            return
        }
        if !selection.contains("strength-2") && !selection.contains("strength-3") {
            critique = "Alex 想建立全身力量，但这一周还没有力量训练。先放入两到三次。"
            return
        }
        if !selection.contains("cardio-2") {
            critique = "Alex 也想让爬楼轻松一点。加入他愿意做的单车或快走。"
            return
        }

        critique = successMessage
        advanceAfterFeedback(to: .alexWorkout)
    }

    private func reviewAlexWorkout() {
        if selection.contains("jumping-jack") {
            critique = "高强度开合跳和 Alex 目前的膝盖反馈不太合拍。固定单车更接近他愿意做、也方便观察的起点。"
            return
        }
        if !selection.contains("machine-chest-press") {
            critique = "现在没有 Push。加入坐姿推胸，再看看是否需要替换重复动作。"
            return
        }
        if !containsPull {
            critique = "现在有推，但没有拉。加入高位下拉或坐姿划船。"
            return
        }
        if !containsLowerBody {
            critique = "还缺少下半身任务。可以加入腿举或徒手髋铰链，并从轻量开始观察。"
            return
        }

        critique = successMessage
        advanceAfterFeedback(to: .personalWeek)
    }

    private func advanceAfterFeedback(to nextStage: Stage) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            stage = nextStage
            selection = []
            critique = nil
        }
    }

    private func savePersonalPlan() {
        guard selection.contains("machine-chest-press"), containsPull, containsLowerBody else {
            critique = "第一节训练还需要 Push、Pull 和至少一个下半身任务。"
            return
        }

        let names =
            currentOptions
            .filter { selection.contains($0.id) }
            .map(\.title)

        let fullWeek = selectedSchedule ?? "2 次全身力量 + 2–4 个短有氧块"
        let busyWeek = "2 次短全身力量 + 2 个 10–20 分钟可移动有氧块"
        progress.save(personalPlan: names)
        progress.save(weeklyPlan: [
            "主要目标：\(progress.leadGoal)",
            "完整周：\(fullWeek)",
            "忙碌周：\(busyWeek)",
        ])
        progress.complete(day: 7)
        path.append(.labLicense)
    }

    private var containsPull: Bool {
        selection.contains("lat-pulldown") || selection.contains("seated-cable-row")
    }

    private var containsLowerBody: Bool {
        selection.contains("leg-press") || selection.contains("bodyweight-good-morning")
    }
}
