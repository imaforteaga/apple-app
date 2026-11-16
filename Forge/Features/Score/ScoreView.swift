import SwiftUI
import SwiftData
import Charts

struct ScoreView: View {
    var body: some View {
        WithScore { engine in ScoreContent(engine: engine) }
    }
}

private struct ScoreContent: View {
    let engine: ScoreEngine

    enum Period: String, CaseIterable, Identifiable {
        case today = "Today", week = "Week", month = "Month"
        var id: String { rawValue }
    }
    @State private var period: Period = .week

    private var overall: Double {
        switch period {
        case .today: return engine.today.total ?? 0
        case .week: return engine.week.overall
        case .month: return engine.month.overall
        }
    }
    private var categoryValues: [ScoreCategory: Double] {
        switch period {
        case .today: return engine.today.values
        case .week: return engine.week.categories
        case .month: return engine.month.categories
        }
    }
    private var periodScore: PeriodScore { period == .month ? engine.month : engine.week }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Picker("Period", selection: $period.animation(Motion.soft)) {
                    ForEach(Period.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented)

                hero
                categories
                attention
                evolution
                weeklyBars
                explainer
            }
            .padding(.horizontal, Theme.pad)
            .padding(.bottom, 40)
        }
        .screenBackground()
        .navigationTitle("Transformation Score")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { ScoreSettingsView() } label: { Image(systemName: "slider.horizontal.3") }
                    .accessibilityLabel("Customize score")
            }
        }
    }

    // MARK: Hero

    private var hero: some View {
        VStack(spacing: 14) {
            ProgressRing(progress: overall / 100, lineWidth: 20) {
                VStack(spacing: -2) {
                    Text("\(Int(overall.rounded()))").font(Theme.number(64)).foregroundStyle(Theme.text)
                        .contentTransition(.numericText()).animation(Motion.soft, value: Int(overall.rounded()))
                    Text("out of 100").font(.caption).foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(width: 200, height: 200)
            .padding(.top, 6)
            Text(engine.label(for: overall)).font(Theme.display(24)).foregroundStyle(Theme.text)
            if period != .today {
                let p = periodScore
                Text("\(p.consistentDays) of \(p.days) days were consistent (score ≥ 60)")
                    .font(.footnote).foregroundStyle(Theme.textSecondary)
            } else {
                Text("Today so far. It updates as you log.").font(.footnote).foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .card()
    }

    // MARK: Categories

    private var categories: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle("By area")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 16) {
                ForEach(engine.enabledCategories) { c in
                    let v = categoryValues[c]
                    VStack(spacing: 8) {
                        ProgressRing(progress: v ?? 0, lineWidth: 8) {
                            if let v {
                                Text("\(Int((v * 100).rounded()))").font(Theme.number(16)).foregroundStyle(Theme.text)
                            } else {
                                Text("–").foregroundStyle(Theme.textSecondary)
                            }
                        }
                        .frame(width: 70, height: 70)
                        HStack(spacing: 4) {
                            Image(systemName: c.icon).font(.system(size: 11))
                            Text(c.title).font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(Theme.text)
                    }
                }
            }
            if engine.enabledCategories.count < ScoreCategory.allCases.count {
                Text("Some areas are switched off in Customize.").font(.caption2).foregroundStyle(Theme.textSecondary)
            }
        }
        .card()
    }

    // MARK: Attention

    private var attention: some View {
        let ranked = engine.needsAttention(in: period == .today ? PeriodScore(overall: 0, level: 0, consistency: 0, categories: engine.today.values, consistentDays: 0, days: 1) : periodScore)
        let weakest = Array(ranked.prefix(2)).filter { $0.1 < 0.85 }
        return VStack(alignment: .leading, spacing: 12) {
            SectionTitle("Needs attention")
            if weakest.isEmpty {
                Label("Everything is on track. Keep the rhythm.", systemImage: "checkmark.seal")
                    .font(.subheadline).foregroundStyle(Theme.textSecondary)
            }
            ForEach(Array(weakest.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 12) {
                    IconBadge(systemName: item.0.icon, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(item.0.title) · \(Int((item.1 * 100).rounded()))").font(.subheadline.weight(.semibold))
                        Text(item.0.tip).font(.caption).foregroundStyle(Theme.textSecondary)
                    }
                }
            }
        }
        .card()
    }

    // MARK: Charts

    private var evolution: some View {
        let days = period == .month ? 30 : 14
        let pts = engine.weeklyEvolution(points: days)
        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle("Evolution", subtitle: "Rolling 7-day score, last \(days) days")
            if pts.count < 2 {
                Text("Use the app for a couple of days to see your trend.").font(.footnote).foregroundStyle(Theme.textSecondary)
            } else {
                Chart(pts) { p in
                    AreaMark(x: .value("Date", p.date), y: .value("Score", p.value))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(LinearGradient(colors: [Theme.orange.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
                    LineMark(x: .value("Date", p.date), y: .value("Score", p.value))
                        .interpolationMethod(.catmullRom).foregroundStyle(Theme.orange)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                }
                .chartYScale(domain: 0...100)
                .frame(height: 160)
            }
        }
        .card()
    }

    private var weeklyBars: some View {
        let weeks: [DatedValue] = (0..<8).reversed().compactMap { i in
            let end = Date().addingDays(-7 * i)
            guard end >= engine.startDate else { return nil }
            return DatedValue(date: end, value: engine.period(days: 7, endingAt: end).overall)
        }
        let days = engine.dailySeries(days: period == .month ? 30 : 7)
        return VStack(alignment: .leading, spacing: 14) {
            SectionTitle("Daily scores", subtitle: period == .month ? "Last 30 days" : "Last 7 days")
            Chart(days) { s in
                BarMark(x: .value("Day", s.day, unit: .day), y: .value("Score", s.total ?? 0))
                    .cornerRadius(4)
                    .foregroundStyle(s.isConsistent ? AnyShapeStyle(Theme.brandGradient) : AnyShapeStyle(Theme.yellow.opacity(0.6)))
                RuleMark(y: .value("Consistent", 60)).lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4])).foregroundStyle(Theme.textSecondary)
            }
            .chartYScale(domain: 0...100)
            .frame(height: 130)
            Text("Dashed line = 60, the “consistent day” threshold").font(.caption2).foregroundStyle(Theme.textSecondary)
            if weeks.count > 1 {
                Divider().overlay(Theme.hairline)
                SectionTitle("Weekly scores", subtitle: "Last 8 weeks")
                Chart(weeks) { w in
                    BarMark(x: .value("Week ending", w.date, unit: .day), y: .value("Score", w.value), width: .fixed(22))
                        .cornerRadius(6).foregroundStyle(Theme.yellow)
                }
                .chartYScale(domain: 0...100)
                .frame(height: 120)
            }
        }
        .card()
    }

    private var explainer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How it works").font(Theme.display(19))
            Text("The score rewards consistency, not perfection. Partial effort earns partial credit, and reaching 90% of a target counts as full. Weekly and monthly scores blend your average level (70%) with how many days were consistent (30%).")
                .font(.footnote).foregroundStyle(Theme.textSecondary)
            ForEach(engine.enabledCategories) { c in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: c.icon).font(.caption).foregroundStyle(Theme.accentText).frame(width: 18)
                    Text(c.explanation).font(.caption).foregroundStyle(Theme.textSecondary)
                }
            }
            Text("This is a personal consistency score. It is not medical advice and not a measure of your health or worth.")
                .font(.caption.weight(.semibold)).foregroundStyle(Theme.accentText)
        }
        .card()
    }
}

// MARK: - Customize

struct ScoreSettingsView: View {
    @Query private var profiles: [UserProfile]
    @Query(sort: \Habit.sortOrder) private var habits: [Habit]
    @Environment(\.modelContext) private var context
    @AppStorage("mobilityWeeklyTarget") private var mobilityTarget = 4

    var body: some View {
        Form {
            if let p = profiles.first {
                Section {
                    ForEach(ScoreCategory.allCases) { c in
                        Toggle(isOn: Binding(
                            get: { !disabled(p).contains(c.rawValue) },
                            set: { on in setCategory(c, on: on, profile: p) })) {
                            Label(c.title, systemImage: c.icon)
                        }
                        .tint(Theme.orange)
                    }
                } header: { Text("Categories in your score") } footer: {
                    Text("Switch off areas that don't apply to you right now.")
                }.listRowBackground(Theme.card)

                Section {
                    ForEach(habits.filter { $0.isActive }) { h in
                        Toggle(isOn: Binding(get: { h.countsForScore },
                                             set: { h.countsForScore = $0; context.saveQuietly() })) {
                            Label(h.name, systemImage: h.icon)
                        }
                        .tint(Theme.orange)
                    }
                } header: { Text("Habits that count") }.listRowBackground(Theme.card)

                Section("Targets") {
                    IntStepperRow(title: "Training days / week", value: Binding(get: { p.weeklyTrainingDays },
                                                                                set: { p.weeklyTrainingDays = $0 }), range: 1...7)
                    IntStepperRow(title: "Mobility sessions / week", value: $mobilityTarget, range: 1...14)
                }.listRowBackground(Theme.card)
            }
        }
        .warmForm()
        .navigationTitle("Customize score")
        .onDisappear { context.saveQuietly() }
    }

    private func disabled(_ p: UserProfile) -> Set<String> {
        Set(p.disabledScoreCategories.split(separator: ",").map(String.init))
    }

    private func setCategory(_ c: ScoreCategory, on: Bool, profile p: UserProfile) {
        var set = disabled(p)
        if on { set.remove(c.rawValue) } else { set.insert(c.rawValue) }
        // Keep at least one category enabled.
        if set.count >= ScoreCategory.allCases.count { return }
        p.disabledScoreCategories = set.sorted().joined(separator: ",")
        context.saveQuietly()
    }
}
