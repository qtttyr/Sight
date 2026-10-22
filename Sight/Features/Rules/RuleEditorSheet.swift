import AppKit
import SightCore
import SwiftUI

struct RuleEditorSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.sightTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var prompt = ""
    @State private var destination: URL?
    @State private var didChooseDestination = false

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty
            && !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && destination != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("NEW RULE")
                        .font(SightFont.micro())
                        .tracking(0.18)
                        .foregroundStyle(theme.textTertiary)
                    Text("A place for something.")
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

            VStack(alignment: .leading, spacing: 18) {
                templateRow
                fields
            }
            .padding(.top, 22)

            Spacer()

            Hairline()

            HStack(spacing: 12) {
                Text(hint)
                    .font(SightFont.micro())
                    .foregroundStyle(theme.textFaint)
                    .lineLimit(2)

                Spacer()

                Button("Cancel") { dismiss() }
                    .buttonStyle(SightButtonStyle(kind: .ghost))

                Button("Create Rule") {
                    guard let destination else { return }
                    let template = RuleLibrary.template(named: trimmedName)
                    model.addRule(
                        name: name,
                        prompt: prompt,
                        destination: destination,
                        threshold: template?.threshold
                    )
                    dismiss()
                }
                .buttonStyle(SightButtonStyle(kind: .primary))
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.35)
            }
            .padding(.top, 18)
        }
        .padding(32)
        .frame(width: 560, height: 500)
        .background(theme.ink)
        .presentationBackground(theme.ink)
    }

    // MARK: - Destination follows the name

    private func updateAutoDestination(_ newName: String) {
        guard !didChooseDestination else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        destination = trimmed.isEmpty
            ? nil
            : model.makeDestination(named: AppModel.folderName(from: trimmed))
    }

    // MARK: - Templates

    private var templateRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("START FROM A TEMPLATE")
                .font(SightFont.micro())
                .tracking(0.12)
                .foregroundStyle(theme.textFaint)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(RuleLibrary.all) { template in
                        templateChip(template)
                    }
                }
                .padding(.vertical, 1)
            }
        }
    }

    private func templateChip(_ template: RuleTemplate) -> some View {
        let isSelected = trimmedName.caseInsensitiveCompare(template.name) == .orderedSame
        return Button {
            name = template.name
            prompt = template.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            updateAutoDestination(template.name)
        } label: {
            Text(template.name)
                .font(SightFont.micro())
                .foregroundStyle(isSelected ? theme.buttonLabel : theme.textSecondary)
                .padding(.horizontal, 12)
                .frame(height: 26)
                .overlay {
                    Capsule().stroke(
                        isSelected ? theme.buttonFill : theme.line,
                        lineWidth: 1
                    )
                }
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(template.catches)
    }

    // MARK: - Fields

    private var fields: some View {
        VStack(alignment: .leading, spacing: 18) {
            field(title: "NAME") {
                TextField("e.g. Invoices", text: $name)
                    .textFieldStyle(.plain)
                    .font(SightFont.headline())
                    .foregroundStyle(theme.textPrimary)
                    .onChange(of: name) { _, newValue in
                        updateAutoDestination(newValue)
                    }
            }

            field(title: "WHAT BELONGS HERE") {
                TextField(
                    "Describe the files in natural language…",
                    text: $prompt,
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .font(SightFont.body())
                .foregroundStyle(theme.textSecondary)
                .lineLimit(3...5)
            }

            field(title: "DESTINATION") {
                HStack(spacing: 12) {
                    Text(destination.map(shortPath) ?? "Follows the name")
                        .font(SightFont.mono())
                        .foregroundStyle(destination == nil ? theme.textFaint : theme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button(didChooseDestination ? "Change…" : "Choose…") {
                        chooseDestination()
                    }
                    .buttonStyle(SightButtonStyle(kind: .ghost))
                }
            }
        }
    }

    private var hint: String {
        if didChooseDestination { return "Custom destination — the folder won't follow the name anymore." }
        if trimmedName.isEmpty { return "Name the rule — its folder fills in as you type." }
        return "Files will land in a folder called “\(AppModel.folderName(from: trimmedName))”."
    }

    private func field<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(SightFont.micro())
                .tracking(0.12)
                .foregroundStyle(theme.textFaint)
            content()
        }
    }

    private func chooseDestination() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.message = "Choose where this category should live."
        panel.directoryURL = destination ?? model.rootURL
        if panel.runModal() == .OK, let url = panel.url {
            didChooseDestination = true
            destination = url
        }
    }

    private func shortPath(_ url: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if url.path.hasPrefix(home) {
            return "~" + url.path.dropFirst(home.count)
        }
        return url.path
    }
}
