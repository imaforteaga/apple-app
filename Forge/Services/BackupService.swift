import Foundation
import SwiftData

/// Exports everything the app stores (data as JSON + original photos) into one zip file.
enum BackupService {
    enum BackupError: LocalizedError {
        case zipFailed
        var errorDescription: String? { "The backup archive could not be created." }
    }

    private static let iso = ISO8601DateFormatter()

    private static func d(_ date: Date?) -> Any {
        guard let date else { return NSNull() }
        return iso.string(from: date)
    }
    private static func n(_ v: Double?) -> Any { v ?? NSNull() }
    private static func json(_ data: Data) -> Any {
        (try? JSONSerialization.jsonObject(with: data)) ?? NSNull()
    }

    @MainActor
    static func exportAll(from context: ModelContext) throws -> URL {
        let fm = FileManager.default
        let stamp: String = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd-HHmm"
            return f.string(from: Date())
        }()
        let folderName = "Forge-Backup-\(stamp)"
        let root = fm.temporaryDirectory.appendingPathComponent(folderName, isDirectory: true)
        try? fm.removeItem(at: root)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)

        var out: [String: Any] = [:]
        out["exportedAt"] = iso.string(from: Date())
        out["app"] = "Forge"
        out["format"] = 1

        let profiles = try context.fetch(FetchDescriptor<UserProfile>())
        out["profile"] = profiles.map { p -> [String: Any] in
            ["name": p.name, "age": p.age, "heightCm": p.heightCm, "startWeightKg": p.startWeightKg,
             "objective": p.objectiveRaw, "experience": p.experienceRaw, "weeklyTrainingDays": p.weeklyTrainingDays,
             "calorieTarget": p.calorieTarget, "proteinTarget": p.proteinTarget, "carbTarget": p.carbTarget,
             "fatTarget": p.fatTarget, "fiberTarget": p.fiberTarget, "waterTargetMl": p.waterTargetMl,
             "sleepTargetHours": p.sleepTargetHours, "createdAt": d(p.createdAt),
             "disabledScoreCategories": p.disabledScoreCategories]
        }

        out["weights"] = try context.fetch(FetchDescriptor<WeightEntry>()).map {
            ["date": d($0.date), "kg": $0.kg, "note": $0.note] as [String: Any]
        }
        out["measurements"] = try context.fetch(FetchDescriptor<BodyMeasurement>()).map {
            ["date": d($0.date), "chest": n($0.chest), "waist": n($0.waist), "arms": n($0.arms),
             "forearms": n($0.forearms), "thighs": n($0.thighs), "calves": n($0.calves),
             "neck": n($0.neck), "bodyFatPercent": n($0.bodyFat), "note": $0.note] as [String: Any]
        }
        let collections = try context.fetch(FetchDescriptor<PhotoCollection>())
        out["photoCollections"] = collections.map {
            ["id": $0.id.uuidString, "name": $0.name, "createdAt": d($0.createdAt)] as [String: Any]
        }
        let photos = try context.fetch(FetchDescriptor<ProgressPhoto>())
        out["photos"] = photos.map {
            ["date": d($0.date), "angle": $0.angleRaw, "note": $0.note, "file": "photos/\($0.fileName)",
             "collectionID": $0.collectionID?.uuidString ?? NSNull()] as [String: Any]
        }
        out["sleep"] = try context.fetch(FetchDescriptor<SleepEntry>()).map {
            ["day": d($0.day), "hours": $0.hours, "quality": $0.quality] as [String: Any]
        }
        out["water"] = try context.fetch(FetchDescriptor<WaterEntry>()).map {
            ["date": d($0.date), "ml": $0.ml] as [String: Any]
        }
        out["customFoods"] = try context.fetch(FetchDescriptor<CustomFood>()).map {
            ["name": $0.name, "brand": $0.brand, "kcalPer100g": $0.kcalPer100, "proteinPer100g": $0.proteinPer100,
             "carbsPer100g": $0.carbsPer100, "fatPer100g": $0.fatPer100, "fiberPer100g": $0.fiberPer100,
             "servingName": $0.servingName, "servingGrams": $0.servingGrams] as [String: Any]
        }
        out["foodEntries"] = try context.fetch(FetchDescriptor<FoodEntry>()).map {
            ["date": d($0.date), "meal": $0.mealRaw, "name": $0.name, "quantity": $0.quantityLabel,
             "grams": $0.grams, "kcal": $0.kcal, "protein": $0.protein, "carbs": $0.carbs,
             "fat": $0.fat, "fiber": $0.fiber] as [String: Any]
        }
        out["favoriteMeals"] = try context.fetch(FetchDescriptor<FavoriteMeal>()).map {
            ["name": $0.name, "meal": $0.mealRaw, "items": json($0.itemsData)] as [String: Any]
        }
        out["routines"] = try context.fetch(FetchDescriptor<Routine>()).map {
            ["name": $0.name, "type": $0.typeRaw, "weekday": $0.weekday, "notes": $0.notes,
             "exercises": json($0.exercisesData)] as [String: Any]
        }
        out["workouts"] = try context.fetch(FetchDescriptor<WorkoutSession>()).map {
            ["date": d($0.date), "end": d($0.endDate), "name": $0.name, "type": $0.typeRaw,
             "notes": $0.notes, "finished": $0.isFinished, "exercises": json($0.logData)] as [String: Any]
        }
        out["mobilityRoutines"] = try context.fetch(FetchDescriptor<MobilityRoutine>()).map {
            ["name": $0.name, "category": $0.categoryRaw, "steps": json($0.stepsData)] as [String: Any]
        }
        out["mobilitySessions"] = try context.fetch(FetchDescriptor<MobilitySession>()).map {
            ["date": d($0.date), "routine": $0.routineName, "category": $0.categoryRaw,
             "durationSeconds": $0.durationSeconds, "note": $0.note] as [String: Any]
        }
        let habits = try context.fetch(FetchDescriptor<Habit>())
        out["habits"] = habits.map {
            ["id": $0.id.uuidString, "name": $0.name, "active": $0.isActive,
             "countsForScore": $0.countsForScore, "autoKey": $0.autoKey] as [String: Any]
        }
        out["habitLogs"] = try context.fetch(FetchDescriptor<HabitLog>()).map {
            ["habitID": $0.habitID.uuidString, "day": d($0.day)] as [String: Any]
        }
        let supplements = try context.fetch(FetchDescriptor<Supplement>())
        out["supplements"] = supplements.map {
            ["id": $0.id.uuidString, "name": $0.name, "dosage": $0.dosage, "time": $0.timeRaw,
             "weekdayMask": $0.weekdayMask, "active": $0.isActive, "notes": $0.notes] as [String: Any]
        }
        out["supplementLogs"] = try context.fetch(FetchDescriptor<SupplementLog>()).map {
            ["supplementID": $0.supplementID.uuidString, "day": d($0.day), "takenAt": d($0.takenAt),
             "dosage": $0.dosage] as [String: Any]
        }
        out["journal"] = try context.fetch(FetchDescriptor<JournalEntry>()).map {
            ["date": d($0.date), "mood": $0.moodValue, "text": $0.text, "achievements": $0.achievements,
             "improvements": $0.improvements, "reflection": $0.reflection, "prompts": $0.prompts,
             "favorite": $0.isFavorite] as [String: Any]
        }
        out["milestones"] = try context.fetch(FetchDescriptor<Milestone>()).map {
            ["id": $0.id.uuidString, "title": $0.title, "details": $0.details, "category": $0.categoryRaw,
             "unit": $0.unit, "start": $0.startValue, "target": $0.targetValue, "current": $0.currentValue,
             "targetDate": d($0.targetDate), "completed": $0.isCompleted, "completedAt": d($0.completedAt),
             "createdAt": d($0.createdAt)] as [String: Any]
        }
        out["milestoneUpdates"] = try context.fetch(FetchDescriptor<MilestoneUpdate>()).map {
            ["milestoneID": $0.milestoneID.uuidString, "date": d($0.date), "value": $0.value,
             "note": $0.note] as [String: Any]
        }
        out["favoriteVerses"] = try context.fetch(FetchDescriptor<FavoriteVerse>()).map {
            ["reference": $0.reference, "savedAt": d($0.savedAt)] as [String: Any]
        }

        let data = try JSONSerialization.data(withJSONObject: out, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: root.appendingPathComponent("forge-data.json"))

        // Photos
        let photoDir = root.appendingPathComponent("photos", isDirectory: true)
        try fm.createDirectory(at: photoDir, withIntermediateDirectories: true)
        for p in photos where PhotoStore.exists(p.fileName) {
            try? fm.copyItem(at: PhotoStore.url(for: p.fileName), to: photoDir.appendingPathComponent(p.fileName))
        }

        let readme = """
        Forge backup – \(stamp)

        forge-data.json  – all measurements, meals, workouts, habits, journal entries, milestones and settings.
        photos/          – your original progress photos (JPEG). forge-data.json references them by file name.

        This archive was created on your device and has not been uploaded anywhere.
        Keep it somewhere private: it contains personal photos and journal entries.
        """
        try readme.write(to: root.appendingPathComponent("README.txt"), atomically: true, encoding: .utf8)

        return try zip(folder: root, name: folderName + ".zip")
    }

    private static func zip(folder: URL, name: String) throws -> URL {
        var coordinatorError: NSError?
        var result: URL?
        var copyError: Error?
        NSFileCoordinator().coordinate(readingItemAt: folder, options: [.forUploading], error: &coordinatorError) { zipURL in
            let dest = FileManager.default.temporaryDirectory.appendingPathComponent(name)
            do {
                try? FileManager.default.removeItem(at: dest)
                try FileManager.default.copyItem(at: zipURL, to: dest)
                result = dest
            } catch {
                copyError = error
            }
        }
        if let e = coordinatorError ?? copyError { throw e }
        guard let result else { throw BackupError.zipFailed }
        return result
    }
}
