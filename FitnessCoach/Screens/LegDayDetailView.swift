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
                    ForEach(session.plan.sections) { section in
                        if section.kind == .strength {
                            PlanSectionCard(section: section) {
                                ExerciseList(exercises: section.exercises)
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
