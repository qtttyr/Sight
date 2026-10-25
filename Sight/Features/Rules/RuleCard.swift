import SightCore
import SwiftUI

struct RuleCard: View {
    let rule: CategoryRule
    let fingerprint: [Float]
    let onUpdate: (String, String, Bool) -> Void
    let onToggle: (Bool) -> Void
    let onDelete: () -> Void

    @Environment(\.sightTheme) private var theme
    @State private var name: String
    @State private var prompt: String
    @State private var isEnabled: Bool
    @State private var isDirty = false
    @State private var showDeleteConfirmation = false

    init(
        rule: CategoryRule,
        fingerprint: [Float],
        onUpdate: @escaping (String, String, Bool) -> Void,
        onToggle: @escaping (Bool) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.rule = rule
        self.fingerprint = fingerprint
        self.onUpdate = onUpdate
        self.onToggle = onToggle
        self.onDelete = onDelete
        _name = State(initialValue: rule.name)
        _prompt = State(initialValue: rule.prompt)
        _isEnabled = State(initialValue: rule.isEnabled)
    }

    var body: some View {
        SightCard(padding: 20) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    TextField("Rule name", text: $name)
                        .textFieldStyle(.plain)
                        .font(SightFont.headline())
                        .foregroundStyle(theme.textPrimary)
                        .onSubmit(save)

                    Spacer()

                    if isDirty {
                        Text("Unsaved")
                            .font(SightFont.micro())
                            .foregroundStyle(theme.textTertiary)
                            .accessibilityHidden(true)

                        Button("Save") { save() }
                            .buttonStyle(SightButtonStyle(kind: .ghost))
                    }

                    SightSwitch(
                        isOn: $isEnabled,
                        label: rule.name,
                        help: isEnabled ? "This rule is active." : "This rule is switched off."
                    )
                    .onChange(of: isEnabled) { _, newValue in
                        // A switch is a decision, not a draft: it takes effect
                        // at once, without waiting for a Save button.
                        isDirty = false
                        onToggle(newValue)
                    }

                    SightIconButton(systemName: "trash", help: "Delete rule") {
                        showDeleteConfirmation = true
                    }
                }

                TextField("Describe what belongs here…", text: $prompt, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(SightFont.body())
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2...4)
                    .onSubmit(save)

                HStack(spacing: 16) {
                    Text(shortPath(rule.destination))
                        .font(SightFont.micro())
                        .foregroundStyle(theme.textFaint)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(rule.destination.path)

                    Spacer()

                    VectorFingerprint(values: fingerprint)
                        .frame(width: 180)
                }
            }
        }
        .opacity(isEnabled ? 1 : 0.5)
        .onChange(of: name) { _, _ in isDirty = true }
        .onChange(of: prompt) { _, _ in isDirty = true }
        .onChange(of: rule) { _, newValue in
            guard !isDirty else { return }
            name = newValue.name
            prompt = newValue.prompt
            isEnabled = newValue.isEnabled
        }
        .confirmationDialog("Delete \(rule.name)?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive, action: onDelete)
        } message: {
            Text("Files already sorted into this folder are not touched.")
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedPrompt.isEmpty else { return }
        isDirty = false
        onUpdate(trimmedName, trimmedPrompt, isEnabled)
    }

    private func shortPath(_ url: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if url.path.hasPrefix(home) {
            return "~" + url.path.dropFirst(home.count)
        }
        return url.path
    }
}
