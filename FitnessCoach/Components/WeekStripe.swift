import SwiftUI

/// This week at a glance: seven dots, Monday first, filled for the days that
/// actually have a finished session. Today is ringed even when it's empty.
struct WeekStripe: View {
    let stats: TrainingStats

    private var todayIndex: Int {
        let weekday = TrainingStats.trainingWeek.component(.weekday, from: .now)
        return (weekday + 5) % 7
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("本周训练")
                    .font(Theme.cardTitle)
                    .foregroundStyle(Theme.mainText)

                Spacer(minLength: 8)

                Text("\(stats.weeklyDone) / \(stats.weeklyTarget) 次")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.primary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }

            HStack(spacing: 0) {
                ForEach(Array(TrainingStats.weekdayLabels.enumerated()), id: \.offset) {
                    index, day in
                    dayCell(index: index, label: day)
                        .frame(maxWidth: .infinity)
                }
            }

            WorkoutProgress(value: stats.weeklyProgress)
        }
        .card()
    }

    private func dayCell(index: Int, label: String) -> some View {
        let done = stats.completedWeekdays.contains(index)
        let today = index == todayIndex

        return VStack(spacing: 6) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(today ? Theme.primary : Theme.secondaryText)

            ZStack {
                Circle()
                    .fill(done ? Theme.primary : Theme.surface)
                    .frame(width: 28, height: 28)

                if today && !done {
                    Circle()
                        .strokeBorder(Theme.primary, lineWidth: 1.5)
                        .frame(width: 28, height: 28)
                }

                if done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
    }
}
