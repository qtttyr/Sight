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
    @State private var didSetDefaultDestination = false

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
            .padding(.bottom, 28)

            Hairline()

            VStack(alignment: .leading, spacing: 20) {
                field(title: "NAME") {
                    TextField("e.g. Invoices", text: $name)
                        .textFieldStyle(.plain)
                        .font(SightFont.headline())
                        .foregroundStyle(theme.textPrimary)
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
                        Text(destination.map(shortPath) ?? "No folder selected")
                            .font(SightFont.mono())
                            .foregroundStyle(destination == nil ? theme.textFaint : theme.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button("Choose…") {
                            chooseDestination()
                        }
                        .buttonStyle(SightButtonStyle(kind: .ghost))
                    }
                }
            }
            .padding(.top, 24)

            Spacer()

            Hairline()

            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .buttonStyle(SightButtonStyle(kind: .ghost))

                Spacer()

                Button("Create Rule") {
                    guard let destination else { return }
                    model.addRule(name: name, prompt: prompt, destination: destination)
                    dismiss()
                }
                .buttonStyle(SightButtonStyle(kind: .primary))
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.35)
            }
            .padding(.top, 20)
        }
        .padding(32)
        .frame(width: 560, height: 460)
        .background(theme.ink)
        .presentationBackground(theme.ink)
        .onAppear {
            guard !didSetDefaultDestination else { return }
            didSetDefaultDestination = true
            destination = model.makeDestination(named: "New")
        }
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
