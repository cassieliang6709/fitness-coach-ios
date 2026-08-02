import SwiftUI

/// /plans/leg-day
struct LegDayDetailView: View {
    @Environment(WorkoutSession.self) private var session
    @Binding var path: [Route]

    @State private var starred = false

    var body: some View {
        @Bindable var session = session

        return MobileAppShell {
            PageHeader(
                title: session.plan.title,
                style: .navBar,
                onBack: { path.removeLast() }
            ) {
                IconButton(
                    symbol: starred ? "star.fill" : "star",
                    tint: starred ? Theme.primary : Theme.secondaryText,
                    background: Theme.surface
                ) {
                    starred.toggle()
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.cardSpacing) {
                    PlanSourceSummary(plan: session.plan)

                    ForEach(session.plan.sections) { section in
                        if section.kind == .strength {
                            PlanSectionCard(section: section) {
                                ExerciseList(exercises: section.exercises) { exercise in
                                    path.append(.exerciseDetail(exercise.id))
                                }
                            }
                        } else {
                            PlanSectionCard(section: section)
                        }
                    }

                    if let note = session.plan.memoryNote {
                        MemoryNoteCard(title: note.title, message: note.body)
                    }

                    AIStyleSelector(selection: $session.aiStyle)
                        .padding(.top, 4)
                }
                .padding(.horizontal, Theme.pagePadding)
                .padding(.bottom, 16)
            }
        } bottom: {
            BottomBar {
                PrimaryButton(title: "开始陪练") {
                    session.enterStrength()
                    path.append(.strength)
                }
            }
        }
    }
}

private struct PlanSourceSummary: View {
    let plan: WorkoutPlan

    private var linkedExercises: [Exercise] {
        plan.sections.flatMap(\.exercises)
    }

    private var focusLabel: String {
        let labels = linkedExercises.compactMap(\.libraryMuscleLabel)
        let unique = labels.reduce(into: [String]()) { result, label in
            if !result.contains(label) { result.append(label) }
        }
        return unique.isEmpty ? "正在同步" : unique.joined(separator: " · ")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.primary)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Theme.lightOrange))

            VStack(alignment: .leading, spacing: 5) {
                Text("已连接你的动作库")
                    .font(Theme.bodyStrong)
                    .foregroundStyle(Theme.mainText)
                Text("\(linkedExercises.count) 个库内动作 · 重点 \(focusLabel)")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text("点任一动作查看发力部位、器械和动作要点。")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.primary)
            }
        }
        .card(filled: Theme.lightOrange.opacity(0.35), padding: 14)
    }
}
