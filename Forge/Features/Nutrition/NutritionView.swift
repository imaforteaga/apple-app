import SwiftUI
import SwiftData
import Charts

struct NutritionView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @Query(sort: \FoodEntry.date) private var allEntries: [FoodEntry]
    @Query private var allWater: [WaterEntry]
    @Query(sort: \FavoriteMeal.createdAt, order: .reverse) private var favorites: [FavoriteMeal]

    @State private var date = Date()
    @State private var addMeal: MealType?
    @State private var editing: FoodEntry?
    @State private var showWater = false
    @State private var savedFavoriteMessage: String?
    @State private var namingFavoriteFor: MealType?
    @State private var favoriteName = ""

    private var profile: UserProfile? { profiles.first }
    private var dayEntries: [FoodEntry] { allEntries.filter { $0.date.isSameDay(as: date) } }
    private var totals: DayNutrition { DayNutrition(entries: dayEntries) }
    private var waterToday: Int { allWater.filter { $0.date.isSameDay(as: date) }.reduce(0) { $0 + $1.ml } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                dateBar
                summaryCard
                waterCard
                ForEach(MealType.allCases) { meal in
                    mealSection(meal)
                }
                if !favorites.isEmpty { favoritesSection }
                weeklyHistory
            }
            .padding(.horizontal, Theme.pad)
            .padding(.bottom, 40)
        }
        .screenBackground()
        .navigationTitle("Nutrition")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    NavigationLink { NutritionGoalsView() } label: { Label("Nutrition goals", systemImage: "target") }
                    NavigationLink { CustomFoodListView() } label: { Label("My foods", systemImage: "list.bullet") }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
            }
        }
        .sheet(item: $addMeal) { meal in
            AddMealView(date: date, defaultMeal: meal)
        }
        .sheet(item: $editing) { entry in
            EditFoodEntryView(entry: entry)
        }
        .sheet(isPresented: $showWater) {
            WaterLogView(date: date)
        }
        .alert("Save as favorite", isPresented: Binding(get: { namingFavoriteFor != nil },
                                                        set: { if !$0 { namingFavoriteFor = nil } })) {
            TextField("Name", text: $favoriteName)
            Button("Save") { saveFavorite() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Save this meal so you can log it again with one tap.")
        }
    }

    // MARK: Date

    private var dateBar: some View {
        HStack {
            Button { shift(-1) } label: {
                Image(systemName: "chevron.left").frame(width: 40, height: 40)
            }
            Spacer()
            VStack(spacing: 2) {
                Text(date.isToday ? "Today" : date.weekdayShort)
                    .font(Theme.display(20))
                    .foregroundStyle(Theme.text)
                DatePicker("", selection: $date, in: ...Date(), displayedComponents: .date)
                    .labelsHidden()
                    .fixedSize()
            }
            Spacer()
            Button { shift(1) } label: {
                Image(systemName: "chevron.right").frame(width: 40, height: 40)
            }
            .disabled(date.isToday)
        }
        .foregroundStyle(Theme.accentText)
        .padding(.top, 6)
    }

    private func shift(_ days: Int) {
        Haptics.select()
        let new = date.addingDays(days)
        if new <= Date() { withAnimation(Motion.soft) { date = new } }
    }

    // MARK: Summary

    private var summaryCard: some View {
        let t = totals
        let goal = Double(profile?.calorieTarget ?? 2500)
        let remaining = goal - t.kcal
        return VStack(spacing: 20) {
            HStack(spacing: 22) {
                ProgressRing(progress: t.kcal / max(goal, 1), lineWidth: 14) {
                    VStack(spacing: 0) {
                        Text(t.kcal.whole).font(Theme.number(32)).foregroundStyle(Theme.text)
                        Text("of \(Int(goal)) kcal").font(.caption2).foregroundStyle(Theme.textSecondary)
                    }
                }
                .frame(width: 128, height: 128)
                VStack(alignment: .leading, spacing: 4) {
                    Text(remaining >= 0 ? "\(Int(remaining.rounded())) left" : "\(Int((-remaining).rounded())) over")
                        .font(Theme.display(24))
                        .foregroundStyle(remaining >= 0 ? Theme.text : Theme.deepOrange)
                    Text(t.count == 0 ? "Nothing logged yet" : "\(t.count) item\(t.count == 1 ? "" : "s") logged")
                        .font(.footnote).foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 0)
            }
            VStack(spacing: 12) {
                MacroBar(label: "Protein", value: t.protein, goal: Double(profile?.proteinTarget ?? 150))
                MacroBar(label: "Carbohydrates", value: t.carbs, goal: Double(profile?.carbTarget ?? 280))
                MacroBar(label: "Fat", value: t.fat, goal: Double(profile?.fatTarget ?? 70))
                MacroBar(label: "Fiber", value: t.fiber, goal: Double(profile?.fiberTarget ?? 30))
            }
        }
        .card()
    }

    // MARK: Water

    private var waterCard: some View {
        let goal = Double(profile?.waterTargetMl ?? 3000)
        return VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Water", subtitle: "\(waterToday) of \(Int(goal)) ml") {
                Button { showWater = true } label: {
                    Text("Details").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accentText)
                }
            }
            LinearProgressBar(progress: Double(waterToday) / max(goal, 1), height: 10)
            HStack(spacing: 8) {
                ForEach([150, 250, 500, 750], id: \.self) { ml in
                    Button {
                        Haptics.tap()
                        context.addWater(ml, on: dateForLogging)
                    } label: {
                        Text("+\(ml)")
                    }
                    .buttonStyle(SoftButtonStyle(compact: true))
                }
            }
        }
        .card()
    }

    /// Logging on a past day keeps the entry on that day.
    private var dateForLogging: Date {
        date.isToday ? Date() : Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
    }

    // MARK: Meals

    private func mealSection(_ meal: MealType) -> some View {
        let entries = dayEntries.filter { $0.meal == meal }
        let kcal = entries.reduce(0) { $0 + $1.kcal }
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                IconBadge(systemName: meal.icon, size: 34)
                Text(meal.title).font(Theme.display(20)).foregroundStyle(Theme.text)
                Spacer()
                if kcal > 0 {
                    Text("\(kcal.whole) kcal")
                        .font(.system(.subheadline, design: .default, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            if entries.isEmpty {
                Text("Nothing logged")
                    .font(.footnote).foregroundStyle(Theme.textSecondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(entries) { e in
                        Button { editing = e } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(e.name).font(.subheadline.weight(.medium)).foregroundStyle(Theme.text)
                                        .multilineTextAlignment(.leading)
                                    Text("\(e.quantityLabel) · P \(e.protein.whole)  C \(e.carbs.whole)  F \(e.fat.whole)")
                                        .font(.caption).foregroundStyle(Theme.textSecondary)
                                }
                                Spacer()
                                Text(e.kcal.whole)
                                    .font(.system(.subheadline, design: .default, weight: .semibold))
                                    .foregroundStyle(Theme.text)
                            }
                            .padding(.vertical, 9)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) { delete(e) } label: { Label("Delete", systemImage: "trash") }
                        }
                        if e.id != entries.last?.id { Divider().overlay(Theme.hairline) }
                    }
                }
            }
            HStack {
                Button { addMeal = meal } label: {
                    Label("Add food", systemImage: "plus")
                }
                .buttonStyle(SoftButtonStyle(compact: true))
                if entries.count > 1 {
                    Button {
                        favoriteName = ""
                        namingFavoriteFor = meal
                    } label: {
                        Label("Save meal", systemImage: "star")
                    }
                    .buttonStyle(SoftButtonStyle(compact: true))
                }
            }
        }
        .card()
    }

    private func delete(_ e: FoodEntry) {
        Haptics.warning()
        context.delete(e)
        context.saveQuietly()
    }

    private func saveFavorite() {
        guard let meal = namingFavoriteFor else { return }
        let items = dayEntries.filter { $0.meal == meal }.map {
            MealItem(name: $0.name, quantityLabel: $0.quantityLabel, grams: $0.grams, kcal: $0.kcal,
                     protein: $0.protein, carbs: $0.carbs, fat: $0.fat, fiber: $0.fiber)
        }
        let name = favoriteName.trimmed.isEmpty ? "My \(meal.title.lowercased())" : favoriteName.trimmed
        context.insert(FavoriteMeal(name: name, meal: meal, items: items))
        context.saveQuietly()
        namingFavoriteFor = nil
        Haptics.success()
    }

    // MARK: Favorites

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("Favorite meals", subtitle: "Tap to log again")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(favorites) { fav in
                        Button {
                            log(favorite: fav)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Image(systemName: "star.fill").foregroundStyle(Theme.yellow)
                                Text(fav.name).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text)
                                    .lineLimit(1)
                                Text("\(fav.totalKcal.whole) kcal · \(fav.totalProtein.whole) g P")
                                    .font(.caption).foregroundStyle(Theme.textSecondary)
                            }
                            .frame(width: 140, alignment: .leading)
                            .card(padding: 14)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                context.delete(fav)
                                context.saveQuietly()
                            } label: { Label("Remove favorite", systemImage: "trash") }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollClipDisabled()
        }
    }

    private func log(favorite fav: FavoriteMeal) {
        let when = dateForLogging
        for item in fav.items {
            context.insert(FoodEntry(date: when, meal: fav.meal, name: item.name, quantityLabel: item.quantityLabel,
                                     grams: item.grams, kcal: item.kcal, protein: item.protein,
                                     carbs: item.carbs, fat: item.fat, fiber: item.fiber))
        }
        context.saveQuietly()
        Haptics.success()
    }

    // MARK: History

    private var weeklyHistory: some View {
        let days = Date.lastDays(7, endingAt: date)
        let data: [NutritionDayPoint] = days.map { d in
            let n = DayNutrition(entries: allEntries.filter { $0.date.isSameDay(as: d) })
            return NutritionDayPoint(day: d, kcal: n.kcal, protein: n.protein)
        }
        let logged = data.filter { $0.kcal > 0 }
        let avgK = logged.isEmpty ? 0 : logged.reduce(0) { $0 + $1.kcal } / Double(logged.count)
        let avgP = logged.isEmpty ? 0 : logged.reduce(0) { $0 + $1.protein } / Double(logged.count)
        let calGoal = Double(profile?.calorieTarget ?? 2500)
        let proGoal = Double(profile?.proteinTarget ?? 150)

        return VStack(alignment: .leading, spacing: 16) {
            SectionTitle("Weekly history", subtitle: logged.isEmpty ? "No data in the last 7 days" :
                            "Average \(avgK.whole) kcal · \(avgP.whole) g protein")
            Text("Calories").font(.footnote.weight(.semibold)).foregroundStyle(Theme.textSecondary)
            Chart {
                ForEach(data) { row in
                    BarMark(x: .value("Day", row.day, unit: .day), y: .value("kcal", row.kcal), width: .fixed(20))
                        .cornerRadius(6)
                        .foregroundStyle(Theme.brandGradient)
                }
                RuleMark(y: .value("Goal", calGoal))
                    .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                    .foregroundStyle(Theme.textSecondary)
            }
            .chartXAxis { AxisMarks(values: .stride(by: .day)) { _ in AxisValueLabel(format: .dateTime.weekday(.narrow)) } }
            .frame(height: 130)
            Text("Protein").font(.footnote.weight(.semibold)).foregroundStyle(Theme.textSecondary)
            Chart {
                ForEach(data) { row in
                    BarMark(x: .value("Day", row.day, unit: .day), y: .value("g", row.protein), width: .fixed(20))
                        .cornerRadius(6)
                        .foregroundStyle(Theme.yellow)
                }
                RuleMark(y: .value("Goal", proGoal))
                    .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                    .foregroundStyle(Theme.textSecondary)
            }
            .chartXAxis { AxisMarks(values: .stride(by: .day)) { _ in AxisValueLabel(format: .dateTime.weekday(.narrow)) } }
            .frame(height: 110)
            Text("Dashed line = your daily goal").font(.caption2).foregroundStyle(Theme.textSecondary)
        }
        .card()
    }
}


struct NutritionDayPoint: Identifiable {
    var id: Date { day }
    var day: Date
    var kcal: Double
    var protein: Double
}
