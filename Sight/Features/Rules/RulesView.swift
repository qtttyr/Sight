import SightCore
import SwiftUI

struct RulesView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.sightTheme) private var theme
    @State private var testText = ""
    @State private var showRestoreConfirmation = false
    @State private var isTesting = false

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                SectionHeader(
                    title: "RULES",
                    subtitle: "\(model.rules.count) categories"
                )
                Spacer()
                Button("Restore Library") {
                    showRestoreConfirmation = true
                }
                .buttonStyle(SightButtonStyle(kind: .ghost))
                .help("Replace the built-in categories with the curated, tuned versions.")
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
                            onToggle: { enabled in
                                var updated = rule
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
        .confirmationDialog(
            "Restore the built-in categories?",
            isPresented: $showRestoreConfirmation
        ) {
            Button("Restore") { model.restoreCuratedLibrary() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The built-in categories go back to their tuned versions. Rules you wrote yourself are kept.")
        }
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
                    if isTesting {
                        Text("Testing…")
                            .font(SightFont.micro())
                            .foregroundStyle(theme.textTertiary)
                    } else if let decision = model.testDecision {
                        if let rule = decision.rule {
                            Text(rule.name)
                                .font(SightFont.micro())
                                .foregroundStyle(theme.textPrimary)
                            Text("\(Int(decision.score * 100))%")
                                .font(SightFont.micro())
                                .foregroundStyle(theme.textTertiary)
                        } else {
                            Text("No category is close enough")
                                .font(SightFont.micro())
                                .foregroundStyle(theme.textTertiary)
                        }
                    }
                }

                HStack(spacing: 12) {
                    TextField("Paste a filename or a sentence…", text: $testText)
                        .textFieldStyle(.plain)
                        .font(SightFont.body())
                        .foregroundStyle(theme.textPrimary)
                        .onSubmit { runTest() }
                        .onChange(of: testText) { _, _ in
                            // The old answer belongs to the old text.
                            model.testDecision = nil
                        }

                    Button("Test") { runTest() }
                        .buttonStyle(SightButtonStyle(kind: .ghost))
                        .disabled(testText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isTesting)
                }
            }
        }
    }

    private func runTest() {
        let value = testText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        isTesting = true
        Task {
            await model.test(text: value)
            isTesting = false
        }
    }
}
