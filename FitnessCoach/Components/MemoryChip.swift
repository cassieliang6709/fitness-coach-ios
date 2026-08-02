import SwiftUI

/// Lightweight pill for an active AI memory. Intentionally not a card.
struct MemoryChip: View {
    let memory: WorkoutMemory

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: memory.category.symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.primary)
            Text(memory.text)
                .font(Theme.caption)
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(Capsule(style: .continuous).fill(Theme.surface))
        .overlay(Capsule(style: .continuous).strokeBorder(Theme.border, lineWidth: 1))
    }
}

/// Light-orange memory card used on the plan detail and review pages.
struct MemoryNoteCard: View {
    let title: String
    let message: String
    var showsMascot = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.mainText)
                Text(message)
                    .font(Theme.body)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if showsMascot {
                Mascot(pose: .point, size: 28)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .fill(Theme.lightOrange)
        )
    }
}
