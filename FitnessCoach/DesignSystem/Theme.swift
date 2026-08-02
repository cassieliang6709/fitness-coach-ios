import SwiftUI

enum Theme {

    // MARK: - Color

    static let primary = Color(hex: 0xFF5A1F)
    static let active = Color(hex: 0xFF6B1A)
    static let lightOrange = Color(hex: 0xFFF2EB)
    static let mainText = Color(hex: 0x171717)
    static let secondaryText = Color(hex: 0x71717A)
    static let border = Color(hex: 0xECECEC)
    static let background = Color(hex: 0xFFFFFF)
    static let surface = Color(hex: 0xFAFAFA)
    static let success = Color(hex: 0x22A559)
    static let mascotInk = Color(hex: 0x3D1C0C)

    // MARK: - Metrics

    static let pagePadding: CGFloat = 20
    static let cardRadius: CGFloat = 22
    static let buttonRadius: CGFloat = 22
    static let cardSpacing: CGFloat = 14
    static let tapTarget: CGFloat = 44

    // MARK: - Type

    static let pageTitle = Font.system(size: 28, weight: .bold)
    static let navTitle = Font.system(size: 18, weight: .semibold)
    static let cardTitle = Font.system(size: 17, weight: .semibold)
    static let body = Font.system(size: 15)
    static let bodyStrong = Font.system(size: 15, weight: .medium)
    static let caption = Font.system(size: 13)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

// MARK: - Card

struct CardModifier: ViewModifier {
    var selected = false
    var filled: Color = Theme.background
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .fill(filled)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .strokeBorder(
                        selected ? Theme.primary : Theme.border,
                        lineWidth: selected ? 1.5 : 1
                    )
            )
            .shadow(color: .black.opacity(0.03), radius: 6, y: 2)
    }
}

extension View {
    func card(
        selected: Bool = false,
        filled: Color = Theme.background,
        padding: CGFloat = 16
    ) -> some View {
        modifier(CardModifier(selected: selected, filled: filled, padding: padding))
    }

    /// Page-transition fade-in.
    func fadeIn() -> some View {
        modifier(FadeInModifier())
    }
}

private struct FadeInModifier: ViewModifier {
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .animation(.easeOut(duration: 0.25), value: visible)
            .onAppear { visible = true }
    }
}
