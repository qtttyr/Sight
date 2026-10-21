import SwiftUI

struct EmptyState: View {
    let icon: String
    let title: String
    var subtitle: String?

    @Environment(\.sightTheme) private var theme

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(theme.textFaint)
            Text(title)
                .font(SightFont.body())
                .foregroundStyle(theme.textSecondary)
            if let subtitle {
                Text(subtitle)
                    .font(SightFont.micro())
                    .tracking(0.06)
                    .foregroundStyle(theme.textFaint)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(SightSpace.xxl)
    }
}
