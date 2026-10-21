import SwiftUI

struct SightSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 0.01

    @Environment(\.sightTheme) private var theme

    private var progress: Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return min(1, max(0, (value - range.lowerBound) / span))
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
        .accessibilityValue("\(value)")
    }
}
