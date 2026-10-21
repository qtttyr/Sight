import SightCore
import SwiftUI

struct EventRow: View {
    let event: SortEvent

    @Environment(\.sightTheme) private var theme

    private var icon: String {
        switch event.outcome {
        case .moved: "arrow.right"
        case .review: "eye"
        case .unrecognized: "questionmark"
        case .skipped: "minus"
        case .failed: "exclamationmark"
        case .undone: "arrow.uturn.backward"
        }
    }

    private var time: String {
        event.date.formatted(date: .omitted, time: .shortened)
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(time)
                .font(SightFont.micro())
                .foregroundStyle(theme.textFaint)
                .frame(width: 54, alignment: .leading)

            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(event.outcome == .failed ? theme.paper : theme.textTertiary)
                .frame(width: 14)

            Text(event.fileName)
                .font(SightFont.body())
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 12)

            if let category = event.category {
                Text(category)
                    .font(SightFont.micro())
                    .tracking(0.06)
                    .foregroundStyle(theme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(theme.hover)
                    .clipShape(Capsule())
            }

            if let score = event.score {
                ConfidenceBar(score: score)
                    .frame(width: 44)
                Text("\(Int(score * 100))")
                    .font(SightFont.micro())
                    .foregroundStyle(theme.textTertiary)
                    .frame(width: 22, alignment: .trailing)
            }
        }
        .frame(height: 34)
    }
}
