import XCTest

@MainActor
final class SightUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testLaunchesAndShowsAWindow() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ApplePersistenceIgnoreState", "YES",
            "-NSQuitAlwaysKeepsWindows", "NO"
        ]
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
    }
}

@MainActor
final class SightSecondRunTests: XCTestCase {
    func testSecondRunScreens() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ApplePersistenceIgnoreState", "YES",
            "-NSQuitAlwaysKeepsWindows", "NO"
        ]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
        XCTAssertTrue(app.buttons["Live"].waitForExistence(timeout: 60))
        sleep(2)
        let attach: (String) -> Void = { name in
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = name
            attachment.lifetime = .keepAlways
            self.add(attachment)
        }
        attach("11-second-run-live")

        app.buttons["Rules"].click()
        sleep(1)
        attach("12-second-run-rules")
        app.buttons["Insights"].click()
        sleep(1)
        attach("13-second-run-insights")
        app.buttons["Settings"].click()
        sleep(1)
        attach("14-second-run-settings")
    }
}

@MainActor
final class SightScreenshotTests: XCTestCase {
    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func click(_ label: String, in app: XCUIApplication) {
        let button = app.buttons[label]
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Missing button: \(label)")
        button.click()
        usleep(700_000)
    }

    func testCaptureScreens() {
        let app = XCUIApplication()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES", "-SightDemo"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
        sleep(2)

        attach("01-live-dark")
        print(app.debugDescription)

        click("Rules", in: app)
        attach("02-rules-dark")

        click("Insights", in: app)
        attach("03-insights-dark")

        click("Settings", in: app)
        attach("04-settings-dark")

        click("Live", in: app)
        click("LIGHT", in: app)
        attach("05-live-light")

        click("Rules", in: app)
        attach("06-rules-light")

        click("Live", in: app)
        app.typeKey("k", modifierFlags: .command)
        usleep(900_000)
        attach("07-palette-light")
        app.typeKey(.escape, modifierFlags: [])
        usleep(500_000)

        let review = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Review'")).firstMatch
        if review.waitForExistence(timeout: 3) {
            review.click()
            usleep(700_000)
            attach("08-review-light")
            app.buttons["Close"].firstMatch.click()
        }

        click("Settings", in: app)
        attach("09-settings-light")

        // Command palette is reachable from the sidebar as well as ⌘K.
        click("Command Palette", in: app)
        usleep(900_000)
        attach("10-palette-light")
    }
}

@MainActor
final class SightRealSetupTests: XCTestCase {
    func testRealModelSetup() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ApplePersistenceIgnoreState", "YES",
            "-NSQuitAlwaysKeepsWindows", "NO"
        ]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
        sleep(8)
        let button = app.buttons["Begin"]
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "onboarding-real"
        attachment.lifetime = .keepAlways
        add(attachment)
        print("BEGIN_STATE=\(button.exists)")
        print(app.debugDescription)
        XCTAssertTrue(button.waitForExistence(timeout: 60))
        button.click()
        usleep(500_000)
        app.buttons["Use Downloads"].click()
        usleep(1_200_000)
        if app.buttons["Continue"].exists {
            app.buttons["Continue"].click()
            usleep(1_300_000)
        }

        // Model install path depends on local state: either download or load.
        if app.buttons["Enter Sight"].waitForExistence(timeout: 15) {
            app.buttons["Enter Sight"].click()
            usleep(2_000_000)
            return
        }

        // Fresh download: model store is empty, so Download & Prepare first.
        let downloadButton = app.buttons["Download & Prepare"]
        XCTAssertTrue(downloadButton.waitForExistence(timeout: 30))
        downloadButton.click()

        var ready = app.buttons["Enter Sight"].waitForExistence(timeout: 660)
        while !ready {
            usleep(5_000_000)
            ready = app.buttons["Enter Sight"].waitForExistence(timeout: 5)
        }
        usleep(1_000_000)
        app.buttons["Enter Sight"].click()
        usleep(2_000_000)
    }
}
