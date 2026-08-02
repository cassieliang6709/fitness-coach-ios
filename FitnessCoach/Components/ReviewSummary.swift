import SwiftUI

/// Completed-work checklist — concrete movements, not abstract stats.
struct ReviewSummary: View {
    let title: String
    let symbol: String
    let rows: [(name: String, detail: String)]

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

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.success)
            }

            VStack(spacing: 10) {
                ForEach(rows, id: \.name) { row in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.success)

                        Text(row.name)
                            .font(Theme.body)
                            .foregroundStyle(Theme.mainText)

                        Spacer(minLength: 8)

                        Text(row.detail)
                            .font(Theme.caption)
                            .foregroundStyle(Theme.secondaryText)
                            .monospacedDigit()
                    }
                }
            }
        }
        .card()
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
