import Charts
import SwiftUI

struct StatsScreen: View {
    @Environment(AppModel.self) private var model
    @AppStorage("statsRange") private var storedRange = FocusStatsRange.all.rawValue
    @State private var anchor = Date()
    @State private var showingSessions = false

    var body: some View {
        let now = Date()
        let range = FocusStatsRange(rawValue: storedRange) ?? .all
        let stats = FocusStats(records: model.records, now: now, calendar: FocusStatsUI.calendar,
                               reference: model.reference, range: range, anchor: anchor)
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    FocusPeriodSelector(storedRange: $storedRange, anchor: $anchor, now: now, identifier: "stats")
                    summary(stats)
                    metrics(stats)
                    if stats.totalSessions == 0 {
                        ContentUnavailableView("这段时间还没有记录", systemImage: "chart.bar.xaxis",
                                               description: Text("切换日期看看其他航程，或完成一次新的专注。"))
                            .padding(.vertical, 24)
                    } else {
                        trendChart(stats)
                        activity(stats, now: now)
                        completion(stats)
                        taskDistribution(stats)
                        startHours(stats)
                        weekdays(stats)
                        durationDistribution(stats)
                        flightMetrics(stats)
                        ranking("常飞航线", stats.topRoutes, tint: Palette.sky)
                        ranking("常飞航司", stats.topAirlines, tint: Palette.mint)
                        ranking("常到机场", stats.topAirports, tint: Palette.amber)
                        ranking("常坐机型", stats.topAircraft, tint: Palette.indigo)
                    }
                    membership(model.stats)
                }
                .padding(16)
            }
            .background(Palette.backdrop.ignoresSafeArea())
            .navigationTitle("专注统计")
        }
    }

    private func summary(_ stats: FocusStats) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(stats.range == .all ? "累计专注时长" : "本期专注时长")
                    .font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "airplane")
                    .font(.system(size: 24, weight: .semibold))
                    .rotationEffect(.degrees(-20))
                    .foregroundStyle(Palette.sky)
            }
            Text(FocusStatsUI.duration(seconds: stats.totalSeconds))
                .font(.system(size: 35, weight: .bold, design: .rounded).monospacedDigit())
                .lineLimit(1).minimumScaleFactor(0.65)
                .accessibilityIdentifier("stats-total-duration")
            HStack(spacing: 14) {
                Label("\(stats.totalSessions) 段航程", systemImage: "ticket")
                Label("\(stats.activeDayCount) 天专注", systemImage: "calendar")
            }
            .font(.caption.weight(.medium)).foregroundStyle(Palette.sky)
            Divider().overlay(.white.opacity(0.08))
            HStack(spacing: 6) {
                Image(systemName: comparisonSymbol(stats))
                Text(comparisonText(stats)).lineLimit(2)
                Spacer(minLength: 0)
            }
            .font(.caption).foregroundStyle(.secondary)
        }
        .padding(20)
        .glassCard(cornerRadius: 26, tint: Palette.sky.opacity(0.1))
    }

    private func comparisonSymbol(_ stats: FocusStats) -> String {
        guard let change = stats.periodChange else { return stats.range == .all ? "clock" : "arrow.left.arrow.right" }
        return change >= 0 ? "arrow.up.right" : "arrow.down.right"
    }

    private func comparisonText(_ stats: FocusStats) -> String {
        guard stats.comparisonPeriod != nil else { return "按航段开始日期统计，暂停时间不计入专注" }
        if let change = stats.periodChange {
            let percentage = String(format: "%.0f", abs(change * 100))
            return "比上期\(change >= 0 ? "增加" : "减少") \(percentage)% · 上期 \(FocusStatsUI.duration(seconds: stats.previousPeriodSeconds))"
        }
        return "上期暂无专注记录 · 本期 \(stats.totalSessions) 段航程"
    }

    private func metrics(_ stats: FocusStats) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            metric("日均专注", value: FocusStatsUI.duration(seconds: stats.elapsedDayCount > 0 ? stats.totalSeconds / stats.elapsedDayCount : 0),
                   detail: "包含本期无记录的日期", symbol: "sun.max", tint: Palette.sky)
            metric("平均每段", value: FocusStatsUI.duration(seconds: stats.totalSessions > 0 ? stats.totalSeconds / stats.totalSessions : 0),
                   detail: "最长 \(stats.longestMinutes) 分钟", symbol: "timer", tint: Palette.indigo)
            metric("完成率", value: "\(Int((stats.completionRate * 100).rounded()))%",
                   detail: "\(stats.completedSessions) / \(stats.totalSessions) 段完成", symbol: "checkmark.seal", tint: Palette.mint)
            metric("最长连续", value: "\(stats.longestStreak) 天",
                   detail: "本期有 \(stats.activeDayCount) 个专注日", symbol: "flame", tint: Palette.amber)
        }
    }

    private func metric(_ title: String, value: String, detail: String, symbol: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(title, systemImage: symbol).font(.caption).foregroundStyle(tint)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                .lineLimit(1).minimumScaleFactor(0.65)
            Text(detail).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .glassCard(cornerRadius: 20)
    }

    private func trendChart(_ stats: FocusStats) -> some View {
        let values = stats.trend.map { showingSessions ? Double($0.sessions) : Double($0.seconds) / 60 }
        let maximum = max(values.max() ?? 0, 1)
        let average = values.reduce(0, +) / Double(max(values.count, 1))
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("专注趋势").font(.headline)
                    Text(trendDescription(stats)).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { withAnimation(.easeInOut(duration: 0.2)) { showingSessions.toggle() } } label: {
                    HStack(spacing: 5) {
                        Text(showingSessions ? "航段" : "时长")
                        Image(systemName: "arrow.left.arrow.right").font(.caption2)
                    }
                    .font(.caption.weight(.semibold)).foregroundStyle(Palette.sky)
                    .padding(.horizontal, 11).padding(.vertical, 7)
                    .background(Palette.sky.opacity(0.1), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("stats-trend-metric")
            }
            Chart {
                ForEach(stats.trend) { point in
                    BarMark(x: .value("日期", point.date, unit: trendComponent(stats.trendUnit)),
                            y: .value(showingSessions ? "航段" : "分钟", showingSessions ? Double(point.sessions) : Double(point.seconds) / 60))
                        .foregroundStyle(LinearGradient(colors: [Palette.sky, Palette.indigo.opacity(0.65)], startPoint: .top, endPoint: .bottom))
                        .cornerRadius(4)
                }
                if average > 0 {
                    RuleMark(y: .value("平均", average))
                        .foregroundStyle(.white.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
            }
            .chartYScale(domain: 0...maximum * 1.15)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) { Text(trendLabel(date, stats: stats)).font(.caption2) }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine().foregroundStyle(.white.opacity(0.08))
                    AxisValueLabel()
                }
            }
            .frame(height: 180)
            HStack {
                Text(showingSessions ? "单位：航段" : "单位：分钟").font(.caption2)
                Spacer()
                Text("虚线为每格平均").font(.caption2)
            }
            .foregroundStyle(.secondary)
        }
        .padding(17)
        .glassCard(cornerRadius: 23)
    }

    private func trendComponent(_ unit: FocusStats.TrendUnit) -> Calendar.Component {
        switch unit {
        case .hour: return .hour
        case .day: return .day
        case .month: return .month
        case .year: return .year
        }
    }

    private func trendDescription(_ stats: FocusStats) -> String {
        switch stats.trendUnit {
        case .hour: return "按开始小时汇总"
        case .day: return "按开始日期汇总，空白日期保留"
        case .month: return "每个月的真实专注时长"
        case .year: return "每一年的专注足迹"
        }
    }

    private func trendLabel(_ date: Date, stats: FocusStats) -> String {
        switch stats.trendUnit {
        case .hour: return FocusStatsUI.date(date, format: "HH时")
        case .day: return FocusStatsUI.date(date, format: "M/d")
        case .month: return FocusStatsUI.date(date, format: stats.range == .all ? "yy年M月" : "M月")
        case .year: return FocusStatsUI.date(date, format: "yyyy")
        }
    }

    private func activity(_ stats: FocusStats, now: Date) -> some View {
        let available = stats.daily.filter { $0.day <= FocusStatsUI.calendar.startOfDay(for: now) }
        let days = Array(available.suffix(stats.range == .all || stats.range == .year ? 84 : available.count))
        let firstWeekday = days.first.map { FocusStatsUI.calendar.component(.weekday, from: $0.day) } ?? 2
        let leading = (firstWeekday + 5) % 7
        let cells: [FocusStats.DayTotal?] = Array(repeating: nil, count: leading) + days.map { Optional($0) }
        let maximum = max(days.map(\.seconds).max() ?? 0, 1)
        return VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "专注日历", trailing: stats.range == .all || stats.range == .year ? "最多显示最近 12 周" : "点日期查看当天")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 7), spacing: 5) {
                ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { day in
                    Text(day).font(.caption2).foregroundStyle(.secondary).padding(.bottom, 3)
                }
                ForEach(Array(cells.enumerated()), id: \.offset) { item in
                    if let day = item.element {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                anchor = day.day
                                storedRange = FocusStatsRange.day.rawValue
                            }
                        } label: {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(day.seconds == 0 ? Color.white.opacity(0.07) : Palette.sky.opacity(0.25 + 0.75 * Double(day.seconds) / Double(maximum)))
                                .frame(height: 15)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("stats-calendar-\(FocusStatsUI.date(day.day, format: "yyyy-MM-dd"))")
                        .accessibilityLabel("\(FocusStatsUI.date(day.day, format: "M月d日"))，\(FocusStatsUI.duration(seconds: day.seconds))，\(day.sessions) 段")
                    } else {
                        Color.clear.frame(height: 15)
                    }
                }
            }
            HStack {
                if let best = stats.bestDay {
                    Text("最佳一天：\(FocusStatsUI.date(best.day, format: "M月d日")) · \(FocusStatsUI.duration(seconds: best.seconds))")
                } else { Text("还没有专注日") }
                Spacer(minLength: 0)
            }
            .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(17)
        .glassCard(cornerRadius: 23)
    }

    private func completion(_ stats: FocusStats) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(text: "航段完成", trailing: "\(Int((stats.completionRate * 100).rounded()))% 完成")
            GeometryReader { geometry in
                let width = max(0, geometry.size.width - 6)
                HStack(spacing: 3) {
                    Capsule().fill(Palette.mint).frame(width: width * CGFloat(stats.landedSessions) / CGFloat(max(stats.totalSessions, 1)))
                    Capsule().fill(Palette.sky).frame(width: width * CGFloat(stats.timerCompletedSessions) / CGFloat(max(stats.totalSessions, 1)))
                    Capsule().fill(Palette.amber).frame(width: width * CGFloat(stats.endedEarlySessions) / CGFloat(max(stats.totalSessions, 1)))
                }
            }
            .frame(height: 8)
            HStack(spacing: 8) {
                outcome("已落地", count: stats.landedSessions, tint: Palette.mint)
                outcome("计时完成", count: stats.timerCompletedSessions, tint: Palette.sky)
                outcome("提前结束", count: stats.endedEarlySessions, tint: Palette.amber)
            }
            Text("完成率包含落地与计时完成，不含提前结束。")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(17)
        .glassCard(cornerRadius: 23)
    }

    private func outcome(_ title: String, count: Int, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("\(count)").font(.title3.bold().monospacedDigit()).foregroundStyle(tint)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func taskDistribution(_ stats: FocusStats) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(text: "任务分布", trailing: "\(stats.tags.count) 类任务")
            HStack(spacing: 16) {
                Chart(stats.tags.filter { $0.seconds > 0 }) { tag in
                    SectorMark(angle: .value("专注秒数", tag.seconds), innerRadius: .ratio(0.7), angularInset: 2)
                        .foregroundStyle(FocusStatsUI.color(tag.tag))
                        .cornerRadius(3)
                }
                .chartBackground { _ in
                    VStack(spacing: 3) {
                        Text("专注").font(.caption2).foregroundStyle(.secondary)
                        Text("\(stats.totalMinutes)分").font(.subheadline.bold().monospacedDigit())
                    }
                }
                .frame(width: 112, height: 130)
                VStack(spacing: 9) {
                    ForEach(stats.tags) { tag in
                        HStack(spacing: 7) {
                            Circle().fill(FocusStatsUI.color(tag.tag)).frame(width: 7, height: 7)
                            Text(tag.tag.title).font(.caption).lineLimit(1)
                            Spacer(minLength: 0)
                            Text(stats.totalSeconds > 0 ? "\(Int((Double(tag.seconds) / Double(stats.totalSeconds) * 100).rounded()))%" : "0%")
                                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            if let top = stats.tags.first {
                Label("投入最多：\(top.tag.title) · \(FocusStatsUI.duration(seconds: top.seconds))", systemImage: top.tag.symbol)
                    .font(.caption).foregroundStyle(FocusStatsUI.color(top.tag))
            }
        }
        .padding(17)
        .glassCard(cornerRadius: 23)
    }

    private func startHours(_ stats: FocusStats) -> some View {
        let best = stats.startHourlySeconds.max().flatMap { $0 > 0 ? stats.startHourlySeconds.firstIndex(of: $0) : nil }
        return VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "开始专注的时间", trailing: best.map { "\($0):00 最多" })
            Chart(Array(stats.startHourlySeconds.enumerated()), id: \.offset) { item in
                BarMark(x: .value("小时", String(item.offset)), y: .value("分钟", Double(item.element) / 60), width: .ratio(0.65))
                    .foregroundStyle(item.offset == best ? Palette.amber : Palette.mint.opacity(0.65))
                    .cornerRadius(3)
            }
            .chartXScale(domain: (0..<24).map { String($0) })
            .chartXAxis {
                AxisMarks(values: ["0", "6", "12", "18"]) { value in
                    AxisValueLabel { if let hour = value.as(String.self) { Text("\(hour)时") } }
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 110)
            Text("每段的专注时间归入它开始的时段。")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(17)
        .glassCard(cornerRadius: 23)
    }

    private func weekdays(_ stats: FocusStats) -> some View {
        let indexes = [1, 2, 3, 4, 5, 6, 0]
        let labels = ["一", "二", "三", "四", "五", "六", "日"]
        return VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "一周的专注节奏", trailing: "按开始日期归属")
            Chart(Array(indexes.enumerated()), id: \.offset) { item in
                BarMark(x: .value("星期", labels[item.offset]), y: .value("分钟", Double(stats.weekdaySeconds[item.element]) / 60))
                    .foregroundStyle(item.offset >= 5 ? Palette.indigo : Palette.sky.opacity(0.8))
                    .cornerRadius(4)
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine().foregroundStyle(.white.opacity(0.08))
                    AxisValueLabel()
                }
            }
            .frame(height: 115)
        }
        .padding(17)
        .glassCard(cornerRadius: 23)
    }

    private func durationDistribution(_ stats: FocusStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "每次专注多久", trailing: "\(stats.totalSessions) 段")
            Chart(stats.durations) { duration in
                BarMark(x: .value("航段", duration.sessions), y: .value("时长", duration.title))
                    .foregroundStyle(Palette.indigo.opacity(0.85)).cornerRadius(4)
                    .annotation(position: .trailing) {
                        Text("\(duration.sessions)").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                    }
            }
            .chartXScale(domain: 0...max(1, (stats.durations.map(\.sessions).max() ?? 0) + 1))
            .chartXAxis(.hidden)
            .chartYAxis { AxisMarks(position: .leading) { _ in AxisValueLabel() } }
            .frame(height: 135)
        }
        .padding(17)
        .glassCard(cornerRadius: 23)
    }

    private func flightMetrics(_ stats: FocusStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "飞行足迹", trailing: "所选范围")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                footprint("陪飞里程", value: "\(Fmt.km(stats.totalKm)) km", symbol: "point.topleft.down.to.point.bottomright.curvepath", tint: Palette.sky)
                footprint("常飞航线", value: "\(stats.routeCount) 条", symbol: "airplane", tint: Palette.indigo)
                footprint("落地机场", value: "\(stats.airportsVisited) 座", symbol: "mappin.and.ellipse", tint: Palette.mint)
                footprint("到访国家 / 地区", value: "\(stats.countriesVisited) 个", symbol: "globe.asia.australia", tint: Palette.amber)
            }
        }
        .padding(17)
        .glassCard(cornerRadius: 23)
    }

    private func footprint(_ title: String, value: String, symbol: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(title, systemImage: symbol).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.title3.bold().monospacedDigit()).foregroundStyle(tint).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func ranking(_ title: String, _ items: [FocusStats.Ranked], tint: Color) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(text: title, trailing: "前 \(min(items.count, 5)) 名")
                ForEach(Array(items.prefix(5).enumerated()), id: \.element.id) { index, item in
                    VStack(spacing: 7) {
                        HStack(alignment: .top, spacing: 10) {
                            Text(String(format: "%02d", index + 1))
                                .font(.caption.weight(.bold).monospacedDigit()).foregroundStyle(tint)
                                .padding(.top, 2)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title).font(.subheadline.weight(.medium)).lineLimit(1)
                                Text(item.subtitle).font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            VStack(alignment: .trailing, spacing: 3) {
                                Text("\(item.count) 段").font(.caption.weight(.semibold).monospacedDigit())
                                Text(FocusStatsUI.duration(seconds: item.seconds)).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        ProgressView(value: Double(item.count) / Double(max(items.first?.count ?? 1, 1)))
                            .tint(tint.opacity(0.65)).scaleEffect(y: 0.65)
                    }
                }
            }
            .padding(17)
            .glassCard(cornerRadius: 23)
        }
    }

    private func membership(_ stats: FocusStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("累计里程等级").font(.caption).foregroundStyle(.secondary)
                    Text("STRATO \(stats.tier.english)").font(.caption2.weight(.heavy)).tracking(1.4).foregroundStyle(Palette.amber)
                    Text(stats.tier.title).font(.title2.bold())
                }
                Spacer()
                Image(systemName: "medal.fill").font(.system(size: 32)).foregroundStyle(Palette.amber)
            }
            ProgressView(value: stats.tierProgress).tint(Palette.amber)
            HStack {
                Text("\(Fmt.km(stats.totalKm)) km · 绕地球 \(String(format: "%.2f", stats.earthLaps)) 圈")
                Spacer(minLength: 0)
                if let next = stats.tier.nextKm { Text("下一级 \(Fmt.km(next)) km") }
            }
            .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(18)
        .glassCard(cornerRadius: 24, tint: Palette.amber.opacity(0.1))
    }
}
