import SightCore
import SwiftUI

struct SightCommands: Commands {
    let model: AppModel

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Choose Folder…") {
                model.chooseFolder()
            }
            .keyboardShortcut("o", modifiers: .command)

            Divider()

            Button("Sweep Now") {
                Task { await model.runSweepWithFeedback() }
            }
            .keyboardShortcut("r", modifiers: .command)

            Button("Undo Last Move") {
                Task { await model.undoLastMove() }
            }
            .keyboardShortcut("z", modifiers: .command)

            Button("Review Queue") {
                model.activeSheet = .review
            }
            .keyboardShortcut(.return, modifiers: .command)
        }

        CommandMenu("Sight") {
            Button("Live") {
                model.section = .live
            }
            .keyboardShortcut("1", modifiers: .command)

            Button("Rules") {
                model.section = .rules
            }
            .keyboardShortcut("2", modifiers: .command)

            Button("Insights") {
                model.section = .insights
            }
            .keyboardShortcut("3", modifiers: .command)

            Button("New Rule…") {
                model.section = .rules
                model.activeSheet = .ruleEditor
            }
            .keyboardShortcut("n", modifiers: .command)

            Divider()

            Button("Command Palette") {
                NotificationCenter.default.post(name: .sightShowPalette, object: nil)
            }
            .keyboardShortcut("k", modifiers: .command)

            Button("Toggle Theme") {
                model.setTheme(model.config.theme == .dark ? .light : .dark)
            }
            .keyboardShortcut("l", modifiers: [.command, .shift])

            Divider()

            Button("Settings") {
                model.section = .settings
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}
