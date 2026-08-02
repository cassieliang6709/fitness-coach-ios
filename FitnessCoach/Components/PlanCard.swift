import SwiftUI

/// Plan card. `featured` shows the concrete exercise preview (name + sets ×
/// reps) so the library never hides what the session actually is.
struct PlanCard: View {
    let plan: WorkoutPlan
    var featured = false
    var selected = false

    var body: some View {
        VStack(alignment: .leading, spacing: featured ? 14 : 0) {
            HStack(spacing: 12) {
                PlanThumbnail(symbol: plan.symbol, size: featured ? 64 : 52)

                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.title)
                        .font(Theme.cardTitle)
                        .foregroundStyle(Theme.mainText)

                    if !featured {
                        Text(plan.tags.joined(separator: " · "))
                            .font(Theme.caption)
                            .foregroundStyle(Theme.secondaryText)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.primary)
                        .transition(.scale.combined(with: .opacity))
                }
            }

            if featured {
                VStack(spacing: 8) {
                    ForEach(plan.strengthExercises) { exercise in
                        HStack {
                            Text(exercise.name)
                                .font(Theme.body)
                                .foregroundStyle(Theme.mainText)
                            Spacer(minLength: 8)
                            Text(exercise.volumeLabel)
                                .font(Theme.caption)
                                .foregroundStyle(Theme.secondaryText)
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
        .card(selected: selected, padding: featured ? 16 : 14)
        .animation(.easeInOut(duration: 0.2), value: selected)
    }
}

struct PlanThumbnail: View {
    let symbol: String
    var size: CGFloat = 56

    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Theme.lightOrange)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: size * 0.42, weight: .medium))
                    .foregroundStyle(Theme.primary)
            )
    }
}
