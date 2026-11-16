import SwiftUI
import SwiftData

// MARK: - Custom foods

struct CustomFoodEditor: View {
    let food: CustomFood?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var brand = ""
    @State private var servingName = "1 serving"
    @State private var servingGrams: Double? = 100
    @State private var kcal: Double?
    @State private var protein: Double?
    @State private var carbs: Double?
    @State private var fat: Double?
    @State private var fiber: Double?
    @State private var loaded = false

    private var canSave: Bool { !name.trimmed.isEmpty && (kcal ?? 0) >= 0 && kcal != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") {
                    TextField("Name", text: $name)
                    TextField("Brand (optional)", text: $brand)
                }.listRowBackground(Theme.card)
                Section("Typical portion") {
                    TextField("Portion name (e.g. 1 scoop)", text: $servingName)
                    NumberField("Portion weight", value: $servingGrams, unit: "g")
                }.listRowBackground(Theme.card)
                Section {
                    NumberField("Calories", value: $kcal, unit: "kcal")
                    NumberField("Protein", value: $protein, unit: "g")
                    NumberField("Carbohydrates", value: $carbs, unit: "g")
                    NumberField("Fat", value: $fat, unit: "g")
                    NumberField("Fiber", value: $fiber, unit: "g")
                } header: { Text("Per 100 g") } footer: {
                    Text("Copy these from the nutrition label (“per 100 g” column).")
                }.listRowBackground(Theme.card)
            }
            .warmForm()
            .keyboardDoneToolbar()
            .navigationTitle(food == nil ? "New food" : "Edit food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }.fontWeight(.semibold).disabled(!canSave)
                }
            }
            .onAppear {
                guard !loaded, let f = food else { return }
                name = f.name; brand = f.brand; servingName = f.servingName; servingGrams = f.servingGrams
                kcal = f.kcalPer100; protein = f.proteinPer100; carbs = f.carbsPer100
                fat = f.fatPer100; fiber = f.fiberPer100
                loaded = true
            }
        }
    }

    private func save() {
        let f = food ?? CustomFood()
        if food == nil { context.insert(f) }
        f.name = name.trimmed
        f.brand = brand.trimmed
        f.servingName = servingName.trimmed.isEmpty ? "1 serving" : servingName.trimmed
        f.servingGrams = max(1, servingGrams ?? 100)
        f.kcalPer100 = kcal ?? 0
        f.proteinPer100 = protein ?? 0
        f.carbsPer100 = carbs ?? 0
        f.fatPer100 = fat ?? 0
        f.fiberPer100 = fiber ?? 0
        context.saveQuietly()
        Haptics.success()
        dismiss()
    }
}

struct CustomFoodListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \CustomFood.name) private var foods: [CustomFood]
    @State private var editing: CustomFood?
    @State private var creating = false

    var body: some View {
        List {
            if foods.isEmpty {
                EmptyState(icon: "fork.knife", title: "No custom foods",
                           message: "Create foods you eat often with exact label values.",
                           actionTitle: "Create food") { creating = true }
                    .listRowBackground(Color.clear)
            }
            ForEach(foods) { f in
                Button { editing = f } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(f.name).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text)
                        Text("\(f.kcalPer100.whole) kcal · P \(f.proteinPer100.clean) · C \(f.carbsPer100.clean) · F \(f.fatPer100.clean) per 100 g")
                            .font(.caption).foregroundStyle(Theme.textSecondary)
                    }
                }
                .listRowBackground(Theme.card)
            }
            .onDelete { idx in
                for i in idx { context.delete(foods[i]) }
                context.saveQuietly()
            }
        }
        .warmForm()
        .navigationTitle("My foods")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { creating = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(item: $editing) { CustomFoodEditor(food: $0) }
        .sheet(isPresented: $creating) { CustomFoodEditor(food: nil) }
    }
}

// MARK: - Goals

struct NutritionGoalsView: View {
    @Query private var profiles: [UserProfile]
    var body: some View {
        if let p = profiles.first {
            GoalsForm(profile: p)
        } else {
            EmptyState(icon: "person", title: "No profile", message: "Finish onboarding first.")
        }
    }
}

private struct GoalsForm: View {
    @Bindable var profile: UserProfile
    @Environment(\.modelContext) private var context
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]
    @State private var goal: NutritionGoal = .maintain

    private var weight: Double { weights.first?.kg ?? profile.startWeightKg }
    private var macroKcal: Int { profile.proteinTarget * 4 + profile.carbTarget * 4 + profile.fatTarget * 9 }

    var body: some View {
        Form {
            Section {
                Picker("Goal", selection: $goal) {
                    ForEach(NutritionGoal.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Button("Apply a starting estimate") { apply() }
            } header: { Text("Goal") } footer: {
                Text("Estimates use your weight, height, age and training days. They are rough guides, not medical advice. Edit any number below.")
            }.listRowBackground(Theme.card)

            Section("Daily targets") {
                row("Calories", $profile.calorieTarget, "kcal")
                row("Protein", $profile.proteinTarget, "g")
                row("Carbohydrates", $profile.carbTarget, "g")
                row("Fat", $profile.fatTarget, "g")
                row("Fiber", $profile.fiberTarget, "g")
                row("Water", $profile.waterTargetMl, "ml")
            }.listRowBackground(Theme.card)

            Section {
                Text("Macros add up to \(macroKcal) kcal (\(profile.calorieTarget > 0 ? Int(Double(macroKcal) / Double(profile.calorieTarget) * 100) : 0)% of your calorie target).")
                    .font(.footnote).foregroundStyle(Theme.textSecondary)
            }.listRowBackground(Color.clear)
        }
        .warmForm()
        .keyboardDoneToolbar()
        .navigationTitle("Nutrition goals")
        .onAppear { goal = NutritionPlanner.goal(for: profile.objective) }
        .onDisappear { context.saveQuietly() }
    }

    private func row(_ title: String, _ value: Binding<Int>, _ unit: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", value: value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 100)
            Text(unit).foregroundStyle(Theme.textSecondary).frame(width: 34, alignment: .leading)
        }
    }

    private func apply() {
        let t = NutritionPlanner.suggest(goal: goal, weightKg: weight, heightCm: profile.heightCm,
                                         age: profile.age, trainingDays: profile.weeklyTrainingDays)
        profile.calorieTarget = t.calories
        profile.proteinTarget = t.protein
        profile.carbTarget = t.carbs
        profile.fatTarget = t.fat
        profile.waterTargetMl = t.waterMl
        Haptics.success()
    }
}

// MARK: - Water log

struct WaterLogView: View {
    let date: Date
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WaterEntry.date, order: .reverse) private var all: [WaterEntry]
    @Query private var profiles: [UserProfile]
    @State private var custom: Double?

    private var entries: [WaterEntry] { all.filter { $0.date.isSameDay(as: date) } }
    private var total: Int { entries.reduce(0) { $0 + $1.ml } }
    private var goal: Int { profiles.first?.waterTargetMl ?? 3000 }
    private var when: Date {
        date.isToday ? Date() : (Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    ProgressRing(progress: Double(total) / Double(max(goal, 1)), lineWidth: 16) {
                        VStack(spacing: 0) {
                            Text(String(format: "%.2f", Double(total) / 1000)).font(Theme.number(36)).foregroundStyle(Theme.text)
                            Text("of \(String(format: "%.1f", Double(goal) / 1000)) L").font(.caption).foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .frame(width: 170, height: 170)
                    .padding(.top, 10)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                        ForEach([150, 250, 330, 500, 750, 1000], id: \.self) { ml in
                            Button {
                                Haptics.tap()
                                context.addWater(ml, on: when)
                            } label: { Text("+\(ml) ml") }
                            .buttonStyle(SoftButtonStyle(compact: true))
                        }
                    }

                    HStack {
                        NumberField("Custom", value: $custom, unit: "ml")
                        Button("Add") {
                            if let c = custom, c > 0 {
                                context.addWater(Int(c), on: when)
                                custom = nil
                                Haptics.tap()
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle(compact: true))
                    }
                    .card(padding: 14)

                    if !entries.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            SectionTitle("Logged").padding(.bottom, 8)
                            ForEach(entries) { e in
                                HStack {
                                    Text(e.date.timeString).foregroundStyle(Theme.textSecondary)
                                    Spacer()
                                    Text("\(e.ml) ml").fontWeight(.semibold)
                                    Button(role: .destructive) {
                                        context.delete(e)
                                        context.saveQuietly()
                                    } label: { Image(systemName: "trash").foregroundStyle(Theme.textSecondary) }
                                        .padding(.leading, 8)
                                }
                                .padding(.vertical, 8)
                                Divider().overlay(Theme.hairline)
                            }
                        }
                        .card()
                    }
                }
                .padding(Theme.pad)
            }
            .screenBackground()
            .keyboardDoneToolbar()
            .navigationTitle("Water")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.fontWeight(.semibold) } }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Sleep log

struct SleepLogView: View {
    let day: Date
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var entries: [SleepEntry]
    @State private var hours: Double = 7.5
    @State private var quality = 3

    private var existing: SleepEntry? { entries.first { $0.day.startOfDay == day.startOfDay } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $hours, in: 0...16, step: 0.25) {
                        HStack {
                            Text("Hours slept")
                            Spacer()
                            Text(hours.clean + " h").foregroundStyle(Theme.textSecondary).monospacedDigit()
                        }
                    }
                    Picker("Quality", selection: $quality) {
                        ForEach(1...5, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.segmented)
                } header: { Text("Last night") } footer: {
                    Text("Logged on \(day.longDate). Sleep counts toward your Transformation Score only on days you log it.")
                }.listRowBackground(Theme.card)
            }
            .warmForm()
            .navigationTitle("Sleep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { Button("Save") { save() }.fontWeight(.semibold) }
            }
            .onAppear {
                if let e = existing { hours = e.hours; quality = e.quality }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        if let e = existing {
            e.hours = hours
            e.quality = quality
        } else {
            context.insert(SleepEntry(day: day, hours: hours, quality: quality))
        }
        context.saveQuietly()
        Haptics.success()
        dismiss()
    }
}
