import SwiftUI

enum FocusStatsUI {
    static var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }

    static func date(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = format
        return formatter.string(from: date)
    }

    static func duration(seconds: Int) -> String {
        let seconds = max(seconds, 0)
        if seconds == 0 { return "0 分钟" }
        if seconds < 60 { return "\(seconds) 秒" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes) 分钟" }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "\(hours) 小时" : "\(hours) 小时 \(remainder) 分"
    }

    static func color(_ tag: FocusTag) -> Color {
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
}

/// The same calendar controls are used by the passport and the statistics page.
struct FocusPeriodSelector: View {
    @Binding var storedRange: String
    @Binding var anchor: Date
    var now: Date
    var identifier: String
    @State private var choosingDate = false

    private var range: FocusStatsRange { FocusStatsRange(rawValue: storedRange) ?? .all }
    private var calendar: Calendar { FocusStatsUI.calendar }
    private var isCurrent: Bool {
        range.interval(containing: anchor, calendar: calendar) == range.interval(containing: now, calendar: calendar)
    }
    private var canAdvance: Bool {
        guard let current = range.interval(containing: now, calendar: calendar) else { return false }
        return range.shifted(anchor, by: 1, calendar: calendar) <= current.start
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 4) {
                ForEach(FocusStatsRange.allCases) { option in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { storedRange = option.rawValue }
                    } label: {
                        Text(option.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(option == range ? Color.white : Color.white.opacity(0.58))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(option == range ? Palette.sky.opacity(0.24) : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("\(identifier)-range-\(option.rawValue)")
                    .accessibilityAddTraits(option == range ? .isSelected : [])
                }
            }
            .padding(4)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            if range == .all {
                HStack {
                    Label("每一段专注，都留下足迹", systemImage: "sparkles")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("全部记录").font(.caption.weight(.medium)).foregroundStyle(Palette.sky)
                }
                .padding(.horizontal, 4)
            } else {
                HStack(spacing: 4) {
                    arrow("chevron.left", offset: -1, label: "上一个周期")
                    Spacer(minLength: 0)
                    Button { choosingDate = true } label: {
                        HStack(spacing: 7) {
                            Text(periodTitle).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.75)
                            Image(systemName: "chevron.down").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("\(identifier)-choose-date")
                    Spacer(minLength: 0)
                    arrow("chevron.right", offset: 1, label: "下一个周期")
                        .disabled(!canAdvance)
                        .opacity(canAdvance ? 1 : 0.25)
                    if !isCurrent {
                        Button(currentTitle) { withAnimation { anchor = now } }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Palette.sky)
                            .padding(.leading, 5)
                            .accessibilityIdentifier("\(identifier)-current-period")
                    }
                }
            }
        }
        .sheet(isPresented: $choosingDate) {
            NavigationStack {
                DatePicker("选择日期", selection: $anchor, in: ...now, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .accessibilityIdentifier("\(identifier)-date-picker")
                    .tint(Palette.sky)
                    .padding(20)
                    .navigationTitle("选择统计周期")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("完成") { choosingDate = false }
                                .accessibilityIdentifier("\(identifier)-date-done")
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func arrow(_ symbol: String, offset: Int, label: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { anchor = range.shifted(anchor, by: offset, calendar: calendar) }
        } label: {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .frame(width: 36, height: 36)
                .background(.white.opacity(0.07), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier("\(identifier)-period-\(offset < 0 ? "previous" : "next")")
    }

    private var periodTitle: String {
        switch range {
        case .all: return "总计"
        case .year: return FocusStatsUI.date(anchor, format: "yyyy年")
        case .month: return FocusStatsUI.date(anchor, format: "yyyy年M月")
        case .day: return FocusStatsUI.date(anchor, format: "yyyy年M月d日 EEE")
        case .week:
            guard let period = range.interval(containing: anchor, calendar: calendar) else { return "本周" }
            let end = period.end.addingTimeInterval(-1)
            let sameYear = calendar.component(.year, from: period.start) == calendar.component(.year, from: end)
            return FocusStatsUI.date(period.start, format: "yyyy年M月d日") + "–" + FocusStatsUI.date(end, format: sameYear ? "M月d日" : "yyyy年M月d日")
        }
    }

    private var currentTitle: String {
        switch range {
        case .all: return "总计"
        case .year: return "本年"
        case .month: return "本月"
        case .week: return "本周"
        case .day: return "今天"
        }
    }
}
