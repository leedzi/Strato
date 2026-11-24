import XCTest

/// Drives the real app against its built-in demo world and keeps a screenshot of every screen.
/// The point is to prove on a simulator that the flows work end to end and the controls respond.
final class StratoUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
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

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    private func waitForState(_ message: String, timeout: TimeInterval = 10,
                              file: StaticString = #filePath, line: UInt = #line,
                              condition: @escaping () -> Bool) {
        let expected = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expected], timeout: timeout), .completed,
                       message, file: file, line: line)
    }

    /// Finder and settings contain controls below the fold, including on smaller simulators.
    private func visible(_ id: String, maxSwipes: Int = 6,
                         file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let target = element(id)
        for attempt in 0...maxSwipes {
            if target.waitForExistence(timeout: attempt == 0 ? 3 : 0.5), target.isHittable {
                return target
            }
            if attempt < maxSwipes {
                let scrollView = app.scrollViews.firstMatch
                if scrollView.exists { scrollView.swipeUp() } else { app.swipeUp() }
            }
        }
        XCTAssertTrue(target.exists, "missing \(id)", file: file, line: line)
        XCTAssertTrue(target.isHittable, "cannot reach \(id)", file: file, line: line)
        return target
    }

    private func setUnlimited(_ on: Bool, file: StaticString = #filePath, line: UInt = #line) {
        let toggle = visible("finder-unlimited", file: file, line: line)
        let value = on ? "1" : "0"
        if toggle.value as? String != value { toggle.tap() }
        waitForState("unlimited setting did not change", file: file, line: line) {
            toggle.value as? String == value
        }
    }

    private func searchAirport(_ code: String, file: StaticString = #filePath, line: UInt = #line) {
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10), "airport search did not open", file: file, line: line)
        search.tap()
        search.typeText(code)
    }

    /// Quick takeoff inherits the home airport, supports explicit routes, and remains usable in landscape.
    func testQuickTakeoffWindowAndLandscapeControls() {
        launch(speed: 3)
        XCTAssertTrue(exists("home-airport", timeout: 40))
        let homeCode = element("home-airport").label.split(separator: "·").last?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        XCTAssertEqual(homeCode.count, 3, "home airport code was not shown")
        tap("quick-takeoff")
        waitForState("quick takeoff did not inherit the home airport") {
            self.element("custom-origin").label.contains(homeCode)
        }

        setUnlimited(true)
        XCTAssertEqual(element("finder-duration-label").label, "全程")
        visible("custom-origin").tap()
        searchAirport("PVG")
        tap("airport-PVG")
        waitForState("custom origin was not selected") { self.element("custom-origin").label.contains("PVG") }

        visible("browse-route-times").tap()
        searchAirport("HND")
        let destination = element("airport-HND")
        XCTAssertTrue(destination.waitForExistence(timeout: 10))
        XCTAssertTrue(destination.label.contains("约"), "airport picker did not show route time")
        shot("50-quick-route-times")
        destination.tap()
        waitForState("custom destination was not selected") { self.element("custom-destination").label.contains("HND") }
        let routeEstimate = visible("custom-route-estimate")
        XCTAssertTrue(routeEstimate.label.contains("起飞，全程约"), "full-route estimate was not shown")
        visible("make-custom").tap()

        XCTAssertTrue(exists("boarding-pass", timeout: 15))
        let pass = element("boarding-pass")
        XCTAssertTrue(pass.label.contains("PVG") && pass.label.contains("HND"), "boarding pass lost the selected route")
        XCTAssertTrue(pass.label.contains("模拟"), "custom flight was not identified as simulated")
        let untilLanding = app.buttons["飞到落地"].firstMatch
        XCTAssertTrue(untilLanding.waitForExistence(timeout: 10))
        XCTAssertTrue(untilLanding.isSelected, "full route should default to flying until landing")
        shot("51-full-route-boarding")
        visible("start-focus").tap()

        XCTAssertTrue(exists("flight-view-map", timeout: 20))
        XCTAssertTrue(element("flight-view-map").isSelected)
        tap("flight-view-window")
        waitForState("window view did not become active") {
            self.element("flight-view-window").isSelected && self.element("cabin-window-view").exists
        }
        XCTAssertFalse(element("flight-view-map").isSelected)
        XCTAssertTrue(app.staticTexts["距落地"].firstMatch.exists, "boarding did not follow the landing time")
        XCTAssertFalse(element("flight-google3d-button").exists, "Google scene appeared without configuration")
        shot("52-window-portrait")

        XCUIDevice.shared.orientation = .landscapeLeft
        waitForState("flight screen did not rotate", timeout: 20) { self.app.frame.width > self.app.frame.height }
        XCTAssertTrue(element("cabin-window-view").exists)
        let pause = visible("pause-button")
        XCTAssertTrue(element("show-pass").isHittable, "pass control is not usable in landscape")
        let focused = element("focused-time")
        let runningTime = focused.label
        waitForState("focus clock did not advance in landscape") { focused.label != runningTime }

        pause.tap()
        waitForState("pause control did not switch to resume") { pause.label.contains("继续") }
        let pausedTime = focused.label
        let landingTime = element("countdown").label
        let mustStayPaused = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in focused.label != pausedTime }, object: nil)
        mustStayPaused.isInverted = true
        XCTAssertEqual(XCTWaiter.wait(for: [mustStayPaused], timeout: 3), .completed,
                       "focus clock kept running while paused in landscape")
        XCTAssertNotEqual(landingTime, element("countdown").label, "landing countdown stopped with the focus clock")
        pause.tap()
        waitForState("resume control did not switch back to pause") { pause.label.contains("暂停") }
        waitForState("focus clock did not resume in landscape") { focused.label != pausedTime }
        shot("53-window-landscape")

        tap("show-pass")
        XCTAssertTrue(exists("hide-pass", timeout: 10))
        XCTAssertTrue(element("hide-pass").isHittable, "cannot dismiss the pass in landscape")
        shot("54-window-pass-landscape")
        tap("hide-pass")
        waitForState("pass did not close") { !self.element("hide-pass").exists }
        visible("end-button").tap()
        let discard = app.buttons["不保存，直接结束"].firstMatch
        XCTAssertTrue(discard.waitForExistence(timeout: 10))
        discard.tap()
        XCTAssertTrue(exists("open-finder", timeout: 20), "landscape flight did not return to the radar")
    }

    /// A preset leaves unlimited mode; destination-only search then includes both demo flights to HND.
    func testUnlimitedDestinationSearchAndPreset() {
        launch(speed: 1)
        tap("open-finder", timeout: 40)
        setUnlimited(true)
        XCTAssertEqual(element("finder-duration-label").label, "不限")
        waitForState("duration slider remained in unlimited mode") { !self.element("duration-slider").exists }

        tap("finder-preset-15")
        waitForState("preset did not restore timed mode") {
            self.element("finder-unlimited").value as? String == "0"
                && self.element("finder-duration-label").label == "15 分钟"
                && self.element("duration-slider").exists
        }
        visible("pick-destination").tap()
        searchAirport("HND")
        tap("airport-HND")
        waitForState("destination filter did not change") { self.element("pick-destination").label.contains("HND") }
        setUnlimited(true)
        visible("search-flights").tap()

        XCTAssertTrue(exists("match-ANA920", timeout: 40), "unlimited search missed the first HND flight")
        waitForState("destination search did not finish", timeout: 40) {
            self.element("search-flights").label.contains("搜索飞往")
        }
        XCTAssertTrue(visible("match-JAL82").exists, "unlimited search retained the 15-minute time filter")
        XCTAssertFalse(element("match-CCA1831").exists, "search returned a flight to SHA")
        XCTAssertFalse(element("match-CES2315").exists, "search returned a flight to PVG")
        shot("60-unlimited-destination-results")
        tap("finder-close")
        XCTAssertTrue(exists("open-finder", timeout: 20))
    }

    /// Calendar navigation changes the data, while both offline passport map styles stay interactive.
    func testCalendarPeriodsAndOfflinePassportMaps() {
        launch(speed: 1)
        XCTAssertTrue(exists("open-finder", timeout: 40))
        openTab("统计")
        tap("stats-range-all")
        let total = element("stats-total-duration")
        XCTAssertTrue(total.waitForExistence(timeout: 10))
        let allTime = total.label
        XCTAssertNotEqual(allTime, "0 分钟", "demo history did not load")

        for range in ["year", "month", "week", "day"] {
            tap("stats-range-\(range)")
            waitForState("statistics range \(range) was not selected") { self.element("stats-range-\(range)").isSelected }
            XCTAssertTrue(element("stats-period-previous").exists)
            XCTAssertFalse(element("stats-period-next").isEnabled, "current period allowed future navigation")
            XCTAssertFalse(element("stats-choose-date").label.isEmpty)
        }
        waitForState("day statistics still showed the all-time total") { total.label != allTime }
        let todayTime = total.label
        let todayTitle = element("stats-choose-date").label
        tap("stats-period-previous")
        waitForState("previous day did not change the period and data") {
            self.element("stats-choose-date").label != todayTitle && total.label != todayTime
        }
        XCTAssertTrue(element("stats-period-next").isEnabled)
        XCTAssertTrue(element("stats-current-period").exists)
        tap("stats-period-next")
        waitForState("next day did not return to today's statistics") {
            self.element("stats-choose-date").label == todayTitle && total.label == todayTime
        }
        XCTAssertFalse(element("stats-period-next").isEnabled)
        tap("stats-period-previous")
        tap("stats-current-period")
        waitForState("current-period shortcut did not return to today") { self.element("stats-choose-date").label == todayTitle }
        shot("70-statistics-day")

        tap("stats-choose-date")
        XCTAssertTrue(exists("stats-date-picker", timeout: 10))
        shot("71-statistics-calendar")
        tap("stats-date-done")
        waitForState("calendar sheet did not close") { !self.element("stats-date-done").exists }
        XCTAssertEqual(element("stats-choose-date").label, todayTitle)
        tap("stats-range-all")

        openTab("护照")
        tap("passport-range-all")
        visible("passport-map-minimal").tap()
        waitForState("offline flat map did not become active") {
            self.element("passport-map-minimal").isSelected && self.element("passport-map-canvas-minimal").exists
        }
        shot("72-passport-offline-map")
        visible("passport-map-globe").tap()
        waitForState("offline globe did not become active") {
            self.element("passport-map-globe").isSelected && self.element("passport-map-canvas-globe").exists
        }
        let globe = visible("passport-map-canvas-globe")
        let reset = visible("passport-globe-reset")
        let initialViewpoint = reset.value as? String ?? ""
        XCTAssertFalse(initialViewpoint.isEmpty, "globe did not expose its viewpoint")
        shot("72b-passport-globe-initial")
        let start = globe.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.55))
        let end = globe.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.55))
        start.press(forDuration: 0.1, thenDragTo: end)
        waitForState("globe did not rotate after dragging") {
            guard let viewpoint = reset.value as? String else { return false }
            return !viewpoint.isEmpty && viewpoint != initialViewpoint
        }
        XCTAssertTrue(element("passport-globe-reset").isHittable, "globe reset was lost after rotation")
        shot("73-passport-globe-rotated")
        reset.tap()
        waitForState("globe did not return to its initial viewpoint") {
            reset.value as? String == initialViewpoint
        }
        XCTAssertTrue(element("passport-map-globe").isSelected)
        XCTAssertTrue(element("passport-map-canvas-globe").exists)
        shot("74-passport-globe-reset")
        visible("passport-map-minimal").tap()
        XCTAssertTrue(exists("passport-map-canvas-minimal", timeout: 10))
    }

    /// Optional services expose setup without requiring a Google key or a real iCloud connection.
    func testOptionalGoogleAndICloudSettings() {
        launch(speed: 1)
        XCTAssertTrue(exists("open-finder", timeout: 40))
        openTab("设置")
        visible("google3d-settings").tap()
        XCTAssertTrue(exists("google3d-settings-view", timeout: 10))
        let google = element("google3d-enabled-toggle")
        XCTAssertTrue(google.waitForExistence(timeout: 10))
        XCTAssertFalse(google.isEnabled, "Google scene can be enabled without a key")
        XCTAssertEqual(google.value as? String, "0", "Google scene was enabled by default")
        XCTAssertTrue(element("google3d-key-status").label.contains("未配置"))
        XCTAssertTrue(element("google3d-key-field").exists)
        XCTAssertFalse(element("google3d-save-key").isEnabled, "empty key can be saved")
        XCTAssertFalse(element("google3d-clear-key").exists, "test unexpectedly found a saved key")
        shot("80-google-without-key")
        app.navigationBars["Google 3D 外景"].buttons.firstMatch.tap()

        visible("icloud-settings").tap()
        XCTAssertTrue(app.navigationBars["iCloud 同步"].waitForExistence(timeout: 10))
        let folder = element("choose-icloud-folder")
        XCTAssertTrue(folder.waitForExistence(timeout: 10), "iCloud setup entry did not open")
        XCTAssertTrue(folder.isEnabled)
        XCTAssertFalse(element("sync-icloud-now").exists, "demo unexpectedly connected to iCloud")
        XCTAssertFalse(element("disconnect-icloud").exists)
        shot("81-icloud-unconnected")
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
        visible("make-custom").tap()
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
