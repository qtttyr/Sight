import SwiftUI

struct SightCard<Content: View>: View {
    var padding: CGFloat = SightSpace.xl
    @ViewBuilder let content: Content

    @Environment(\.sightTheme) private var theme

    init(padding: CGFloat = SightSpace.xl, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: SightRadius.card, style: .continuous)
                    .fill(theme.surface)
            }
            .overlay {
                RoundedRectangle(cornerRadius: SightRadius.card, style: .continuous)
                    .stroke(theme.line, lineWidth: 1)
            }
    }
}
