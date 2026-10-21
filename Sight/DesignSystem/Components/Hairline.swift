import SwiftUI

struct Hairline: View {
    @Environment(\.sightTheme) private var theme
    var axis: Axis = .horizontal

    var body: some View {
        Rectangle()
            .fill(theme.line)
            .frame(
                width: axis == .vertical ? 0.5 : nil,
                height: axis == .horizontal ? 0.5 : nil
            )
    }
}
