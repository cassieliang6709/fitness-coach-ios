import SwiftData
import SwiftUI

/// /home — the app's root after onboarding.
///
/// Three capsule tabs over one page: talk to the coach, manage today's plan,
/// or learn the 50-movement library through swipeable cards.
struct HomeView: View {
    @Environment(WorkoutSession.self) private var session
    @Environment(\.workoutStore) private var store
    @Binding var path: [Route]

    @State private var tab: HomeTab

    init(path: Binding<[Route]>) {
        _path = path

        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-home-tab"),
            arguments.indices.contains(index + 1),
            let requestedTab = HomeTab(rawValue: arguments[index + 1])
        {
            _tab = State(initialValue: requestedTab)
        } else {
            _tab = State(initialValue: .plan)
        }
        #else
        _tab = State(initialValue: .plan)
        #endif
    }

    var body: some View {
        MobileAppShell {
            PageHeader(title: headerTitle, subtitle: subtitle) {
                Mascot(pose: headerPose, size: 42)
            }

            switch tab {
            case .chat:
                HomeChatTab(thread: session.daily, path: $path)
            case .plan:
                HomePlanTab(path: $path)
            case .learn:
                ExerciseHubTab(path: $path)
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
                case .learn:
                    EmptyView()
                }
            }
        }
        .onAppear { session.daily.startIfNeeded() }
    }

    // MARK: - Copy

    private var headerTitle: String {
        tab == .learn ? "动作抽卡" : greeting
    }

    private var headerPose: MascotPose {
        switch tab {
        case .chat: return .listening
        case .plan: return .idle
        case .learn: return .point
        }
    }

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
        switch tab {
        case .chat:
            return "今天想练点什么？说一句就行。"
        case .plan:
            return store?.profile()?.summary ?? "今天的安排和你的记录"
        case .learn:
            return "拍下器械，挑 3–6 个动作直接开练"
        }
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

            if tab != .learn {
                action
                    .padding(.horizontal, Theme.pagePadding)
                    .padding(.top, 12)
            }

            CapsuleTabBar(selection: $tab)
                .padding(.top, 12)
                .padding(.bottom, 4)
        }
        .background(Theme.background)
    }
}

// MARK: - Learn tab

private struct ExerciseHubTab: View {
    enum Mode: String, CaseIterable, Identifiable {
        case draw = "抽动作"
        case library = "动作库"

        var id: String { rawValue }
    }

    @Binding var path: [Route]
    @State private var mode: Mode

    init(path: Binding<[Route]>) {
        _path = path
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-exercise-mode"),
            arguments.indices.contains(index + 1),
            let requested = Mode(rawValue: arguments[index + 1])
        {
            _mode = State(initialValue: requested)
        } else {
            _mode = State(initialValue: .draw)
        }
        #else
        _mode = State(initialValue: .draw)
        #endif
    }

    var body: some View {
        VStack(spacing: 10) {
            Picker("动作模式", selection: $mode) {
                ForEach(Mode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Theme.pagePadding)
            .accessibilityIdentifier("exercise-mode-picker")

            switch mode {
            case .draw:
                ExerciseDrawTab(path: $path)
            case .library:
                ExerciseLearningTab()
            }
        }
    }
}

/// A lightweight study loop over the complete curated catalogue. Learning is
/// intentionally separate from safety filtering: every movement remains
/// discoverable, while each card carries its own caution text.
private struct ExerciseLearningTab: View {
    @State private var selection = 0
    @AppStorage("learnedExerciseIDs") private var learnedExerciseIDs = ""

    private let exercises = LearningSequence.exercises

    private var learnedIDs: Set<String> {
        Set(learnedExerciseIDs.split(separator: ",").map(String.init))
    }

    var body: some View {
        VStack(spacing: 12) {
            progressHeader

            TabView(selection: $selection) {
                ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                    ScrollView {
                        ExerciseLearningCard(
                            exercise: exercise,
                            index: index,
                            total: exercises.count,
                            isLearned: learnedIDs.contains(exercise.id),
                            onToggleLearned: { toggleLearned(exercise.id) }
                        )
                        .padding(.bottom, 8)
                    }
                    .scrollIndicators(.hidden)
                    .accessibilityIdentifier("learn-exercise-card-\(exercise.id)")
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            navigationHint
        }
        .padding(.horizontal, Theme.pagePadding)
        .padding(.bottom, 8)
    }

    private var progressHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Text("第 \(selection + 1) / \(exercises.count) 个")
                    .font(Theme.bodyStrong)
                    .foregroundStyle(Theme.mainText)

                Spacer()

                Text("已学 \(learnedIDs.count)")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.success)
                    .monospacedDigit()
            }

            ProgressView(value: Double(selection + 1), total: Double(exercises.count))
                .tint(Theme.primary)
        }
    }

    private var navigationHint: some View {
        HStack(spacing: 12) {
            Button {
                move(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: Theme.tapTarget, height: Theme.tapTarget)
            }
            .buttonStyle(.plain)
            .foregroundStyle(selection == 0 ? Theme.border : Theme.mainText)
            .disabled(selection == 0)
            .accessibilityLabel("上一个动作")

            Spacer()

            Label("左右滑动学习", systemImage: "hand.draw.fill")
                .font(Theme.caption)
                .foregroundStyle(Theme.secondaryText)

            Spacer()

            Button {
                move(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: Theme.tapTarget, height: Theme.tapTarget)
            }
            .buttonStyle(.plain)
            .foregroundStyle(selection == exercises.count - 1 ? Theme.border : Theme.mainText)
            .disabled(selection == exercises.count - 1)
            .accessibilityLabel("下一个动作")
        }
    }

    private func move(by offset: Int) {
        let next = min(max(selection + offset, 0), exercises.count - 1)
        withAnimation(.easeInOut(duration: 0.22)) {
            selection = next
        }
    }

    private func toggleLearned(_ id: String) {
        var ids = learnedIDs
        if ids.contains(id) {
            ids.remove(id)
        } else {
            ids.insert(id)
        }
        learnedExerciseIDs = ids.sorted().joined(separator: ",")
    }
}

/// Produces a deterministic, visually varied study order. Exercise-specific
/// illustrations are unique keys; movements still using the pose library are
/// spread out so the same fallback artwork does not appear back-to-back.
private enum LearningSequence {
    static let exercises = variedOrder(ExerciseCatalog.all)

    private static func variedOrder(_ source: [ExerciseDefinition]) -> [ExerciseDefinition] {
        var buckets = Dictionary(grouping: source, by: visualKey)
        for key in buckets.keys {
            buckets[key]?.sort { stableRank($0.id) < stableRank($1.id) }
        }

        var result: [ExerciseDefinition] = []
        var previousKey: String?

        while result.count < source.count {
            let candidates = buckets.keys.filter {
                $0 != previousKey && !(buckets[$0]?.isEmpty ?? true)
            }

            // A duplicate is only possible when no alternate visual remains.
            let available = candidates.isEmpty
                ? buckets.keys.filter { !(buckets[$0]?.isEmpty ?? true) }
                : candidates

            guard let nextKey = available.max(by: { left, right in
                let leftCount = buckets[left]?.count ?? 0
                let rightCount = buckets[right]?.count ?? 0
                if leftCount != rightCount { return leftCount < rightCount }
                return stableRank("\(result.count)-\(left)")
                    < stableRank("\(result.count)-\(right)")
            }),
                let next = buckets[nextKey]?.removeFirst()
            else { break }

            result.append(next)
            previousKey = nextKey
        }

        assert(zip(result, result.dropFirst()).allSatisfy {
            visualKey($0) != visualKey($1)
        })
        return result
    }

    private static func visualKey(_ exercise: ExerciseDefinition) -> String {
        if UIImage(named: exercise.animationAssetName) != nil {
            return exercise.animationAssetName
        }
        return "pose-\(exercise.mascotPose.rawValue)"
    }

    /// Swift's `hashValue` changes between processes; this tiny stable hash
    /// keeps the mixed order consistent across launches and UI tests.
    private static func stableRank(_ value: String) -> UInt64 {
        value.utf8.reduce(14_695_981_039_346_656_037) { partial, byte in
            (partial ^ UInt64(byte)) &* 1_099_511_628_211
        }
    }
}

private struct ExerciseLearningCard: View {
    let exercise: ExerciseDefinition
    let index: Int
    let total: Int
    let isLearned: Bool
    let onToggleLearned: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                LearningBadge(text: exercise.category.label, tint: Theme.primary)
                LearningBadge(text: exercise.level.label, tint: Theme.secondaryText)

                Spacer()

                if isLearned {
                    Label("已学", systemImage: "checkmark.circle.fill")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.success)
                }
            }

            ExerciseArtwork(exercise: exercise, size: 132)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(Theme.mainText)
                Text(exercise.englishName)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondaryText)
            }

            HStack(spacing: 8) {
                LearningMetadata(symbol: "figure.strengthtraining.traditional", text: exercise.muscleLabel)
                LearningMetadata(symbol: "dumbbell", text: exercise.equipmentLabel)
            }

            LearningMetadata(symbol: "repeat", text: exercise.prescription)

            Divider().overlay(Theme.border)

            VStack(alignment: .leading, spacing: 6) {
                Text("动作要点")
                    .font(Theme.cardTitle)
                    .foregroundStyle(Theme.mainText)

                ForEach(Array(exercise.coachingTips.enumerated()), id: \.offset) { index, tip in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.primary)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(Theme.lightOrange))

                        Text(tip)
                            .font(Theme.caption)
                            .foregroundStyle(Theme.mainText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            caution

            Button(action: onToggleLearned) {
                Label(
                    isLearned ? "取消已学" : "我学会了",
                    systemImage: isLearned ? "checkmark.circle.fill" : "checkmark.circle"
                )
                .font(Theme.bodyStrong)
                .foregroundStyle(isLearned ? .white : Theme.primary)
                .frame(maxWidth: .infinity)
                .frame(height: Theme.tapTarget)
                .background(
                    Capsule(style: .continuous)
                        .fill(isLearned ? Theme.success : Theme.lightOrange)
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("learned-toggle-\(exercise.id)")
        }
        .card(selected: true, padding: 14)
    }

    private var caution: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.shield.fill")
                .foregroundStyle(Theme.warning)

            VStack(alignment: .leading, spacing: 4) {
                Text("注意事项")
                    .font(Theme.bodyStrong)
                    .foregroundStyle(Theme.mainText)
                Text(cautionText)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.warningTint)
        )
    }

    private var cautionText: String {
        guard !exercise.contraindications.isEmpty else {
            return "先用轻重量熟悉动作轨迹；出现疼痛时立即停止。"
        }
        let labels = exercise.contraindications.map(\.label).sorted().joined(separator: "、")
        return "\(labels)不适时谨慎或跳过；持续不适请咨询专业人士。"
    }
}

private struct LearningBadge: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(Capsule(style: .continuous).fill(tint.opacity(0.1)))
    }
}

private struct LearningMetadata: View {
    let symbol: String
    let text: String

    var body: some View {
        Label(text, systemImage: symbol)
            .font(Theme.caption)
            .foregroundStyle(Theme.secondaryText)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
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
        VStack(spacing: 8) {
            if let error = thread.lastError {
                CoachErrorBanner(
                    message: error,
                    onRetry: thread.canRetryLastTurn ? { thread.retryLastTurn() } : nil,
                    onDismiss: { thread.dismissError() }
                )
                .transition(.opacity)
            }

            // The mic on this page had no feedback at all: no transcript while
            // listening, nothing when a turn ended empty. Both read as "the
            // button doesn't work".
            if let status {
                Text(status)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .transition(.opacity)
            }

            inputRow
        }
        .animation(.easeInOut(duration: 0.2), value: thread.voiceState)
        .animation(.easeInOut(duration: 0.15), value: status)
        .animation(.easeInOut(duration: 0.2), value: thread.lastError)
    }

    /// While the mic is open, the words as they land; otherwise why the last
    /// attempt came back empty.
    private var status: String? {
        if thread.isHolding {
            if thread.isCancelingHold { return "松开取消" }
            return thread.partialTranscript.isEmpty
                ? "松开发送 · 上滑取消"
                : thread.partialTranscript
        }
        if thread.voiceState == .listening {
            return thread.partialTranscript.isEmpty ? "在听…" : thread.partialTranscript
        }
        return thread.voiceNotice
    }

    private var inputRow: some View {
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

            PushToTalkButton(thread: thread, diameter: Theme.tapTarget)
        }
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
