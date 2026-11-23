import SwiftUI
import Charts

struct AnalyticsView: View {
    @Environment(StratoStore.self) private var store

    private struct DailyFocusBar: Identifiable {
        let id = UUID()
        let dateLabel: String
        let minutes: Int
    }

    private struct TagSlice: Identifiable {
        var id: String { tag.rawValue }
        let tag: FocusTag
        let minutes: Int
    }

    private var last7DaysData: [DailyFocusBar] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"

        return (0..<7).reversed().map { offset in
            let day = cal.date(byAdding: .day, value: -offset, to: today) ?? today
            let mins = store.logbook
                .filter { cal.isDate($0.completedAt, inSameDayAs: day) }
                .reduce(0) { $0 + $1.durationMinutes }
            return DailyFocusBar(dateLabel: offset == 0 ? "今天" : formatter.string(from: day), minutes: mins)
        }
    }

    private var tagDistribution: [TagSlice] {
        var grouped: [FocusTag: Int] = [:]
        for record in store.logbook {
            grouped[record.focusTag, default: 0] += record.durationMinutes
        }
        return FocusTag.allCases.compactMap { tag in
            guard let mins = grouped[tag], mins > 0 else { return nil }
            return TagSlice(tag: tag, minutes: mins)
        }
    }

    private var topAirlines: [(name: String, count: Int, minutes: Int)] {
        var counts: [String: (Int, Int)] = [:]
        for r in store.logbook {
            let cur = counts[r.airlineName] ?? (0, 0)
            counts[r.airlineName] = (cur.0 + 1, cur.1 + r.durationMinutes)
        }
        return counts.map { ($0.key, $0.value.0, $0.value.1) }
            .sorted { $0.minutes > $1.minutes }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // 1. Frequent Flyer Tier Card
                    frequentFlyerCard

                    // 2. Core KPI Grid
                    HStack(spacing: 10) {
                        kpiBox(title: "总专注时长", value: String(format: "%.1f h", Double(store.totalFocusMinutes) / 60.0), sub: "\(store.logbook.count) 个航段", color: StratoTheme.skyCyan)
                        kpiBox(title: "累计巡航里程", value: "\(store.totalDistanceKM) km", sub: "绕赤道 \(String(format: "%.2f", Double(store.totalDistanceKM) / 40075.0)) 圈", color: StratoTheme.radarEmerald)
                        kpiBox(title: "连续执飞", value: "\(store.currentStreakDays) 天", sub: "解锁 \(store.visitedAirportsCount) 座机场", color: StratoTheme.amberBeacon)
                    }

                    // 3. 7-Day Focus Trend Chart (Swift Charts)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("近 7 日专注飞行趋势")
                                .font(.headline)
                            Spacer()
                            Text("单位：分钟")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Chart(last7DaysData) { item in
                            BarMark(
                                x: .value("日期", item.dateLabel),
                                y: .value("专注分钟", item.minutes)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [StratoTheme.skyCyan, StratoTheme.radarEmerald],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .cornerRadius(6)
                        }
                        .frame(height: 180)
                    }
                    .padding(18)
                    .stratoGlassCard(cornerRadius: 24)

                    // 4. Focus Category Breakdown (Donut Chart)
                    if !tagDistribution.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("专注舱位与任务分布")
                                .font(.headline)

                            HStack(spacing: 20) {
                                Chart(tagDistribution) { slice in
                                    SectorMark(
                                        angle: .value("时长", slice.minutes),
                                        innerRadius: .ratio(0.62),
                                        angularInset: 2
                                    )
                                    .foregroundStyle(by: .value("标签", slice.tag.rawValue))
                                    .cornerRadius(4)
                                }
                                .frame(width: 130, height: 130)
                                .chartLegend(.hidden)

                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(tagDistribution) { slice in
                                        HStack {
                                            Image(systemName: slice.tag.symbol)
                                                .font(.caption)
                                                .foregroundStyle(StratoTheme.skyCyan)
                                                .frame(width: 18)
                                            Text(slice.tag.rawValue)
                                                .font(.caption.weight(.semibold))
                                            Spacer()
                                            Text("\(slice.minutes)m")
                                                .font(.caption.monospacedDigit().bold())
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(18)
                        .stratoGlassCard(cornerRadius: 24)
                    }

                    // 5. Top Airlines Flown
                    if !topAirlines.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("最常执飞航司排行")
                                .font(.headline)

                            ForEach(Array(topAirlines.prefix(5).enumerated()), id: \.offset) { idx, item in
                                HStack {
                                    Text("#\(idx + 1)")
                                        .font(.caption.monospaced().bold())
                                        .foregroundStyle(StratoTheme.skyCyan)
                                        .frame(width: 24, alignment: .leading)
                                    Text(item.name)
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Text("\(item.count) 次航班 · \(item.minutes) 分钟")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 6)
                            }
                        }
                        .padding(18)
                        .stratoGlassCard(cornerRadius: 24)
                    }
                }
                .padding(16)
            }
            .navigationTitle("专注数据分析")
        }
    }

    private var frequentFlyerCard: some View {
        let tier = store.frequentFlyerTier
        let progress = min(1.0, Double(store.totalDistanceKM) / Double(max(1, tier.nextTierKM)))

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tier.titleEN)
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(tier.color)
                    Text("Strato 常旅客 · \(tier.titleCN)")
                        .font(.title3.bold())
                }
                Spacer()
                Image(systemName: "medal.star.fill")
                    .font(.title)
                    .foregroundStyle(tier.color)
            }

            ProgressView(value: progress)
                .tint(tier.color)

            HStack {
                Text("当前累计 \(store.totalDistanceKM) km")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Text("距离下一等级还需 \(max(0, tier.nextTierKM - store.totalDistanceKM)) km")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .stratoGlassCard(cornerRadius: 24, tint: tier.color.opacity(0.15))
    }

    private func kpiBox(title: String, value: String, sub: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.bold().monospacedDigit())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(sub)
                .font(.system(size: 9.5))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .stratoGlassCard(cornerRadius: 18)
    }
}
