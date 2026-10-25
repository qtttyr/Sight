import SightCore
import SwiftUI

/// A deliberately tiny design system: one ink, one paper, and opacity steps.
/// Both themes use the exact same roles, which keeps every screen honest.
struct SightTheme {
    let scheme: ColorScheme

    var isDark: Bool { scheme == .dark }

    var ink: Color { isDark ? .black : .white }
    var paper: Color { isDark ? .white : .black }

    var surface: Color { isDark ? Color(white: 0.035) : Color(white: 0.965) }
    var surfaceRaised: Color { isDark ? Color(white: 0.07) : Color(white: 0.925) }

    var line: Color { paper.opacity(isDark ? 0.08 : 0.10) }
    var lineStrong: Color { paper.opacity(isDark ? 0.16 : 0.18) }

    var textPrimary: Color { paper }
    var textSecondary: Color { paper.opacity(0.72) }
    var textTertiary: Color { paper.opacity(0.58) }
    /// The lightest step still has to be readable. At 0.18 it was 1.55:1
    /// against the background — the folder path and every timestamp were
    /// invisible. 0.46 is 4.7:1, which clears WCAG AA.
    var textFaint: Color { paper.opacity(0.46) }

    var hover: Color { paper.opacity(isDark ? 0.05 : 0.045) }
    var active: Color { paper.opacity(isDark ? 0.08 : 0.07) }

    var buttonFill: Color { paper }
    var buttonLabel: Color { ink }

    var sidebar: Color { isDark ? Color(white: 0.02) : Color(white: 0.985) }
}

private struct SightThemeKey: EnvironmentKey {
    static let defaultValue = SightTheme(scheme: .dark)
}

extension EnvironmentValues {
    var sightTheme: SightTheme {
        get { self[SightThemeKey.self] }
        set { self[SightThemeKey.self] = newValue }
    }
}

private struct SightThemeModifier: ViewModifier {
    let mode: ThemeMode
    @Environment(\.colorScheme) private var systemScheme

    private var resolvedScheme: ColorScheme {
        switch mode {
        case .system: systemScheme
        case .dark: .dark
        case .light: .light
        }
    }

    func body(content: Content) -> some View {
        content
            .environment(\.sightTheme, SightTheme(scheme: resolvedScheme))
            .preferredColorScheme(mode == .system ? nil : resolvedScheme)
    }
}

extension View {
    func sightTheme(_ mode: ThemeMode) -> some View {
        modifier(SightThemeModifier(mode: mode))
    }
}
