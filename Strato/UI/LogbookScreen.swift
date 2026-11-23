import Charts
import MapKit
import SwiftUI

// MARK: - Logbook

struct LogbookScreen: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    if model.records.isEmpty {
                        empty
                    } else {
                        header
                        RouteMapCard(records: model.records)
                        VStack(spacing: 10) {
                            SectionTitle(text: "登机牌", trailing: "\(model.records.count) 张")
                            ForEach(model.records) { record in
                                NavigationLink(value: record) {
                                    RecordRow(record: record)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("删除", systemImage: "trash", role: .destructive) { model.delete(record) }
                                }
                                .accessibilityIdentifier("record-\(record.flightNumber)")
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Palette.backdrop.ignoresSafeArea())
            .navigationTitle("飞行护照")
            .navigationDestination(for: FocusRecord.self) { RecordDetail(record: $0) }
        }
    }

    private var empty: some View {
        ContentUnavailableView {
            Label("护照还是空的", systemImage: "book.closed")
        } description: {
            Text("去雷达上挑一班正在飞的航班，陪它飞到落地，登机牌会盖章收在这里。")
        }
        .padding(.top, 80)
    }

    private var header: some View {
        let s = model.stats
        return HStack(spacing: 10) {
            tile("航段", "\(s.totalSessions)", "已落地 \(s.airportsVisited) 座机场")
            tile("专注", Fmt.hours(minutes: s.totalMinutes), "最长一次 \(s.longestMinutes) 分钟")
            tile("里程", "\(Fmt.km(s.totalKm))", "公里 · \(s.tier.title)")
        }
    }

    private func tile(_ title: String, _ value: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(detail).font(.caption2).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .glassCard(cornerRadius: 18)
    }
}

/// Every flight in the logbook drawn on one map.
struct RouteMapCard: View {
    var records: [FocusRecord]

    var body: some View {
        Map(initialPosition: .automatic, interactionModes: [.pan, .zoom]) {
            ForEach(records.prefix(80)) { record in
                MapPolyline(coordinates: coordinates(record), contourStyle: .geodesic)
                    .stroke(Palette.sky.opacity(0.9), lineWidth: 2)
                Annotation(record.destination.code, coordinate: CLLocationCoordinate2D(latitude: record.destination.lat, longitude: record.destination.lon)) {
                    Circle().fill(Palette.mint).frame(width: 6, height: 6)
                }
            }
        }
        .mapStyle(.imagery(elevation: .flat))
        .frame(height: 230)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.15)))
        .accessibilityLabel("飞过的航线地图")
    }

    private func coordinates(_ r: FocusRecord) -> [CLLocationCoordinate2D] {
        let points = r.path.count > 1 ? r.path : [Geo.interpolate(r.origin.point, r.destination.point, r.boardedFraction), Geo.interpolate(r.origin.point, r.destination.point, r.endFraction)]
        return points.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
    }
}

struct RecordRow: View {
    @Environment(AppModel.self) private var model
    var record: FocusRecord

    var body: some View {
        let brand = AirlineBrand.forICAO(record.airlineICAO)
        HStack(spacing: 0) {
            LinearGradient(colors: [brand.primaryColor, brand.secondaryColor], startPoint: .top, endPoint: .bottom)
                .frame(width: 8)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(record.flightNumber)
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                    Text(model.reference.airlineName(icao: record.airlineICAO, fallback: record.airlineName))
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    Spacer()
                    Text(Fmt.day(record.startedAt)).font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Text(record.origin.code).font(.system(size: 22, weight: .bold, design: .rounded))
                    Image(systemName: "airplane").font(.caption).foregroundStyle(brand.accentColor)
                    Text(record.destination.code).font(.system(size: 22, weight: .bold, design: .rounded))
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(record.focusMinutes) 分钟").font(.subheadline.weight(.semibold).monospacedDigit())
                        Label(outcomeText, systemImage: outcomeSymbol)
                            .font(.caption2)
                            .foregroundStyle(record.completed ? Palette.mint : Palette.amber)
                    }
                }
                Text("\(record.origin.city) → \(record.destination.city) · \(record.tag.title)\(record.simulated ? " · 模拟" : "")")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .glassCard(cornerRadius: 20)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 20))
    }

    private var outcomeText: String {
        switch record.outcome {
        case .landed: return "已落地"
        case .timerDone: return "专注完成"
        case .endedEarly: return "中途下机"
        }
    }

    private var outcomeSymbol: String {
        switch record.outcome {
        case .landed: return "checkmark.seal.fill"
        case .timerDone: return "timer"
        case .endedEarly: return "figure.walk"
        }
    }
}

struct RecordDetail: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var record: FocusRecord
    @State private var shareImage: Image?
    @State private var confirmDelete = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                BoardingPassView(pass: PassData(record: record, model: model))

                VStack(spacing: 12) {
                    row("时间", "\(Fmt.dayWithWeekday(record.startedAt)) \(Fmt.time(record.startedAt)) – \(Fmt.time(record.endedAt))")
                    row("专注时长", "\(record.focusMinutes) 分钟" + (record.pauseCount > 0 ? "（暂停 \(record.pauseCount) 次）" : ""))
                    row("陪飞里程", "\(Fmt.km(record.distanceKm)) km，全程 \(Fmt.km(record.routeKm)) km")
                    row("登机位置", "航程的 \(Int((record.boardedFraction * 100).rounded()))% 处")
                    row("机型", AircraftTypes.name(code: record.typeCode, fallback: record.typeName) + (record.registration.map { " · \($0)" } ?? ""))
                    if record.simulated { row("说明", "自选航线，模拟飞行") }
                    if record.landingEstimated { row("说明", "落地时间为推算") }
                }
                .padding(16)
                .glassCard(cornerRadius: 22)

                if record.altitudeProfile.count > 2 {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle(text: "高度剖面", trailing: "最高 \(FlightMath.flightLevel(record.maxAltitudeFt))")
                        Chart(Array(record.altitudeProfile.enumerated()), id: \.offset) { item in
                            AreaMark(x: .value("进程", item.offset), y: .value("高度", item.element))
                                .foregroundStyle(LinearGradient(colors: [Palette.sky.opacity(0.55), Palette.sky.opacity(0.05)], startPoint: .top, endPoint: .bottom))
                                .interpolationMethod(.monotone)
                            LineMark(x: .value("进程", item.offset), y: .value("高度", item.element))
                                .foregroundStyle(Palette.sky)
                                .interpolationMethod(.monotone)
                        }
                        .chartXAxis(.hidden)
                        .chartYAxis {
                            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                                AxisGridLine().foregroundStyle(.white.opacity(0.12))
                                AxisValueLabel {
                                    if let ft = value.as(Int.self) { Text("\(ft / 1000)k") }
                                }
                            }
                        }
                        .frame(height: 120)
                    }
                    .padding(16)
                    .glassCard(cornerRadius: 22)
                }

                HStack(spacing: 10) {
                    if let shareImage {
                        ShareLink(item: shareImage, preview: SharePreview("\(record.flightNumber) 登机牌", image: shareImage)) {
                            Label("分享登机牌", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 5)
                        }
                        .buttonStyle(.glass)
                    }
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Label("删除", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                    }
                    .buttonStyle(.glass)
                }
            }
            .padding(16)
        }
        .background(Palette.backdrop.ignoresSafeArea())
        .navigationTitle(record.flightNumber)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("删除这张登机牌？", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                model.delete(record)
                dismiss()
            }
        } message: {
            Text("对应的专注时间和里程也会从统计里去掉。")
        }
        .task {
            let renderer = ImageRenderer(content: BoardingPassView(pass: PassData(record: record, model: model)).frame(width: 360).padding(24).background(Palette.dusk))
            renderer.scale = 3
            if let ui = renderer.uiImage { shareImage = Image(uiImage: ui) }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value).font(.subheadline.weight(.medium)).multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Statistics

struct StatsScreen: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let s = model.stats
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    tierCard(s)
                    HStack(spacing: 10) {
                        kpi("今天", "\(s.todayMinutes)", "分钟", Palette.sky)
                        kpi("连续", "\(s.currentStreak)", "天 · 最长 \(s.longestStreak)", Palette.amber)
                        kpi("完成率", "\(Int((s.completionRate * 100).rounded()))%", "\(s.completedSessions)/\(s.totalSessions) 段", Palette.mint)
                    }
                    if s.totalSessions == 0 {
                        ContentUnavailableView("还没有数据", systemImage: "chart.bar.xaxis", description: Text("完成第一趟专注航程后，这里会开始统计。"))
                            .padding(.top, 30)
                    } else {
                        dailyChart(s)
                        hourlyChart(s)
                        tagChart(s)
                        ranking("常飞航司", s.topAirlines, symbol: "airplane.circle.fill")
                        ranking("常飞航线", s.topRoutes, symbol: "point.topleft.down.to.point.bottomright.curvepath")
                        ranking("常坐机型", s.topAircraft, symbol: "airplane")
                    }
                }
                .padding(16)
            }
            .background(Palette.backdrop.ignoresSafeArea())
            .navigationTitle("专注统计")
        }
    }

    private func tierCard(_ s: FocusStats) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("STRATO \(s.tier.english)")
                        .font(.system(size: 11, weight: .heavy)).tracking(1.5)
                        .foregroundStyle(Palette.amber)
                    Text(s.tier.title).font(.title2.bold())
                }
                Spacer()
                Image(systemName: "medal.fill").font(.system(size: 34)).foregroundStyle(Palette.amber)
            }
            ProgressView(value: s.tierProgress).tint(Palette.amber)
            HStack {
                Text("累计 \(Fmt.km(s.totalKm)) km · 绕地球 \(String(format: "%.2f", s.earthLaps)) 圈")
                Spacer()
                if let next = s.tier.nextKm {
                    Text("下一级 \(Fmt.km(next)) km")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(18)
        .glassCard(cornerRadius: 24, tint: Palette.amber.opacity(0.12))
    }

    private func kpi(_ title: String, _ value: String, _ detail: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(detail).font(.caption2).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .glassCard(cornerRadius: 18)
    }

    private func dailyChart(_ s: FocusStats) -> some View {
        let delta = s.weekMinutes - s.previousWeekMinutes
        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "近 30 天", trailing: "本周 \(Fmt.hours(minutes: s.weekMinutes))，比上周\(delta >= 0 ? "多" : "少") \(abs(delta)) 分钟")
            Chart(s.daily) { day in
                BarMark(x: .value("日期", day.day, unit: .day), y: .value("分钟", day.minutes))
                    .foregroundStyle(LinearGradient(colors: [Palette.sky, Palette.indigo], startPoint: .top, endPoint: .bottom))
                    .cornerRadius(3)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisValueLabel(format: .dateTime.month(.defaultDigits).day())
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine().foregroundStyle(.white.opacity(0.12))
                    AxisValueLabel()
                }
            }
            .frame(height: 150)
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private func hourlyChart(_ s: FocusStats) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "一天里什么时候最专注", trailing: s.bestHour.map { "\($0):00 前后最多" })
            Chart(Array(s.hourly.enumerated()), id: \.offset) { item in
                BarMark(x: .value("小时", item.offset), y: .value("分钟", item.element), width: .ratio(0.7))
                    .foregroundStyle(item.offset == s.bestHour ? Palette.amber : Palette.mint.opacity(0.75))
                    .cornerRadius(2)
            }
            .chartXAxis {
                AxisMarks(values: [0, 6, 12, 18, 23]) { value in
                    AxisValueLabel {
                        if let h = value.as(Int.self) { Text("\(h)时") }
                    }
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 110)
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private func tagColor(_ tag: FocusTag) -> Color {
        switch tag {
        case .deepWork: return Palette.sky
        case .coding: return Palette.mint
        case .study: return Palette.amber
        case .reading: return Palette.indigo
        case .writing: return Palette.coral
        case .creative: return Color(rgb: 0xE58BFF)
        case .other: return Color(rgb: 0x9AA4B8)
        }
    }

    private func tagChart(_ s: FocusStats) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "时间都花在哪", trailing: nil)
            HStack(spacing: 18) {
                Chart(s.tags) { t in
                    SectorMark(angle: .value("分钟", t.minutes), innerRadius: .ratio(0.62), angularInset: 2)
                        .foregroundStyle(tagColor(t.tag))
                        .cornerRadius(3)
                }
                .frame(width: 118, height: 118)
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(s.tags) { t in
                        HStack(spacing: 8) {
                            Circle().fill(tagColor(t.tag)).frame(width: 9, height: 9)
                            Text(t.tag.title).font(.subheadline)
                            Spacer()
                            Text(Fmt.hours(minutes: t.minutes)).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    @ViewBuilder
    private func ranking(_ title: String, _ items: [FocusStats.Ranked], symbol: String) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(text: title, trailing: nil)
                ForEach(Array(items.prefix(5).enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption.weight(.heavy).monospacedDigit())
                            .frame(width: 20, height: 20)
                            .background(index == 0 ? Palette.amber.opacity(0.9) : Color.white.opacity(0.14), in: Circle())
                            .foregroundStyle(index == 0 ? Color.black : Color.white)
                        Text(item.title).font(.subheadline.weight(.medium)).lineLimit(1)
                        Spacer()
                        Text("\(item.count) 次 · \(Fmt.hours(minutes: item.minutes))")
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(16)
            .glassCard(cornerRadius: 22)
        }
    }
}
