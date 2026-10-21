import SwiftUI

struct LiveDot: View {
    var isActive: Bool = true
    @Environment(\.sightTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false

    var body: some View {
        Circle()
            .fill(theme.paper)
            .frame(width: 6, height: 6)
            .opacity(isActive ? (breathing ? 0.28 : 1) : 0.22)
            .animation(
                reduceMotion || !isActive ? nil : SightMotion.breathe,
                value: breathing
            )
            .onAppear { breathing = true }
    }
}
