import SwiftUI

struct SightSwitch: View {
    @Binding var isOn: Bool
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
        .accessibilityValue(isOn ? "On" : "Off")
    }
}
