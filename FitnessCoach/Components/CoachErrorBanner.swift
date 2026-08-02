import SwiftUI

/// A failed coach turn, said out loud to the user.
///
/// These were recorded on `CoachThread.lastError` and rendered nowhere, so a
/// dropped connection looked identical to the coach simply having nothing to
/// say. It sits over the input on every page that hosts a thread.
struct CoachErrorBanner: View {
    let message: String
    /// Nil when re-sending would repeat work that already took effect — a turn
    /// that failed after its tool calls ran must not be offered a retry.
    var onRetry: (() -> Void)?
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundStyle(Theme.warning)

            Text(message)
                .font(Theme.caption)
                .foregroundStyle(Theme.mainText)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 4)

            if let onRetry {
                Button("重试", action: onRetry)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.primary)
                    .buttonStyle(.plain)
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.secondaryText)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("忽略")
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.warningTint)
        )
    }
}
