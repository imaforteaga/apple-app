import SwiftUI
import SwiftData
import Charts

struct HomeView: View {
    var body: some View {
        WithScore { engine in
            HomeContent(engine: engine)
        }
    }
}

private enum HomeSheet: String, Identifiable {
    case meal, weight, photo, water, habits, sleep
    var id: String { rawValue }
}

private struct HomeContent: View {
    let engine: ScoreEngine
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var appState: AppState

    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]
    @Query private var routines: [Routine]
    @Query private var sessions: [WorkoutSession]
    @Query private var habitLogs: [HabitLog]
    @Query private var favoriteVerses: [FavoriteVerse]

    @State private var sheet: HomeSheet?
    @State private var activeSession: WorkoutSession?

    private var profile: UserProfile? { engine.profile }
    private var today: Date { Date() }
    private var verse: Verse { BibleData.verse(on: today) }
    private var nutrition: DayNutrition { engine.nutrition(on: today) }
    private var todaysRoutine: Routine? {
        routines.filter { $0.weekday == today.weekday }.sorted { $0.sortOrder < $1.sortOrder }.first
    }
    private var openSession: WorkoutSession? { sessions.first { !$0.isFinished } }
    private var trainedToday: Bool { engine.workoutCount(on: today) > 0 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                verseCard
                todayCard
                quickActions
                scoreWidget
                workoutCard
                habitsCard
                bodyCard
                weekCard
                journalCard
            }
            .padding(.horizontal, Theme.pad)
            .padding(.bottom, 40)
        }
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $sheet) { s in
            switch s {
            case .meal: AddMealView(date: today, defaultMeal: MealType.current)
            case .weight: AddWeightView()
            case .photo: AddPhotoView()
            case .water: WaterLogView(date: today)
            case .habits: HabitChecklistSheet()
            case .sleep: SleepLogView(day: today)
            }
        }
        .fullScreenCover(item: $activeSession) { s in
            WorkoutSessionView(session: s)
        }
        .onAppear { _ = MilestoneSync.sync(context) }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(today.longDate.uppercased())
                .font(.system(.caption, design: .default, weight: .bold))
                .tracking(1.3)
                .foregroundStyle(Theme.accentText)
            Text(Motivation.greeting(name: profile?.firstName ?? ""))
                .font(Theme.display(34))
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            Text(Motivation.message(for: today))
                .font(.system(.body, design: .default).italic())
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.top, 18)
    }

    // MARK: Verse

    private var verseCard: some View {
        NavigationLink {
            BibleView()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Verse of the day", systemImage: "book.closed")
                        .font(.system(.caption, design: .default, weight: .bold))
                        .foregroundStyle(Theme.accentText)
                        .textCase(.uppercase)
                        .tracking(0.8)
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.textSecondary)
                }
                Text("“\(verse.text)”")
                    .font(.system(.body, design: .default))
                    .foregroundStyle(Theme.text)
                    .lineLimit(5)
                    .multilineTextAlignment(.leading)
                Text(verse.reference + " · KJV")
                    .font(.system(.footnote, design: .default, weight: .semibold))
                    .foregroundStyle(Theme.accentText)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .fill(LinearGradient(colors: [Theme.softAccent, Theme.card],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .stroke(Theme.yellow.opacity(0.35), lineWidth: 0.8))
            .shadow(color: Theme.orange.opacity(0.10), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: Today

    private var todayCard: some View {
        let calGoal = Double(profile?.calorieTarget ?? 2500)
        let proGoal = Double(profile?.proteinTarget ?? 150)
        let waterGoal = Double(profile?.waterTargetMl ?? 3000)
        let water = Double(engine.waterMl(on: today))
        let habits = engine.habitsDone(on: today)

        return VStack(alignment: .leading, spacing: 18) {
            SectionTitle("Today", subtitle: summaryLine(cal: nutrition.kcal / max(calGoal, 1), habits: habits))
            HStack(alignment: .top, spacing: 8) {
                Button { appState.tab = .nutrition } label: {
                    RingStat(title: "Calories", value: nutrition.kcal.whole,
                             detail: "of \(Int(calGoal)) kcal",
                             progress: nutrition.kcal / max(calGoal, 1), icon: "flame")
                }.buttonStyle(.plain)
                Button { appState.tab = .nutrition } label: {
                    RingStat(title: "Protein", value: "\(nutrition.protein.whole) g",
                             detail: "of \(Int(proGoal)) g",
                             progress: nutrition.protein / max(proGoal, 1), icon: "bolt")
                }.buttonStyle(.plain)
                Button { sheet = .water } label: {
                    RingStat(title: "Water", value: String(format: "%.1f L", water / 1000),
                             detail: "of \(String(format: "%.1f", waterGoal / 1000)) L",
                             progress: water / max(waterGoal, 1), icon: "drop")
                }.buttonStyle(.plain)
            }
        }
        .card()
    }

    private func summaryLine(cal: Double, habits: (done: Int, total: Int)) -> String {
        if habits.total > 0 {
            return "\(Int((cal * 100).rounded()))% of calories · \(habits.done)/\(habits.total) habits"
        }
        return "\(Int((cal * 100).rounded()))% of your calorie target"
    }

    // MARK: Quick actions

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("Quick actions")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    QuickAction(icon: "fork.knife", title: "Meal") { sheet = .meal }
                    QuickAction(icon: "scalemass", title: "Weight") { sheet = .weight }
                    QuickAction(icon: "play.fill", title: "Workout") { startWorkout(todaysRoutine) }
                    QuickAction(icon: "camera", title: "Photo") { sheet = .photo }
                    QuickAction(icon: "drop", title: "Water") { sheet = .water }
                    QuickAction(icon: "checkmark.circle", title: "Habit") { sheet = .habits }
                    QuickAction(icon: "moon.zzz", title: "Sleep") { sheet = .sleep }
                }
                .padding(.vertical, 4)
            }
            .scrollClipDisabled()
        }
    }

    // MARK: Score widget

    private var scoreWidget: some View {
        let week = engine.week
        let evolution = engine.weeklyEvolution(points: 14)
        return NavigationLink {
            ScoreView()
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Transformation Score", systemImage: "flame")
                        .font(.system(.caption, design: .default, weight: .bold))
                        .foregroundStyle(Theme.accentText)
                        .textCase(.uppercase)
                        .tracking(0.8)
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.textSecondary)
                }
                HStack(spacing: 18) {
                    ProgressRing(progress: week.overall / 100, lineWidth: 11) {
                        VStack(spacing: -2) {
                            Text("\(Int(week.overall.rounded()))")
                                .font(Theme.number(30))
                                .foregroundStyle(Theme.text)
                            Text("/ 100").font(.caption2).foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .frame(width: 96, height: 96)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(engine.label(for: week.overall))
                            .font(Theme.display(19))
                            .foregroundStyle(Theme.text)
                        Text("Last 7 days · \(week.consistentDays) consistent day\(week.consistentDays == 1 ? "" : "s")")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                        if let weakest = engine.needsAttention(in: week).first {
                            Label("Focus: \(weakest.0.title)", systemImage: weakest.0.icon)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.accentText)
                        }
                    }
                    Spacer(minLength: 0)
                }
                if evolution.count > 1 {
                    Chart(evolution) { p in
                        AreaMark(x: .value("Day", p.date), y: .value("Score", p.value))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(LinearGradient(colors: [Theme.orange.opacity(0.30), Theme.orange.opacity(0)],
                                                            startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("Day", p.date), y: .value("Score", p.value))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Theme.orange)
                            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .chartYScale(domain: 0...100)
                    .frame(height: 52)
                }
                Text("Measures personal consistency, not medical health or self-worth.")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
            }
            .card()
        }
        .buttonStyle(.plain)
    }

    // MARK: Workout

    private var workoutCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle("Today's workout")
            if let open = openSession {
                HStack(spacing: 14) {
                    IconBadge(systemName: open.type.icon, size: 46)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(open.name).font(.headline).foregroundStyle(Theme.text)
                        Text("In progress · started \(open.date.timeString)")
                            .font(.footnote).foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                }
                Button("Resume workout") { activeSession = open }
                    .buttonStyle(PrimaryButtonStyle())
            } else if trainedToday {
                HStack(spacing: 14) {
                    IconBadge(systemName: "checkmark", size: 46)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Workout complete").font(.headline).foregroundStyle(Theme.text)
                        Text("Nice work. Recover well: eat, hydrate, stretch.")
                            .font(.footnote).foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                }
            } else if let r = todaysRoutine {
                HStack(spacing: 14) {
                    IconBadge(systemName: r.type.icon, size: 46)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(r.name).font(.headline).foregroundStyle(Theme.text)
                        Text("\(r.type.title) · \(r.exercises.count) exercises")
                            .font(.footnote).foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                }
                Button("Start workout") { startWorkout(r) }
                    .buttonStyle(PrimaryButtonStyle())
            } else {
                HStack(spacing: 14) {
                    IconBadge(systemName: "figure.cooldown", size: 46)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(routines.isEmpty ? "No routines yet" : "Nothing scheduled")
                            .font(.headline).foregroundStyle(Theme.text)
                        Text(routines.isEmpty ? "Create a routine in Training to see it here."
                             : "Rest day, or start a session anyway.")
                            .font(.footnote).foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                }
                HStack {
                    Button("Quick workout") { startWorkout(nil) }
                        .buttonStyle(SoftButtonStyle(compact: true))
                    Button("Open Training") { appState.tab = .training }
                        .buttonStyle(SoftButtonStyle(compact: true))
                }
            }
        }
        .card()
    }

    private func startWorkout(_ routine: Routine?) {
        activeSession = WorkoutLauncher.start(routine: routine, context: context, sessions: sessions)
    }

    // MARK: Habits

    private var habitsCard: some View {
        let habits = engine.activeHabits
        let progress = engine.habitsDone(on: today)
        return VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Habits", subtitle: "\(progress.done) of \(progress.total) done today") {
                NavigationLink { HabitsView() } label: {
                    Text("See all").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accentText)
                }
            }
            if habits.isEmpty {
                Text("No habits yet. Add some in Habits.")
                    .font(.footnote).foregroundStyle(Theme.textSecondary)
            } else {
                LinearProgressBar(progress: progress.total == 0 ? 0 : Double(progress.done) / Double(progress.total))
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(habits.prefix(6)) { h in
                        HabitPill(habit: h, done: engine.isDone(h, on: today), streak: engine.streak(for: h)) {
                            Haptics.tap()
                            withAnimation(Motion.quick) {
                                context.toggleHabit(h, on: today, logs: habitLogs)
                            }
                        }
                    }
                }
            }
        }
        .card()
    }

    // MARK: Body

    private var bodyCard: some View {
        let current = weights.first?.kg ?? profile?.startWeightKg
        let first = weights.last?.kg ?? profile?.startWeightKg
        let series = Array(weights.reversed().suffix(20))
        return NavigationLink {
            BodyView()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Body weight", systemImage: "scalemass")
                        .font(.system(.caption, design: .default, weight: .bold))
                        .foregroundStyle(Theme.accentText)
                        .textCase(.uppercase)
                        .tracking(0.8)
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.textSecondary)
                }
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        if let current {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(current.clean).font(Theme.number(40)).foregroundStyle(Theme.text)
                                Text("kg").font(.subheadline).foregroundStyle(Theme.textSecondary)
                            }
                        }
                        if let current, let first, series.count > 1 {
                            let d = current - first
                            Text("\(d >= 0 ? "+" : "−")\(abs(d).oneDecimal) kg since start")
                                .font(.footnote).foregroundStyle(Theme.textSecondary)
                        } else {
                            Text("Add weigh-ins to see your trend")
                                .font(.footnote).foregroundStyle(Theme.textSecondary)
                        }
                    }
                    Spacer()
                    if series.count > 1 {
                        Chart(series) { w in
                            LineMark(x: .value("Date", w.date), y: .value("kg", w.kg))
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(Theme.orange)
                                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        }
                        .chartXAxis(.hidden)
                        .chartYAxis(.hidden)
                        .chartYScale(domain: .automatic(includesZero: false))
                        .frame(width: 130, height: 54)
                    }
                }
            }
            .card()
        }
        .buttonStyle(.plain)
    }

    // MARK: Week

    private var weekCard: some View {
        let days = Date.lastDays(7)
        let scores = days.map { engine.daily(on: $0) }
        let workoutsCount = days.reduce(0) { $0 + engine.workoutCount(on: $1) }
        let mobilityCount = days.reduce(0) { $0 + engine.mobilityCount(on: $1) }
        let avgHabits: Double = {
            let vals = scores.compactMap { $0.values[.habits] }
            return vals.isEmpty ? 0 : vals.reduce(0, +) / Double(vals.count)
        }()
        return VStack(alignment: .leading, spacing: 14) {
            SectionTitle("This week", subtitle: "Daily consistency")
            Chart(scores) { s in
                BarMark(x: .value("Day", s.day, unit: .day), y: .value("Score", s.total ?? 0), width: .fixed(22))
                    .cornerRadius(7)
                    .foregroundStyle(s.day.isToday ? AnyShapeStyle(Theme.brandGradient) : AnyShapeStyle(Theme.yellow.opacity(0.75)))
            }
            .chartYScale(domain: 0...100)
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                }
            }
            .frame(height: 110)
            HStack(spacing: 10) {
                StatTile(value: "\(workoutsCount)", label: "Workouts", icon: "dumbbell")
                StatTile(value: "\(mobilityCount)", label: "Mobility", icon: "figure.flexibility")
                StatTile(value: "\(Int((avgHabits * 100).rounded()))%", label: "Habits", icon: "checklist")
            }
        }
        .card()
    }

    // MARK: Journal

    private var journalCard: some View {
        NavigationLink {
            JournalView()
        } label: {
            HStack(spacing: 14) {
                IconBadge(systemName: "square.and.pencil", size: 46)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Daily reflection").font(.headline).foregroundStyle(Theme.text)
                    Text("Did I stay disciplined today? Write it down.")
                        .font(.footnote).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.textSecondary)
            }
            .card()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Small components

private struct QuickAction: View {
    let icon: String
    let title: String
    let action: () -> Void
    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(Theme.buttonGradient))
                    .shadow(color: Theme.orange.opacity(0.18), radius: 8, y: 4)
                Text(title)
                    .font(.system(.caption, design: .default, weight: .semibold))
                    .foregroundStyle(Theme.text)
            }
            .frame(width: 74)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.card))
            .shadow(color: Color.black.opacity(0.05), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }
}

struct HabitPill: View {
    let habit: Habit
    let done: Bool
    var streak: Int = 0
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: done ? "checkmark.circle.fill" : habit.icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(done ? Color.white : Theme.accentText)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 0) {
                    Text(habit.name)
                        .font(.system(.footnote, design: .default, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    if streak > 1 {
                        Text("\(streak)-day streak").font(.system(size: 10)).opacity(0.8)
                    }
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(done ? Color.white : Theme.text)
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(done ? AnyShapeStyle(Theme.buttonGradient) : AnyShapeStyle(Theme.cardAlt)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(habit.name), \(done ? "completed" : "not completed")")
    }
}
