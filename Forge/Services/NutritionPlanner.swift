import Foundation

struct NutritionTargets {
    var calories: Int
    var protein: Int
    var carbs: Int
    var fat: Int
    var waterMl: Int
}

/// Rough starting-point estimates only – not medical advice. Everything is editable.
enum NutritionPlanner {
    /// Mifflin-St Jeor averaged across sexes (the app doesn't ask), scaled by training days.
    static func maintenanceCalories(weightKg: Double, heightCm: Double, age: Int, trainingDays: Int) -> Double {
        let bmr = 10 * weightKg + 6.25 * heightCm - 5 * Double(age) - 78
        let factor = 1.2 + 0.075 * Double(min(max(trainingDays, 0), 7))
        return bmr * factor
    }

    static func suggest(goal: NutritionGoal, weightKg: Double, heightCm: Double, age: Int, trainingDays: Int) -> NutritionTargets {
        let maintenance = maintenanceCalories(weightKg: weightKg, heightCm: heightCm, age: age, trainingDays: trainingDays)
        let adjust: Double
        switch goal {
        case .gain: adjust = 300
        case .maintain: adjust = 0
        case .lose: adjust = -450
        }
        let kcal = max(1200, round((maintenance + adjust) / 50) * 50)
        let protein = (weightKg * (goal == .lose ? 2.2 : 2.0)).rounded()
        let fat = max((weightKg * 0.9).rounded(), (kcal * 0.22 / 9).rounded())
        let carbs = max(0, ((kcal - protein * 4 - fat * 9) / 4).rounded())
        let water = max(1500, (weightKg * 35 / 250).rounded() * 250)
        return NutritionTargets(calories: Int(kcal), protein: Int(protein), carbs: Int(carbs), fat: Int(fat), waterMl: Int(water))
    }

    static func goal(for objective: Objective) -> NutritionGoal {
        switch objective {
        case .muscleGain, .strength: return .gain
        case .fatLoss: return .lose
        case .recomposition, .generalFitness: return .maintain
        }
    }
}
