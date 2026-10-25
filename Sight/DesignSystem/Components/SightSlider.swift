import SwiftUI

struct SightSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 0.01
    /// What the slider controls, e.g. "Auto-sort confidence".
    var label: String?
    /// How the value is read out, e.g. "percent".
    var valueLabel: String = ""

    @Environment(\.sightTheme) private var theme

    private var progress: Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return min(1, max(0, (value - range.lowerBound) / span))
    }

    private var spokenValue: String {
        guard !valueLabel.isEmpty else { return String(format: "%.2f", value) }
        return "\(Int((value * 100).rounded())) \(valueLabel)"
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let knob: CGFloat = 12
            ZStack(alignment: .leading) {
                Capsule().fill(theme.line).frame(height: 2)
                Capsule()
                    .fill(theme.paper)
                    .frame(width: max(2, width * progress), height: 2)
                Circle()
                    .fill(theme.paper)
                    .frame(width: knob, height: knob)
                    .offset(x: max(0, (width - knob) * progress))
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let fraction = min(1, max(0, gesture.location.x / max(width, 1)))
                        let raw = range.lowerBound + fraction * (range.upperBound - range.lowerBound)
                        value = (raw / step).rounded() * step
                    }
            )
        }
        .frame(height: 20)
        .accessibilityElement()
        .accessibilityLabel(label ?? "Value")
        .accessibilityValue(spokenValue)
        // Without this the slider cannot be moved at all with VoiceOver or
        // from the keyboard.
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                value = min(range.upperBound, value + step)
            case .decrement:
                value = max(range.lowerBound, value - step)
            @unknown default:
                break
            }
        }
        .focusable()
    }
}
