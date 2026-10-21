import SwiftUI

struct VectorFingerprint: View {
    let values: [Float]
    var barCount: Int = 32

    @Environment(\.sightTheme) private var theme

    private var normalized: [Float] {
        guard !values.isEmpty else { return Array(repeating: 0, count: barCount) }
        let maximum = max(values.max() ?? 1, 0.0001)
        return values.map { min(1, max(0, $0 / maximum)) }
    }

    var body: some View {
        GeometryReader { proxy in
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(normalized.prefix(barCount).enumerated()), id: \.offset) { _, value in
                    Capsule()
                        .fill(theme.paper.opacity(0.16 + 0.84 * Double(value)))
                        .frame(height: max(2, proxy.size.height * CGFloat(value)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .frame(height: 30)
    }
}
