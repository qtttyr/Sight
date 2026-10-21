import Foundation
import SightCore
import Testing
@testable import Sight

@Suite("App model")
@MainActor
struct AppModelTests {
    @Test("Default model assets include text and vision")
    func defaultAssets() {
        let model = AppModel()
        #expect(model.modelAssets.contains(.text))
        #expect(model.modelAssets.contains(.vision))
        #expect(!model.modelAssets.contains(.audio))
    }

    @Test("Every section is reachable")
    func sections() {
        #expect(AppSection.allCases == [.live, .rules, .insights, .settings])
        #expect(AppSection.live.title == "Live")
        #expect(AppSection.settings.icon == "slider.horizontal.3")
    }

    @Test("Root display path stays compact")
    func rootDisplayPath() {
        let model = AppModel()
        #expect(model.rootDisplayPath == "NO FOLDER")

        model.rootURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop", isDirectory: true)
        #expect(model.rootDisplayPath.hasPrefix("~/"))
    }

    @Test("Auto mode requires both the mode and the opt-in flag")
    func autoMode() {
        let model = AppModel()
        model.config.mode = .auto
        model.config.autoSortEnabled = false
        #expect(!model.isAutoMode)

        model.config.autoSortEnabled = true
        #expect(model.isAutoMode)
    }
}
