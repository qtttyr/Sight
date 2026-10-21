import SwiftUI

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil

    @Environment(\.sightTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(SightFont.micro())
                .tracking(0.18)
                .foregroundStyle(theme.textTertiary)
            if let subtitle {
                Text(subtitle)
                    .font(SightFont.title())
                    .foregroundStyle(theme.textPrimary)
            }
        }
    }
}
