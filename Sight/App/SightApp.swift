import SightCore
import SwiftUI

@main
struct SightApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .sightTheme(model.config.theme)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1180, height: 760)
        .windowResizability(.contentMinSize)
        .commands {
            SightCommands(model: model)
        }

        MenuBarExtra {
            MenuBarView()
                .environment(model)
                .sightTheme(model.config.theme)
        } label: {
            Image(systemName: "circle.dotted")
        }
        .menuBarExtraStyle(.window)
    }
}
