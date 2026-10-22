import SightCore
import SwiftUI

struct CommandPaletteView: View {
    @Binding var isPresented: Bool

    @Environment(AppModel.self) private var model
    @Environment(\.sightTheme) private var theme
    @FocusState private var isSearchFocused: Bool
    @State private var query = ""

    fileprivate struct PaletteCommand: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let icon: String
        let shortcut: String?
        let action: () -> Void
    }

    private var commands: [PaletteCommand] {
        [
            PaletteCommand(
                title: "Go to Live",
                subtitle: "Watch and sweep your folder",
                icon: "waveform.path.ecg",
                shortcut: "⌘1"
            ) { model.section = .live },
            PaletteCommand(
                title: "Go to Rules",
                subtitle: "Edit categories and prompts",
                icon: "square.stack.3d.up",
                shortcut: "⌘2"
            ) { model.section = .rules },
            PaletteCommand(
                title: "Go to Insights",
                subtitle: "Statistics and model details",
                icon: "chart.bar.xaxis",
                shortcut: "⌘3"
            ) { model.section = .insights },
            PaletteCommand(
                title: "Go to Settings",
                subtitle: "Folder, model, and appearance",
                icon: "slider.horizontal.3",
                shortcut: "⌘,"
            ) { model.section = .settings },
            PaletteCommand(
                title: "New Rule",
                subtitle: "Pick a template or write your own",
                icon: "plus.circle",
                shortcut: "⌘N"
            ) { model.section = .rules; model.activeSheet = .ruleEditor },
            PaletteCommand(
                title: "Choose Folder…",
                subtitle: "Change the watched folder",
                icon: "folder",
                shortcut: "⌘O"
            ) { model.chooseFolder() },
            PaletteCommand(
                title: "Sweep Now",
                subtitle: "Classify everything in the root",
                icon: "arrow.clockwise",
                shortcut: "⌘R"
            ) { Task { await model.runSweep() } },
            PaletteCommand(
                title: "Undo Last Move",
                subtitle: "Put the last sorted file back",
                icon: "arrow.uturn.backward",
                shortcut: "⌘Z"
            ) { Task { await model.undoLastMove() } },
            PaletteCommand(
                title: "Toggle Theme",
                subtitle: "Switch between dark and light",
                icon: "circle.lefthalf.filled",
                shortcut: "⇧⌘L"
            ) { model.setTheme(model.config.theme == .dark ? .light : .dark) }
        ]
    }

    private var filtered: [PaletteCommand] {
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !search.isEmpty else { return commands }
        return commands.filter {
            $0.title.lowercased().contains(search) || $0.subtitle.lowercased().contains(search)
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            theme.ink.opacity(0.62)
                .ignoresSafeArea()
                .onTapGesture { close() }

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(theme.textTertiary)
                    TextField("Search actions…", text: $query)
                        .textFieldStyle(.plain)
                        .font(SightFont.body())
                        .foregroundStyle(theme.textPrimary)
                        .focused($isSearchFocused)
                        .onSubmit(performFirst)
                    Text("ESC")
                        .font(SightFont.micro())
                        .foregroundStyle(theme.textFaint)
                }
                .padding(.horizontal, 18)
                .frame(height: 54)
                .overlay(alignment: .bottom) { Hairline() }

                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(filtered) { command in
                            PaletteRow(command: command) {
                                command.action()
                                close()
                            }
                        }
                        if filtered.isEmpty {
                            Text("No matching actions.")
                                .font(SightFont.body())
                                .foregroundStyle(theme.textFaint)
                                .frame(maxWidth: .infinity, minHeight: 90)
                        }
                    }
                    .padding(8)
                }
                .scrollIndicators(.hidden)
                .frame(maxHeight: 320)
            }
            .frame(width: 560)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(theme.lineStrong, lineWidth: 1)
            }
            .shadow(color: .black.opacity(theme.isDark ? 0.5 : 0.12), radius: 40, y: 18)
            .padding(.top, 120)
        }
        .onAppear {
            isSearchFocused = true
        }
        .onKeyPress(.escape) {
            close()
            return .handled
        }
        .transition(.opacity.combined(with: .scale(scale: 0.985, anchor: .top)))
    }

    private func performFirst() {
        guard let first = filtered.first else { return }
        first.action()
        close()
    }

    private func close() {
        withAnimation(SightMotion.quick) {
            isPresented = false
        }
    }
}

private struct PaletteRow: View {
    let command: CommandPaletteView.PaletteCommand
    let action: () -> Void

    @Environment(\.sightTheme) private var theme
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: command.icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.textTertiary)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(command.title)
                        .font(SightFont.body())
                        .foregroundStyle(theme.textPrimary)
                    Text(command.subtitle)
                        .font(SightFont.micro())
                        .foregroundStyle(theme.textFaint)
                }
                Spacer()
                if let shortcut = command.shortcut {
                    Text(shortcut)
                        .font(SightFont.micro())
                        .foregroundStyle(theme.textFaint)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 48)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isHovering ? theme.hover : Color.clear)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
