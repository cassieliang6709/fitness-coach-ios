import SwiftUI

struct LabProgressStrip: View {
    let completedDays: Set<Int>
    let currentDay: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...7, id: \.self) { day in
                dayMarker(day)

                if day < 7 {
                    Rectangle()
                        .fill(day <= currentDay ? Theme.primary.opacity(0.22) : Theme.border)
                        .frame(height: 2)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Gym License 进度 \(completedDays.count) / 7")
    }

    private func dayMarker(_ day: Int) -> some View {
        let isCompleted = completedDays.contains(day)
        let isCurrent = day == currentDay && !isCompleted

        return ZStack {
            Circle()
                .fill(isCompleted ? Theme.primary : Theme.background)
                .overlay(
                    Circle().strokeBorder(
                        isCurrent ? Theme.primary : Theme.border,
                        lineWidth: isCurrent ? 2 : 1
                    )
                )

            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Text("\(day)")
                    .font(.system(size: 12, weight: isCurrent ? .bold : .medium))
                    .foregroundStyle(isCurrent ? Theme.primary : Theme.secondaryText)
            }
        }
        .frame(width: 32, height: 32)
    }
}

struct LabNotebookLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Theme.mainText)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.labHighlight)
            )
            .rotationEffect(.degrees(-1))
    }
}

struct LabChoiceButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(isSelected ? Theme.primary : Theme.secondaryText)

                Text(title)
                    .font(Theme.bodyStrong)
                    .foregroundStyle(Theme.mainText)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Theme.lightOrange : Theme.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? Theme.primary : Theme.border, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct LabBodyMap: View {
    var compact = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image("lab-body-map-chest")
                .resizable()
                .scaledToFit()
                .accessibilityLabel("人体正面示意图，胸部区域已高亮")

            Mascot(pose: .point, size: compact ? 74 : 94)
                .offset(x: compact ? -4 : -10, y: compact ? 2 : 8)

            HStack(spacing: 4) {
                Image(systemName: "arrow.left")
                Text("胸肌")
                    .font(.system(size: compact ? 13 : 15, weight: .bold))
            }
            .foregroundStyle(Theme.primary)
            .rotationEffect(.degrees(-4))
            .offset(x: compact ? 148 : 196, y: compact ? -122 : -168)
        }
        .frame(maxWidth: .infinity)
    }
}

struct LabSafetyNote: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.shield.fill")
                .foregroundStyle(Theme.warning)

            Text("只用能轻松控制的重量。出现尖锐疼痛、麻木、明显头晕或失去控制时立即停止。")
                .font(Theme.caption)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.warningTint)
        )
    }
}
