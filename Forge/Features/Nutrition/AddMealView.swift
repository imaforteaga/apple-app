import SwiftUI
import SwiftData

struct AddMealView: View {
    let date: Date
    @State var meal: MealType

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CustomFood.name) private var customFoods: [CustomFood]
    @Query(sort: \FavoriteMeal.createdAt, order: .reverse) private var favorites: [FavoriteMeal]

    enum Mode: String, CaseIterable, Identifiable {
        case search = "Search", manual = "Manual", favorites = "Favorites"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .search
    @State private var query = ""
    @State private var showCustomEditor = false

    // manual entry
    @State private var mName = ""
    @State private var mKcal: Double?
    @State private var mProtein: Double?
    @State private var mCarbs: Double?
    @State private var mFat: Double?
    @State private var mFiber: Double?

    init(date: Date, defaultMeal: MealType) {
        self.date = date
        self._meal = State(initialValue: defaultMeal)
    }

    private var loggingDate: Date {
        date.isToday ? Date() : (Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    ChipPicker(options: MealType.allCases, selection: $meal, label: { $0.title }, icon: { $0.icon })
                        .padding(.horizontal, -Theme.pad)
                    Picker("Mode", selection: $mode) {
                        ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal, Theme.pad)
                .padding(.vertical, 12)

                switch mode {
                case .search: searchList
                case .manual: manualForm
                case .favorites: favoritesList
                }
            }
            .screenBackground()
            .navigationTitle("Add food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showCustomEditor = true } label: { Label("New food", systemImage: "plus.circle") }
                }
            }
            .sheet(isPresented: $showCustomEditor) {
                CustomFoodEditor(food: nil)
            }
        }
    }

    // MARK: Search

    private var results: [FoodRef] {
        Array(FoodDatabase.search(query, custom: customFoods).prefix(80))
    }

    private var searchList: some View {
        List {
            Section {
                ForEach(results) { food in
                    NavigationLink {
                        FoodQuantityView(food: food, meal: meal, date: loggingDate) { dismiss() }
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(food.name).font(.subheadline.weight(.medium))
                                if food.isCustom {
                                    Text("Custom")
                                        .font(.system(size: 10, weight: .bold))
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Capsule().fill(Theme.softAccent))
                                        .foregroundStyle(Theme.accentText)
                                }
                            }
                            Text("\(food.kcal.whole) kcal · P \(food.protein.clean) · C \(food.carbs.clean) · F \(food.fat.clean)  per 100 g")
                                .font(.caption).foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .listRowBackground(Theme.card)
                }
            } footer: {
                Text("Reference values are approximate. Check labels, or create a custom food for exact numbers.")
            }
            if results.isEmpty {
                Section {
                    VStack(spacing: 10) {
                        Text("No foods match “\(query)”").foregroundStyle(Theme.textSecondary)
                        Button("Create custom food") { showCustomEditor = true }
                            .buttonStyle(SoftButtonStyle(compact: true))
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
            }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search foods")
        .warmForm()
    }

    // MARK: Manual

    private var manualForm: some View {
        Form {
            Section("Food") {
                TextField("Name (e.g. Lunch at work)", text: $mName)
            }
            Section("Nutrition for this entry") {
                NumberField("Calories", value: $mKcal, unit: "kcal")
                NumberField("Protein", value: $mProtein, unit: "g")
                NumberField("Carbohydrates", value: $mCarbs, unit: "g")
                NumberField("Fat", value: $mFat, unit: "g")
                NumberField("Fiber (optional)", value: $mFiber, unit: "g")
            }
            .listRowBackground(Theme.card)
            Section {
                Button("Add to \(meal.title)") { addManual() }
                    .buttonStyle(PrimaryButtonStyle())
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .disabled((mKcal ?? 0) <= 0 && (mProtein ?? 0) <= 0)
            }
        }
        .warmForm()
        .keyboardDoneToolbar()
    }

    private func addManual() {
        let name = mName.trimmed.isEmpty ? "Quick add" : mName.trimmed
        context.insert(FoodEntry(date: loggingDate, meal: meal, name: name, quantityLabel: "1 entry", grams: 0,
                                 kcal: mKcal ?? 0, protein: mProtein ?? 0, carbs: mCarbs ?? 0,
                                 fat: mFat ?? 0, fiber: mFiber ?? 0))
        context.saveQuietly()
        Haptics.success()
        dismiss()
    }

    // MARK: Favorites

    private var favoritesList: some View {
        List {
            if favorites.isEmpty {
                EmptyState(icon: "star", title: "No favorite meals yet",
                           message: "Log a meal with two or more foods, then tap “Save meal” to reuse it.")
                    .listRowBackground(Color.clear)
            }
            ForEach(favorites) { fav in
                Button {
                    for item in fav.items {
                        context.insert(FoodEntry(date: loggingDate, meal: meal, name: item.name,
                                                 quantityLabel: item.quantityLabel, grams: item.grams, kcal: item.kcal,
                                                 protein: item.protein, carbs: item.carbs, fat: item.fat, fiber: item.fiber))
                    }
                    context.saveQuietly()
                    Haptics.success()
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(fav.name).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text)
                        Text("\(fav.items.count) items · \(fav.totalKcal.whole) kcal · \(fav.totalProtein.whole) g protein")
                            .font(.caption).foregroundStyle(Theme.textSecondary)
                    }
                }
                .listRowBackground(Theme.card)
            }
            .onDelete { idx in
                for i in idx { context.delete(favorites[i]) }
                context.saveQuietly()
            }
        }
        .warmForm()
    }
}

// MARK: - Quantity

struct FoodQuantityView: View {
    let food: FoodRef
    let meal: MealType
    let date: Date
    var onDone: () -> Void

    @Environment(\.modelContext) private var context

    enum Unit: String, CaseIterable, Identifiable {
        case grams = "Grams", portions = "Portions"
        var id: String { rawValue }
    }

    @State private var unit: Unit = .grams
    @State private var amountText = ""
    @State private var targetMeal: MealType

    init(food: FoodRef, meal: MealType, date: Date, onDone: @escaping () -> Void) {
        self.food = food
        self.meal = meal
        self.date = date
        self.onDone = onDone
        self._targetMeal = State(initialValue: meal)
    }

    private var amount: Double { parseDouble(amountText) ?? 0 }
    private var grams: Double { unit == .grams ? amount : amount * food.servingGrams }
    private var m: (kcal: Double, protein: Double, carbs: Double, fat: Double, fiber: Double) {
        food.macros(forGrams: grams)
    }
    private var label: String {
        unit == .grams ? "\(amount.clean) g" : "\(amount.clean) × \(food.servingName) (\(grams.whole) g)"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(food.name).font(Theme.display(26)).foregroundStyle(Theme.text)

                Picker("Unit", selection: $unit) {
                    ForEach(Unit.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .onChange(of: unit) { _, new in
                    amountText = new == .grams ? food.servingGrams.clean : "1"
                }

                HStack {
                    TextField("0", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(Theme.number(40))
                        .frame(maxWidth: 160)
                    Text(unit == .grams ? "g" : food.servingName)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                }
                .card()

                if unit == .portions {
                    Text("1 portion = \(food.servingName) ≈ \(food.servingGrams.clean) g")
                        .font(.footnote).foregroundStyle(Theme.textSecondary)
                }

                VStack(spacing: 12) {
                    HStack {
                        stat("Calories", m.kcal.whole, "kcal")
                        stat("Protein", m.protein.oneDecimal, "g")
                    }
                    HStack {
                        stat("Carbs", m.carbs.oneDecimal, "g")
                        stat("Fat", m.fat.oneDecimal, "g")
                        stat("Fiber", m.fiber.oneDecimal, "g")
                    }
                }

                ChipPicker(options: MealType.allCases, selection: $targetMeal, label: { $0.title }, icon: { $0.icon })
                    .padding(.horizontal, -Theme.pad)

                Button("Add to \(targetMeal.title)") { add() }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(grams <= 0)
            }
            .padding(Theme.pad)
        }
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .keyboardDoneToolbar()
        .onAppear { if amountText.isEmpty { amountText = food.servingGrams.clean } }
    }

    private func stat(_ title: String, _ value: String, _ unit: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(Theme.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(Theme.number(22)).foregroundStyle(Theme.text)
                Text(unit).font(.caption).foregroundStyle(Theme.textSecondary)
            }
        }
        .card(padding: 12)
    }

    private func add() {
        let v = m
        context.insert(FoodEntry(date: date, meal: targetMeal, name: food.name, quantityLabel: label, grams: grams,
                                 kcal: v.kcal, protein: v.protein, carbs: v.carbs, fat: v.fat, fiber: v.fiber))
        context.saveQuietly()
        Haptics.success()
        onDone()
    }
}

// MARK: - Edit entry

struct EditFoodEntryView: View {
    @Bindable var entry: FoodEntry
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var kcal: Double?
    @State private var protein: Double?
    @State private var carbs: Double?
    @State private var fat: Double?
    @State private var fiber: Double?
    @State private var loaded = false
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") {
                    TextField("Name", text: $entry.name)
                    TextField("Quantity", text: $entry.quantityLabel)
                    Picker("Meal", selection: $entry.mealRaw) {
                        ForEach(MealType.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                }
                .listRowBackground(Theme.card)
                Section("Nutrition") {
                    NumberField("Calories", value: $kcal, unit: "kcal")
                    NumberField("Protein", value: $protein, unit: "g")
                    NumberField("Carbohydrates", value: $carbs, unit: "g")
                    NumberField("Fat", value: $fat, unit: "g")
                    NumberField("Fiber", value: $fiber, unit: "g")
                }
                .listRowBackground(Theme.card)
                Section("Scale portion") {
                    HStack(spacing: 10) {
                        ForEach([0.5, 1.5, 2.0], id: \.self) { f in
                            Button("×\(f.clean)") { scale(f) }
                                .buttonStyle(SoftButtonStyle(compact: true))
                        }
                    }
                    .listRowBackground(Color.clear)
                }
                Section {
                    Button("Delete entry", role: .destructive) { confirmDelete = true }
                }
                .listRowBackground(Theme.card)
            }
            .warmForm()
            .keyboardDoneToolbar()
            .navigationTitle("Edit entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { Button("Save") { save() }.fontWeight(.semibold) }
            }
            .confirmationDialog("Delete this entry?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    context.delete(entry)
                    context.saveQuietly()
                    dismiss()
                }
            }
            .onAppear {
                guard !loaded else { return }
                kcal = entry.kcal; protein = entry.protein; carbs = entry.carbs; fat = entry.fat; fiber = entry.fiber
                loaded = true
            }
        }
    }

    private func scale(_ f: Double) {
        kcal = (kcal ?? 0) * f
        protein = (protein ?? 0) * f
        carbs = (carbs ?? 0) * f
        fat = (fat ?? 0) * f
        fiber = (fiber ?? 0) * f
        entry.grams *= f
        Haptics.tap()
    }

    private func save() {
        entry.kcal = kcal ?? 0
        entry.protein = protein ?? 0
        entry.carbs = carbs ?? 0
        entry.fat = fat ?? 0
        entry.fiber = fiber ?? 0
        context.saveQuietly()
        dismiss()
    }
}
