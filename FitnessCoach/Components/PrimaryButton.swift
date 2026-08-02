import SwiftUI

/// The single strong CTA allowed per page.
struct PrimaryButton: View {
    let title: String
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: Theme.buttonRadius, style: .continuous)
                        .fill(enabled ? Theme.primary : Theme.primary.opacity(0.4))
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

/// Quiet secondary action — never competes with the primary CTA.
struct GhostButton: View {
    let title: String
    var symbol: String?
    var tint: Color = Theme.primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let symbol {
                    Image(systemName: symbol).font(.system(size: 13, weight: .semibold))
                }
                Text(title).font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(
                Capsule(style: .continuous).fill(tint.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }
}
