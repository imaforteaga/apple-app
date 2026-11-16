import SwiftUI
import SwiftData
import Charts

// MARK: - Month grid (shared with Journal)

struct MonthGrid: View {
    @Binding var month: Date
    @Binding var selected: Date
    var markers: (Date) -> Int

    private var days: [Date?] {
        let cal = Calendar.current
        let start = month.startOfMonth
        guard let range = cal.range(of: .day, in: .month, for: start) else { return [] }
        let firstWeekday = cal.component(.weekday, from: start)
        let offset = (firstWeekday - cal.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: offset)
        for d in range { cells.append(cal.date(byAdding: .day, value: d - 1, to: start)) }
        return cells
    }

    private var canGoForward: Bool { month.startOfMonth < Date().startOfMonth }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button { shift(-1) } label: { Image(systemName: "chevron.left").frame(width: 36, height: 36) }
                Spacer()
                Text(month.formatted("MMMMy")).font(Theme.display(20)).foregroundStyle(Theme.text)
                Spacer()
                Button { shift(1) } label: { Image(systemName: "chevron.right").frame(width: 36, height: 36) }
                    .disabled(!canGoForward)
            }
            .foregroundStyle(Theme.accentText)

            let symbols = Calendar.current.veryShortWeekdaySymbols
            let first = Calendar.current.firstWeekday - 1
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    Text(symbols[(first + i) % 7]).font(.caption2.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 6) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, d in
                    if let d {
                        cell(d)
                    } else {
                        Color.clear.frame(height: 42)
                    }
                }
            }
        }
    }

    private func cell(_ d: Date) -> some View {
        let isSel = d.isSameDay(as: selected)
        let future = d > Date()
        let n = markers(d)
        return Button {
            Haptics.select()
            selected = d
        } label: {
            VStack(spacing: 3) {
                Text("\(Calendar.current.component(.day, from: d))")
                    .font(.system(.subheadline, design: .default, weight: isSel ? .bold : .medium))
                    .foregroundStyle(isSel ? Color.white : (future ? Theme.textSecondary.opacity(0.5) : Theme.text))
                HStack(spacing: 2) {
                    ForEach(0..<min(n, 3), id: \.self) { _ in
                        Circle().fill(isSel ? Color.white : Theme.orange).frame(width: 4, height: 4)
                    }
                }
                .frame(height: 4)
            }
            .frame(maxWidth: .infinity).frame(height: 42)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSel ? AnyShapeStyle(Theme.buttonGradient) : AnyShapeStyle(Color.clear)))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(d.isToday && !isSel ? Theme.orange : Color.clear, lineWidth: 1.3))
        }
        .buttonStyle(.plain)
        .disabled(future)
        .accessibilityLabel(d.formatted("EEEdMMMM"))
    }

    private func shift(_ n: Int) {
        if let m = Calendar.current.date(byAdding: .month, value: n, to: month) {
            month = m
            Haptics.select()
        }
    }
}

// MARK: - Calendar & reports

struct CalendarView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case calendar = "Calendar", week = "Weekly", month = "Monthly"
        var id: String { rawValue }
    }
    @State private var mode: Mode = .calendar

    var body: some View {
        WithScore { engine in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Picker("Mode", selection: $mode) {
                        ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.segmented)
                    switch mode {
                    case .calendar: CalendarMode(engine: engine)
                    case .week: ReportView(engine: engine, days: 7)
                    case .month: ReportView(engine: engine, days: 30)
                    }
                }
                .padding(.horizontal, Theme.pad)
                .padding(.bottom, 40)
            }
            .screenBackground()
            .navigationTitle("Calendar")
        }
    }
}

private struct CalendarMode: View {
    let engine: ScoreEngine
    @Query private var photos: [ProgressPhoto]
    @Query private var weights: [WeightEntry]
    @Query private var sessions: [WorkoutSession]
    @Query private var mobility: [MobilitySession]
    @Query private var journal: [JournalEntry]
    @Query private var foods: [FoodEntry]
    @State private var month = Date()
    @State private var selected = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            MonthGrid(month: $month, selected: $selected) { d in
                var n = 0
                if foods.contains(where: { $0.date.isSameDay(as: d) }) { n += 1 }
                if sessions.contains(where: { $0.isFinished && $0.date.isSameDay(as: d) }) { n += 1 }
                if weights.contains(where: { $0.date.isSameDay(as: d) }) || photos.contains(where: { $0.date.isSameDay(as: d) }) { n += 1 }
                if mobility.contains(where: { $0.date.isSameDay(as: d) }) || journal.contains(where: { $0.date.isSameDay(as: d) }) { n += 1 }
                return n
            }
            .card()
            dayDetail(selected)
        }
    }

    private func dayDetail(_ d: Date) -> some View {
        let score = engine.daily(on: d)
        let nut = engine.nutrition(on: d)
        let dayFoods = foods.filter { $0.date.isSameDay(as: d) }
        let dayWeights = weights.filter { $0.date.isSameDay(as: d) }
        let dayWorkouts = sessions.filter { $0.isFinished && $0.date.isSameDay(as: d) }
        let dayMobility = mobility.filter { $0.date.isSameDay(as: d) }
        let dayPhotos = photos.filter { $0.date.isSameDay(as: d) }
        let dayJournal = journal.filter { $0.date.isSameDay(as: d) }
        let habits = engine.activeHabits.filter { engine.isDone($0, on: d) }
        let sleep = engine.sleepHours(on: d)

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionTitle(d.isToday ? "Today" : d.formatted("EEEdMMMM"))
                Spacer()
                if let t = score.total {
                    Text("\(Int(t.rounded()))").font(Theme.number(22)).foregroundStyle(Theme.accentText)
                    + Text(" score").font(.caption).foregroundStyle(Theme.textSecondary)
                }
            }

            row("fork.knife", "Meals", dayFoods.isEmpty ? nil :
                    "\(nut.kcal.whole) kcal · \(nut.protein.whole) g protein · \(dayFoods.count) items",
                detail: dayFoods.map(\.name).prefix(4).joined(separator: ", "))
            row("drop", "Water", engine.waterMl(on: d) > 0 ? "\(engine.waterMl(on: d)) ml" : nil)
            row("moon.zzz", "Sleep", sleep.map { "\($0.clean) h" })
            row("scalemass", "Weight", dayWeights.isEmpty ? nil : dayWeights.map { "\($0.kg.clean) kg" }.joined(separator: ", "))
            row("dumbbell", "Workouts", dayWorkouts.isEmpty ? nil :
                    dayWorkouts.map { "\($0.name) · \(formatMinutes($0.durationSeconds)) · \(Int($0.totalVolume)) kg" }.joined(separator: "\n"))
            row("figure.flexibility", "Mobility", dayMobility.isEmpty ? nil :
                    dayMobility.map { "\($0.routineName) · \(formatMinutes($0.durationSeconds))" }.joined(separator: "\n"))
            row("checklist", "Habits", engine.activeHabits.isEmpty ? nil : "\(habits.count) of \(engine.activeHabits.count) done",
                detail: habits.map(\.name).joined(separator: ", "))
            if !dayPhotos.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Photos", systemImage: "camera").font(.subheadline.weight(.semibold))
                    HStack(spacing: 8) {
                        ForEach(dayPhotos.prefix(4)) { p in
                            StoredImage(fileName: p.fileName, maxPixel: 300)
                                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                }
            }
            if !dayJournal.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Journal", systemImage: "square.and.pencil").font(.subheadline.weight(.semibold))
                    ForEach(dayJournal) { e in
                        Text(e.preview).font(.system(.footnote, design: .default)).foregroundStyle(Theme.textSecondary).lineLimit(3)
                    }
                }
            }
            if dayFoods.isEmpty && dayWorkouts.isEmpty && dayWeights.isEmpty && dayMobility.isEmpty && dayPhotos.isEmpty
                && dayJournal.isEmpty && engine.waterMl(on: d) == 0 && habits.isEmpty {
                Text("Nothing recorded on this day.").font(.footnote).foregroundStyle(Theme.textSecondary)
            }
        }
        .card()
    }

    @ViewBuilder
    private func row(_ icon: String, _ title: String, _ value: String?, detail: String = "") -> some View {
        if let value {
            HStack(alignment: .top, spacing: 12) {
                IconBadge(systemName: icon, size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text)
                    Text(value).font(.footnote).foregroundStyle(Theme.textSecondary)
                    if !detail.isEmpty { Text(detail).font(.caption).foregroundStyle(Theme.textSecondary.opacity(0.8)).lineLimit(2) }
                }
            }
        }
    }
}

// MARK: - Reports

private struct ReportView: View {
    let engine: ScoreEngine
    let days: Int
    @Query(sort: \WeightEntry.date) private var weights: [WeightEntry]
    @Query private var sessions: [WorkoutSession]
    @State private var exercise = ""

    private var window: [Date] { Date.lastDays(days).filter { $0 >= engine.startDate } }
    private var finished: [WorkoutSession] { sessions.filter { $0.isFinished } }

    var body: some View {
        let p = engine.period(days: days)
        VStack(alignment: .leading, spacing: 18) {
            if window.isEmpty {
                EmptyState(icon: "chart.bar", title: "No data yet", message: "Reports fill in as you log meals, workouts and habits.")
            } else {
                summary(p)
                weightChart
                calorieChart
                proteinChart
                workoutChart
                volumeChart
                strengthChart
                habitChart
            }
        }
    }

    private func summary(_ p: PeriodScore) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(days == 7 ? "Weekly report" : "Monthly report", subtitle: "Last \(days) days")
            HStack(spacing: 14) {
                ProgressRing(progress: p.overall / 100, lineWidth: 10) {
                    Text("\(Int(p.overall.rounded()))").font(Theme.number(24)).foregroundStyle(Theme.text)
                }
                .frame(width: 84, height: 84)
                VStack(alignment: .leading, spacing: 4) {
                    Text(engine.label(for: p.overall)).font(Theme.display(19))
                    Text("\(p.consistentDays) of \(p.days) consistent days").font(.footnote).foregroundStyle(Theme.textSecondary)
                    if let w = engine.needsAttention(in: p).first {
                        Text("Focus: \(w.0.title)").font(.footnote.weight(.semibold)).foregroundStyle(Theme.accentText)
                    }
                }
            }
        }
        .card()
    }

    // Weight
    private var weightChart: some View {
        let from = Date().addingDays(-days)
        let pts = weights.filter { $0.date >= from }
        return chartCard("Weight evolution", pts.count < 2 ? "Log at least two weigh-ins" : nil) {
            Chart(pts) { w in
                LineMark(x: .value("Date", w.date), y: .value("kg", w.kg)).foregroundStyle(Theme.orange)
                    .interpolationMethod(.catmullRom).lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                PointMark(x: .value("Date", w.date), y: .value("kg", w.kg)).foregroundStyle(Theme.deepOrange)
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .frame(height: 150)
        } show: { pts.count >= 2 }
    }

    // Calories
    private var calorieChart: some View {
        let goal = engine.calorieTarget
        let data = window.map { DatedValue(date: $0, value: engine.nutrition(on: $0).kcal) }
        let logged = data.filter { $0.value > 0 }
        let within = logged.filter { abs($0.value / max(goal, 1) - 1) <= 0.10 }.count
        let sub = logged.isEmpty ? "No meals logged" : "\(within) of \(logged.count) logged days within ±10% of target"
        return chartCard("Calorie consistency", sub) {
            Chart {
                ForEach(data) { d in
                    BarMark(x: .value("Day", d.date, unit: .day), y: .value("kcal", d.value))
                        .foregroundStyle(abs(d.value / max(goal, 1) - 1) <= 0.10 && d.value > 0 ? AnyShapeStyle(Theme.brandGradient) : AnyShapeStyle(Theme.yellow.opacity(0.6)))
                }
                RuleMark(y: .value("Goal", goal)).lineStyle(StrokeStyle(lineWidth: 1.2, dash: [4, 4])).foregroundStyle(Theme.textSecondary)
            }
            .frame(height: 140)
        } show: { !logged.isEmpty }
    }

    // Protein
    private var proteinChart: some View {
        let goal = engine.proteinTarget
        let data = window.map { DatedValue(date: $0, value: engine.nutrition(on: $0).protein) }
        let logged = data.filter { $0.value > 0 }
        let hit = logged.filter { $0.value >= 0.9 * goal }.count
        let sub = logged.isEmpty ? "No meals logged" : "Hit ≥90% of target on \(hit) of \(logged.count) logged days"
        return chartCard("Protein consistency", sub) {
            Chart {
                ForEach(data) { d in
                    BarMark(x: .value("Day", d.date, unit: .day), y: .value("g", d.value)).foregroundStyle(Theme.yellow)
                }
                RuleMark(y: .value("Goal", goal)).lineStyle(StrokeStyle(lineWidth: 1.2, dash: [4, 4])).foregroundStyle(Theme.textSecondary)
            }
            .frame(height: 130)
        } show: { !logged.isEmpty }
    }

    // Workout frequency (per week)
    private var weekStarts: [Date] {
        var starts: [Date] = []
        var d = window.first?.startOfWeek ?? Date().startOfWeek
        while d <= Date() {
            starts.append(d)
            d = d.addingDays(7)
        }
        return starts
    }

    private var workoutChart: some View {
        let data = weekStarts.map { w in
            DatedValue(date: w, value: Double(finished.filter { $0.date >= w && $0.date < w.addingDays(7) }.count))
        }
        let total = Int(data.reduce(0) { $0 + $1.value })
        return chartCard("Workout frequency", "\(total) session\(total == 1 ? "" : "s") · target \(engine.weeklyWorkoutTarget)/week") {
            Chart {
                ForEach(data) { d in
                    BarMark(x: .value("Week", d.date, unit: .weekOfYear), y: .value("Workouts", d.value)).foregroundStyle(Theme.brandGradient)
                }
                RuleMark(y: .value("Target", Double(engine.weeklyWorkoutTarget)))
                    .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [4, 4])).foregroundStyle(Theme.textSecondary)
            }
            .frame(height: 120)
        } show: { true }
    }

    private var volumeChart: some View {
        let data = weekStarts.map { w in
            DatedValue(date: w, value: finished.filter { $0.date >= w && $0.date < w.addingDays(7) }.reduce(0) { $0 + $1.totalVolume })
        }
        let total = data.reduce(0) { $0 + $1.value }
        return chartCard("Training volume", total > 0 ? "\(Int(total).formatted()) kg lifted" : "No lifting volume logged") {
            Chart(data) { d in
                BarMark(x: .value("Week", d.date, unit: .weekOfYear), y: .value("kg", d.value)).foregroundStyle(Theme.yellow)
            }
            .frame(height: 120)
        } show: { total > 0 }
    }

    // Strength
    private var strengthChart: some View {
        let names = ExerciseAnalytics.exerciseNames(in: finished)
        let chosen = exercise.isEmpty ? (mostLogged(names) ?? "") : exercise
        let pts = chosen.isEmpty ? [] : ExerciseAnalytics.history(for: chosen, in: finished)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionTitle("Strength progression", subtitle: pts.count < 2 ? "Log an exercise in two workouts" : "Estimated 1RM")
                if !names.isEmpty {
                    Menu {
                        ForEach(names, id: \.self) { n in Button(n) { exercise = n } }
                    } label: {
                        HStack(spacing: 4) { Text(chosen).lineLimit(1); Image(systemName: "chevron.up.chevron.down") }
                            .font(.caption.weight(.semibold)).foregroundStyle(Theme.accentText)
                    }
                }
            }
            if pts.count >= 2 {
                Chart(pts) { p in
                    LineMark(x: .value("Date", p.date), y: .value("1RM", p.bestE1RM)).foregroundStyle(Theme.orange)
                        .interpolationMethod(.catmullRom).lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    PointMark(x: .value("Date", p.date), y: .value("1RM", p.bestE1RM)).foregroundStyle(Theme.deepOrange)
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 150)
            }
        }
        .card()
    }

    private func mostLogged(_ names: [String]) -> String? {
        names.max { a, b in
            ExerciseAnalytics.history(for: a, in: finished).count < ExerciseAnalytics.history(for: b, in: finished).count
        }
    }

    // Habits
    private var habitChart: some View {
        let data = window.map { d -> DatedValue in
            let h = engine.habitsDone(on: d)
            return DatedValue(date: d, value: h.total == 0 ? 0 : Double(h.done) / Double(h.total) * 100)
        }
        let avg = data.isEmpty ? 0 : data.reduce(0) { $0 + $1.value } / Double(data.count)
        return chartCard("Habit completion", "Average \(Int(avg.rounded()))% per day") {
            Chart(data) { d in
                BarMark(x: .value("Day", d.date, unit: .day), y: .value("%", d.value)).foregroundStyle(Theme.brandGradient)
            }
            .chartYScale(domain: 0...100)
            .frame(height: 120)
        } show: { engine.activeHabits.count > 0 }
    }

    private func chartCard<C: View>(_ title: String, _ subtitle: String?, @ViewBuilder content: () -> C, show: () -> Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title, subtitle: subtitle)
            if show() { content() }
        }
        .card()
    }
}
