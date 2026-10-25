import SwiftUI

struct SightSegment<Value: Hashable>: Identifiable {
    let id: Value
    let label: String
}

struct SightSegmented<Value: Hashable>: View {
    let options: [SightSegment<Value>]
    @Binding var selection: Value
    /// Names the group for VoiceOver, e.g. "Sorting mode".
    var label: String?

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
                // The selected segment used to be marked by colour alone,
                // which tells a screen reader nothing.
                .accessibilityLabel(option.label)
                .accessibilityAddTraits(selection == option.id ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(2)
        .background(theme.hover)
        .clipShape(Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label ?? "")
    }
}
