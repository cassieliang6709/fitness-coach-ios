import SwiftData
import SwiftUI

/// /home — the app's root after onboarding.
///
/// Two capsule tabs over one page, not two separate screens: 「对话」is where
/// you talk to the coach before training, 「我的计划」is today's plan plus what
/// you have actually finished. The header and the tab bar stay put across the
/// switch so it reads as one place.
struct HomeView: View {
    @Environment(WorkoutSession.self) private var session
    @Environment(\.workoutStore) private var store
    @Binding var path: [Route]

    @State private var tab = HomeTab.plan

    var body: some View {
        MobileAppShell {
            PageHeader(title: greeting, subtitle: subtitle) {
                HStack(spacing: 8) {
                    // Entry to the MiniMax realtime path. Separate from the
                    // mic in the input bar below, which is on-device dictation
                    // into the text coach — this one is a live voice call.
                    IconButton(
                        symbol: "waveform",
                        tint: Theme.primary,
                        background: Theme.lightOrange
                    ) {
                        path.append(.realtime)
                    }
                    .accessibilityLabel("实时语音陪练")

                    Mascot(pose: tab == .chat ? .listening : .idle, size: 42)
                }
            }

            switch tab {
            case .chat:
                HomeChatTab(thread: session.daily, path: $path)
            case .plan:
                HomePlanTab(path: $path)
            }
        } bottom: {
            HomeBottomBar(tab: $tab) {
                switch tab {
                case .chat:
                    HomeInputBar(thread: session.daily)
                case .plan:
                    if session.canStartWorkout {
                        PrimaryButton(title: "开始今天的训练") {
                            session.enterStrength()
                            path.append(.strength)
                        }
                    } else {
                        PrimaryButton(
                            title: session.isPlanLoading ? "正在生成计划…" : "生成今天的计划",
                            enabled: !session.isPlanLoading
                        ) {
                            Task { await session.syncPlan(generateIfMissing: true) }
                        }
                    }
                }
            }
        }
        .onAppear { session.daily.startIfNeeded() }
    }

    // MARK: - Copy

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<11: return "早上好"
        case 11..<14: return "中午好"
        case 14..<18: return "下午好"
        default: return "晚上好"
        }
    }

    /// On the plan tab this reads the welcome answers back to the user — without
    /// it the goal and venue they picked never appear on the page that measures
    /// them. Falls back to a description when there is no profile yet.
    private var subtitle: String {
        guard tab == .plan else { return "今天想练点什么？说一句就行。" }
        return store?.profile()?.summary ?? "今天的安排和你的记录"
    }
}

// MARK: - Bottom

/// The page's action plus the floating tab capsule. Written here rather than
/// reusing `BottomBar` because the tab bar has to float below the action.
private struct HomeBottomBar<Action: View>: View {
    @Binding var tab: HomeTab
    @ViewBuilder var action: Action

    var body: some View {
        VStack(spacing: 0) {
            Divider().overlay(Theme.border)

            action
                .padding(.horizontal, Theme.pagePadding)
                .padding(.top, 12)

            CapsuleTabBar(selection: $tab)
                .padding(.top, 12)
                .padding(.bottom, 4)
        }
        .background(Theme.background)
    }
}

// MARK: - Chat tab

/// The coach, before training. Same thread component as the coaching pages, so
/// the conversation looks identical wherever it happens.
private struct HomeChatTab: View {
    @Environment(WorkoutSession.self) private var session
    @Bindable var thread: CoachThread
    @Binding var path: [Route]

    @Query(
        filter: #Predicate<SessionRecord> { $0.endedAt != nil },
        sort: \SessionRecord.startedAt,
        order: .reverse
    )
    private var sessions: [SessionRecord]

    private var visibleSuggestions: [String] {
        thread.remainingSuggestions.filter { suggestion in
            suggestion != "上次练得怎么样？"
                || sessions.contains(where: { session.usesDemoData || !$0.isSamplePlan })
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ChatThread(
                messages: thread.messages,
                isTyping: thread.isTyping,
                generatedPlan: session.plan,
                onOpenGeneratedPlan: { path.append(.legDay) }
            )
            .frame(maxHeight: .infinity)
            .layoutPriority(1)

            SuggestionRow(suggestions: visibleSuggestions) { text in
                thread.send(text: text)
            }
        }
    }
}

/// The generated plan stays in the conversation where the user asked for it.
/// It is intentionally compact: the detail screen owns the full exercise list.
struct GeneratedPlanResultCard: View {
    let plan: WorkoutPlan
    let action: () -> Void

    private var focusLabel: String {
        let labels = plan.strengthExercises
            .compactMap(\.libraryMuscleLabel)
            .flatMap { label in
                label.components(separatedBy: " · ")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
        let unique = labels.reduce(into: [String]()) { result, label in
            if !result.contains(label) { result.append(label) }
        }
        return unique.prefix(3).joined(separator: " · ")
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                PlanThumbnail(symbol: "sparkles", size: 52)

                VStack(alignment: .leading, spacing: 4) {
                    Text("AI 计划已生成")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                    Text(plan.title)
                        .font(Theme.cardTitle)
                        .foregroundStyle(Theme.mainText)
                    Text(
                        focusLabel.isEmpty
                            ? "\(plan.strengthExercises.count) 个动作 · 来自动作库"
                            : "\(plan.strengthExercises.count) 个动作 · 重点 \(focusLabel)"
                    )
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondaryText)
                }

                Spacer(minLength: 6)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.primary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .card(selected: true, filled: Theme.lightOrange.opacity(0.35), padding: 14)
        .accessibilityLabel("查看 AI 计划：\(plan.title)")
    }
}

/// Tappable openers. They disappear as they're used, so the row shrinks to
/// nothing instead of nagging with the same three chips forever.
private struct SuggestionRow: View {
    let suggestions: [String]
    let onTap: (String) -> Void

    var body: some View {
        if !suggestions.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button {
                            onTap(suggestion)
                        } label: {
                            Text(suggestion)
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.mainText)
                                .padding(.horizontal, 14)
                                .frame(height: 36)
                                .background(
                                    Capsule(style: .continuous).fill(Theme.lightOrange)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Theme.pagePadding)
                .padding(.bottom, 10)
            }
            .scrollIndicators(.hidden)
            .animation(.easeInOut(duration: 0.2), value: suggestions)
        }
    }
}

/// Compact input for the home tab. Deliberately not `WorkoutInputBar` — there
/// is no session to end here, and the big gym-sized mic would crowd out the
/// tab bar.
private struct HomeInputBar: View {
    @Bindable var thread: CoachThread

    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                TextField("和教练说点什么…", text: $draft)
                    .font(Theme.body)
                    .focused($focused)
                    .submitLabel(.send)
                    .onSubmit(submit)

                Button(action: submit) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle().fill(canSend ? Theme.primary : Theme.primary.opacity(0.35))
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
            }
            .padding(.horizontal, 12)
            .frame(height: Theme.tapTarget)
            .background(Capsule(style: .continuous).fill(Theme.surface))
            .overlay(Capsule(style: .continuous).strokeBorder(Theme.border, lineWidth: 1))

            IconButton(
                symbol: thread.voiceState == .idle ? "mic.fill" : "stop.fill",
                tint: thread.voiceState == .idle ? Theme.primary : .white,
                background: thread.voiceState == .idle ? Theme.lightOrange : Theme.primary
            ) {
                if thread.voiceState == .idle {
                    thread.beginVoiceTurn()
                } else {
                    thread.cancelVoiceTurn()
                }
            }
            .accessibilityLabel(thread.voiceState == .idle ? "开始语音" : "取消语音")
        }
        .animation(.easeInOut(duration: 0.2), value: thread.voiceState)
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !thread.isBusy
    }

    private func submit() {
        guard canSend else { return }
        thread.send(text: draft)
        draft = ""
    }
}

// MARK: - Plan tab

/// Today's plan and the user's own record. Every number is read back from
/// storage — a new account sees zeros, not a fake streak.
private struct HomePlanTab: View {
    @Environment(WorkoutSession.self) private var session
    @Environment(\.workoutStore) private var store
    @Binding var path: [Route]

    @Query(
        filter: #Predicate<MemoryRecord> { $0.active },
        sort: \MemoryRecord.createdAt
    )
    private var memories: [MemoryRecord]

    @Query(
        filter: #Predicate<SessionRecord> { $0.endedAt != nil },
        sort: \SessionRecord.startedAt,
        order: .reverse
    )
    private var sessions: [SessionRecord]

    private var stats: TrainingStats {
        TrainingStats(sessions: visibleSessions, weeklyTarget: store?.weeklyTarget ?? 4)
    }

    private var visibleSessions: [SessionRecord] {
        session.usesDemoData ? sessions : sessions.filter { !$0.isSamplePlan }
    }

    var body: some View {
        @Bindable var session = session

        return ScrollView {
            VStack(alignment: .leading, spacing: Theme.cardSpacing) {
                if session.canStartWorkout {
                    todayCard
                } else {
                    planStatusCard
                }

                WeekStripe(stats: stats)

                MetricRow(metrics: stats.tiles)

                memorySection

                if !visibleSessions.isEmpty {
                    historySection
                }

                AIStyleSelector(selection: $session.aiStyle)
                    .padding(.top, 4)
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.bottom, 16)
        }
    }

    // MARK: Sections

    private var planStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                PlanThumbnail(
                    symbol: session.isPlanLoading ? "sparkles" : "arrow.clockwise",
                    size: 56
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(session.isPlanLoading ? "正在生成今天的计划" : "还没有可用计划")
                        .font(Theme.cardTitle)
                        .foregroundStyle(Theme.mainText)
                    Text(
                        session.planError
                            ?? "AI 会读取你的目标、场地和身体状况，动作只从真实动作库里选择。"
                    )
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !session.isPlanLoading {
                GhostButton(title: "重新生成", symbol: "arrow.clockwise") {
                    Task { await session.syncPlan(generateIfMissing: true) }
                }
            }
        }
        .card(selected: session.isPlanLoading)
    }

    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                PlanThumbnail(symbol: session.plan.symbol, size: 56)

                VStack(alignment: .leading, spacing: 4) {
                    Text("今天")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.primary)
                    Text(session.plan.title)
                        .font(Theme.cardTitle)
                        .foregroundStyle(Theme.mainText)
                    Text(session.plan.tags.joined(separator: " · "))
                        .font(Theme.caption)
                        .foregroundStyle(Theme.secondaryText)
                }

                Spacer(minLength: 8)
            }

            VStack(spacing: 8) {
                ForEach(session.plan.sections) { section in
                    HStack(spacing: 8) {
                        Image(systemName: section.kind.symbol)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.primary)
                            .frame(width: 18)

                        Text(section.kind.title)
                            .font(Theme.body)
                            .foregroundStyle(Theme.mainText)

                        Spacer(minLength: 8)

                        Text(section.duration)
                            .font(Theme.caption)
                            .foregroundStyle(Theme.secondaryText)
                            .monospacedDigit()
                    }
                }
            }

            HStack(spacing: 8) {
                GhostButton(title: "查看完整计划", symbol: "list.bullet") {
                    path.append(.legDay)
                }

                GhostButton(title: "换个计划", symbol: "square.grid.2x2", tint: Theme.secondaryText) {
                    path.append(.plans)
                }
            }
        }
        .card(selected: true)
    }

    private var memorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "AI 记住的事", detail: "\(memories.count) 条")

            if memories.isEmpty {
                Text("还没有记录。训练时说一句，我就记住了。")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondaryText)
            } else {
                MemoryChipRow(memories: memories.map(\.asMemory))
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "最近训练", detail: stats.weeklyHeadline)

            VStack(spacing: 8) {
                ForEach(visibleSessions.prefix(3)) { record in
                    HistoryRow(record: record)
                }
            }
        }
    }
}

/// Quiet section label used down the plan tab.
private struct SectionTitle: View {
    let title: String
    var detail: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(Theme.cardTitle)
                .foregroundStyle(Theme.mainText)

            Spacer(minLength: 8)

            if let detail {
                Text(detail)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }
}

private struct HistoryRow: View {
    let record: SessionRecord

    private static let dayFormat: Date.FormatStyle =
        .dateTime.month(.defaultDigits).day(.defaultDigits)

    var body: some View {
        HStack(spacing: 10) {
            Image(
                systemName: record.completionPercent >= 100
                    ? "checkmark.circle.fill" : "circle.lefthalf.filled"
            )
            .font(.system(size: 15))
            .foregroundStyle(record.completionPercent >= 100 ? Theme.success : Theme.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text(record.planTitle)
                    .font(Theme.body)
                    .foregroundStyle(Theme.mainText)
                Text(record.startedAt.formatted(Self.dayFormat))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondaryText)
            }

            Spacer(minLength: 8)

            Text("\(record.durationMinutes) 分钟 · \(record.completionPercent)%")
                .font(Theme.caption)
                .foregroundStyle(Theme.secondaryText)
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .frame(height: 56)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface)
        )
    }
}
