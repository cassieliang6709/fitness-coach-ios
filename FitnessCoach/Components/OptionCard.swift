import SwiftUI

/// One answer in the welcome flow. Same card language as the plan library —
/// icon tile, title, one line of consequence — so onboarding doesn't look like
/// a different app.
struct OptionCard: View {
    let symbol: String
    let title: String
    var detail: String?
    let selected: Bool
    /// Multi-select answers get a square mark, single-select a round one.
    var multiple = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(selected ? Theme.primary.opacity(0.14) : Theme.surface)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: symbol)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(selected ? Theme.primary : Theme.secondaryText)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(Theme.cardTitle)
                        .foregroundStyle(Theme.mainText)

                    if let detail {
                        Text(detail)
                            .font(Theme.caption)
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }
                }

                Spacer(minLength: 8)

                Image(systemName: mark)
                    .font(.system(size: 20))
                    .foregroundStyle(selected ? Theme.primary : Theme.border)
            }
            .card(selected: selected, padding: 14)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.18), value: selected)
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
        // Stable handle for UI tests — the composed label also carries `detail`.
        .accessibilityIdentifier("option-\(title)")
    }

    private var mark: String {
        if multiple {
            return selected ? "checkmark.square.fill" : "square"
        }
        return selected ? "checkmark.circle.fill" : "circle"
    }
}
