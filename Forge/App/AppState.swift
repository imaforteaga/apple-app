import SwiftUI
import SwiftData

enum AppTab: Int, CaseIterable, Identifiable {
    case home, nutrition, training, progress, profile
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .home: return "Home"
        case .nutrition: return "Nutrition"
        case .training: return "Training"
        case .progress: return "Progress"
        case .profile: return "Profile"
        }
    }
    var icon: String {
        switch self {
        case .home: return "house"
        case .nutrition: return "fork.knife"
        case .training: return "dumbbell"
        case .progress: return "chart.line.uptrend.xyaxis"
        case .profile: return "person"
        }
    }
}

struct AchievementInfo: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
}

/// Cross-feature UI state: tab selection and milestone celebrations.
@MainActor
final class AppState: ObservableObject {
    @Published var tab: AppTab = .home
    @Published var achievement: AchievementInfo?
    /// Set to start a workout from anywhere (e.g. the Home quick action).
    @Published var startWorkoutRequest = false
}

enum AppConfig {
    /// Set to `true` after adding the iCloud capability (CloudKit) in Xcode – see README.
    /// Requires a paid Apple Developer account; leave `false` for local-only storage.
    static let enableCloudKitSync = false
}

// MARK: - Milestone auto-sync

enum MilestoneSync {
    /// Refreshes auto-linked milestones from stored data. Returns milestones that were just completed.
    @MainActor
    @discardableResult
    static func sync(_ context: ModelContext) -> [Milestone] {
        guard let milestones = try? context.fetch(FetchDescriptor<Milestone>()) else { return [] }
        let active = milestones.filter { !$0.isCompleted && $0.source != .manual }
        guard !active.isEmpty else { return [] }

        let weights = (try? context.fetch(FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? []
        let sessions = (try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []
        let mobility = (try? context.fetch(FetchDescriptor<MobilitySession>())) ?? []
        let monthStart = Date().startOfMonth

        var completed: [Milestone] = []
        for m in active {
            var newValue: Double?
            switch m.source {
            case .manual: break
            case .bodyWeight: newValue = weights.first?.kg
            case .exerciseBest:
                let best = ExerciseAnalytics.records(for: m.autoExercise, in: sessions).heaviest
                newValue = best > 0 ? best : nil
            case .workoutsThisMonth:
                newValue = Double(sessions.filter { $0.isFinished && $0.date >= monthStart }.count)
            case .mobilityThisMonth:
                newValue = Double(mobility.filter { $0.date >= monthStart }.count)
            }
            guard let v = newValue else { continue }
            if abs(v - m.currentValue) > 0.001 {
                m.currentValue = v
                context.insert(MilestoneUpdate(milestoneID: m.id, value: v))
            }
            if m.reachedTarget && m.currentValue != m.startValue {
                m.isCompleted = true
                m.completedAt = Date()
                completed.append(m)
            }
        }
        try? context.save()
        return completed
    }
}

// MARK: - Common data operations

extension ModelContext {
    func saveQuietly() {
        do { try save() } catch { print("Save failed: \(error)") }
    }

    func addWater(_ ml: Int, on date: Date = Date()) {
        insert(WaterEntry(date: date, ml: ml))
        saveQuietly()
    }

    func toggleHabit(_ habit: Habit, on day: Date, logs: [HabitLog]) {
        let d = day.startOfDay
        let matches = logs.filter { $0.habitID == habit.id && $0.day.startOfDay == d }
        if matches.isEmpty {
            insert(HabitLog(habitID: habit.id, day: d))
        } else {
            matches.forEach { delete($0) }
        }
        saveQuietly()
    }

    func deletePhoto(_ photo: ProgressPhoto) {
        PhotoStore.delete(fileName: photo.fileName)
        delete(photo)
        saveQuietly()
    }
}
