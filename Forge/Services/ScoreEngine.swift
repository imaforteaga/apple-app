import Foundation
import SwiftUI

// MARK: - Categories

enum ScoreCategory: String, CaseIterable, Identifiable {
    case nutrition, workouts, mobility, hydration, sleep, habits, goals
    var id: String { rawValue }

    var title: String {
        switch self {
        case .nutrition: return "Nutrition"
        case .workouts: return "Workouts"
        case .mobility: return "Mobility"
        case .hydration: return "Hydration"
        case .sleep: return "Sleep"
        case .habits: return "Habits"
        case .goals: return "Goals"
        }
    }
    var icon: String {
        switch self {
        case .nutrition: return "fork.knife"
        case .workouts: return "dumbbell"
        case .mobility: return "figure.flexibility"
        case .hydration: return "drop"
        case .sleep: return "moon.zzz"
        case .habits: return "checklist"
        case .goals: return "flag"
        }
    }
    var explanation: String {
        switch self {
        case .nutrition: return "Calories close to target (±10% counts as on target) and protein ≥ 90% of target."
        case .workouts: return "Sessions completed versus your weekly training target. Scheduled days you skip count against you."
        case .mobility: return "Stretching / mobility sessions versus a weekly target of sessions."
        case .hydration: return "Water logged versus your daily target (90% counts as full)."
        case .sleep: return "Hours slept versus your target (90% counts as full). Days you don't log are ignored."
        case .habits: return "Share of your score-counting habits completed each day."
        case .goals: return "How many of your active milestones you moved forward in the last 7 days."
        }
    }
    var tip: String {
        switch self {
        case .nutrition: return "Log meals as you eat them — protein first."
        case .workouts: return "Book your next session now, even a short one counts."
        case .mobility: return "Ten minutes of morning or evening mobility is enough."
        case .hydration: return "Keep a bottle in sight and use the quick-add buttons."
        case .sleep: return "Protect a consistent bedtime tonight."
        case .habits: return "Pick the one habit you keep skipping and do it first."
        case .goals: return "Log a small update on one milestone today."
        }
    }
}

// MARK: - Result types

struct DayScore: Identifiable {
    var id: Date { day }
    var day: Date
    var values: [ScoreCategory: Double]   // 0…1, only categories that apply that day
    var total: Double?                    // 0…100

    var isConsistent: Bool { (total ?? 0) >= 60 }
}

struct PeriodScore {
    var overall: Double                    // 0…100
    var level: Double                      // average of category scores, 0…100
    var consistency: Double                // share of days ≥ 60, 0…100
    var categories: [ScoreCategory: Double]  // 0…1
    var consistentDays: Int
    var days: Int

    static let empty = PeriodScore(overall: 0, level: 0, consistency: 0, categories: [:], consistentDays: 0, days: 0)
}

struct ScorePoint: Identifiable {
    var id: Date { date }
    var date: Date
    var value: Double
}

// MARK: - Engine

/// Computes the Transformation Score from stored data.
///
/// Philosophy: *consistency over perfection.* Partial effort earns partial credit, 90% of a
/// target counts as full credit, and the period score blends the average level (70%) with how
/// many days were "consistent" (30%, a day ≥ 60 is consistent).
/// This is a personal consistency measure – not a medical or health assessment.
struct ScoreEngine {
    let profile: UserProfile?
    let habits: [Habit]
    let supplements: [Supplement]
    let milestones: [Milestone]
    let routines: [Routine]

    private let foodByDay: [Date: DayNutrition]
    private let waterByDay: [Date: Int]
    private let workoutsByDay: [Date: Int]
    private let mobilityCountByDay: [Date: Int]
    private let mobilitySecondsByDay: [Date: Int]
    private let sleepByDay: [Date: Double]
    private let habitDone: Set<HabitDay>
    private let suppLogged: [Date: Set<UUID>]
    private let milestoneUpdateDays: [UUID: [Date]]

    struct HabitDay: Hashable {
        var habit: UUID
        var day: Date
    }

    init(profile: UserProfile?,
         foodEntries: [FoodEntry],
         water: [WaterEntry],
         workouts: [WorkoutSession],
         mobility: [MobilitySession],
         habits: [Habit],
         habitLogs: [HabitLog],
         sleep: [SleepEntry],
         supplements: [Supplement],
         supplementLogs: [SupplementLog],
         milestones: [Milestone],
         milestoneUpdates: [MilestoneUpdate],
         routines: [Routine]) {
        self.profile = profile
        self.habits = habits
        self.supplements = supplements
        self.milestones = milestones
        self.routines = routines

        var food: [Date: [FoodEntry]] = [:]
        for e in foodEntries { food[e.date.startOfDay, default: []].append(e) }
        self.foodByDay = food.mapValues { DayNutrition(entries: $0) }

        var w: [Date: Int] = [:]
        for e in water { w[e.date.startOfDay, default: 0] += e.ml }
        self.waterByDay = w

        var wk: [Date: Int] = [:]
        for s in workouts where s.isFinished { wk[s.date.startOfDay, default: 0] += 1 }
        self.workoutsByDay = wk

        var mc: [Date: Int] = [:]
        var ms: [Date: Int] = [:]
        for m in mobility {
            mc[m.date.startOfDay, default: 0] += 1
            ms[m.date.startOfDay, default: 0] += m.durationSeconds
        }
        self.mobilityCountByDay = mc
        self.mobilitySecondsByDay = ms

        var sl: [Date: Double] = [:]
        for s in sleep { sl[s.day.startOfDay] = s.hours }
        self.sleepByDay = sl

        self.habitDone = Set(habitLogs.map { HabitDay(habit: $0.habitID, day: $0.day.startOfDay) })

        var sup: [Date: Set<UUID>] = [:]
        for l in supplementLogs { sup[l.day.startOfDay, default: []].insert(l.supplementID) }
        self.suppLogged = sup

        var mu: [UUID: [Date]] = [:]
        for u in milestoneUpdates { mu[u.milestoneID, default: []].append(u.date.startOfDay) }
        self.milestoneUpdateDays = mu
    }

    // MARK: Settings

    var disabled: Set<String> {
        Set((profile?.disabledScoreCategories ?? "").split(separator: ",").map(String.init))
    }
    var enabledCategories: [ScoreCategory] {
        ScoreCategory.allCases.filter { !disabled.contains($0.rawValue) }
    }
    var startDate: Date { (profile?.createdAt ?? Date()).startOfDay }
    var weeklyWorkoutTarget: Int { max(1, profile?.weeklyTrainingDays ?? 3) }
    var weeklyMobilityTarget: Int {
        let v = UserDefaults.standard.integer(forKey: "mobilityWeeklyTarget")
        return v > 0 ? v : 4
    }
    var calorieTarget: Double { Double(profile?.calorieTarget ?? 2500) }
    var proteinTarget: Double { Double(profile?.proteinTarget ?? 150) }
    var waterTarget: Double { Double(profile?.waterTargetMl ?? 3000) }
    var sleepTarget: Double { profile?.sleepTargetHours ?? 8 }

    // MARK: Raw day data (shared with the rest of the app)

    func nutrition(on day: Date) -> DayNutrition { foodByDay[day.startOfDay] ?? DayNutrition() }
    func waterMl(on day: Date) -> Int { waterByDay[day.startOfDay] ?? 0 }
    func workoutCount(on day: Date) -> Int { workoutsByDay[day.startOfDay] ?? 0 }
    func mobilityCount(on day: Date) -> Int { mobilityCountByDay[day.startOfDay] ?? 0 }
    func mobilitySeconds(on day: Date) -> Int { mobilitySecondsByDay[day.startOfDay] ?? 0 }
    func sleepHours(on day: Date) -> Double? { sleepByDay[day.startOfDay] }

    var activeHabits: [Habit] {
        habits.filter { $0.isActive }.sorted { $0.sortOrder < $1.sortOrder }
    }

    func dueSupplements(on day: Date) -> [Supplement] {
        supplements.filter { $0.isDue(on: day) }
    }

    // MARK: Habits

    func isManuallyDone(_ habit: Habit, on day: Date) -> Bool {
        habitDone.contains(HabitDay(habit: habit.id, day: day.startOfDay))
    }

    func isAutoDone(_ habit: Habit, on day: Date) -> Bool {
        let d = day.startOfDay
        switch habit.autoKey {
        case "water": return Double(waterMl(on: d)) >= 0.9 * waterTarget
        case "training": return workoutCount(on: d) > 0
        case "stretch": return mobilityCount(on: d) > 0
        case "protein": return nutrition(on: d).protein >= 0.9 * proteinTarget
        case "sleep":
            if let h = sleepHours(on: d) { return h >= 0.9 * sleepTarget }
            return false
        case "supplements":
            let due = dueSupplements(on: d)
            guard !due.isEmpty else { return false }
            let logged = suppLogged[d] ?? []
            return due.allSatisfy { logged.contains($0.id) }
        case "creatine":
            let creatine = supplements.filter { $0.isActive && $0.name.lowercased().contains("creatine") }
            guard !creatine.isEmpty else { return false }
            let logged = suppLogged[d] ?? []
            return creatine.contains { logged.contains($0.id) }
        default: return false
        }
    }

    func isDone(_ habit: Habit, on day: Date) -> Bool {
        isManuallyDone(habit, on: day) || isAutoDone(habit, on: day)
    }

    /// Consecutive completed days. Today not yet done does not break the streak.
    func streak(for habit: Habit) -> Int {
        var d = Date().startOfDay
        if !isDone(habit, on: d) { d = d.addingDays(-1) }
        var n = 0
        while n < 2000, isDone(habit, on: d) {
            n += 1
            d = d.addingDays(-1)
        }
        return n
    }

    func completionRate(for habit: Habit, days: Int) -> Double {
        let window = Date.lastDays(days).filter { $0 >= startDate }
        guard !window.isEmpty else { return 0 }
        return Double(window.filter { isDone(habit, on: $0) }.count) / Double(window.count)
    }

    func habitsDone(on day: Date) -> (done: Int, total: Int) {
        let hs = activeHabits
        return (hs.filter { isDone($0, on: day) }.count, hs.count)
    }

    // MARK: Daily values

    private var scoringHabits: [Habit] { activeHabits.filter { $0.countsForScore } }

    private func activeMilestones(on day: Date) -> [Milestone] {
        milestones.filter { m in
            m.createdAt.startOfDay <= day &&
            (!m.isCompleted || (m.completedAt?.startOfDay ?? day) >= day)
        }
    }

    func value(_ cat: ScoreCategory, on rawDay: Date) -> Double? {
        let day = rawDay.startOfDay
        let isToday = day.isToday
        switch cat {
        case .nutrition:
            let n = nutrition(on: day)
            guard n.count > 0 else { return 0 }
            let ratio = calorieTarget > 0 ? n.kcal / calorieTarget : 1
            let cal: Double
            if isToday && ratio <= 1.1 {
                cal = min(ratio / 0.9, 1)
            } else {
                let dev = abs(ratio - 1)
                cal = dev <= 0.10 ? 1 : max(0, 1 - (dev - 0.10) / 0.40)
            }
            let prot = proteinTarget > 0 ? min(n.protein / (0.9 * proteinTarget), 1) : 1
            return 0.6 * cal + 0.4 * prot

        case .workouts:
            if workoutCount(on: day) > 0 { return 1 }
            let scheduled = routines.contains { $0.weekday == day.weekday }
            return (scheduled && !isToday) ? 0 : nil

        case .mobility:
            return mobilityCount(on: day) > 0 ? 1 : nil

        case .hydration:
            guard waterTarget > 0 else { return nil }
            return min(Double(waterMl(on: day)) / (0.9 * waterTarget), 1)

        case .sleep:
            guard let h = sleepHours(on: day), sleepTarget > 0 else { return nil }
            return min(h / (0.9 * sleepTarget), 1)

        case .habits:
            let hs = scoringHabits
            guard !hs.isEmpty else { return nil }
            return Double(hs.filter { isDone($0, on: day) }.count) / Double(hs.count)

        case .goals:
            let ms = activeMilestones(on: day)
            guard !ms.isEmpty else { return nil }
            let from = day.addingDays(-6)
            let moved = ms.filter { m in
                (milestoneUpdateDays[m.id] ?? []).contains { $0 >= from && $0 <= day }
            }.count
            return Double(moved) / Double(ms.count)
        }
    }

    func daily(on rawDay: Date) -> DayScore {
        let day = rawDay.startOfDay
        var values: [ScoreCategory: Double] = [:]
        for c in enabledCategories {
            if let v = value(c, on: day) { values[c] = v }
        }
        let total: Double? = values.isEmpty ? nil : (values.values.reduce(0, +) / Double(values.count)) * 100
        return DayScore(day: day, values: values, total: total)
    }

    // MARK: Periods

    /// Rolling window of `days` ending on `end` (inclusive). Days before the app was first used are skipped.
    func period(days: Int, endingAt end: Date = Date()) -> PeriodScore {
        let window = Date.lastDays(days, endingAt: end).filter { $0 >= startDate }
        guard !window.isEmpty else { return .empty }
        let scores = window.map { daily(on: $0) }
        var cats: [ScoreCategory: Double] = [:]

        for c in enabledCategories {
            switch c {
            case .workouts, .mobility:
                let count = window.reduce(0) {
                    $0 + (c == .workouts ? workoutCount(on: $1) : mobilityCount(on: $1))
                }
                let weekly = Double(c == .workouts ? weeklyWorkoutTarget : weeklyMobilityTarget)
                let target = max(1, weekly * Double(window.count) / 7.0)
                cats[c] = min(Double(count) / target, 1)
            default:
                let vals = scores.compactMap { $0.values[c] }
                if !vals.isEmpty { cats[c] = vals.reduce(0, +) / Double(vals.count) }
            }
        }
        let level = cats.isEmpty ? 0 : (cats.values.reduce(0, +) / Double(cats.count)) * 100
        let consistent = scores.filter { $0.isConsistent }.count
        let consistency = Double(consistent) / Double(window.count) * 100
        let overall = 0.7 * level + 0.3 * consistency
        return PeriodScore(overall: overall, level: level, consistency: consistency,
                           categories: cats, consistentDays: consistent, days: window.count)
    }

    var today: DayScore { daily(on: Date()) }
    var week: PeriodScore { period(days: 7) }
    var month: PeriodScore { period(days: 30) }

    /// Rolling 7-day score for each of the last `n` days (oldest first) – the "evolution".
    func weeklyEvolution(points n: Int = 14) -> [ScorePoint] {
        Date.lastDays(n).compactMap { d in
            guard d >= startDate else { return nil }
            return ScorePoint(date: d, value: period(days: 7, endingAt: d).overall)
        }
    }

    func dailySeries(days: Int) -> [DayScore] {
        Date.lastDays(days).filter { $0 >= startDate }.map { daily(on: $0) }
    }

    /// Categories ordered from most to least in need of attention.
    func needsAttention(in p: PeriodScore) -> [(ScoreCategory, Double)] {
        p.categories.sorted { $0.value < $1.value }.map { ($0.key, $0.value) }
    }

    // MARK: Convenience

    func label(for score: Double) -> String {
        switch score {
        case 85...: return "Outstanding consistency"
        case 70..<85: return "Strong rhythm"
        case 50..<70: return "Building momentum"
        case 25..<50: return "Getting started"
        default: return "A fresh start"
        }
    }
}
