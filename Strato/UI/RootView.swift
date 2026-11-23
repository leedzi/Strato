import SwiftUI

enum AppTab: Hashable {
    case radar, logbook, stats, settings
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var tab: AppTab = .radar

    var body: some View {
        @Bindable var model = model
        ZStack {
            TabView(selection: $tab) {
                Tab("雷达", systemImage: "dot.radiowaves.left.and.right", value: AppTab.radar) {
                    RadarScreen()
                }
                Tab("护照", systemImage: "book.closed.fill", value: AppTab.logbook) {
                    LogbookScreen()
                }
                Tab("统计", systemImage: "chart.bar.xaxis", value: AppTab.stats) {
                    StatsScreen()
                }
                Tab("设置", systemImage: "gearshape.fill", value: AppTab.settings) {
                    SettingsScreen()
                }
            }
            .accessibilityHidden(model.session != nil)
            // The flight screen covers everything while a session is running. It is an overlay
            // rather than a modal so sheets underneath never fight with it.
            if model.session != nil {
                FlightScreen()
                    .transition(.opacity.combined(with: .scale(scale: 1.03)))
                    .zIndex(1)
            }
        }
        .animation(.smooth(duration: 0.45), value: model.session?.id)
        .sheet(item: $model.arrival) { record in
            ArrivalSheet(record: record)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Arrival

struct ArrivalSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var record: FocusRecord
    @State private var stamped = false

    private var title: String {
        switch record.outcome {
        case .landed: return "已落地\(record.destination.city)"
        case .timerDone: return "专注完成"
        case .endedEarly: return "中途下机"
        }
    }

    private var subtitle: String {
        switch record.outcome {
        case .landed:
            return record.landingEstimated ? "落地时间为推算，登机牌已盖章" : "一路陪到了跑道上，登机牌已盖章"
        case .timerDone:
            return "\(record.flightNumber) 还在继续飞，你的这一段完成了"
        case .endedEarly:
            return "这一段已经记进护照"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Image(systemName: record.outcome == .endedEarly ? "figure.walk.departure" : "checkmark.seal.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(record.outcome == .endedEarly ? Palette.amber : Palette.mint)
                        .symbolEffect(.bounce, value: stamped)
                    Text(title).font(.title2.bold())
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .padding(.top, 18)

                BoardingPassView(pass: PassData(record: record, model: model))
                    .scaleEffect(stamped ? 1 : 0.94)
                    .opacity(stamped ? 1 : 0)

                HStack(spacing: 10) {
                    summary("专注", "\(record.focusMinutes)", "分钟")
                    summary("飞行", Fmt.km(record.distanceKm), "公里")
                    summary("最高", FlightMath.flightLevel(record.maxAltitudeFt), Fmt.altitudeMeters(record.maxAltitudeFt))
                }

                tierProgress

                Button {
                    dismiss()
                } label: {
                    Text("收进护照")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.glassProminent)
                .accessibilityIdentifier("arrival-done")
            }
            .padding(20)
        }
        .background(Palette.backdrop.ignoresSafeArea())
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.72).delay(0.15)) { stamped = true }
        }
    }

    private func summary(_ title: String, _ value: String, _ unit: String) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit()).minimumScaleFactor(0.6).lineLimit(1)
            Text(unit).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .glassCard(cornerRadius: 18)
    }

    private var tierProgress: some View {
        let stats = model.stats
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(stats.tier.title, systemImage: "medal.fill").font(.subheadline.weight(.semibold))
                Spacer()
                if let next = stats.tier.nextKm {
                    Text("距下一级还差 \(Fmt.km(max(0, next - stats.totalKm))) km")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("已是最高等级").font(.caption).foregroundStyle(.secondary)
                }
            }
            ProgressView(value: stats.tierProgress).tint(Palette.amber)
            Text("累计 \(Fmt.km(stats.totalKm)) km · 连续 \(stats.currentStreak) 天")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(16)
        .glassCard(cornerRadius: 20)
    }
}
