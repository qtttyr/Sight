import SwiftUI

struct SightButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case ghost
    }

    let kind: Kind
    @Environment(\.sightTheme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SightFont.label())
            .foregroundStyle(kind == .primary ? theme.buttonLabel : theme.textPrimary)
            .padding(.horizontal, 16)
            .frame(height: 36)
            .background {
                RoundedRectangle(cornerRadius: SightRadius.control, style: .continuous)
                    .fill(kind == .primary ? theme.buttonFill : Color.clear)
            }
            .overlay {
                if kind == .ghost {
                    RoundedRectangle(cornerRadius: SightRadius.control, style: .continuous)
                        .stroke(theme.lineStrong, lineWidth: 1)
                }
            }
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(SightMotion.quick, value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

struct SightIconButton: View {
    let systemName: String
    var help: String = ""
    let action: () -> Void

    @Environment(\.sightTheme) private var theme
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isHovering ? theme.textPrimary : theme.textSecondary)
                .frame(width: 32, height: 32)
                .background {
                    RoundedRectangle(cornerRadius: SightRadius.control, style: .continuous)
                        .fill(isHovering ? theme.hover : Color.clear)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(help)
        .onHover { isHovering = $0 }
        .help(help)
    }
}
