import SwiftUI

struct SightSegment<Value: Hashable>: Identifiable {
    let id: Value
    let label: String
}

struct SightSegmented<Value: Hashable>: View {
    let options: [SightSegment<Value>]
    @Binding var selection: Value

    @Environment(\.sightTheme) private var theme

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options) { option in
                Button {
                    withAnimation(SightMotion.quick) {
                        selection = option.id
                    }
                } label: {
                    Text(option.label)
                        .font(SightFont.micro())
                        .tracking(0.08)
                        .foregroundStyle(selection == option.id ? theme.buttonLabel : theme.textTertiary)
                        .padding(.horizontal, 12)
                        .frame(height: 26)
                        .background {
                            if selection == option.id {
                                Capsule().fill(theme.buttonFill)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(theme.hover)
        .clipShape(Capsule())
    }
}
