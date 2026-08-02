import SwiftUI

/// The full server catalogue when connected, with the hand-curated 50 movement
/// set retained as an offline fallback.
struct ExerciseLibraryView: View {
    @Environment(WorkoutSession.self) private var session
    @Environment(\.workoutStore) private var store
    @Binding var path: [Route]

    @State private var searchText = ""
    @State private var selectedLevel: ExerciseLevel?
    @State private var selectedMuscle: MuscleGroup?
    @State private var expandedExerciseID: String?

    private var profile: UserProfile {
        store?.profile() ?? UserProfile()
    }

    private var safeExercises: [ExerciseDefinition] {
        ExerciseCatalog.available(for: profile)
    }

    private var hiddenCount: Int {
        ExerciseCatalog.all.count - safeExercises.count
    }

    private var usesServerCatalog: Bool {
        !session.exerciseCatalog.isEmpty
    }

    private var filteredServerExercises: [ExerciseCatalogItem] {
        session.exerciseCatalog.filter { exercise in
            let matchesMuscle =
                selectedMuscle.map { exercise.muscleGroups.contains($0) } ?? true
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesSearch =
                query.isEmpty
                || exercise.displayName.localizedCaseInsensitiveContains(query)
                || exercise.englishName.localizedCaseInsensitiveContains(query)
                || exercise.muscleLabel.localizedCaseInsensitiveContains(query)
                || exercise.equipmentLabel.localizedCaseInsensitiveContains(query)
            return matchesMuscle && matchesSearch
        }
    }

    private var filteredExercises: [ExerciseDefinition] {
        safeExercises.filter { exercise in
            let matchesLevel = selectedLevel == nil || exercise.level == selectedLevel
            let matchesMuscle =
                selectedMuscle.map { muscle in
                    exercise.primaryMuscles.contains(muscle)
                        || exercise.secondaryMuscles.contains(muscle)
                } ?? true
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesSearch =
                query.isEmpty
                || exercise.name.localizedCaseInsensitiveContains(query)
                || exercise.englishName.localizedCaseInsensitiveContains(query)
                || exercise.muscleLabel.localizedCaseInsensitiveContains(query)
                || exercise.equipmentLabel.localizedCaseInsensitiveContains(query)
            return matchesLevel && matchesMuscle && matchesSearch
        }
    }

    var body: some View {
        MobileAppShell {
            PageHeader(
                title: "动作库",
                subtitle: usesServerCatalog
                    ? "已连接完整库 · \(session.exerciseCatalog.count) 个动作"
                    : "离线精选 · \(safeExercises.count) / 50 个适合当前设置",
                style: .large,
                onBack: { path.removeLast() }
            ) {
                RiveMascot(pose: .dumbbell, size: 76)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.cardSpacing) {
                    safetySummary
                    #if DEBUG
                    riveLabTeaser
                    #endif
                    searchField
                    if !usesServerCatalog {
                        levelFilters
                    }
                    muscleFilters

                    HStack(alignment: .firstTextBaseline) {
                        Text(usesServerCatalog ? "全部动作" : "可用动作")
                            .font(Theme.cardTitle)
                            .foregroundStyle(Theme.mainText)
                        Spacer()
                        Text(
                            "\(usesServerCatalog ? filteredServerExercises.count : filteredExercises.count) 个"
                        )
                        .font(Theme.caption)
                        .foregroundStyle(Theme.secondaryText)
                    }
                    .padding(.top, 2)

                    if session.isCatalogLoading && !usesServerCatalog {
                        ProgressView("正在连接完整动作库…")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 36)
                    } else if usesServerCatalog && filteredServerExercises.isEmpty {
                        emptyState
                    } else if usesServerCatalog {
                        ForEach(filteredServerExercises) { exercise in
                            ServerExerciseLibraryCard(
                                exercise: exercise,
                                expanded: expandedExerciseID == exercise.id,
                                onToggle: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        expandedExerciseID =
                                            expandedExerciseID == exercise.id ? nil : exercise.id
                                    }
                                }
                            )
                        }
                    } else if filteredExercises.isEmpty {
                        emptyState
                    } else {
                        ForEach(filteredExercises) { exercise in
                            ExerciseLibraryCard(
                                exercise: exercise,
                                expanded: expandedExerciseID == exercise.id,
                                onToggle: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        expandedExerciseID =
                                            expandedExerciseID == exercise.id ? nil : exercise.id
                                    }
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal, Theme.pagePadding)
                .padding(.bottom, 24)
            }
        }
    }

    #if DEBUG
    private var riveLabTeaser: some View {
        Button {
            path.append(.riveLab)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.primary)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Theme.lightOrange))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Rive 动作状态机实验")
                        .font(Theme.bodyStrong)
                        .foregroundStyle(Theme.mainText)
                    Text("切换 Beginner / Intermediate / Expert")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.secondaryText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.secondaryText)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .card()
        .accessibilityIdentifier("rive-lab-entry")
    }
    #endif

    private var safetySummary: some View {
        HStack(alignment: .center, spacing: 12) {
            Mascot(pose: .point, size: 54)

            VStack(alignment: .leading, spacing: 4) {
                Text(usesServerCatalog ? "完整动作库已连接" : "已经替你筛过一遍")
                    .font(Theme.bodyStrong)
                    .foregroundStyle(Theme.mainText)

                Text(safetySummaryText)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text("筛选不替代诊断，持续或加重的不适请咨询专业人士。")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .card(filled: Theme.lightOrange.opacity(0.55), padding: 14)
    }

    private var safetySummaryText: String {
        if usesServerCatalog {
            return "计划生成会按你已确认的器械筛选；浏览完整目录不代表医疗安全推荐。"
        }
        let venue = "当前场地：\(profile.venue.label)"
        guard hiddenCount > 0 else { return "\(venue)。当前没有需要隐藏的动作。" }

        let conditions = profile.conditions.map(\.label).joined(separator: "、")
        if conditions.isEmpty {
            return "\(venue)，已隐藏 \(hiddenCount) 个不适合该场地的动作。"
        }
        return "\(venue)，注意\(conditions)。已隐藏 \(hiddenCount) 个不合适的动作。"
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.secondaryText)

            TextField("搜索动作、部位或器械", text: $searchText)
                .font(Theme.body)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.secondaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清除搜索")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.border)
        )
    }

    private var levelFilters: some View {
        HStack(spacing: 8) {
            FilterChip(title: "全部等级", selected: selectedLevel == nil) {
                selectedLevel = nil
            }
            ForEach(ExerciseLevel.allCases) { level in
                FilterChip(title: level.label, selected: selectedLevel == level) {
                    selectedLevel = level
                }
            }
        }
    }

    private var muscleFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "全部部位", selected: selectedMuscle == nil) {
                    selectedMuscle = nil
                }
                ForEach(MuscleGroup.libraryFilters) { muscle in
                    FilterChip(title: muscle.label, selected: selectedMuscle == muscle) {
                        selectedMuscle = muscle
                    }
                }
            }
        }
        .contentMargins(.horizontal, 0, for: .scrollContent)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Mascot(pose: .listening, size: 72)
            Text("没有匹配的动作")
                .font(Theme.bodyStrong)
                .foregroundStyle(Theme.mainText)
            Text("换一个关键词或筛选条件试试。")
                .font(Theme.caption)
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }
}

// MARK: - Entry card

private struct ServerExerciseLibraryCard: View {
    let exercise: ExerciseCatalogItem
    let expanded: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    Mascot(pose: .dumbbell, size: 62)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.displayName)
                            .font(Theme.cardTitle)
                            .foregroundStyle(Theme.mainText)

                        if !exercise.englishName.isEmpty {
                            Text(exercise.englishName)
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.secondaryText)
                        }

                        Text(exercise.muscleLabel)
                            .font(Theme.caption)
                            .foregroundStyle(Theme.primary)
                    }

                    Spacer(minLength: 4)

                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.secondaryText)
                }

                HStack(spacing: 12) {
                    MetadataLabel(symbol: "number", text: "动作 ID \(exercise.id)")
                    MetadataLabel(symbol: "dumbbell", text: exercise.equipmentLabel)
                }

                if expanded {
                    Divider().overlay(Theme.border)

                    if exercise.steps.isEmpty {
                        Text("这条动作暂时没有分步说明，训练前请确认动作姿势。")
                            .font(Theme.caption)
                            .foregroundStyle(Theme.secondaryText)
                    } else {
                        VStack(alignment: .leading, spacing: 9) {
                            Text("动作要点")
                                .font(Theme.bodyStrong)
                                .foregroundStyle(Theme.mainText)

                            ForEach(Array(exercise.steps.enumerated()), id: \.offset) {
                                index, tip in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("\(index + 1)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Theme.primary)
                                        .frame(width: 18, height: 18)
                                        .background(Circle().fill(Theme.lightOrange))

                                    Text(tip)
                                        .font(Theme.body)
                                        .foregroundStyle(Theme.mainText)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .card(selected: expanded)
        .accessibilityHint(expanded ? "轻点收起动作要点" : "轻点查看动作要点")
    }
}

private struct ExerciseLibraryCard: View {
    let exercise: ExerciseDefinition
    let expanded: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    ExerciseArtwork(exercise: exercise, size: 76)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(exercise.name)
                                .font(Theme.cardTitle)
                                .foregroundStyle(Theme.mainText)
                            LevelBadge(level: exercise.level)
                        }

                        Text(exercise.englishName)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.secondaryText)

                        Text(exercise.muscleLabel)
                            .font(Theme.caption)
                            .foregroundStyle(Theme.primary)
                    }

                    Spacer(minLength: 4)

                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.secondaryText)
                }

                HStack(spacing: 12) {
                    MetadataLabel(symbol: "repeat", text: exercise.prescription)
                    MetadataLabel(symbol: "dumbbell", text: exercise.equipmentLabel)
                }

                if expanded {
                    Divider().overlay(Theme.border)

                    VStack(alignment: .leading, spacing: 9) {
                        Text("动作要点")
                            .font(Theme.bodyStrong)
                            .foregroundStyle(Theme.mainText)

                        ForEach(Array(exercise.coachingTips.enumerated()), id: \.offset) {
                            index, tip in
                            HStack(alignment: .top, spacing: 8) {
                                Text("\(index + 1)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Theme.primary)
                                    .frame(width: 18, height: 18)
                                    .background(Circle().fill(Theme.lightOrange))

                                Text(tip)
                                    .font(Theme.body)
                                    .foregroundStyle(Theme.mainText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    if !exercise.contraindications.isEmpty {
                        HStack(alignment: .top, spacing: 7) {
                            Image(systemName: "exclamationmark.shield.fill")
                                .foregroundStyle(Theme.primary)
                            Text(
                                "以下部位不适时不推荐："
                                    + exercise.contraindications.map(\.label).sorted()
                                    .joined(separator: "、")
                            )
                            .font(Theme.caption)
                            .foregroundStyle(Theme.secondaryText)
                        }
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .card(selected: expanded)
        .accessibilityHint(expanded ? "轻点收起动作要点" : "轻点查看动作要点")
    }
}

private struct MetadataLabel: View {
    let symbol: String
    let text: String

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.system(size: 12))
            .foregroundStyle(Theme.secondaryText)
            .lineLimit(1)
    }
}

private struct LevelBadge: View {
    let level: ExerciseLevel

    var body: some View {
        Text(level.label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(level.tint)
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(Capsule().fill(level.tint.opacity(0.1)))
    }
}

private struct FilterChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? .white : Theme.secondaryText)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(
                    Capsule(style: .continuous)
                        .fill(selected ? Theme.primary : Theme.surface)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(selected ? Color.clear : Theme.border)
                )
        }
        .buttonStyle(.plain)
    }
}

private extension ExerciseLevel {
    var tint: Color {
        switch self {
        case .beginner: return Theme.success
        case .intermediate: return Theme.primary
        case .advanced: return Color(hex: 0x7C3AED)
        }
    }
}

// MARK: - Library entry point

struct ExerciseLibraryTeaser: View {
    @Environment(WorkoutSession.self) private var session
    let action: () -> Void

    private var count: Int {
        session.exerciseCatalog.isEmpty ? ExerciseCatalog.all.count : session.exerciseCatalog.count
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Mascot(pose: .stretch, size: 72)

                VStack(alignment: .leading, spacing: 5) {
                    Text("\(count) 个动作库")
                        .font(Theme.cardTitle)
                        .foregroundStyle(Theme.mainText)
                    Text(
                        session.exerciseCatalog.isEmpty
                            ? "离线精选，按部位、等级和身体状态筛选"
                            : "与 AI 计划同一套完整动作数据"
                    )
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 6)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.primary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .card(filled: Theme.lightOrange.opacity(0.45))
        .accessibilityLabel("打开 \(count) 个动作库")
    }
}
