import SwiftUI

struct PageHeader<Trailing: View>: View {
    enum Style {
        case large
        case navBar
    }

    let title: String
    /// Second line under a large title. Ignored by the nav-bar style.
    var subtitle: String?
    var style: Style = .large
    var onBack: (() -> Void)?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        Group {
            switch style {
            case .large:
                HStack(alignment: .center) {
                    if let onBack {
                        IconButton(symbol: "chevron.left", action: onBack)
                            .accessibilityLabel("返回")
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(Theme.pageTitle)
                            .foregroundStyle(Theme.mainText)

                        if let subtitle {
                            Text(subtitle)
                                .font(Theme.body)
                                .foregroundStyle(Theme.secondaryText)
                                .transition(.opacity)
                                .id(subtitle)
                        }
                    }
                    Spacer(minLength: 8)
                    trailing
                }
                .padding(.top, 8)
                .padding(.bottom, 14)

            case .navBar:
                ZStack {
                    Text(title)
                        .font(Theme.navTitle)
                        .foregroundStyle(Theme.mainText)

                    HStack {
                        if let onBack {
                            IconButton(symbol: "chevron.left", action: onBack)
                                .accessibilityLabel("返回")
                        }
                        Spacer()
                        trailing
                    }
                }
                .frame(height: Theme.tapTarget)
                .padding(.bottom, 6)
            }
        }
        .padding(.horizontal, Theme.pagePadding)
    }
}

extension PageHeader where Trailing == EmptyView {
    init(
        title: String,
        subtitle: String? = nil,
        style: Style = .large,
        onBack: (() -> Void)? = nil
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            style: style,
            onBack: onBack,
            trailing: { EmptyView() }
        )
    }
}

/// 44pt tap target with a light-surface backing.
struct IconButton: View {
    let symbol: String
    var tint: Color = Theme.mainText
    var background: Color = Theme.surface
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: Theme.tapTarget, height: Theme.tapTarget)
                .background(Circle().fill(background))
        }
        .buttonStyle(.plain)
    }
}
