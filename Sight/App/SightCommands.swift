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
                Task { await model.runSweep() }
            }
            .keyboardShortcut("r", modifiers: .command)

            Button("Undo Last Move") {
                Task { await model.undoLastMove() }
            }
            .keyboardShortcut("z", modifiers: .command)
        }

        CommandMenu("Sight") {
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
