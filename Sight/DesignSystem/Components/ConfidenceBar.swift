import SwiftUI

struct ConfidenceBar: View {
    let score: Float
    @Environment(\.sightTheme) private var theme

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(theme.line)
                Capsule()
                    .fill(theme.paper)
                    .frame(width: max(2, proxy.size.width * CGFloat(min(max(score, 0), 1))))
            }
        }
        .frame(height: 2)
        .animation(SightMotion.spring, value: score)
    }
}
