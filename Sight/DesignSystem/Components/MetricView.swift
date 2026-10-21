import SwiftUI

struct MetricView: View {
    let value: String
    let label: String
    var suffix: String?

    @Environment(\.sightTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(SightFont.number())
                    .foregroundStyle(theme.textPrimary)
                    .contentTransition(.numericText())
                if let suffix {
                    Text(suffix)
                        .font(SightFont.label())
                        .foregroundStyle(theme.textTertiary)
                }
            }
            Text(label)
                .font(SightFont.micro())
                .tracking(0.12)
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
