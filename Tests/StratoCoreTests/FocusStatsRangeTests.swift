import XCTest
@testable import StratoCore

final class FocusStatsRangeTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func record(_ start: Date, seconds: Int = 1800, tag: FocusTag = .coding,
                        outcome: SessionOutcome = .landed, destination: Airport = Fixtures.hnd) -> FocusRecord {
        FocusRecord(id: UUID(), flightNumber: "NH920", callsign: "ANA920", airlineICAO: "ANA", airlineName: nil,
                    registration: nil, typeCode: "B789", typeName: nil, origin: Fixtures.pvg, destination: destination,
                    tag: tag, seat: "12A", cabin: .business, gate: "G16", sequence: 1,
                    startedAt: start, endedAt: start.addingTimeInterval(Double(seconds)), focusSeconds: seconds,
                    pausedSeconds: 0, pauseCount: 0, distanceKm: 800, routeKm: 1740,
                    boardedFraction: 0.4, endFraction: outcome == .landed ? 1 : 0.7, outcome: outcome,
                    simulated: false, landingEstimated: false, maxAltitudeFt: 38000, path: [], altitudeProfile: [])
    }

    private func stats(_ records: [FocusRecord], range: FocusStatsRange, anchor: Date, now: Date? = nil) -> FocusStats {
        FocusStats(records: records, now: now ?? anchor, calendar: calendar, reference: Fixtures.reference,
                   range: range, anchor: anchor)
    }

    func testMonthBoundariesAreHalfOpen() {
        let records = [record(date(2026, 10, 31, hour: 23, minute: 59)), record(date(2026, 11, 1)),
                       record(date(2026, 11, 30, hour: 23, minute: 59), seconds: 2700), record(date(2026, 12, 1))]
        let result = stats(records, range: .month, anchor: date(2026, 11, 24), now: date(2026, 12, 5))
        XCTAssertEqual(result.totalSessions, 2)
        XCTAssertEqual(result.totalSeconds, 4500)
        XCTAssertEqual(result.period?.start, date(2026, 11, 1))
        XCTAssertEqual(result.period?.end, date(2026, 12, 1))
        XCTAssertEqual(result.daily.count, 30)
        XCTAssertEqual(result.trend.reduce(0) { $0 + $1.seconds }, result.totalSeconds)
        XCTAssertEqual(result.previousPeriodSessions, 1)
    }

    func testOvernightFlightBelongsToItsStartDate() {
        let records = [record(date(2026, 11, 23, hour: 23, minute: 30), seconds: 5400),
                       record(date(2026, 11, 24), seconds: 1800)]
        let today = stats(records, range: .day, anchor: date(2026, 11, 24, hour: 12))
        let yesterday = stats(records, range: .day, anchor: date(2026, 11, 23), now: date(2026, 11, 24, hour: 12))
        XCTAssertEqual(today.totalSeconds, 1800)
        XCTAssertEqual(yesterday.totalSeconds, 5400)
        XCTAssertEqual(today.totalSessions, 1)
        XCTAssertEqual(today.trend.reduce(0) { $0 + $1.sessions }, 1)
        XCTAssertEqual(today.trend.count, 24)
    }

    func testSecondsAreSummedBeforeRounding() {
        let result = stats([record(date(2026, 11, 24, hour: 9), seconds: 31),
                            record(date(2026, 11, 24, hour: 10), seconds: 31)],
                           range: .all, anchor: date(2026, 11, 24, hour: 15))
        XCTAssertEqual(result.totalSeconds, 62)
        XCTAssertEqual(result.totalMinutes, 1)
        XCTAssertEqual(result.daily.first?.seconds, 62)
        XCTAssertEqual(result.daily.first?.minutes, 1)
        XCTAssertEqual(result.tags.first?.seconds, 62)
        XCTAssertEqual(result.tags.first?.minutes, 1)
        XCTAssertEqual(result.topRoutes.first?.seconds, 62)
        XCTAssertEqual(result.startHourlySeconds.reduce(0, +), 62)
        XCTAssertEqual(result.weekdaySeconds.reduce(0, +), 62)
    }

    func testCompletionUsesRecordedOutcomeAndOnlyLandedAirportsCount() {
        let records = [record(date(2026, 11, 24, hour: 8), tag: .coding, outcome: .landed),
                       record(date(2026, 11, 24, hour: 9), tag: .study, outcome: .timerDone, destination: Fixtures.jfk),
                       record(date(2026, 11, 24, hour: 10), tag: .reading, outcome: .endedEarly, destination: Fixtures.lhr)]
        let result = stats(records, range: .day, anchor: date(2026, 11, 24, hour: 15))
        XCTAssertEqual(result.landedSessions, 1)
        XCTAssertEqual(result.timerCompletedSessions, 1)
        XCTAssertEqual(result.endedEarlySessions, 1)
        XCTAssertEqual(result.completionRate, 2.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(result.airportsVisited, 1)
        XCTAssertEqual(result.countriesVisited, 1)
        XCTAssertEqual(result.routeCount, 3)
        XCTAssertEqual(result.tags.reduce(0) { $0 + $1.seconds }, result.totalSeconds)
    }

    func testWeekCrossesCalendarYearWithoutLosingFlights() {
        let records = [record(date(2026, 12, 27)), record(date(2026, 12, 28)),
                       record(date(2027, 1, 3)), record(date(2027, 1, 4))]
        let result = stats(records, range: .week, anchor: date(2027, 1, 1), now: date(2027, 1, 10))
        XCTAssertEqual(result.period?.start, date(2026, 12, 28))
        XCTAssertEqual(result.period?.end, date(2027, 1, 4))
        XCTAssertEqual(result.totalSessions, 2)
        XCTAssertEqual(result.daily.count, 7)
    }

    func testNavigationUsesPeriodStartInsteadOfClampingMonthEnd() {
        XCTAssertEqual(FocusStatsRange.month.shifted(date(2026, 1, 31), by: 1, calendar: calendar), date(2026, 2, 1))
        XCTAssertEqual(FocusStatsRange.month.shifted(date(2026, 3, 31), by: -1, calendar: calendar), date(2026, 2, 1))
        XCTAssertEqual(FocusStatsRange.year.shifted(date(2024, 2, 29), by: 1, calendar: calendar), date(2025, 1, 1))
    }

    func testCurrentMonthComparesSameElapsedPortion() {
        let now = date(2026, 11, 24, hour: 15)
        let records = [record(date(2026, 11, 24, hour: 14), seconds: 100),
                       record(date(2026, 10, 24, hour: 14, minute: 59), seconds: 200),
                       record(date(2026, 10, 24, hour: 15, minute: 1), seconds: 300)]
        let result = stats(records, range: .month, anchor: now)
        XCTAssertEqual(result.previousPeriodSeconds, 200)
        XCTAssertEqual(result.comparisonPeriod?.end, date(2026, 10, 24, hour: 15))
        XCTAssertEqual(result.periodChange ?? 0, -0.5, accuracy: 0.0001)
    }

    func testLeapYearAndMonthFillZeroDays() {
        let records = [record(date(2024, 2, 29, hour: 10)), record(date(2024, 12, 31, hour: 10))]
        let year = stats(records, range: .year, anchor: date(2024, 2, 29), now: date(2025, 1, 5))
        XCTAssertEqual(year.daily.count, 366)
        XCTAssertEqual(year.trend.count, 12)
        XCTAssertEqual(year.trend.reduce(0) { $0 + $1.seconds }, 3600)
        let month = stats(records, range: .month, anchor: date(2024, 2, 29), now: date(2025, 1, 5))
        XCTAssertEqual(month.daily.count, 29)
        XCTAssertEqual(month.totalSessions, 1)
        XCTAssertEqual(month.daily.filter { $0.seconds == 0 }.count, 28)
    }

    func testAverageIncludesElapsedDaysWithNoRecords() {
        let result = stats([record(date(2026, 11, 3, hour: 9), seconds: 1200)],
                           range: .month, anchor: date(2026, 11, 3, hour: 15))
        XCTAssertEqual(result.elapsedDayCount, 3)
        XCTAssertEqual(result.activeDayCount, 1)
        XCTAssertEqual(result.averageDailyMinutes, 7)
        XCTAssertEqual(result.averageActiveDayMinutes, 20)
        XCTAssertEqual(result.longestStreak, 1)
    }

    func testEmptySelectedPeriodHasNoInheritedTotalsOrRankings() {
        let result = stats([record(date(2025, 11, 24))], range: .month, anchor: date(2026, 11, 24, hour: 15))
        XCTAssertEqual(result.totalSeconds, 0)
        XCTAssertEqual(result.totalSessions, 0)
        XCTAssertEqual(result.activeDayCount, 0)
        XCTAssertEqual(result.completionRate, 0)
        XCTAssertTrue(result.topRoutes.isEmpty)
        XCTAssertTrue(result.tags.isEmpty)
        XCTAssertEqual(result.daily.count, 30)
        XCTAssertTrue(result.trend.allSatisfy { $0.seconds == 0 && $0.sessions == 0 })
        XCTAssertNil(result.bestDay)
    }

    func testDayTrendHandlesBothDaylightSavingBoundaries() {
        var newYork = calendar
        newYork.timeZone = TimeZone(identifier: "America/New_York")!
        let spring = FocusStats(records: [record(date(2026, 3, 8, hour: 7, minute: 30), seconds: 600)],
                                now: date(2026, 3, 8, hour: 20), calendar: newYork, reference: Fixtures.reference,
                                range: .day, anchor: date(2026, 3, 8, hour: 20))
        XCTAssertEqual(spring.trend.count, 23)
        XCTAssertEqual(spring.trend.reduce(0) { $0 + $1.seconds }, 600)
        let autumn = FocusStats(records: [record(date(2026, 11, 1, hour: 5, minute: 30), seconds: 600),
                                         record(date(2026, 11, 1, hour: 6, minute: 30), seconds: 900)],
                                now: date(2026, 11, 1, hour: 20), calendar: newYork, reference: Fixtures.reference,
                                range: .day, anchor: date(2026, 11, 1, hour: 20))
        XCTAssertEqual(autumn.trend.count, 25)
        XCTAssertEqual(Set(autumn.trend.map(\.date)).count, 25)
        XCTAssertEqual(autumn.trend.reduce(0) { $0 + $1.seconds }, 1500)
        XCTAssertEqual(autumn.startHourlySeconds[1], 1500)
    }
}
