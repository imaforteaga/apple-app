import Foundation
import SwiftData

enum MealType: String, CaseIterable, Identifiable, Codable {
    case breakfast, lunch, dinner, snack
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var icon: String {
        switch self {
        case .breakfast: return "sunrise"
        case .lunch: return "sun.max"
        case .dinner: return "moon.stars"
        case .snack: return "leaf"
        }
    }
    /// Sensible default meal for the current time of day.
    static var current: MealType {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 4..<11: return .breakfast
        case 11..<16: return .lunch
        case 16..<22: return .dinner
        default: return .snack
        }
    }
}

/// A user-created food (values per 100 g).
@Model
final class CustomFood {
    var id: UUID = UUID()
    var name: String = ""
    var brand: String = ""
    var kcalPer100: Double = 0
    var proteinPer100: Double = 0
    var carbsPer100: Double = 0
    var fatPer100: Double = 0
    var fiberPer100: Double = 0
    var servingName: String = "1 serving"
    var servingGrams: Double = 100
    var createdAt: Date = Date()
    init() {}
    var ref: FoodRef {
        FoodRef(id: id.uuidString, name: brand.isEmpty ? name : "\(name) · \(brand)",
                kcal: kcalPer100, protein: proteinPer100, carbs: carbsPer100,
                fat: fatPer100, fiber: fiberPer100,
                servingName: servingName, servingGrams: servingGrams, isCustom: true)
    }
}

/// A logged food item. Totals are stored so history never changes if a food is edited.
@Model
final class FoodEntry {
    var id: UUID = UUID()
    var date: Date = Date()
    var mealRaw: String = MealType.snack.rawValue
    var name: String = ""
    var quantityLabel: String = ""
    var grams: Double = 0
    var kcal: Double = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0
    var fiber: Double = 0
    init(date: Date, meal: MealType, name: String, quantityLabel: String, grams: Double,
         kcal: Double, protein: Double, carbs: Double, fat: Double, fiber: Double) {
        self.date = date
        self.mealRaw = meal.rawValue
        self.name = name
        self.quantityLabel = quantityLabel
        self.grams = grams
        self.kcal = kcal
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
    }
    var meal: MealType {
        get { MealType(rawValue: mealRaw) ?? .snack }
        set { mealRaw = newValue.rawValue }
    }
}

struct MealItem: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var quantityLabel: String
    var grams: Double
    var kcal: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double
}

/// A saved combination of foods that can be logged again with one tap.
@Model
final class FavoriteMeal {
    var id: UUID = UUID()
    var name: String = ""
    var mealRaw: String = MealType.lunch.rawValue
    var itemsData: Data = Data()
    var createdAt: Date = Date()
    init(name: String, meal: MealType, items: [MealItem]) {
        self.name = name
        self.mealRaw = meal.rawValue
        self.itemsData = (try? JSONEncoder().encode(items)) ?? Data()
    }
    var items: [MealItem] {
        get { (try? JSONDecoder().decode([MealItem].self, from: itemsData)) ?? [] }
        set { itemsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }
    var meal: MealType { MealType(rawValue: mealRaw) ?? .lunch }
    var totalKcal: Double { items.reduce(0) { $0 + $1.kcal } }
    var totalProtein: Double { items.reduce(0) { $0 + $1.protein } }
}

/// Lightweight value used for both the built-in reference list and custom foods.
struct FoodRef: Identifiable, Hashable {
    var id: String
    var name: String
    var kcal: Double      // per 100 g
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double
    var servingName: String
    var servingGrams: Double
    var isCustom: Bool = false

    func macros(forGrams g: Double) -> (kcal: Double, protein: Double, carbs: Double, fat: Double, fiber: Double) {
        let f = g / 100
        return (kcal * f, protein * f, carbs * f, fat * f, fiber * f)
    }
}

struct DayNutrition {
    var kcal: Double = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0
    var fiber: Double = 0
    var count: Int = 0

    init(entries: [FoodEntry] = []) {
        for e in entries {
            kcal += e.kcal; protein += e.protein; carbs += e.carbs; fat += e.fat; fiber += e.fiber
        }
        count = entries.count
    }
}
