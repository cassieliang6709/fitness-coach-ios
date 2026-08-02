import SwiftUI

/// Numbered exercise list used on the plan detail page.
struct ExerciseList: View {
    let exercises: [Exercise]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                ExerciseRow(index: index + 1, exercise: exercise)
            }
        }
    }
}

struct ExerciseRow: View {
    let index: Int
    let exercise: Exercise

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(index)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.primary)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Theme.lightOrange))

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(Theme.bodyStrong)
                    .foregroundStyle(Theme.mainText)

                if let weightLabel = exercise.weightLabel {
                    Text(weightLabel)
                        .font(Theme.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
            }

            Spacer(minLength: 8)

            Text(exercise.volumeLabel)
                .font(Theme.caption)
                .foregroundStyle(Theme.secondaryText)
                .monospacedDigit()
        }
    }
}

/// Section container: "热身 · 8 分钟" style header plus its content.
struct PlanSectionCard<Content: View>: View {
    let section: PlanSection
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: section.kind.symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.primary)

                Text(section.kind.title)
                    .font(Theme.cardTitle)
                    .foregroundStyle(Theme.mainText)

                Text(section.duration)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondaryText)

                Spacer(minLength: 0)
            }

            if let subtitle = section.subtitle {
                Text(subtitle)
                    .font(Theme.body)
                    .foregroundStyle(Theme.secondaryText)
            }

            content
        }
        .card()
    }
}

extension PlanSectionCard where Content == EmptyView {
    init(section: PlanSection) {
        self.init(section: section, content: { EmptyView() })
    }
}
