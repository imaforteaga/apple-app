import Foundation
import SwiftData
import SwiftUI

// MARK: - Shared enums (stored as raw strings so SwiftData / CloudKit stay happy)

enum Objective: String, CaseIterable, Identifiable {
    case muscleGain, fatLoss, recomposition, strength, generalFitness
    var id: String { rawValue }
    var title: String {
        switch self {
        case .muscleGain: return "Muscle gain"
        case .fatLoss: return "Fat loss"
        case .recomposition: return "Body recomposition"
        case .strength: return "Strength"
        case .generalFitness: return "General fitness"
        }
    }
    var icon: String {
        switch self {
        case .muscleGain: return "figure.strengthtraining.traditional"
        case .fatLoss: return "flame"
        case .recomposition: return "arrow.triangle.2.circlepath"
        case .strength: return "dumbbell"
        case .generalFitness: return "figure.run"
        }
    }
    var blurb: String {
        switch self {
        case .muscleGain: return "Build size with a slight calorie surplus."
        case .fatLoss: return "Lose fat while keeping muscle."
        case .recomposition: return "Build muscle and lose fat at maintenance."
        case .strength: return "Get stronger on the big lifts."
        case .generalFitness: return "Feel capable, healthy and consistent."
        }
    }
}

enum Experience: String, CaseIterable, Identifiable {
    case beginner, intermediate, advanced
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var detail: String {
        switch self {
        case .beginner: return "Under 1 year"
        case .intermediate: return "1–3 years"
        case .advanced: return "3+ years"
        }
    }
}

enum NutritionGoal: String, CaseIterable, Identifiable {
    case gain, maintain, lose
    var id: String { rawValue }
    var title: String {
        switch self {
        case .gain: return "Gain muscle"
        case .maintain: return "Maintain"
        case .lose: return "Lose fat"
        }
    }
}

// MARK: - Profile

@Model
final class UserProfile {
    var id: UUID = UUID()
    var name: String = ""
    var age: Int = 25
    var heightCm: Double = 175
    var startWeightKg: Double = 70
    var objectiveRaw: String = Objective.muscleGain.rawValue
    var experienceRaw: String = Experience.beginner.rawValue
    var weeklyTrainingDays: Int = 4
    var calorieTarget: Int = 2500
    var proteinTarget: Int = 150
    var carbTarget: Int = 280
    var fatTarget: Int = 70
    var fiberTarget: Int = 30
    var waterTargetMl: Int = 3000
    var sleepTargetHours: Double = 8
    var createdAt: Date = Date()
    var hasOnboarded: Bool = false
    /// Comma separated `ScoreCategory` raw values that are switched OFF.
    var disabledScoreCategories: String = ""

    init() {}

    var objective: Objective {
        get { Objective(rawValue: objectiveRaw) ?? .generalFitness }
        set { objectiveRaw = newValue.rawValue }
    }
    var experience: Experience {
        get { Experience(rawValue: experienceRaw) ?? .beginner }
        set { experienceRaw = newValue.rawValue }
    }
    var firstName: String { name.split(separator: " ").first.map(String.init) ?? name }
}

// MARK: - Body

@Model
final class WeightEntry {
    var id: UUID = UUID()
    var date: Date = Date()
    var kg: Double = 0
    var note: String = ""
    init(date: Date = Date(), kg: Double, note: String = "") {
        self.date = date
        self.kg = kg
        self.note = note
    }
}

@Model
final class BodyMeasurement {
    var id: UUID = UUID()
    var date: Date = Date()
    var chest: Double?
    var waist: Double?
    var arms: Double?
    var forearms: Double?
    var thighs: Double?
    var calves: Double?
    var neck: Double?
    var bodyFat: Double?
    var note: String = ""
    init(date: Date = Date()) { self.date = date }
}

enum MeasurementSite: String, CaseIterable, Identifiable {
    case chest, waist, arms, forearms, thighs, calves, neck, bodyFat
    var id: String { rawValue }
    var title: String {
        switch self {
        case .chest: return "Chest"
        case .waist: return "Waist"
        case .arms: return "Arms"
        case .forearms: return "Forearms"
        case .thighs: return "Thighs"
        case .calves: return "Calves"
        case .neck: return "Neck"
        case .bodyFat: return "Body fat"
        }
    }
    var unit: String { self == .bodyFat ? "%" : "cm" }
    func value(in m: BodyMeasurement) -> Double? {
        switch self {
        case .chest: return m.chest
        case .waist: return m.waist
        case .arms: return m.arms
        case .forearms: return m.forearms
        case .thighs: return m.thighs
        case .calves: return m.calves
        case .neck: return m.neck
        case .bodyFat: return m.bodyFat
        }
    }
}

enum PhotoAngle: String, CaseIterable, Identifiable {
    case front, side, back
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var icon: String {
        switch self {
        case .front: return "person.fill"
        case .side: return "person.fill.turn.right"
        case .back: return "person.fill.turn.down"
        }
    }
}

@Model
final class ProgressPhoto {
    var id: UUID = UUID()
    var date: Date = Date()
    var angleRaw: String = PhotoAngle.front.rawValue
    var note: String = ""
    /// File name inside the app's private `ProgressPhotos` directory.
    var fileName: String = ""
    var collectionID: UUID?
    init(date: Date = Date(), angle: PhotoAngle, note: String = "", fileName: String, collectionID: UUID? = nil) {
        self.date = date
        self.angleRaw = angle.rawValue
        self.note = note
        self.fileName = fileName
        self.collectionID = collectionID
    }
    var angle: PhotoAngle {
        get { PhotoAngle(rawValue: angleRaw) ?? .front }
        set { angleRaw = newValue.rawValue }
    }
}

@Model
final class PhotoCollection {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()
    init(name: String) { self.name = name }
}

// MARK: - Sleep & water

@Model
final class SleepEntry {
    var id: UUID = UUID()
    var day: Date = Date().startOfDay
    var hours: Double = 0
    var quality: Int = 3
    init(day: Date, hours: Double, quality: Int = 3) {
        self.day = day.startOfDay
        self.hours = hours
        self.quality = quality
    }
}

@Model
final class WaterEntry {
    var id: UUID = UUID()
    var date: Date = Date()
    var ml: Int = 0
    init(date: Date = Date(), ml: Int) {
        self.date = date
        self.ml = ml
    }
}
