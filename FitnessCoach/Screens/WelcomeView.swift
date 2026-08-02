import SwiftUI

/// /welcome — the first thing a new user sees.
///
/// Five steps, and every answer after the first becomes an AI memory. The point
/// is not to collect a profile: it's that the coach's opening line in the very
/// first session already reflects the bad knee and the venue the user just
/// named, so "AI 记得你" is true before training starts.
struct WelcomeView: View {
    let onFinish: (UserProfile) -> Void

    @State private var step = 0
    @State private var draft = UserProfile()
    @State private var gymVision = GymVision(userID: InstallIdentity.current)

    private static let lastStep = 4

    var body: some View {
        MobileAppShell {
            header

            StepIndicator(current: step, total: Self.lastStep + 1)
                .padding(.horizontal, Theme.pagePadding)
                .padding(.bottom, 18)

            // The intro has no list to scroll, so it centres in the page
            // instead of stacking against the header with dead space below.
            if step == 0 {
                intro
                    .padding(.horizontal, Theme.pagePadding)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.cardSpacing) {
                        content
                    }
                    .padding(.horizontal, Theme.pagePadding)
                    .padding(.bottom, 16)
                    // A fresh identity per step so the fade runs on every change.
                    .id(step)
                    .transition(.opacity.combined(with: .offset(y: 8)))
                }
            }
        } bottom: {
            BottomBar {
                PrimaryButton(
                    title: step == Self.lastStep ? "开始使用" : "继续",
                    enabled: !isBusy,
                    action: advance
                )
            }
        }
        .animation(.easeInOut(duration: 0.25), value: step)
    }

    // MARK: - Header

    private var header: some View {
        let copy = MockData.welcomeSteps[step]

        return PageHeader(title: copy.title, subtitle: copy.subtitle) {
            if step > 0 {
                IconButton(symbol: "chevron.left") {
                    step -= 1
                }
                .accessibilityLabel("上一步")
            }
        }
    }

    // MARK: - Steps

    @ViewBuilder
    private var content: some View {
        switch step {
        case 1: goalStep
        case 2: venueStep
        case 3: conditionStep
        default: styleStep
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer(minLength: 0)

            HStack {
                Spacer()
                Mascot(pose: .wave, size: 168)
                Spacer()
            }
            .padding(.bottom, 12)

            ForEach(MockData.welcomeHighlights) { highlight in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: highlight.symbol)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.primary)
                        .frame(width: 28, height: 28)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(highlight.title)
                            .font(Theme.bodyStrong)
                            .foregroundStyle(Theme.mainText)
                        Text(highlight.body)
                            .font(Theme.caption)
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 0)
        }
    }

    private var goalStep: some View {
        ForEach(TrainingGoal.allCases) { goal in
            OptionCard(
                symbol: goal.symbol,
                title: goal.label,
                detail: goal.detail,
                selected: draft.goal == goal
            ) {
                draft.goal = goal
            }
        }
    }

    @ViewBuilder
    private var venueStep: some View {
        ForEach(TrainingVenue.allCases) { venue in
            OptionCard(
                symbol: venue.symbol,
                title: venue.label,
                detail: venue.detail,
                selected: draft.venue == venue
            ) {
                draft.venue = venue
            }
        }

        if draft.venue == .gym {
            if let gymVision {
                GymPhotoScanner(vision: gymVision, goal: draft.goal.label)
            } else {
                Label("配置教练服务后可识别健身房器械", systemImage: "camera.viewfinder")
                    .font(Theme.body)
                    .foregroundStyle(Theme.secondaryText)
                    .card(filled: Theme.surface)
            }
        }
    }

    @ViewBuilder
    private var conditionStep: some View {
        ForEach(BodyCondition.allCases) { condition in
            OptionCard(
                symbol: condition.symbol,
                title: condition.label,
                detail: condition.detail,
                selected: draft.conditions.contains(condition),
                multiple: true
            ) {
                toggle(condition)
            }
        }

        OptionCard(
            symbol: "checkmark.seal",
            title: "都没有",
            detail: "之后训练时说一句，我也会记住。",
            selected: draft.conditions.isEmpty,
            multiple: true
        ) {
            draft.conditions = []
        }
    }

    @ViewBuilder
    private var styleStep: some View {
        AIStyleSelector(selection: $draft.style)

        ChatBubble(
            message: ChatMessage(
                role: .assistant,
                content: MockData.styleSampleLines[draft.style] ?? ""
            )
        )
        .padding(.top, 2)

        MemoryNoteCard(
            title: "我会记住",
            message: draft.seedMemories.map(\.text).joined(separator: "；"),
            showsMascot: true
        )
        .padding(.top, 2)
    }

    // MARK: - Actions

    private func toggle(_ condition: BodyCondition) {
        if let index = draft.conditions.firstIndex(of: condition) {
            draft.conditions.remove(at: index)
        } else {
            draft.conditions.append(condition)
        }
    }

    private func advance() {
        guard step < Self.lastStep else {
            onFinish(draft)
            return
        }

        if step == 2, draft.venue == .gym, let gymVision, gymVision.needsSave {
            Task {
                let equipment = gymVision.confirmedEquipment
                guard await gymVision.saveConfirmed() else { return }
                draft.equipment = equipment
                step += 1
            }
            return
        }
        step += 1
    }

    private var isBusy: Bool {
        guard step == 2, let gymVision else { return false }
        return gymVision.phase == .uploading || gymVision.phase == .saving
    }
}

/// Thin capsule progress for the welcome flow. Segments, not dots — the user
/// should see how much is left, and it's short.
struct StepIndicator: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(index <= current ? Theme.primary : Theme.border)
                    .frame(height: 4)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: current)
        .accessibilityLabel("第 \(current + 1) 步，共 \(total) 步")
    }
}
