import Foundation
import SwiftData

// MARK: - Reference food list
// Approximate values per 100 g (typical USDA-style figures). Brands and cooking vary,
// so check labels and create a custom food for anything you eat often.

enum FoodDatabase {
    private static func f(_ name: String, _ kcal: Double, _ p: Double, _ c: Double, _ fat: Double, _ fiber: Double,
                          serving: String, grams: Double) -> FoodRef {
        FoodRef(id: "builtin-" + name.lowercased().replacingOccurrences(of: " ", with: "-"),
                name: name, kcal: kcal, protein: p, carbs: c, fat: fat, fiber: fiber,
                servingName: serving, servingGrams: grams)
    }

    static let all: [FoodRef] = [
        // Protein
        f("Chicken breast, cooked", 165, 31, 0, 3.6, 0, serving: "1 breast", grams: 170),
        f("Chicken thigh, cooked, skinless", 209, 26, 0, 10.9, 0, serving: "1 thigh", grams: 110),
        f("Ground beef 90% lean, cooked", 217, 26, 0, 11.7, 0, serving: "1 patty", grams: 113),
        f("Beef steak, lean, cooked", 217, 29, 0, 10, 0, serving: "1 steak", grams: 200),
        f("Pork loin, cooked", 197, 27, 0, 9, 0, serving: "1 portion", grams: 120),
        f("Turkey breast, cooked", 135, 30, 0, 1, 0, serving: "1 portion", grams: 120),
        f("Ham, sliced", 145, 21, 1.5, 5.5, 0, serving: "2 slices", grams: 56),
        f("Bacon, cooked", 541, 37, 1.4, 42, 0, serving: "1 slice", grams: 8),
        f("Salmon, cooked", 206, 22, 0, 12, 0, serving: "1 fillet", grams: 150),
        f("Tuna, canned in water", 116, 26, 0, 0.8, 0, serving: "1 can", grams: 120),
        f("Cod, cooked", 105, 23, 0, 0.9, 0, serving: "1 fillet", grams: 150),
        f("Shrimp, cooked", 99, 24, 0.2, 0.3, 0, serving: "10 shrimp", grams: 85),
        f("Egg, whole", 143, 12.6, 0.7, 9.5, 0, serving: "1 large egg", grams: 50),
        f("Egg white", 52, 11, 0.7, 0.2, 0, serving: "1 egg white", grams: 33),
        f("Tofu, firm", 144, 17, 3, 9, 2, serving: "1/2 block", grams: 125),
        f("Beef jerky", 410, 33, 11, 26, 1.8, serving: "1 serving", grams: 28),
        // Dairy
        f("Greek yogurt, plain nonfat", 59, 10, 3.6, 0.4, 0, serving: "1 pot", grams: 170),
        f("Greek yogurt, plain whole", 97, 9, 4, 5, 0, serving: "1 pot", grams: 170),
        f("Milk, whole", 61, 3.2, 4.8, 3.3, 0, serving: "1 glass (250 ml)", grams: 258),
        f("Milk, skim", 34, 3.4, 5, 0.1, 0, serving: "1 glass (250 ml)", grams: 258),
        f("Cottage cheese, low fat", 72, 12, 2.7, 1, 0, serving: "1/2 cup", grams: 113),
        f("Cheddar cheese", 403, 25, 1.3, 33, 0, serving: "1 slice", grams: 28),
        f("Cream cheese", 342, 6, 4, 34, 0, serving: "1 tbsp", grams: 15),
        f("Whey protein powder (typical)", 400, 80, 8, 6, 0, serving: "1 scoop", grams: 30),
        // Carbs
        f("White rice, cooked", 130, 2.7, 28, 0.3, 0.4, serving: "1 cup", grams: 158),
        f("Brown rice, cooked", 123, 2.7, 25.6, 1, 1.6, serving: "1 cup", grams: 195),
        f("Pasta, cooked", 158, 5.8, 30.9, 0.9, 1.8, serving: "1 cup", grams: 140),
        f("Quinoa, cooked", 120, 4.4, 21.3, 1.9, 2.8, serving: "1 cup", grams: 185),
        f("Oats, dry", 389, 16.9, 66.3, 6.9, 10.6, serving: "1/2 cup", grams: 40),
        f("Bread, white", 265, 9, 49, 3.2, 2.7, serving: "1 slice", grams: 30),
        f("Bread, whole wheat", 247, 13, 41, 3.4, 7, serving: "1 slice", grams: 35),
        f("Wheat tortilla", 312, 8.2, 51, 8, 3, serving: "1 tortilla", grams: 45),
        f("Granola", 471, 10, 64, 20, 7, serving: "1 serving", grams: 45),
        f("Rice cake", 387, 8, 81, 2.8, 4, serving: "1 cake", grams: 9),
        f("Potato, boiled", 87, 1.9, 20, 0.1, 1.8, serving: "1 medium", grams: 170),
        f("Sweet potato, baked", 90, 2, 21, 0.2, 3.3, serving: "1 medium", grams: 130),
        f("Pizza, cheese", 266, 11, 33, 10, 2.3, serving: "1 slice", grams: 107),
        // Fruit & veg
        f("Banana", 89, 1.1, 22.8, 0.3, 2.6, serving: "1 medium", grams: 118),
        f("Apple", 52, 0.3, 13.8, 0.2, 2.4, serving: "1 medium", grams: 182),
        f("Orange", 47, 0.9, 11.8, 0.1, 2.4, serving: "1 medium", grams: 131),
        f("Blueberries", 57, 0.7, 14.5, 0.3, 2.4, serving: "1 cup", grams: 148),
        f("Strawberries", 32, 0.7, 7.7, 0.3, 2, serving: "1 cup", grams: 152),
        f("Avocado", 160, 2, 8.5, 14.7, 6.7, serving: "1/2 avocado", grams: 100),
        f("Broccoli, cooked", 35, 2.4, 7.2, 0.4, 3.3, serving: "1 cup", grams: 156),
        f("Spinach, raw", 23, 2.9, 3.6, 0.4, 2.2, serving: "1 cup", grams: 30),
        f("Carrot, raw", 41, 0.9, 9.6, 0.2, 2.8, serving: "1 medium", grams: 61),
        f("Tomato", 18, 0.9, 3.9, 0.2, 1.2, serving: "1 medium", grams: 123),
        f("Cucumber", 15, 0.7, 3.6, 0.1, 0.5, serving: "1/2 cucumber", grams: 150),
        // Legumes, nuts, fats
        f("Lentils, cooked", 116, 9, 20, 0.4, 7.9, serving: "1 cup", grams: 198),
        f("Black beans, cooked", 132, 8.9, 23.7, 0.5, 8.7, serving: "1 cup", grams: 172),
        f("Chickpeas, cooked", 164, 8.9, 27.4, 2.6, 7.6, serving: "1 cup", grams: 164),
        f("Hummus", 166, 7.9, 14.3, 9.6, 6, serving: "2 tbsp", grams: 30),
        f("Almonds", 579, 21.2, 21.6, 49.9, 12.5, serving: "1 handful", grams: 28),
        f("Walnuts", 654, 15, 14, 65, 6.7, serving: "1 handful", grams: 28),
        f("Peanut butter", 588, 25, 20, 50, 6, serving: "2 tbsp", grams: 32),
        f("Olive oil", 884, 0, 0, 100, 0, serving: "1 tbsp", grams: 13.5),
        f("Butter", 717, 0.9, 0.1, 81, 0, serving: "1 tbsp", grams: 14),
        // Sweet & drinks
        f("Honey", 304, 0.3, 82.4, 0, 0.2, serving: "1 tbsp", grams: 21),
        f("Dulce de leche", 320, 6, 56, 7.5, 0, serving: "1 tbsp", grams: 20),
        f("Dark chocolate 70%", 598, 7.8, 46, 43, 11, serving: "3 squares", grams: 30),
        f("Orange juice", 45, 0.7, 10.4, 0.2, 0.2, serving: "1 glass (250 ml)", grams: 248),
        f("Cola", 42, 0, 10.6, 0, 0, serving: "1 can (330 ml)", grams: 330),
        f("Beer", 43, 0.5, 3.6, 0, 0, serving: "1 bottle (355 ml)", grams: 355),
        f("Coffee, black", 1, 0.1, 0, 0, 0, serving: "1 cup", grams: 240)
    ]

    static func search(_ query: String, custom: [CustomFood]) -> [FoodRef] {
        let q = query.trimmed.lowercased()
        let pool = custom.map { $0.ref } + all
        guard !q.isEmpty else { return pool }
        let terms = q.split(separator: " ").map(String.init)
        return pool.filter { food in
            let n = food.name.lowercased()
            return terms.allSatisfy { n.contains($0) }
        }
    }
}

// MARK: - Default habits

enum DefaultHabits {
    static let list: [(name: String, icon: String, key: String)] = [
        ("Drink enough water", "drop.fill", "water"),
        ("Take creatine", "pills.fill", "creatine"),
        ("Take supplements", "cross.vial.fill", "supplements"),
        ("Complete training", "dumbbell.fill", "training"),
        ("Stretch", "figure.flexibility", "stretch"),
        ("Sleep enough", "moon.zzz.fill", "sleep"),
        ("Eat enough protein", "fork.knife", "protein"),
        ("Read the Bible", "book.closed.fill", "bible")
    ]

    static func autoDescription(_ key: String) -> String? {
        switch key {
        case "water": return "Completes automatically when you reach 90% of your water target."
        case "training": return "Completes automatically when you finish a workout."
        case "stretch": return "Completes automatically when you log a mobility session."
        case "protein": return "Completes automatically at 90% of your protein target."
        case "sleep": return "Completes automatically when you log enough sleep."
        case "supplements": return "Completes automatically when all of today's supplements are logged."
        case "creatine": return "Completes automatically when a creatine supplement is logged. You can also tick it manually."
        case "bible": return "Tick manually, or tap “Mark as read” in the Bible section."
        default: return nil
        }
    }
}

// MARK: - Mobility library (built-in templates)

enum MobilityLibrary {
    private static func step(_ name: String, _ seconds: Int, _ detail: String) -> MobilityStep {
        MobilityStep(name: name, seconds: seconds, detail: detail)
    }

    static let builtIn: [MobilityRoutineInfo] = [
        MobilityRoutineInfo(id: "b-morning", name: "Morning Mobility", category: .morning, steps: [
            step("Cat–cow", 60, "On hands and knees, slowly round and arch your spine with your breath."),
            step("Open book rotations", 60, "Side-lying, rotate your top arm open and follow it with your eyes. 30 s per side."),
            step("World's greatest stretch", 90, "Deep lunge, elbow to instep, then rotate up. 45 s per side."),
            step("Deep squat hold", 45, "Heels down, chest tall, press knees out with your elbows."),
            step("90/90 hip switches", 60, "Sit with both knees at 90° and rotate them side to side."),
            step("Arm circles & shoulder rolls", 45, "Slow, big circles forwards then backwards."),
            step("Standing forward fold", 45, "Soft knees, let your head hang and breathe.")
        ], isBuiltIn: true),
        MobilityRoutineInfo(id: "b-evening", name: "Evening Wind-down", category: .evening, steps: [
            step("Child's pose", 60, "Sit back on your heels, arms long, breathe into your lower back."),
            step("Supine spinal twist", 60, "Knees to one side, shoulders flat. 30 s per side."),
            step("Figure-four glute stretch", 90, "On your back, ankle over opposite knee, pull gently. 45 s per side."),
            step("Kneeling hip flexor stretch", 90, "Tuck the pelvis, lean forward slightly. 45 s per side."),
            step("Supine hamstring stretch", 90, "Strap or towel round the foot, keep the leg long. 45 s per side."),
            step("Legs up the wall", 120, "Lie back with legs vertical, slow nasal breathing.")
        ], isBuiltIn: true),
        MobilityRoutineInfo(id: "b-neck", name: "Neck Care", category: .neck, steps: [
            step("Chin tucks", 45, "Draw the chin straight back, long back of neck. Slow reps."),
            step("Side neck tilts", 60, "Ear toward shoulder, relaxed shoulders. 30 s per side."),
            step("Neck rotations", 45, "Turn slowly to look over each shoulder."),
            step("Isometric neck holds", 60, "Press a hand against the head in four directions, 5–10 s each, light effort."),
            step("Upper trap stretch", 60, "Sit on one hand, tilt away gently. 30 s per side.")
        ], isBuiltIn: true),
        MobilityRoutineInfo(id: "b-shoulder", name: "Shoulder Mobility", category: .shoulder, steps: [
            step("Shoulder CARs", 60, "Slow, controlled full-range arm circles. 30 s per side."),
            step("Wall slides", 60, "Forearms on the wall, slide up while keeping ribs down."),
            step("Doorway pec stretch", 60, "Forearm on the frame, step through gently. 30 s per side."),
            step("Cross-body shoulder stretch", 60, "Pull the arm across the chest. 30 s per side."),
            step("Thread the needle", 60, "On all fours, slide one arm under the other. 30 s per side.")
        ], isBuiltIn: true),
        MobilityRoutineInfo(id: "b-hip", name: "Hip Opener", category: .hip, steps: [
            step("90/90 hip switches", 90, "Rotate both knees side to side, keeping tall."),
            step("Couch stretch", 120, "Back foot up on a wall or bench, squeeze the glute. 60 s per side."),
            step("Pigeon pose", 120, "Front shin across, fold forward. 60 s per side."),
            step("Frog stretch", 90, "Knees wide, rock back gently, breathe."),
            step("Deep squat prying", 60, "Use your elbows to gently open the knees.")
        ], isBuiltIn: true),
        MobilityRoutineInfo(id: "b-hamstring", name: "Hamstring Flexibility", category: .hamstring, steps: [
            step("Supine strap stretch", 120, "Keep the opposite leg flat and the stretched knee soft. 60 s per side."),
            step("Seated forward fold", 90, "Hinge from the hips and keep the spine long."),
            step("Standing pyramid stretch", 90, "Front leg straight, hinge over it. 45 s per side."),
            step("Active leg raises", 60, "Lying down, raise a straight leg slowly. 30 s per side.")
        ], isBuiltIn: true),
        MobilityRoutineInfo(id: "b-back", name: "Back Mobility", category: .back, steps: [
            step("Cat–cow", 60, "Smooth spinal waves with the breath."),
            step("Bird-dog", 60, "Opposite arm and leg, hold still. 30 s per side."),
            step("Knee rocks (lumbar rotation)", 60, "On your back, drop both knees side to side."),
            step("Child's pose with side reach", 60, "Walk the hands to each side and breathe into the flank."),
            step("Glute bridge hold", 45, "Squeeze the glutes, ribs down.")
        ], isBuiltIn: true),
        MobilityRoutineInfo(id: "b-recovery", name: "Recovery Session", category: .recovery, steps: [
            step("Easy walk or bike", 300, "Very easy pace, nasal breathing."),
            step("Foam roll quads", 90, "Slow passes, pause on tender spots. 45 s per side."),
            step("Foam roll upper back", 90, "Arms crossed, roll between shoulder blades."),
            step("Foam roll hamstrings", 90, "Slow passes. 45 s per side."),
            step("Box breathing", 120, "Inhale 4, hold 4, exhale 4, hold 4."),
            step("Legs up the wall", 180, "Relax and let the legs drain.")
        ], isBuiltIn: true)
    ]
}

// MARK: - Routine templates (user can add and then freely edit)

struct RoutineTemplate: Identifiable {
    var id: String { name }
    let name: String
    let type: TrainingType
    let exercises: [RoutineExercise]
}

enum RoutineTemplates {
    private static func ex(_ name: String, _ sets: Int, _ reps: Int, rest: Int = 90, timed: Bool = false) -> RoutineExercise {
        RoutineExercise(name: name, sets: sets, reps: reps, restSeconds: rest, isTimed: timed)
    }

    static let all: [RoutineTemplate] = [
        RoutineTemplate(name: "Push Day", type: .hypertrophy, exercises: [
            ex("Bench Press", 4, 8, rest: 120), ex("Overhead Press", 3, 10), ex("Incline Dumbbell Press", 3, 10),
            ex("Lateral Raise", 3, 15, rest: 60), ex("Triceps Pushdown", 3, 12, rest: 60)]),
        RoutineTemplate(name: "Pull Day", type: .hypertrophy, exercises: [
            ex("Pull-Up", 4, 8, rest: 120), ex("Barbell Row", 4, 8, rest: 120), ex("Seated Cable Row", 3, 10),
            ex("Face Pull", 3, 15, rest: 60), ex("Biceps Curl", 3, 12, rest: 60)]),
        RoutineTemplate(name: "Leg Day", type: .hypertrophy, exercises: [
            ex("Back Squat", 4, 8, rest: 150), ex("Romanian Deadlift", 3, 10, rest: 120), ex("Leg Press", 3, 12),
            ex("Leg Curl", 3, 12, rest: 60), ex("Standing Calf Raise", 4, 15, rest: 60)]),
        RoutineTemplate(name: "Upper Strength", type: .strength, exercises: [
            ex("Bench Press", 5, 5, rest: 180), ex("Barbell Row", 5, 5, rest: 150),
            ex("Overhead Press", 3, 5, rest: 150), ex("Pull-Up", 3, 6, rest: 120)]),
        RoutineTemplate(name: "Lower Strength", type: .strength, exercises: [
            ex("Back Squat", 5, 5, rest: 180), ex("Deadlift", 3, 5, rest: 180), ex("Walking Lunge", 3, 10, rest: 90)]),
        RoutineTemplate(name: "Rugby Power", type: .rugby, exercises: [
            ex("Power Clean", 5, 3, rest: 150), ex("Back Squat", 4, 5, rest: 150), ex("Bench Press", 4, 6, rest: 120),
            ex("Weighted Pull-Up", 4, 6, rest: 120), ex("Sled Push", 5, 1, rest: 90, timed: true)]),
        RoutineTemplate(name: "MMA Conditioning", type: .mma, exercises: [
            ex("Shadow boxing rounds", 3, 3, rest: 60, timed: true), ex("Heavy bag rounds", 5, 3, rest: 60, timed: true),
            ex("Sprawls & burpees", 4, 1, rest: 60, timed: true)]),
        RoutineTemplate(name: "Wrestling Conditioning", type: .wrestling, exercises: [
            ex("Live drilling rounds", 6, 3, rest: 60, timed: true), ex("Bear crawls", 4, 1, rest: 45, timed: true),
            ex("Farmer's Carry", 4, 1, rest: 60, timed: true)]),
        RoutineTemplate(name: "Easy Cardio", type: .cardio, exercises: [
            ex("Easy run or bike", 1, 30, rest: 0, timed: true)]),
        RoutineTemplate(name: "Interval Conditioning", type: .conditioning, exercises: [
            ex("Sprint intervals", 8, 1, rest: 60, timed: true), ex("Kettlebell swings", 4, 1, rest: 60, timed: true)])
    ]
}

// MARK: - First-launch seeding

enum Seeder {
    /// Creates the default habits once. Never invents any user data (weights, meals, photos…).
    static func seedHabitsIfNeeded(_ context: ModelContext) {
        let existing = (try? context.fetchCount(FetchDescriptor<Habit>())) ?? 0
        guard existing == 0 else { return }
        for (i, h) in DefaultHabits.list.enumerated() {
            context.insert(Habit(name: h.name, icon: h.icon, autoKey: h.key, sortOrder: i))
        }
        try? context.save()
    }
}
