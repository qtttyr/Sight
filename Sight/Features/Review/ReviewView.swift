import SightCore
import SwiftUI

struct ReviewView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.sightTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("REVIEW")
                        .font(SightFont.micro())
                        .tracking(0.18)
                        .foregroundStyle(theme.textTertiary)
                    Text("\(model.pendingDecisions.count) files")
                        .font(SightFont.title())
                        .foregroundStyle(theme.textPrimary)
                }
                Spacer()
                SightIconButton(systemName: "xmark", help: "Close") {
                    dismiss()
                }
            }
            .padding(.bottom, 24)

            Hairline()

            if model.pendingDecisions.isEmpty {
                EmptyState(
                    icon: "checkmark",
                    title: "All clear.",
                    subtitle: "Nothing is waiting for review."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(model.pendingDecisions) { decision in
                            ReviewRow(decision: decision)
                            Hairline()
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }

            Hairline()

            HStack(spacing: 12) {
                Button("Close") { dismiss() }
                    .buttonStyle(SightButtonStyle(kind: .ghost))

                Spacer()

                Button("Approve All") {
                    Task {
                        await model.approveAll()
                        dismiss()
                    }
                }
                .buttonStyle(SightButtonStyle(kind: .primary))
                .disabled(model.pendingDecisions.isEmpty)
            }
            .padding(.top, 18)
        }
        .padding(32)
        .frame(width: 720, height: 560)
        .background(theme.ink)
        .presentationBackground(theme.ink)
    }
}

private struct ReviewRow: View {
    let decision: RoutingDecision

    @Environment(AppModel.self) private var model
    @Environment(\.sightTheme) private var theme

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "doc")
                .font(.system(size: 12))
                .foregroundStyle(theme.textFaint)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 4) {
                Text(decision.file.name)
                    .font(SightFont.body())
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(decision.rule?.name ?? "Unrecognized")
                    .font(SightFont.micro())
                    .foregroundStyle(theme.textTertiary)
            }

            Spacer()

            ConfidenceBar(score: decision.score)
                .frame(width: 80)
            Text("\(Int(decision.score * 100))%")
                .font(SightFont.micro())
                .foregroundStyle(theme.textTertiary)
                .frame(width: 32, alignment: .trailing)

            SightIconButton(systemName: "checkmark", help: "Approve") {
                Task { await model.approve(decision) }
            }
            SightIconButton(systemName: "xmark", help: "Keep in place") {
                model.reject(decision)
            }
        }
        .padding(.vertical, 12)
    }
}
