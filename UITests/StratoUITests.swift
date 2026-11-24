import XCTest

/// Drives the real app against its built-in demo world and keeps a screenshot of every screen.
/// The point is to prove on a simulator that the flows work end to end and the controls respond.
final class StratoUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(speed: Int) {
        app.launchArguments = ["-demo", "1", "-uitest", "1", "-demoSpeed", "\(speed)", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
    }

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func tap(_ id: String, timeout: TimeInterval = 20, file: StaticString = #filePath, line: UInt = #line) {
        let element = app.descendants(matching: .any)[id].firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "missing \(id)", file: file, line: line)
        element.tap()
    }

    private func exists(_ id: String, timeout: TimeInterval = 20) -> Bool {
        app.descendants(matching: .any)[id].firstMatch.waitForExistence(timeout: timeout)
    }

    private func openTab(_ title: String) {
        let button = app.tabBars.buttons[title].firstMatch
        if button.waitForExistence(timeout: 10) {
            button.tap()
        } else {
            app.buttons[title].firstMatch.tap()
        }
    }

    /// Radar → search by duration → board → fly → pause → pass → leave early → logbook, stats, settings.
    func testJourney() {
        launch(speed: 3)
        XCTAssertTrue(exists("open-finder", timeout: 40))
        sleep(8) // let aircraft and imagery load
        shot("01-radar")

        // Look a flight up by number and inspect its card.
        tap("flight-search")
        app.typeText("CA1831\n")
        XCTAssertTrue(exists("board-button", timeout: 25), "flight card did not appear")
        sleep(5)
        shot("02-flight-card")
        tap("card-close")

        // Ask for a flight landing in about an hour.
        tap("quick-60")
        let match = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'match-'")).firstMatch
        XCTAssertTrue(match.waitForExistence(timeout: 40), "no match found for a 60 minute session")
        sleep(2)
        shot("03-finder-results")
        match.tap()
        XCTAssertTrue(exists("start-focus", timeout: 15))
        tap("tag-coding")
        sleep(1)
        shot("04-boarding")
        tap("start-focus")

        // In flight.
        XCTAssertTrue(exists("pause-button", timeout: 20), "flight screen did not appear")
        sleep(5)
        shot("05-in-flight")

        let countdown = app.staticTexts["countdown"].firstMatch
        XCTAssertTrue(countdown.waitForExistence(timeout: 5))
        let before = countdown.label
        sleep(3)
        XCTAssertNotEqual(before, countdown.label, "countdown is not running")

        // Pausing stops the focus clock (the aircraft, and so the landing countdown, carries on).
        let focused = app.staticTexts["focused-time"].firstMatch
        XCTAssertTrue(focused.waitForExistence(timeout: 5))
        tap("pause-button")
        sleep(1)
        let paused = focused.label
        sleep(3)
        XCTAssertEqual(paused, focused.label, "focus time kept running while paused")
        shot("06-paused")
        tap("pause-button")
        sleep(3)
        XCTAssertNotEqual(paused, focused.label, "focus time did not resume")

        // Boarding pass overlay.
        tap("show-pass")
        XCTAssertTrue(exists("hide-pass", timeout: 10))
        sleep(1)
        shot("07-pass-in-flight")
        tap("hide-pass")

        // Ambient sound menu opens and a choice sticks.
        tap("ambient-menu")
        let cabin = app.buttons["巡航机舱"].firstMatch
        XCTAssertTrue(cabin.waitForExistence(timeout: 10), "ambient menu did not open")
        cabin.tap()
        sleep(1)

        // Leave early and keep the segment (the demo clock has run well past a minute by now).
        sleep(12)
        tap("end-button")
        let save = app.buttons["保存并下机"].firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 10), "end dialog did not appear")
        save.tap()
        XCTAssertTrue(exists("arrival-done", timeout: 20), "summary did not appear")
        sleep(2)
        shot("08-left-early")
        tap("arrival-done")

        // Logbook.
        sleep(1)
        openTab("护照")
        sleep(4)
        shot("09-logbook")
        let first = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'record-'")).firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 10), "logbook has no records")
        first.tap()
        sleep(2)
        shot("10-record-detail")
        app.swipeUp()
        sleep(1)
        shot("11-record-detail-lower")
        app.navigationBars.buttons.firstMatch.tap()

        // Statistics.
        openTab("统计")
        sleep(2)
        shot("12-stats")
        app.swipeUp()
        sleep(1)
        shot("13-stats-lower")
        app.swipeUp()
        sleep(1)
        shot("14-stats-bottom")

        // Settings.
        openTab("设置")
        sleep(2)
        shot("15-settings")
        app.swipeUp()
        sleep(1)
        shot("16-settings-lower")
    }

    /// Board a flight that is close to landing, with the demo clock sped up, and ride it to touchdown.
    func testRideToLanding() {
        launch(speed: 12)
        XCTAssertTrue(exists("open-finder", timeout: 40))
        sleep(2)
        tap("flight-search")
        app.typeText("MU2315\n") // about 47 demo minutes from landing at launch
        XCTAssertTrue(exists("board-button", timeout: 25), "flight card did not appear")
        tap("board-button")
        XCTAssertTrue(exists("start-focus", timeout: 15), "boarding sheet did not open")
        tap("start-focus")
        XCTAssertTrue(exists("pause-button", timeout: 20), "flight screen did not appear")
        sleep(3)
        shot("19-descending")

        // Somewhere on the way down the cabin announcements should show up.
        if exists("announcement", timeout: 90) {
            shot("20-announcement")
        }
        XCTAssertTrue(exists("arrival-done", timeout: 240), "the flight never landed")
        sleep(2)
        shot("21-landed")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS '已落地'")).firstMatch.exists, "landing was not reported")
        tap("arrival-done")

        openTab("护照")
        XCTAssertTrue(exists("record-MU2315", timeout: 10), "landed flight is not in the logbook")
    }

    /// The same flow against the real feeds, over busy airspace. Skipped, not failed, when the
    /// network or the feeds are unavailable, since that says nothing about the app.
    func testLiveSmoke() throws {
        app.launchArguments = ["-uitest", "1", "-startLat", "50.0", "-startLon", "8.6", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(exists("open-finder", timeout: 40))
        let anyPlane = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'plane-'")).firstMatch
        guard anyPlane.waitForExistence(timeout: 45) else {
            shot("40-live-no-data")
            throw XCTSkip("no live aircraft received")
        }
        sleep(8)
        shot("40-live-radar")

        tap("quick-45")
        let match = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'match-'")).firstMatch
        guard match.waitForExistence(timeout: 150) else {
            shot("41-live-no-match")
            throw XCTSkip("no live match found")
        }
        sleep(6)
        shot("41-live-results")
        match.tap()
        XCTAssertTrue(exists("start-focus", timeout: 20))
        sleep(3)
        shot("42-live-boarding")
        tap("start-focus")
        XCTAssertTrue(exists("pause-button", timeout: 20), "flight screen did not appear")
        sleep(25)
        shot("43-live-in-flight")
        tap("end-button")
        let discard = app.buttons["不保存，直接结束"].firstMatch
        XCTAssertTrue(discard.waitForExistence(timeout: 10))
        discard.tap()
        XCTAssertTrue(exists("open-finder", timeout: 20), "did not return to the radar")
    }

    /// The custom-route (simulated) path.
    func testCustomRoute() {
        launch(speed: 6)
        tap("open-finder", timeout: 40)
        app.buttons["自选航线"].firstMatch.tap()
        XCTAssertTrue(exists("make-custom", timeout: 10))
        sleep(1)
        shot("30-custom-route")
        tap("make-custom")
        XCTAssertTrue(exists("start-focus", timeout: 15))
        sleep(1)
        shot("31-custom-boarding")
        tap("start-focus")
        XCTAssertTrue(exists("pause-button", timeout: 20), "flight screen did not appear")
        sleep(4)
        shot("32-custom-in-flight")
        tap("end-button")
        let discard = app.buttons["不保存，直接结束"].firstMatch
        XCTAssertTrue(discard.waitForExistence(timeout: 10))
        discard.tap()
        XCTAssertTrue(exists("open-finder", timeout: 20), "did not return to the radar")
    }
}
