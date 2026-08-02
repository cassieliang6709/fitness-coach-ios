import SwiftUI

/// /workout/review
struct ReviewView: View {
    @Environment(WorkoutSession.self) private var session
    @Binding var path: [Route]

    private var strengthRows: [(name: String, detail: String)] {
        session.plan.strengthExercises.map { ($0.name, $0.volumeLabel) }
    }

    var body: some View {
        MobileAppShell {
            PageHeader(title: "今天完成了") {
                Mascot(pose: .celebration, size: 40)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.cardSpacing) {
                    ReviewSummary(
                        title: session.plan.title,
                        symbol: "dumbbell.fill",
                        rows: strengthRows
                    )

                    ReviewSummary(
                        title: "有氧",
                        symbol: "figure.run",
                        rows: [(MockData.cardioName, "\(session.cardioTarget) 分钟")]
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
