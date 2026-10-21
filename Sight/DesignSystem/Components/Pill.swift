import SwiftUI

struct Pill: View {
    let text: String
    var isActive: Bool = false

    @Environment(\.sightTheme) private var theme

    var body: some View {
        Text(text)
            .font(SightFont.micro())
            .tracking(0.08)
            .foregroundStyle(isActive ? theme.buttonLabel : theme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isActive ? theme.buttonFill : theme.hover)
            .clipShape(Capsule())
    }
}
