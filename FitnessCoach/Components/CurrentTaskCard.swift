import SwiftUI

/// Everything about "what am I doing right now" lives in this one card —
/// never split across widgets. Used sticky at the top of both coach pages.
struct CurrentTaskCard<Accessory: View>: View {
    let title: String
    let metrics: String
    let progressLabel: String
    var secondaryLabel: String?
    var progress: Double?
    var venue: String?
    var pose: MascotPose = .idle
    @ViewBuilder var accessory: Accessory

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    if let secondaryLabel {
                        Text(secondaryLabel)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.primary)
                    }

                    Text(title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Theme.mainText)

                    Text(metrics)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.secondaryText)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }

                Spacer(minLength: 8)

                Mascot(pose: pose, size: 30)
            }

            HStack(spacing: 8) {
                Text(progressLabel)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.mainText)
                    .monospacedDigit()
                    .contentTransition(.numericText())

                Spacer(minLength: 8)

                if let venue {
                    Text(venue)
                        .font(Theme.caption)
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(1)
                }
            }

            if let progress {
                WorkoutProgress(value: progress)
            }

            accessory
        }
        .card(padding: 16)
        .padding(.horizontal, Theme.pagePadding)
        .padding(.bottom, 10)
        .background(Theme.background)
    }
}

extension CurrentTaskCard where Accessory == EmptyView {
    init(
        title: String,
        metrics: String,
        progressLabel: String,
        secondaryLabel: String? = nil,
        progress: Double? = nil,
        venue: String? = nil,
        pose: MascotPose = .idle
    ) {
        self.init(
            title: title,
            metrics: metrics,
            progressLabel: progressLabel,
            secondaryLabel: secondaryLabel,
            progress: progress,
            venue: venue,
            pose: pose,
            accessory: { EmptyView() }
        )
    }
}
