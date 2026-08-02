import SwiftUI

/// Simple progress bar for the cardio task card.
struct WorkoutProgress: View {
    let value: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Theme.border)
                Capsule(style: .continuous)
                    .fill(Theme.primary)
                    .frame(width: max(0, min(1, value)) * proxy.size.width)
            }
        }
        .frame(height: 6)
        .animation(.easeInOut(duration: 0.4), value: value)
    }
}

/// Per-set dots for the strength card, with a check animation on completion.
struct SetProgressDots: View {
    let total: Int
    let completed: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { index in
                let done = index < completed
                ZStack {
                    Circle()
                        .fill(done ? Theme.success : Theme.border)
                    if done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: 16, height: 16)
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.7), value: completed)
    }
}

/// Live rest countdown.
struct RestTimer: View {
    let remaining: Int
    let onSkip: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "timer")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.primary)

            Text("休息")
                .font(Theme.bodyStrong)
                .foregroundStyle(Theme.mainText)

            Text(Format.clock(remaining))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.primary)
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))

            Spacer(minLength: 8)

            Button("跳过", action: onSkip)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.secondaryText)
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .frame(height: Theme.tapTarget)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.lightOrange)
        )
        .animation(.easeInOut(duration: 0.25), value: remaining)
    }
}
