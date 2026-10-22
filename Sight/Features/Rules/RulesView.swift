import SightCore
import SwiftUI

struct RulesView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.sightTheme) private var theme
    @State private var testText = ""

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                SectionHeader(
                    title: "RULES",
                    subtitle: "\(model.rules.count) categories"
                )
                Spacer()
                Button("New Rule") {
                    model.activeSheet = .ruleEditor
                }
                .buttonStyle(SightButtonStyle(kind: .primary))
            }

            Spacer(minLength: 24)

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(model.rules) { rule in
                        RuleCard(
                            rule: rule,
                            fingerprint: model.ruleFingerprints[rule.id] ?? [],
                            onUpdate: { name, prompt, enabled in
                                var updated = rule
                                updated.name = name
                                updated.prompt = prompt
                                updated.isEnabled = enabled
                                model.updateRule(updated)
                            },
                            onDelete: {
                                model.deleteRule(id: rule.id)
                            }
                        )
                    }

                    if model.rules.isEmpty {
                        EmptyState(
                            icon: "square.stack.3d.up",
                            title: "No rules yet.",
                            subtitle: "Add a category — start from a tuned template or write your own."
                        )
                        .frame(minHeight: 220)
                    }
                }
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)

            Spacer(minLength: 20)

            testCard
        }
        .padding(.horizontal, 40)
        .padding(.top, 38)
        .padding(.bottom, 28)
    }

    private var testCard: some View {
        SightCard(padding: 20) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("ZERO-SHOT TEST")
                        .font(SightFont.micro())
                        .tracking(0.14)
                        .foregroundStyle(theme.textTertiary)
                    Spacer()
                    if let decision = model.testDecision, let rule = decision.rule {
                        Text(rule.name)
                            .font(SightFont.micro())
                            .foregroundStyle(theme.textPrimary)
                        Text("\(Int(decision.score * 100))%")
                            .font(SightFont.micro())
                            .foregroundStyle(theme.textTertiary)
                    }
                }

                HStack(spacing: 12) {
                    TextField("Paste a filename or a sentence…", text: $testText)
                        .textFieldStyle(.plain)
                        .font(SightFont.body())
                        .foregroundStyle(theme.textPrimary)
                        .onSubmit { runTest() }

                    Button("Test") { runTest() }
                        .buttonStyle(SightButtonStyle(kind: .ghost))
                        .disabled(testText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func runTest() {
        let value = testText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        Task { await model.test(text: value) }
    }
}
