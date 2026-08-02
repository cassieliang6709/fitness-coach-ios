import SwiftUI

/// /plans
struct PlanLibraryView: View {
    @Environment(WorkoutSession.self) private var session
    @Binding var path: [Route]

    var body: some View {
        MobileAppShell {
            PageHeader(title: "训练计划库")

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.cardSpacing) {
                    HStack(spacing: 8) {
                        ForEach(session.memories) { memory in
                            MemoryChip(memory: memory)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.bottom, 2)

                    PlanCard(plan: session.plan, featured: true, selected: true)

                    ForEach(MockData.otherPlans) { plan in
                        PlanCard(plan: plan)
                    }
                }
                .padding(.horizontal, Theme.pagePadding)
                .padding(.bottom, 16)
            }
        } bottom: {
            BottomBar {
                PrimaryButton(title: "查看计划") {
                    path.append(.legDay)
                }
            }
        }
    }
}
