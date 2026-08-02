import SwiftUI

/// A shared destination for movements opened from either an AI plan or the
/// exercise library. The route keeps the source page on the stack, so the
/// visible back button always returns to the user's previous context.
struct ExerciseDetailView: View {
    @Environment(WorkoutSession.self) private var session
    @Environment(\.workoutStore) private var store

    let exerciseID: String
    @Binding var path: [Route]

    private var definition: ExerciseDefinition? {
        ExerciseCatalog.exercise(id: exerciseID)
    }

    private var catalogDefinition: ExerciseCatalogItem? {
        session.catalogExercise(id: exerciseID)
    }

    private var prescription: Exercise? {
        session.plan.sections
            .flatMap(\.exercises)
            .first { $0.id == exerciseID }
    }

    private var isAvailable: Bool {
        guard let definition else { return false }
        return definition.isAvailable(for: store?.profile() ?? UserProfile())
    }

    var body: some View {
        MobileAppShell {
            PageHeader(
                title: definition?.name ?? catalogDefinition?.displayName ?? prescription?.name
                    ?? "动作详情",
                style: .navBar,
                onBack: { path.removeLast() }
            )

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.cardSpacing) {
                    if let definition {
                        identityCard(definition)

                        if let prescription {
                            currentPlanCard(prescription)
                        }

                        coachingCard(definition)
                        safetyCard(definition)
                    } else if let catalogDefinition {
                        catalogIdentityCard(catalogDefinition)

                        if let prescription {
                            currentPlanCard(prescription)
                        }

                        catalogCoachingCard(catalogDefinition)
                        remoteSourceCard
                    } else if let prescription {
                        remoteIdentityCard(prescription)
                        currentPlanCard(prescription)
                        remoteCoachingCard(prescription)
                        remoteSourceCard
                    } else {
                        unavailableState
                    }
                }
                .padding(.horizontal, Theme.pagePadding)
                .padding(.bottom, 24)
            }
        }
    }

    private func identityCard(_ exercise: ExerciseDefinition) -> some View {
        HStack(spacing: 14) {
            Mascot(pose: exercise.mascotPose, size: 78)

            VStack(alignment: .leading, spacing: 6) {
                Text(exercise.englishName)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondaryText)

                Text(exercise.muscleLabel)
                    .font(Theme.cardTitle)
                    .foregroundStyle(Theme.primary)

                Label(exercise.equipmentLabel, systemImage: "dumbbell")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondaryText)

                Label(exercise.level.label, systemImage: "chart.bar.fill")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondaryText)
            }

            Spacer(minLength: 0)
        }
        .card(selected: true)
    }

    private func currentPlanCard(_ exercise: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("在今天的 AI 计划里")
                .font(Theme.bodyStrong)
                .foregroundStyle(Theme.mainText)

            HStack {
                Text(exercise.volumeLabel)
                    .font(Theme.cardTitle)
                    .foregroundStyle(Theme.primary)

                Spacer()

                if let weight = exercise.weightLabel {
                    Text(weight)
                        .font(Theme.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
            }

            if let note = exercise.alternative, !note.isEmpty {
                Text(note)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .card(filled: Theme.lightOrange.opacity(0.35), padding: 14)
    }

    private func remoteIdentityCard(_ exercise: Exercise) -> some View {
        HStack(spacing: 14) {
            Mascot(pose: .dumbbell, size: 78)

            VStack(alignment: .leading, spacing: 6) {
                Text("云端动作库")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondaryText)

                Text(exercise.libraryMuscleLabel ?? "全身")
                    .font(Theme.cardTitle)
                    .foregroundStyle(Theme.primary)

                if let equipment = exercise.libraryEquipmentLabel {
                    Label(equipment, systemImage: "dumbbell")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
            }

            Spacer(minLength: 0)
        }
        .card(selected: true)
    }

    private func catalogIdentityCard(_ exercise: ExerciseCatalogItem) -> some View {
        HStack(spacing: 14) {
            Mascot(pose: .dumbbell, size: 78)

            VStack(alignment: .leading, spacing: 6) {
                if !exercise.englishName.isEmpty {
                    Text(exercise.englishName)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.secondaryText)
                }

                Text(exercise.muscleLabel)
                    .font(Theme.cardTitle)
                    .foregroundStyle(Theme.primary)

                Label(exercise.equipmentLabel, systemImage: "dumbbell")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondaryText)

                Label("动作 ID \(exercise.id)", systemImage: "number")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondaryText)
            }

            Spacer(minLength: 0)
        }
        .card(selected: true)
    }

    private func coachingCard(_ exercise: ExerciseDefinition) -> some View {
        VStack(alignment: .leading, spacing: 12) {
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
                        .font(Theme.body)
                        .foregroundStyle(Theme.mainText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .card()
    }

    @ViewBuilder
    private func catalogCoachingCard(_ exercise: ExerciseCatalogItem) -> some View {
        if exercise.steps.isEmpty {
            MemoryNoteCard(
                title: "动作要点暂缺",
                message: "这条库内动作暂时没有分步说明，训练前请确认动作姿势。"
            )
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("动作要点")
                    .font(Theme.cardTitle)
                    .foregroundStyle(Theme.mainText)

                ForEach(Array(exercise.steps.enumerated()), id: \.offset) { index, tip in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.primary)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(Theme.lightOrange))

                        Text(tip)
                            .font(Theme.body)
                            .foregroundStyle(Theme.mainText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .card()
        }
    }

    @ViewBuilder
    private func remoteCoachingCard(_ exercise: Exercise) -> some View {
        if exercise.libraryCoachingTips.isEmpty {
            MemoryNoteCard(
                title: "动作要点正在同步",
                message: "计划已经导入；详细步骤暂时不可用，训练前请先确认动作姿势。"
            )
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("动作要点")
                    .font(Theme.cardTitle)
                    .foregroundStyle(Theme.mainText)

                ForEach(Array(exercise.libraryCoachingTips.enumerated()), id: \.offset) {
                    index, tip in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.primary)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(Theme.lightOrange))

                        Text(tip)
                            .font(Theme.body)
                            .foregroundStyle(Theme.mainText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .card()
        }
    }

    private var remoteSourceCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.shield.fill")
                .foregroundStyle(Theme.success)

            VStack(alignment: .leading, spacing: 4) {
                Text("已从生成计划的动作库导入")
                    .font(Theme.bodyStrong)
                    .foregroundStyle(Theme.mainText)
                Text("这条资料与 AI 计划使用同一个动作 ID；目录浏览不等于医疗安全推荐。")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .card(filled: Theme.surface, padding: 14)
    }

    private func safetyCard(_ exercise: ExerciseDefinition) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isAvailable ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                .foregroundStyle(isAvailable ? Theme.success : Theme.primary)

            VStack(alignment: .leading, spacing: 4) {
                Text(isAvailable ? "符合你当前的场地与身体设置" : "当前设置下不建议安排")
                    .font(Theme.bodyStrong)
                    .foregroundStyle(Theme.mainText)

                Text(safetyText(exercise))
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .card(filled: isAvailable ? Theme.surface : Theme.lightOrange.opacity(0.45), padding: 14)
    }

    private func safetyText(_ exercise: ExerciseDefinition) -> String {
        guard !exercise.contraindications.isEmpty else {
            return "动作库没有为这个动作标记与你当前资料冲突的部位。"
        }
        let labels = exercise.contraindications.map(\.label).sorted().joined(separator: "、")
        return "\(labels)不适时不推荐；持续或加重的不适请咨询专业人士。"
    }

    private var unavailableState: some View {
        VStack(spacing: 10) {
            Mascot(pose: .listening, size: 84)
            Text("动作资料暂时不可用")
                .font(Theme.cardTitle)
                .foregroundStyle(Theme.mainText)
            Text("返回计划选择其他动作。")
                .font(Theme.caption)
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}
