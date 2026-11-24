import Charts
import SwiftUI

// MARK: - Logbook

struct LogbookScreen: View {
    @Environment(AppModel.self) private var model
    @AppStorage("passportRange") private var storedRange = FocusStatsRange.all.rawValue
    @State private var anchor = Date()

    var body: some View {
        let now = Date()
        let range = FocusStatsRange(rawValue: storedRange) ?? .all
        let records = range.records(model.records, anchor: anchor, calendar: FocusStatsUI.calendar)
            .sorted { $0.startedAt > $1.startedAt }
        let stats = FocusStats(records: model.records, now: now, calendar: FocusStatsUI.calendar,
                               reference: model.reference, range: range, anchor: anchor)
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    FocusPeriodSelector(storedRange: $storedRange, anchor: $anchor, now: now, identifier: "passport")
                    header(stats)
                    PassportMapCard(records: records)
                    if records.isEmpty {
                        empty
                    } else {
                        VStack(spacing: 10) {
                            SectionTitle(text: "登机牌", trailing: "\(records.count) 张")
                            ForEach(records) { record in
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
            Label(model.records.isEmpty ? "护照还是空的" : "这段时间还没有登机牌", systemImage: "book.closed")
        } description: {
            Text(model.records.isEmpty ? "去雷达上挑一班正在飞的航班，陪它飞到落地，登机牌会盖章收在这里。" : "试试切换统计周期，看看其他日期留下的航迹。")
        }
        .padding(.vertical, 20)
    }

    private func header(_ s: FocusStats) -> some View {
        HStack(spacing: 10) {
            tile("航段", "\(s.totalSessions)", "完成 \(s.completedSessions) 段")
            tile("专注", FocusStatsUI.duration(seconds: s.totalSeconds), "最长 \(s.longestMinutes) 分钟")
            tile("里程", "\(Fmt.km(s.totalKm))", "公里 · \(s.airportsVisited) 座机场")
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
