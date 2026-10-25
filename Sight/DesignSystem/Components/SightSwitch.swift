import SwiftUI

struct SightSwitch: View {
    @Binding var isOn: Bool
    /// What the switch is about. Without it VoiceOver announces a bare
    /// "On" with no idea what it belongs to.
    var label: String?
    var help: String?

    @Environment(\.sightTheme) private var theme

    var body: some View {
        Button {
            withAnimation(SightMotion.quick) { isOn.toggle() }
        } label: {
            Capsule()
                .fill(isOn ? theme.paper : theme.lineStrong)
                .frame(width: 36, height: 20)
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle()
                        .fill(isOn ? theme.ink : theme.paper)
                        .frame(width: 14, height: 14)
                        .padding(3)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label ?? "Enabled")
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(help ?? "")
    }
}
