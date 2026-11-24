import Foundation

/// Calendar periods use half-open boundaries: a flight belongs to the period it started in.
enum FocusStatsRange: String, CaseIterable, Identifiable, Codable, Sendable {
    case all, year, month, week, day

    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: return "总计"
        case .year: return "年"
        case .month: return "月"
        case .week: return "周"
        case .day: return "日"
        }
    }
    var component: Calendar.Component? {
        switch self {
        case .all: return nil
        case .year: return .year
        case .month: return .month
        case .week: return .weekOfYear
        case .day: return .day
        }
    }
    func interval(containing date: Date, calendar: Calendar) -> DateInterval? {
        guard let component else { return nil }
        return calendar.dateInterval(of: component, for: date)
    }
    func records(_ records: [FocusRecord], anchor: Date, calendar: Calendar) -> [FocusRecord] {
        guard let interval = interval(containing: anchor, calendar: calendar) else { return records }
        return records.filter { $0.startedAt >= interval.start && $0.startedAt < interval.end }
    }
    func shifted(_ date: Date, by offset: Int, calendar: Calendar) -> Date {
        guard let component, let interval = interval(containing: date, calendar: calendar) else { return date }
        return calendar.date(byAdding: component, value: offset, to: interval.start) ?? date
    }
}

/// Analytics over the logbook. Everything is computed from records, so it is always consistent.
struct FocusStats: Sendable {
    struct DayTotal: Identifiable, Hashable, Sendable {
        var day: Date
        var minutes: Int
        var sessions: Int
        var seconds: Int = 0
        var id: Date { day }
    }

    struct Ranked: Identifiable, Hashable, Sendable {
        var key: String
        var title: String
        var subtitle: String
        var count: Int
        var minutes: Int
        var seconds: Int = 0
        var id: String { key }
    }

    struct TagTotal: Identifiable, Hashable, Sendable {
        var tag: FocusTag
        var minutes: Int
        var sessions: Int
        var seconds: Int = 0
        var id: String { tag.rawValue }
    }

    enum TrendUnit: Sendable { case hour, day, month, year }

    struct TrendTotal: Identifiable, Hashable, Sendable {
        var date: Date
        var seconds: Int
        var sessions: Int
        var minutes: Int { FocusStats.minutes(seconds: seconds) }
        var id: Date { date }
    }

    struct DurationTotal: Identifiable, Hashable, Sendable {
        var index: Int
        var title: String
        var sessions: Int
        var id: Int { index }
    }

    struct Tier: Hashable, Sendable {
        var index: Int
        var title: String
        var english: String
        var floorKm: Double
        /// nil at the top tier.
        var nextKm: Double?
    }

    static let tiers: [(title: String, english: String, km: Double)] = [
        ("蓝天卡", "BLUE", 0),
        ("银卡", "SILVER", 5_000),
        ("金卡", "GOLD", 20_000),
        ("白金卡", "PLATINUM", 60_000),
        ("钻石卡", "DIAMOND", 150_000),
        ("终身平流层", "STRATOSPHERE", 400_000)
    ]

    var totalSessions = 0
    var completedSessions = 0
    var landedSessions = 0
    var timerCompletedSessions = 0
    var endedEarlySessions = 0
    var totalSeconds = 0
    var totalMinutes = 0
    var totalKm = 0.0
    var longestMinutes = 0
    var averageMinutes = 0
    var currentStreak = 0
    var longestStreak = 0
    var todayMinutes = 0
    var weekMinutes = 0
    var previousWeekMinutes = 0
    var airportsVisited = 0
    var countriesVisited = 0
    var activeDayCount = 0
    var elapsedDayCount = 0
    var averageDailyMinutes = 0
    var averageActiveDayMinutes = 0
    var routeCount = 0
    var pauseCount = 0
    var pausedMinutes = 0
    var range: FocusStatsRange = .all
    var period: DateInterval?
    var comparisonPeriod: DateInterval?
    var previousPeriodMinutes = 0
    var previousPeriodSessions = 0
    var previousPeriodSeconds = 0
    var trendUnit: TrendUnit = .day
    var trend: [TrendTotal] = []
    /// Time-of-day and weekday totals attributed to the session's actual start, not inferred pause timing.
    var startHourly: [Int] = Array(repeating: 0, count: 24)
    var weekdayMinutes: [Int] = Array(repeating: 0, count: 7)
    var startHourlySeconds: [Int] = Array(repeating: 0, count: 24)
    var weekdaySeconds: [Int] = Array(repeating: 0, count: 7)
    var durations: [DurationTotal] = []
    var daily: [DayTotal] = []
    /// Minutes focused in each hour of the day, 0...23.
    var hourly: [Int] = Array(repeating: 0, count: 24)
    var tags: [TagTotal] = []
    var topAirlines: [Ranked] = []
    var topAirports: [Ranked] = []
    var topRoutes: [Ranked] = []
    var topAircraft: [Ranked] = []
    var tier = Tier(index: 0, title: "蓝天卡", english: "BLUE", floorKm: 0, nextKm: 5_000)

    var completionRate: Double { totalSessions == 0 ? 0 : Double(completedSessions) / Double(totalSessions) }
    var periodChange: Double? {
        guard comparisonPeriod != nil, previousPeriodSeconds > 0 else { return nil }
        return Double(totalSeconds - previousPeriodSeconds) / Double(previousPeriodSeconds)
    }
    var bestDay: DayTotal? { daily.filter { $0.seconds > 0 }.max { $0.seconds < $1.seconds } }
    var earthLaps: Double { totalKm / 40_075 }
    /// Hour of day with the most focus time, or nil with no data.
    var bestHour: Int? {
        guard let best = hourly.max(), best > 0 else { return nil }
        return hourly.firstIndex(of: best)
    }
    var tierProgress: Double {
        guard let next = tier.nextKm else { return 1 }
        return min(max((totalKm - tier.floorKm) / max(next - tier.floorKm, 1), 0), 1)
    }

    static func tier(forKm km: Double) -> Tier {
        var index = 0
        for (i, t) in tiers.enumerated() where km >= t.km { index = i }
        let t = tiers[index]
        return Tier(
            index: index,
            title: t.title,
            english: t.english,
            floorKm: t.km,
            nextKm: index + 1 < tiers.count ? tiers[index + 1].km : nil
        )
    }

    init() {}

    static func minutes(seconds: Int) -> Int { Int((Double(max(seconds, 0)) / 60).rounded()) }

    init(records: [FocusRecord], now: Date, calendar: Calendar, reference: ReferenceData, days: Int = 30) {
        totalSessions = records.count
        completedSessions = records.filter { $0.completed }.count
        landedSessions = records.filter { $0.outcome == .landed }.count
        timerCompletedSessions = records.filter { $0.outcome == .timerDone }.count
        endedEarlySessions = records.filter { $0.outcome == .endedEarly }.count
        totalSeconds = records.reduce(0) { $0 + max($1.focusSeconds, 0) }
        totalMinutes = Self.minutes(seconds: totalSeconds)
        totalKm = records.reduce(0) { $0 + max($1.distanceKm, 0) }
        longestMinutes = Self.minutes(seconds: records.map { $0.focusSeconds }.max() ?? 0)
        averageMinutes = records.isEmpty ? 0 : Self.minutes(seconds: totalSeconds / records.count)
        pauseCount = records.reduce(0) { $0 + max($1.pauseCount, 0) }
        pausedMinutes = Self.minutes(seconds: records.reduce(0) { $0 + max($1.pausedSeconds, 0) })
        tier = FocusStats.tier(forKm: totalKm)

        let today = calendar.startOfDay(for: now)

        // Per-day totals, keyed by the day the session started.
        var perDay: [Date: (Int, Int)] = [:]
        for r in records {
            let d = calendar.startOfDay(for: r.startedAt)
            let cur = perDay[d] ?? (0, 0)
            perDay[d] = (cur.0 + max(r.focusSeconds, 0), cur.1 + 1)
        }
        todayMinutes = Self.minutes(seconds: perDay[today]?.0 ?? 0)
        daily = (0..<max(days, 1)).reversed().compactMap { offset in
            guard let d = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let v = perDay[d] ?? (0, 0)
            return DayTotal(day: d, minutes: Self.minutes(seconds: v.0), sessions: v.1, seconds: v.0)
        }
        var weekSeconds = 0
        var previousWeekSeconds = 0
        for offset in 0..<14 {
            guard let d = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let m = perDay[d]?.0 ?? 0
            if offset < 7 { weekSeconds += m } else { previousWeekSeconds += m }
        }
        weekMinutes = Self.minutes(seconds: weekSeconds)
        previousWeekMinutes = Self.minutes(seconds: previousWeekSeconds)

        // Streaks over days with at least one session. Today not yet done does not break a streak.
        let activeDays = Set(perDay.filter { $0.value.0 > 0 }.keys)
        activeDayCount = activeDays.count
        var cursor = today
        if !activeDays.contains(cursor), let y = calendar.date(byAdding: .day, value: -1, to: cursor) { cursor = y }
        while activeDays.contains(cursor) {
            currentStreak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        var run = 0
        var previousDay: Date?
        for d in activeDays.sorted() {
            if let p = previousDay, let next = calendar.date(byAdding: .day, value: 1, to: p), calendar.isDate(next, inSameDayAs: d) {
                run += 1
            } else {
                run = 1
            }
            longestStreak = max(longestStreak, run)
            previousDay = d
        }

        // Hour-of-day distribution: spread each session's minutes across the hours it covered.
        for r in records {
            var t = r.startedAt
            var left = max(r.focusSeconds, 0)
            while left > 0 {
                let hour = calendar.component(.hour, from: t)
                let nextHour = calendar.nextDate(after: t, matching: DateComponents(minute: 0, second: 0), matchingPolicy: .nextTime) ?? t.addingTimeInterval(3600)
                let chunk = min(left, max(1, Int(nextHour.timeIntervalSince(t))))
                hourly[hour] += chunk
                left -= chunk
                t = t.addingTimeInterval(Double(chunk))
            }
        }
        hourly = hourly.map { Int((Double($0) / 60).rounded()) }

        // Tags.
        var tagMap: [FocusTag: (Int, Int)] = [:]
        for r in records {
            let cur = tagMap[r.tag] ?? (0, 0)
            tagMap[r.tag] = (cur.0 + max(r.focusSeconds, 0), cur.1 + 1)
        }
        tags = FocusTag.allCases.compactMap { t in
            guard let v = tagMap[t], v.1 > 0 else { return nil }
            return TagTotal(tag: t, minutes: Self.minutes(seconds: v.0), sessions: v.1, seconds: v.0)
        }.sorted {
            if $0.seconds != $1.seconds { return $0.seconds > $1.seconds }
            return $0.tag.rawValue < $1.tag.rawValue
        }

        // Rankings.
        func ranked(_ entries: [(key: String, title: String, subtitle: String, seconds: Int)]) -> [Ranked] {
            var map: [String: Ranked] = [:]
            for e in entries where !e.key.isEmpty {
                var cur = map[e.key] ?? Ranked(key: e.key, title: e.title, subtitle: e.subtitle, count: 0, minutes: 0)
                cur.count += 1
                cur.seconds += e.seconds
                cur.minutes = Self.minutes(seconds: cur.seconds)
                map[e.key] = cur
            }
            return map.values.sorted {
                if $0.count != $1.count { return $0.count > $1.count }
                if $0.minutes != $1.minutes { return $0.minutes > $1.minutes }
                return $0.key < $1.key
            }
        }
        topAirlines = ranked(records.map { r in
            let code = r.airlineICAO ?? ""
            return (code, reference.airlineName(icao: r.airlineICAO, fallback: r.airlineName), code, max(r.focusSeconds, 0))
        })
        topRoutes = ranked(records.map { r in
            ("\(r.origin.code)-\(r.destination.code)", "\(r.origin.city) → \(r.destination.city)", "\(r.origin.code) – \(r.destination.code)", max(r.focusSeconds, 0))
        })
        topAircraft = ranked(records.map { r in
            let code = r.typeCode ?? ""
            return (code, AircraftTypes.name(code: r.typeCode, fallback: r.typeName), code, max(r.focusSeconds, 0))
        })
        // Only airports actually landed at count as visited.
        let landed = records.filter { $0.outcome == .landed }
        topAirports = ranked(landed.map { r in
            (r.destination.code, r.destination.city, r.destination.code, max(r.focusSeconds, 0))
        })
        routeCount = topRoutes.count
        airportsVisited = Set(landed.map { $0.destination.code }).count
        countriesVisited = Set(landed.map { $0.destination.country }.filter { !$0.isEmpty }).count
    }

    /// Range-aware analytics. Keep the original initializer for AppModel and existing widgets.
    /// Pauses have no timestamps in a record, so charts attribute actual focus seconds to the start.
    init(records allRecords: [FocusRecord], now: Date, calendar: Calendar, reference: ReferenceData,
         range: FocusStatsRange, anchor: Date? = nil) {
        let anchor = anchor ?? now
        let selectedPeriod = range.interval(containing: anchor, calendar: calendar)
        let records = range.records(allRecords, anchor: anchor, calendar: calendar)
        let evaluationDate = selectedPeriod.map { min(now, $0.end.addingTimeInterval(-1)) } ?? now
        self.init(records: records, now: evaluationDate, calendar: calendar, reference: reference)
        self.range = range
        period = selectedPeriod

        let firstDay = records.map { calendar.startOfDay(for: $0.startedAt) }.min() ?? calendar.startOfDay(for: now)
        let lastDay = max(calendar.startOfDay(for: now), records.map { calendar.startOfDay(for: $0.startedAt) }.max() ?? firstDay)
        let start = selectedPeriod?.start ?? firstDay
        let end = selectedPeriod?.end ?? calendar.date(byAdding: .day, value: 1, to: lastDay) ?? now
        let elapsedEnd = min(end, calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now)
        elapsedDayCount = max(0, calendar.dateComponents([.day], from: start, to: elapsedEnd).day ?? 0)
        averageDailyMinutes = elapsedDayCount > 0 ? Self.minutes(seconds: totalSeconds / elapsedDayCount) : 0
        averageActiveDayMinutes = activeDayCount > 0 ? Self.minutes(seconds: totalSeconds / activeDayCount) : 0

        var dailyMap: [Date: (seconds: Int, sessions: Int)] = [:]
        var startSeconds = Array(repeating: 0, count: 24)
        var weekdaySeconds = Array(repeating: 0, count: 7)
        var durationCounts = Array(repeating: 0, count: 5)
        for record in records {
            let seconds = max(record.focusSeconds, 0)
            let day = calendar.startOfDay(for: record.startedAt)
            let value = dailyMap[day] ?? (0, 0)
            dailyMap[day] = (value.seconds + seconds, value.sessions + 1)
            startSeconds[calendar.component(.hour, from: record.startedAt)] += seconds
            weekdaySeconds[calendar.component(.weekday, from: record.startedAt) - 1] += seconds
            let bucket: Int
            switch seconds {
            case ..<900: bucket = 0
            case ..<1800: bucket = 1
            case ..<3600: bucket = 2
            case ..<7200: bucket = 3
            default: bucket = 4
            }
            durationCounts[bucket] += 1
        }
        startHourly = startSeconds.map { Self.minutes(seconds: $0) }
        weekdayMinutes = weekdaySeconds.map { Self.minutes(seconds: $0) }
        startHourlySeconds = startSeconds
        self.weekdaySeconds = weekdaySeconds
        let durationTitles = ["少于15分", "15–29分", "30–59分", "1–2小时", "2小时及以上"]
        durations = durationTitles.enumerated().map { DurationTotal(index: $0.offset, title: $0.element, sessions: durationCounts[$0.offset]) }
        daily = []
        var cursor = calendar.startOfDay(for: start)
        while cursor < end {
            let value = dailyMap[cursor] ?? (0, 0)
            daily.append(DayTotal(day: cursor, minutes: Self.minutes(seconds: value.seconds), sessions: value.sessions, seconds: value.seconds))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor), next > cursor else { break }
            cursor = next
        }

        let component: Calendar.Component
        switch range {
        case .day: trendUnit = .hour; component = .hour
        case .week, .month: trendUnit = .day; component = .day
        case .year: trendUnit = .month; component = .month
        case .all:
            let months = calendar.dateComponents([.month], from: start, to: end).month ?? 0
            trendUnit = months > 24 ? .year : .month
            component = months > 24 ? .year : .month
        }
        var buckets: [Date: (seconds: Int, sessions: Int)] = [:]
        for record in records {
            guard let bucketStart = calendar.dateInterval(of: component, for: record.startedAt)?.start else { continue }
            let value = buckets[bucketStart] ?? (0, 0)
            buckets[bucketStart] = (value.seconds + max(record.focusSeconds, 0), value.sessions + 1)
        }
        cursor = calendar.dateInterval(of: component, for: start)?.start ?? start
        while cursor < end {
            let value = buckets[cursor] ?? (0, 0)
            trend.append(TrendTotal(date: cursor, seconds: value.seconds, sessions: value.sessions))
            guard let next = calendar.date(byAdding: component, value: 1, to: cursor), next > cursor else { break }
            cursor = next
        }

        if let selectedPeriod, let component = range.component,
           let previousStart = calendar.date(byAdding: component, value: -1, to: selectedPeriod.start),
           let previous = range.interval(containing: previousStart, calendar: calendar) {
            var previousEnd = previous.end
            // Compare an ongoing calendar period with the same elapsed calendar portion last time.
            if now >= selectedPeriod.start && now < selectedPeriod.end {
                let elapsed = calendar.dateComponents([.month, .day, .hour, .minute, .second], from: selectedPeriod.start, to: now)
                previousEnd = min(previous.end, calendar.date(byAdding: elapsed, to: previous.start) ?? previous.end)
            }
            comparisonPeriod = DateInterval(start: previous.start, end: max(previous.start, previousEnd))
            let previousRecords = allRecords.filter { $0.startedAt >= previous.start && $0.startedAt < previousEnd }
            previousPeriodSessions = previousRecords.count
            previousPeriodSeconds = previousRecords.reduce(0) { $0 + max($1.focusSeconds, 0) }
            previousPeriodMinutes = Self.minutes(seconds: previousPeriodSeconds)
        }
    }
}

/// Friendly names for common ICAO type designators.
enum AircraftTypes {
    private static let names: [String: String] = [
        "A19N": "空客 A319neo", "A20N": "空客 A320neo", "A21N": "空客 A321neo",
        "A318": "空客 A318", "A319": "空客 A319", "A320": "空客 A320", "A321": "空客 A321",
        "A332": "空客 A330-200", "A333": "空客 A330-300", "A338": "空客 A330-800", "A339": "空客 A330-900",
        "A342": "空客 A340-200", "A343": "空客 A340-300", "A346": "空客 A340-600",
        "A359": "空客 A350-900", "A35K": "空客 A350-1000", "A388": "空客 A380-800",
        "BCS1": "空客 A220-100", "BCS3": "空客 A220-300",
        "B37M": "波音 737 MAX 7", "B38M": "波音 737 MAX 8", "B39M": "波音 737 MAX 9", "B3XM": "波音 737 MAX 10",
        "B733": "波音 737-300", "B734": "波音 737-400", "B735": "波音 737-500", "B736": "波音 737-600",
        "B737": "波音 737-700", "B738": "波音 737-800", "B739": "波音 737-900",
        "B744": "波音 747-400", "B748": "波音 747-8", "B752": "波音 757-200", "B753": "波音 757-300",
        "B762": "波音 767-200", "B763": "波音 767-300", "B764": "波音 767-400",
        "B772": "波音 777-200", "B77L": "波音 777-200LR", "B773": "波音 777-300", "B77W": "波音 777-300ER",
        "B788": "波音 787-8", "B789": "波音 787-9", "B78X": "波音 787-10",
        "C919": "中国商飞 C919", "AJ27": "中国商飞 ARJ21", "C909": "中国商飞 C909",
        "E170": "巴航工业 E170", "E75L": "巴航工业 E175", "E75S": "巴航工业 E175", "E190": "巴航工业 E190",
        "E195": "巴航工业 E195", "E290": "巴航工业 E190-E2", "E295": "巴航工业 E195-E2",
        "CRJ2": "庞巴迪 CRJ200", "CRJ7": "庞巴迪 CRJ700", "CRJ9": "庞巴迪 CRJ900", "CRJX": "庞巴迪 CRJ1000",
        "AT72": "ATR 72", "AT75": "ATR 72-500", "AT76": "ATR 72-600", "AT45": "ATR 42-500",
        "DH8D": "德哈维兰 Dash 8-400", "DH8C": "德哈维兰 Dash 8-300",
        "MD11": "麦道 MD-11", "SU95": "苏霍伊 SSJ100"
    ]

    static func name(code: String?, fallback: String? = nil) -> String {
        if let code, let n = names[code.uppercased()] { return n }
        if let fallback, !fallback.isEmpty { return fallback.capitalized }
        return code ?? "未知机型"
    }

    /// Wide-body types, for sizing the map icon.
    static func isWidebody(code: String?, category: String?) -> Bool {
        if category == "A5" { return true }
        guard let c = code?.uppercased() else { return false }
        return c.hasPrefix("A33") || c.hasPrefix("A34") || c.hasPrefix("A35") || c.hasPrefix("A38")
            || c.hasPrefix("B74") || c.hasPrefix("B76") || c.hasPrefix("B77") || c.hasPrefix("B78") || c == "MD11"
    }
}
