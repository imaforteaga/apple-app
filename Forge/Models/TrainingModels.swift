import Foundation
import SwiftData

enum TrainingType: String, CaseIterable, Identifiable, Codable {
    case hypertrophy, strength, rugby, mma, wrestling, cardio, conditioning
    var id: String { rawValue }
    var title: String {
        switch self {
        case .mma: return "MMA"
        default: return rawValue.capitalized
        }
    }
    var icon: String {
        switch self {
        case .hypertrophy: return "figure.strengthtraining.traditional"
        case .strength: return "dumbbell.fill"
        case .rugby: return "figure.rugby"
        case .mma: return "figure.boxing"
        case .wrestling: return "figure.wrestling"
        case .cardio: return "heart.circle"
        case .conditioning: return "bolt.heart"
        }
    }
}

/// A planned exercise inside a routine.
struct RoutineExercise: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var sets: Int = 3
    var reps: Int = 10
    var restSeconds: Int = 90
    var notes: String = ""
    /// Timed exercises (cardio, conditioning, rounds) log minutes instead of reps × weight.
    var isTimed: Bool = false
}

@Model
final class Routine {
    var id: UUID = UUID()
    var name: String = ""
    var typeRaw: String = TrainingType.hypertrophy.rawValue
    /// 0 = flexible, otherwise Calendar weekday (1 = Sunday … 7 = Saturday)
    var weekday: Int = 0
    var notes: String = ""
    var exercisesData: Data = Data()
    var createdAt: Date = Date()
    var sortOrder: Int = 0

    init(name: String, type: TrainingType, weekday: Int = 0, exercises: [RoutineExercise] = []) {
        self.name = name
        self.typeRaw = type.rawValue
        self.weekday = weekday
        self.exercisesData = (try? JSONEncoder().encode(exercises)) ?? Data()
    }

    var type: TrainingType {
        get { TrainingType(rawValue: typeRaw) ?? .hypertrophy }
        set { typeRaw = newValue.rawValue }
    }
    var exercises: [RoutineExercise] {
        get { (try? JSONDecoder().decode([RoutineExercise].self, from: exercisesData)) ?? [] }
        set { exercisesData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }
}

struct LoggedSet: Codable, Identifiable, Hashable {
    var id = UUID()
    var reps: Int = 0
    var weightKg: Double = 0
    var durationMin: Double = 0
    var isWarmup: Bool = false
    var done: Bool = false
}

struct LoggedExercise: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var notes: String = ""
    var isTimed: Bool = false
    var restSeconds: Int = 90
    var sets: [LoggedSet] = []

    /// Working-set volume in kg (weight × reps, completed non-warm-up sets only).
    var volume: Double {
        sets.filter { $0.done && !$0.isWarmup }.reduce(0) { $0 + $1.weightKg * Double($1.reps) }
    }
    var completedSets: Int { sets.filter { $0.done }.count }
}

@Model
final class WorkoutSession {
    var id: UUID = UUID()
    var date: Date = Date()
    var endDate: Date?
    var routineID: UUID?
    var name: String = ""
    var typeRaw: String = TrainingType.hypertrophy.rawValue
    var notes: String = ""
    var isFinished: Bool = false
    var logData: Data = Data()

    init(name: String, type: TrainingType, routineID: UUID? = nil, exercises: [LoggedExercise] = []) {
        self.name = name
        self.typeRaw = type.rawValue
        self.routineID = routineID
        self.logData = (try? JSONEncoder().encode(exercises)) ?? Data()
    }

    var type: TrainingType {
        get { TrainingType(rawValue: typeRaw) ?? .hypertrophy }
        set { typeRaw = newValue.rawValue }
    }
    var exercises: [LoggedExercise] {
        get { (try? JSONDecoder().decode([LoggedExercise].self, from: logData)) ?? [] }
        set { logData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }
    var durationSeconds: Int {
        guard let endDate else { return Int(Date().timeIntervalSince(date)) }
        return max(0, Int(endDate.timeIntervalSince(date)))
    }
    var totalVolume: Double { exercises.reduce(0) { $0 + $1.volume } }
    var totalSets: Int { exercises.reduce(0) { $0 + $1.completedSets } }
}

// MARK: - Exercise analytics

struct ExercisePoint: Identifiable {
    var id = UUID()
    var date: Date
    var bestWeight: Double
    var bestE1RM: Double
    var volume: Double
}

struct ExerciseRecords {
    var heaviest: Double = 0
    var best1RM: Double = 0
    var bestSetVolume: Double = 0
    var totalVolume: Double = 0
}

enum ExerciseAnalytics {
    static func normalized(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespaces).lowercased()
    }

    /// Epley estimate. Returns the weight itself for a single.
    static func e1RM(weight: Double, reps: Int) -> Double {
        guard weight > 0, reps > 0 else { return 0 }
        if reps == 1 { return weight }
        return weight * (1 + Double(reps) / 30.0)
    }

    static func exerciseNames(in sessions: [WorkoutSession]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for s in sessions {
            for e in s.exercises where !e.isTimed {
                let k = normalized(e.name)
                if !k.isEmpty, !seen.contains(k) {
                    seen.insert(k)
                    out.append(e.name)
                }
            }
        }
        return out.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    static func history(for name: String, in sessions: [WorkoutSession]) -> [ExercisePoint] {
        let key = normalized(name)
        var points: [ExercisePoint] = []
        for s in sessions.sorted(by: { $0.date < $1.date }) where s.isFinished {
            let matches = s.exercises.filter { normalized($0.name) == key }
            guard !matches.isEmpty else { continue }
            var bestW = 0.0, bestE = 0.0, vol = 0.0
            for ex in matches {
                for set in ex.sets where set.done && !set.isWarmup {
                    bestW = max(bestW, set.weightKg)
                    bestE = max(bestE, e1RM(weight: set.weightKg, reps: set.reps))
                    vol += set.weightKg * Double(set.reps)
                }
            }
            if bestW > 0 || vol > 0 {
                points.append(ExercisePoint(date: s.date, bestWeight: bestW, bestE1RM: bestE, volume: vol))
            }
        }
        return points
    }

    static func records(for name: String, in sessions: [WorkoutSession]) -> ExerciseRecords {
        var r = ExerciseRecords()
        let key = normalized(name)
        for s in sessions where s.isFinished {
            for ex in s.exercises where normalized(ex.name) == key {
                for set in ex.sets where set.done && !set.isWarmup {
                    r.heaviest = max(r.heaviest, set.weightKg)
                    r.best1RM = max(r.best1RM, e1RM(weight: set.weightKg, reps: set.reps))
                    r.bestSetVolume = max(r.bestSetVolume, set.weightKg * Double(set.reps))
                    r.totalVolume += set.weightKg * Double(set.reps)
                }
            }
        }
        return r
    }

    /// Previous performance for an exercise (used to pre-fill and to show "last time").
    static func lastPerformance(of name: String, in sessions: [WorkoutSession], excluding id: UUID? = nil) -> LoggedExercise? {
        let key = normalized(name)
        for s in sessions.sorted(by: { $0.date > $1.date }) where s.isFinished && s.id != id {
            if let ex = s.exercises.first(where: { normalized($0.name) == key && $0.sets.contains(where: { $0.done }) }) {
                return ex
            }
        }
        return nil
    }
}

// MARK: - Mobility

enum MobilityCategory: String, CaseIterable, Identifiable, Codable {
    case morning, evening, neck, shoulder, hip, hamstring, back, recovery, custom
    var id: String { rawValue }
    var title: String {
        switch self {
        case .morning: return "Morning mobility"
        case .evening: return "Evening mobility"
        case .neck: return "Neck"
        case .shoulder: return "Shoulders"
        case .hip: return "Hips"
        case .hamstring: return "Hamstrings"
        case .back: return "Back"
        case .recovery: return "Recovery"
        case .custom: return "Custom"
        }
    }
    var icon: String {
        switch self {
        case .morning: return "sunrise"
        case .evening: return "moon"
        case .neck: return "person.bust"
        case .shoulder: return "figure.arms.open"
        case .hip: return "figure.flexibility"
        case .hamstring: return "figure.cooldown"
        case .back: return "figure.mind.and.body"
        case .recovery: return "bed.double"
        case .custom: return "star"
        }
    }
}

struct MobilityStep: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var seconds: Int = 45
    var detail: String = ""
}

@Model
final class MobilityRoutine {
    var id: UUID = UUID()
    var name: String = ""
    var categoryRaw: String = MobilityCategory.custom.rawValue
    var stepsData: Data = Data()
    var createdAt: Date = Date()

    init(name: String, category: MobilityCategory, steps: [MobilityStep]) {
        self.name = name
        self.categoryRaw = category.rawValue
        self.stepsData = (try? JSONEncoder().encode(steps)) ?? Data()
    }

    var category: MobilityCategory {
        get { MobilityCategory(rawValue: categoryRaw) ?? .custom }
        set { categoryRaw = newValue.rawValue }
    }
    var steps: [MobilityStep] {
        get { (try? JSONDecoder().decode([MobilityStep].self, from: stepsData)) ?? [] }
        set { stepsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }
}

@Model
final class MobilitySession {
    var id: UUID = UUID()
    var date: Date = Date()
    var routineName: String = ""
    var categoryRaw: String = MobilityCategory.custom.rawValue
    var durationSeconds: Int = 0
    var note: String = ""
    init(date: Date = Date(), routineName: String, category: MobilityCategory, durationSeconds: Int) {
        self.date = date
        self.routineName = routineName
        self.categoryRaw = category.rawValue
        self.durationSeconds = durationSeconds
    }
    var category: MobilityCategory { MobilityCategory(rawValue: categoryRaw) ?? .custom }
}

/// Uniform description of a routine (built-in template or user routine).
struct MobilityRoutineInfo: Identifiable, Hashable {
    var id: String
    var name: String
    var category: MobilityCategory
    var steps: [MobilityStep]
    var isBuiltIn: Bool
    var totalSeconds: Int { steps.reduce(0) { $0 + $1.seconds } }
}
