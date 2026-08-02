import SwiftUI

/// Completed-work checklist — concrete movements, not abstract stats.
struct ReviewSummary: View {
    let title: String
    let symbol: String
    let outcomes: [ExerciseOutcome]

    private var allComplete: Bool { outcomes.allSatisfy(\.isComplete) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.primary)

                Text(title)
                    .font(Theme.cardTitle)
                    .foregroundStyle(Theme.mainText)

                Spacer(minLength: 8)

                Image(systemName: allComplete ? "checkmark.circle.fill" : "circle.dotted")
                    .font(.system(size: 18))
                    .foregroundStyle(allComplete ? Theme.success : Theme.secondaryText)
            }

            VStack(spacing: 10) {
                ForEach(outcomes) { outcome in
                    HStack(spacing: 8) {
                        Image(systemName: statusSymbol(for: outcome))
                            .font(.system(size: 14))
                            .foregroundStyle(statusTint(for: outcome))

                        Text(outcome.name)
                            .font(Theme.body)
                            .foregroundStyle(
                                outcome.isUntouched ? Theme.secondaryText : Theme.mainText
                            )

                        Spacer(minLength: 8)

                        Text(outcome.detail)
                            .font(Theme.caption)
                            .foregroundStyle(Theme.secondaryText)
                            .monospacedDigit()
                    }
                }
            }
        }
        .card()
    }

    private func statusSymbol(for outcome: ExerciseOutcome) -> String {
        if outcome.isComplete { return "checkmark.circle.fill" }
        return outcome.isUntouched ? "circle" : "circle.lefthalf.filled"
    }

    private func statusTint(for outcome: ExerciseOutcome) -> Color {
        if outcome.isComplete { return Theme.success }
        return outcome.isUntouched ? Theme.border : Theme.primary
    }
}

/// Three quiet numbers at the bottom of the review.
struct MetricRow: View {
    let metrics: [(value: String, label: String)]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(metrics, id: \.label) { metric in
                VStack(spacing: 4) {
                    Text(metric.value)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.mainText)
                        .monospacedDigit()
                    Text(metric.label)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.surface)
                )
            }
        }
    }
}
