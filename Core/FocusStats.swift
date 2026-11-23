import Foundation

/// Analytics over the logbook. Everything is computed from records, so it is always consistent.
struct FocusStats: Sendable {
    struct DayTotal: Identifiable, Hashable, Sendable {
        var day: Date
        var minutes: Int
        var sessions: Int
        var id: Date { day }
    }

    struct Ranked: Identifiable, Hashable, Sendable {
        var key: String
        var title: String
        var subtitle: String
        var count: Int
        var minutes: Int
        var id: String { key }
    }

    struct TagTotal: Identifiable, Hashable, Sendable {
        var tag: FocusTag
        var minutes: Int
        var sessions: Int
        var id: String { tag.rawValue }
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

    init(records: [FocusRecord], now: Date, calendar: Calendar, reference: ReferenceData, days: Int = 30) {
        totalSessions = records.count
        completedSessions = records.filter { $0.completed }.count
        totalMinutes = records.reduce(0) { $0 + $1.focusMinutes }
        totalKm = records.reduce(0) { $0 + $1.distanceKm }
        longestMinutes = records.map { $0.focusMinutes }.max() ?? 0
        averageMinutes = records.isEmpty ? 0 : totalMinutes / records.count
        tier = FocusStats.tier(forKm: totalKm)

        let today = calendar.startOfDay(for: now)

        // Per-day totals, keyed by the day the session started.
        var perDay: [Date: (Int, Int)] = [:]
        for r in records {
            let d = calendar.startOfDay(for: r.startedAt)
            let cur = perDay[d] ?? (0, 0)
            perDay[d] = (cur.0 + r.focusMinutes, cur.1 + 1)
        }
        todayMinutes = perDay[today]?.0 ?? 0
        daily = (0..<max(days, 1)).reversed().compactMap { offset in
            guard let d = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let v = perDay[d] ?? (0, 0)
            return DayTotal(day: d, minutes: v.0, sessions: v.1)
        }
        for offset in 0..<14 {
            guard let d = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let m = perDay[d]?.0 ?? 0
            if offset < 7 { weekMinutes += m } else { previousWeekMinutes += m }
        }

        // Streaks over days with at least one session. Today not yet done does not break a streak.
        let activeDays = Set(perDay.keys)
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
            var left = r.focusSeconds
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
            tagMap[r.tag] = (cur.0 + r.focusMinutes, cur.1 + 1)
        }
        tags = FocusTag.allCases.compactMap { t in
            guard let v = tagMap[t], v.1 > 0 else { return nil }
            return TagTotal(tag: t, minutes: v.0, sessions: v.1)
        }.sorted { $0.minutes > $1.minutes }

        // Rankings.
        func ranked(_ entries: [(key: String, title: String, subtitle: String, minutes: Int)]) -> [Ranked] {
            var map: [String: Ranked] = [:]
            for e in entries where !e.key.isEmpty {
                var cur = map[e.key] ?? Ranked(key: e.key, title: e.title, subtitle: e.subtitle, count: 0, minutes: 0)
                cur.count += 1
                cur.minutes += e.minutes
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
            return (code, reference.airlineName(icao: r.airlineICAO, fallback: r.airlineName), code, r.focusMinutes)
        })
        topRoutes = ranked(records.map { r in
            ("\(r.origin.code)-\(r.destination.code)", "\(r.origin.city) → \(r.destination.city)", "\(r.origin.code) – \(r.destination.code)", r.focusMinutes)
        })
        topAircraft = ranked(records.map { r in
            let code = r.typeCode ?? ""
            return (code, AircraftTypes.name(code: r.typeCode, fallback: r.typeName), code, r.focusMinutes)
        })
        // Only airports actually landed at count as visited.
        let landed = records.filter { $0.outcome == .landed }
        topAirports = ranked(landed.map { r in
            (r.destination.code, r.destination.city, r.destination.code, r.focusMinutes)
        })
        airportsVisited = Set(landed.map { $0.destination.code }).count
        countriesVisited = Set(landed.map { $0.destination.country }.filter { !$0.isEmpty }).count
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
