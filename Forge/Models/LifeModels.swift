import Foundation
import SwiftData
import SwiftUI

// MARK: - Habits & supplements

@Model
final class Habit {
    var id: UUID = UUID()
    var name: String = ""
    var icon: String = "checkmark.circle"
    var isActive: Bool = true
    var countsForScore: Bool = true
    var sortOrder: Int = 0
    /// When non-empty the habit is auto-completed from other data (e.g. "water", "training").
    var autoKey: String = ""
    var createdAt: Date = Date()

    init(name: String, icon: String, autoKey: String = "", sortOrder: Int = 0) {
        self.name = name
        self.icon = icon
        self.autoKey = autoKey
        self.sortOrder = sortOrder
    }
}

@Model
final class HabitLog {
    var id: UUID = UUID()
    var habitID: UUID = UUID()
    var day: Date = Date().startOfDay
    init(habitID: UUID, day: Date) {
        self.habitID = habitID
        self.day = day.startOfDay
    }
}

enum SupplementTime: String, CaseIterable, Identifiable {
    case morning, withMeal, preWorkout, postWorkout, evening, bedtime
    var id: String { rawValue }
    var title: String {
        switch self {
        case .morning: return "Morning"
        case .withMeal: return "With a meal"
        case .preWorkout: return "Pre-workout"
        case .postWorkout: return "Post-workout"
        case .evening: return "Evening"
        case .bedtime: return "Bedtime"
        }
    }
    var order: Int { SupplementTime.allCases.firstIndex(of: self) ?? 0 }
}

@Model
final class Supplement {
    var id: UUID = UUID()
    var name: String = ""
    var dosage: String = ""
    var timeRaw: String = SupplementTime.morning.rawValue
    /// Bitmask of Calendar weekdays: bit (weekday-1). 127 = every day.
    var weekdayMask: Int = 127
    var isActive: Bool = true
    var reminderEnabled: Bool = false
    var reminderHour: Int = 9
    var reminderMinute: Int = 0
    var notes: String = ""
    var createdAt: Date = Date()

    init(name: String, dosage: String, time: SupplementTime = .morning) {
        self.name = name
        self.dosage = dosage
        self.timeRaw = time.rawValue
    }

    var time: SupplementTime {
        get { SupplementTime(rawValue: timeRaw) ?? .morning }
        set { timeRaw = newValue.rawValue }
    }

    func isDue(on date: Date) -> Bool {
        isActive && (weekdayMask & (1 << (date.weekday - 1))) != 0
    }
}

@Model
final class SupplementLog {
    var id: UUID = UUID()
    var supplementID: UUID = UUID()
    var day: Date = Date().startOfDay
    var takenAt: Date = Date()
    var dosage: String = ""
    init(supplementID: UUID, day: Date, dosage: String) {
        self.supplementID = supplementID
        self.day = day.startOfDay
        self.dosage = dosage
    }
}

// MARK: - Journal

enum Mood: Int, CaseIterable, Identifiable {
    case low = 1, flat, steady, good, great
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .low: return "Low"
        case .flat: return "Flat"
        case .steady: return "Steady"
        case .good: return "Good"
        case .great: return "Great"
        }
    }
    var icon: String {
        switch self {
        case .low: return "cloud.rain"
        case .flat: return "cloud"
        case .steady: return "sun.haze"
        case .good: return "sun.max"
        case .great: return "sparkles"
        }
    }
}

@Model
final class JournalEntry {
    var id: UUID = UUID()
    var date: Date = Date()
    var updatedAt: Date = Date()
    var moodValue: Int = 3
    var text: String = ""
    var achievements: String = ""
    var improvements: String = ""
    var reflection: String = ""
    var promptsData: Data = Data()
    var isFavorite: Bool = false

    init(date: Date = Date()) { self.date = date }

    var mood: Mood {
        get { Mood(rawValue: moodValue) ?? .steady }
        set { moodValue = newValue.rawValue }
    }
    var prompts: [String: String] {
        get { (try? JSONDecoder().decode([String: String].self, from: promptsData)) ?? [:] }
        set { promptsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var isEmpty: Bool {
        text.trimmed.isEmpty && achievements.trimmed.isEmpty && improvements.trimmed.isEmpty
            && reflection.trimmed.isEmpty && prompts.values.allSatisfy { $0.trimmed.isEmpty }
    }

    /// All text, lower-cased – used by search.
    var searchableText: String {
        ([text, achievements, improvements, reflection] + Array(prompts.values)).joined(separator: " ").lowercased()
    }

    var preview: String {
        let candidates = [text, achievements, reflection, improvements] + Array(prompts.values)
        return candidates.first(where: { !$0.trimmed.isEmpty })?.trimmed ?? "No text"
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

enum JournalPrompt: String, CaseIterable, Identifiable {
    case accomplished = "What did I accomplish today?"
    case better = "What could I have done better?"
    case disciplined = "Did I stay disciplined?"
    case grateful = "What am I grateful for?"
    case tomorrow = "What is my main objective for tomorrow?"
    case values = "Did I act according to my values?"
    var id: String { rawValue }
}

// MARK: - Milestones

enum MilestoneCategory: String, CaseIterable, Identifiable {
    case physique, strength, nutrition, fitness, mobility, discipline, spirituality, development
    var id: String { rawValue }
    var title: String {
        switch self {
        case .physique: return "Physique"
        case .strength: return "Strength"
        case .nutrition: return "Nutrition"
        case .fitness: return "Fitness"
        case .mobility: return "Mobility"
        case .discipline: return "Discipline"
        case .spirituality: return "Spirituality"
        case .development: return "Personal development"
        }
    }
    var icon: String {
        switch self {
        case .physique: return "figure.stand"
        case .strength: return "dumbbell"
        case .nutrition: return "fork.knife"
        case .fitness: return "figure.run"
        case .mobility: return "figure.flexibility"
        case .discipline: return "scope"
        case .spirituality: return "book.closed"
        case .development: return "leaf"
        }
    }
}

enum MilestoneSource: String, CaseIterable, Identifiable {
    case manual, bodyWeight, exerciseBest, workoutsThisMonth, mobilityThisMonth
    var id: String { rawValue }
    var title: String {
        switch self {
        case .manual: return "I'll update it myself"
        case .bodyWeight: return "Body weight (auto)"
        case .exerciseBest: return "Heaviest lift for an exercise (auto)"
        case .workoutsThisMonth: return "Workouts this month (auto)"
        case .mobilityThisMonth: return "Mobility sessions this month (auto)"
        }
    }
}

@Model
final class Milestone {
    var id: UUID = UUID()
    var title: String = ""
    var details: String = ""
    var categoryRaw: String = MilestoneCategory.physique.rawValue
    var unit: String = ""
    var startValue: Double = 0
    var targetValue: Double = 100
    var currentValue: Double = 0
    var targetDate: Date?
    var createdAt: Date = Date()
    var isCompleted: Bool = false
    var completedAt: Date?
    var sourceRaw: String = MilestoneSource.manual.rawValue
    var autoExercise: String = ""

    init(title: String) { self.title = title }

    var category: MilestoneCategory {
        get { MilestoneCategory(rawValue: categoryRaw) ?? .physique }
        set { categoryRaw = newValue.rawValue }
    }
    var source: MilestoneSource {
        get { MilestoneSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    /// 0…1 – works for goals that go up (80 → 100 kg) and down (95 → 80 kg).
    var progress: Double {
        if isCompleted { return 1 }
        let span = targetValue - startValue
        guard span != 0 else { return currentValue == targetValue ? 1 : 0 }
        return min(max((currentValue - startValue) / span, 0), 1)
    }
    var reachedTarget: Bool {
        targetValue >= startValue ? currentValue >= targetValue : currentValue <= targetValue
    }
}

@Model
final class MilestoneUpdate {
    var id: UUID = UUID()
    var milestoneID: UUID = UUID()
    var date: Date = Date()
    var value: Double = 0
    var note: String = ""
    init(milestoneID: UUID, value: Double, note: String = "", date: Date = Date()) {
        self.milestoneID = milestoneID
        self.value = value
        self.note = note
        self.date = date
    }
}

// MARK: - Bible

@Model
final class FavoriteVerse {
    var id: UUID = UUID()
    var reference: String = ""
    var savedAt: Date = Date()
    init(reference: String) { self.reference = reference }
}
