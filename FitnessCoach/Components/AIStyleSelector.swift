import SwiftUI

/// Tone picker. Explanations are not persistent — they surface as a short
/// tooltip when a style is tapped.
struct AIStyleSelector: View {
    @Binding var selection: AIStyle

    @State private var tooltipStyle: AIStyle?
    @State private var tooltipTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("AI 风格")
                    .font(Theme.cardTitle)
                    .foregroundStyle(Theme.mainText)
                Spacer(minLength: 8)

                if let tooltipStyle {
                    Text(tooltipStyle.tooltip)
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous).fill(Theme.mainText.opacity(0.9))
                        )
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }

            HStack(spacing: 8) {
                ForEach(AIStyle.allCases) { style in
                    Button {
                        selection = style
                        showTooltip(for: style)
                    } label: {
                        Text(style.label)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(selection == style ? .white : Theme.secondaryText)
                            .frame(maxWidth: .infinity)
                            .frame(height: Theme.tapTarget)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(selection == style ? Theme.primary : Theme.surface)
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(
                                        selection == style ? .clear : Theme.border,
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selection)
        .animation(.easeInOut(duration: 0.2), value: tooltipStyle)
    }

    private func showTooltip(for style: AIStyle) {
        tooltipStyle = style
        tooltipTask?.cancel()
        tooltipTask = Task {
            try? await Task.sleep(for: .seconds(2.5))
            if Task.isCancelled { return }
            tooltipStyle = nil
        }
    }
}
