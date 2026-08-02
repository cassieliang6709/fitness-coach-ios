import SwiftUI

/// The app's two homes: talk to the coach, or look at the plan and what you
/// actually finished.
enum HomeTab: String, CaseIterable, Identifiable, Hashable {
    case chat
    case plan

    var id: String { rawValue }

    var label: String {
        switch self {
        case .chat: return "对话"
        case .plan: return "我的计划"
        }
    }

    var symbol: String {
        switch self {
        case .chat: return "bubble.left.and.bubble.right.fill"
        case .plan: return "checklist"
        }
    }
}

/// Floating pill navigation. Two capsules inside one capsule — the selected
/// one slides rather than cross-fades, so the switch reads as one control.
struct CapsuleTabBar: View {
    @Binding var selection: HomeTab

    @Namespace private var indicator

    var body: some View {
        HStack(spacing: 4) {
            ForEach(HomeTab.allCases) { tab in
                Button {
                    guard selection != tab else { return }
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                        selection = tab
                    }
                } label: {
                    segment(for: tab)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.label)
                .accessibilityAddTraits(selection == tab ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(4)
        .background(
            Capsule(style: .continuous)
                .fill(Theme.surface)
                .overlay(Capsule(style: .continuous).strokeBorder(Theme.border, lineWidth: 1))
        )
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }

    @ViewBuilder
    private func segment(for tab: HomeTab) -> some View {
        let active: Bool = selection == tab
        let tint: Color = active ? .white : Theme.secondaryText

        HStack(spacing: 6) {
            Image(systemName: tab.symbol)
                .font(.system(size: 13, weight: .semibold))
            Text(tab.label)
                .font(.system(size: 15, weight: .semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 20)
        .frame(height: Theme.tapTarget)
        .background {
            if active {
                Capsule(style: .continuous)
                    .fill(Theme.primary)
                    .matchedGeometryEffect(id: "tab-pill", in: indicator)
            }
        }
        .contentShape(Capsule(style: .continuous))
    }
}

#Preview {
    @Previewable @State var tab = HomeTab.chat
    return CapsuleTabBar(selection: $tab).padding()
}
