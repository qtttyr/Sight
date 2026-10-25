import SightCore
import SwiftUI

struct ReviewView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.sightTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    /// The proposals that clear the bar *right now*. The count and the action
    /// have to use the same rule, or the button lies about what it will do.
    private var confidentDecisions: [RoutingDecision] {
        model.pendingDecisions.filter { $0.score >= model.config.confidence }
    }

    private var confidentCount: Int {
        confidentDecisions.count
    }

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
                    if !model.pendingDecisions.isEmpty {
                        Text(subtitle)
                            .font(SightFont.micro())
                            .foregroundStyle(theme.textTertiary)
                    }
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
                    .disabled(model.isApproving)

                Spacer()

                if model.isApproving {
                    Text("Moving \(model.approvingCount) of \(model.approvingTotal)…")
                        .font(SightFont.micro())
                        .foregroundStyle(theme.textTertiary)
                } else if confidentCount > 0, confidentCount < model.pendingDecisions.count {
                    Button("Approve \(confidentCount) sure") {
                        Task {
                            await model.approveAll(minimumScore: model.config.confidence)
                        }
                    }
                    .buttonStyle(SightButtonStyle(kind: .ghost))
                }

                Button("Approve All") {
                    Task {
                        await model.approveAll()
                        if model.pendingDecisions.isEmpty { dismiss() }
                    }
                }
                .buttonStyle(SightButtonStyle(kind: .primary))
                .disabled(model.pendingDecisions.isEmpty || model.isApproving)
            }
            .padding(.top, 18)
        }
        .padding(32)
        .frame(width: 760, height: 580)
        .background(theme.ink)
        .presentationBackground(theme.ink)
    }

    private var subtitle: String {
        let doubtful = model.pendingDecisions.count - confidentCount
        if doubtful == 0 { return "Everything is a confident match. One click sorts it all." }
        return "\(confidentCount) confident, \(doubtful) worth a quick look. Change a category with the menu."
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
                if let renamed = decision.suggestedName {
                    Text("→ \(renamed)")
                        .font(SightFont.micro())
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Text(decision.reason ?? "")
                    .font(SightFont.micro())
                    .foregroundStyle(theme.textFaint)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()

            categoryMenu

            ConfidenceBar(score: decision.score)
                .frame(width: 56)
            Text("\(Int((decision.score * 100).rounded()))%")
                .font(SightFont.micro())
                .foregroundStyle(decision.accepted ? theme.textSecondary : theme.textTertiary)
                .frame(width: 34, alignment: .trailing)

            SightIconButton(systemName: "checkmark", help: "Move to \(decision.rule?.name ?? "folder")") {
                Task { await model.approve(decision) }
            }
            SightIconButton(systemName: "xmark", help: "Keep in place") {
                model.reject(decision)
            }
        }
        .padding(.vertical, 12)
    }

    private var categoryMenu: some View {
        Menu {
            ForEach(model.rules.filter(\.isValid)) { rule in
                Button {
                    Task { await model.approve(decision, as: rule) }
                } label: {
                    if rule.id == decision.rule?.id {
                        Label(rule.name, systemImage: "checkmark")
                    } else {
                        Text(rule.name)
                    }
                }
            }
        } label: {
            Text(decision.rule?.name ?? "Choose…")
                .font(SightFont.label())
                .foregroundStyle(theme.textPrimary)
                .frame(minWidth: 84, alignment: .trailing)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.visible)
        .fixedSize()
        .help("Send to a different category and teach Sight")
    }
}
