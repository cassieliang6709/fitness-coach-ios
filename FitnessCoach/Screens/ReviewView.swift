import SwiftUI

/// /workout/review
///
/// Reports logged work only. An exercise the user never reached shows as
/// unfinished rather than getting a green tick.
struct ReviewView: View {
    @Environment(WorkoutSession.self) private var session
    @Binding var path: [Route]

    private var title: String {
        session.completionPercent >= 100 ? "今天完成了" : "今天练到这里"
    }

    var body: some View {
        MobileAppShell {
            PageHeader(title: title) {
                Mascot(pose: session.completionPercent >= 100 ? .celebration : .idle, size: 40)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.cardSpacing) {
                    ReviewSummary(
                        title: session.plan.title,
                        symbol: "dumbbell.fill",
                        outcomes: session.strengthOutcomes
                    )

                    ReviewSummary(
                        title: "有氧",
                        symbol: "figure.run",
                        outcomes: [session.cardioOutcome]
                    )

                    MemoryNoteCard(
                        title: "AI 记忆更新",
                        message: session.memoryUpdateText,
                        showsMascot: true
                    )

                    MetricRow(metrics: session.reviewMetrics)
                }
                .padding(.horizontal, Theme.pagePadding)
                .padding(.bottom, 16)
            }
        } bottom: {
            BottomBar {
                PrimaryButton(title: "完成") {
                    session.reset()
                    path.popToRoot()
                }
            }
        }
        .onAppear { session.enterReview() }
    }
}
