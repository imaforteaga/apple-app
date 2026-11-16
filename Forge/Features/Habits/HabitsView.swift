import SwiftUI
import SwiftData

struct HabitsView: View {
    var body: some View {
        WithScore { engine in HabitsContent(engine: engine) }
    }
}

private struct HabitsContent: View {
    let engine: ScoreEngine
    @Environment(\.modelContext) private var context
    @Query private var logs: [HabitLog]
    @Query private var supplementLogs: [SupplementLog]
    @State private var editing: Habit?
    @State private var creating = false

    private var today: Date { Date() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                summary
                todayList
                weekGrid
                supplementsCard
                manage
            }
            .padding(.horizontal, Theme.pad)
            .padding(.bottom, 40)
        }
        .screenBackground()
        .navigationTitle("Habits")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { creating = true } label: { Image(systemName: "plus") }.accessibilityLabel("New habit")
            }
        }
        .sheet(item: $editing) { HabitEditor(habit: $0) }
        .sheet(isPresented: $creating) { HabitEditor(habit: nil) }
    }

    private var summary: some View {
        let p = engine.habitsDone(on: today)
        let rate: Double = {
            let hs = engine.activeHabits
            guard !hs.isEmpty else { return 0 }
            return hs.map { engine.completionRate(for: $0, days: 7) }.reduce(0, +) / Double(hs.count)
        }()
        return HStack(spacing: 18) {
            ProgressRing(progress: p.total == 0 ? 0 : Double(p.done) / Double(p.total), lineWidth: 10) {
                Text("\(p.done)/\(p.total)").font(Theme.number(20)).foregroundStyle(Theme.text)
            }
            .frame(width: 88, height: 88)
            VStack(alignment: .leading, spacing: 4) {
                Text("Today").font(Theme.display(22))
                Text("7-day completion: \(Int((rate * 100).rounded()))%").font(.footnote).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
        .card()
    }

    private var todayList: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("Daily habits", subtitle: "Some complete automatically from your other data")
            ForEach(engine.activeHabits) { h in
                let done = engine.isDone(h, on: today)
                let auto = engine.isAutoDone(h, on: today) && !engine.isManuallyDone(h, on: today)
                HStack(spacing: 12) {
                    IconBadge(systemName: h.icon, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(h.name).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text)
                        let streak = engine.streak(for: h)
                        Text(auto ? "Completed automatically" : (streak > 0 ? "\(streak)-day streak" : "No streak yet"))
                            .font(.caption).foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Button {
                        Haptics.tap()
                        withAnimation(Motion.quick) {
                            context.toggleHabit(h, on: today, logs: logs)
                        }
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(done ? Color.white : Theme.hairline)
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(done ? AnyShapeStyle(Theme.buttonGradient) : AnyShapeStyle(Theme.cardAlt)))
                    }
                    .buttonStyle(.plain)
                    .disabled(auto)
                    .accessibilityLabel("\(h.name), \(done ? "done" : "not done")")
                }
                .card(padding: 12)
            }
        }
    }

    private var weekGrid: some View {
        let days = Date.lastDays(7)
        return VStack(alignment: .leading, spacing: 12) {
            SectionTitle("Weekly statistics")
            HStack(spacing: 0) {
                Text("").frame(width: 110, alignment: .leading)
                ForEach(days, id: \.self) { d in
                    Text(d.weekdayInitial).font(.caption2.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
                Text("%").font(.caption2.weight(.semibold)).foregroundStyle(Theme.textSecondary).frame(width: 36)
            }
            ForEach(engine.activeHabits) { h in
                HStack(spacing: 0) {
                    Text(h.name).font(.caption).lineLimit(1).frame(width: 110, alignment: .leading)
                    ForEach(days, id: \.self) { d in
                        Circle()
                            .fill(engine.isDone(h, on: d) ? AnyShapeStyle(Theme.brandGradient) : AnyShapeStyle(Theme.cardAlt))
                            .frame(width: 16, height: 16)
                            .frame(maxWidth: .infinity)
                    }
                    Text("\(Int((engine.completionRate(for: h, days: 7) * 100).rounded()))")
                        .font(.caption.weight(.semibold)).monospacedDigit().frame(width: 36)
                }
            }
        }
        .card()
    }

    private var supplementsCard: some View {
        let due = engine.dueSupplements(on: today).sorted { $0.time.order < $1.time.order }
        return VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Supplements", subtitle: due.isEmpty ? "Nothing scheduled today" : "Today") {
                NavigationLink { SupplementsView() } label: {
                    Text("Manage").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accentText)
                }
            }
            ForEach(due) { s in
                SupplementRow(supplement: s, logs: supplementLogs, day: today)
            }
        }
        .card()
    }

    private var manage: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("Manage habits")
            ForEach(engine.habits.sorted { $0.sortOrder < $1.sortOrder }) { h in
                Button { editing = h } label: {
                    HStack {
                        Image(systemName: h.icon).foregroundStyle(Theme.accentText).frame(width: 26)
                        Text(h.name).foregroundStyle(h.isActive ? Theme.text : Theme.textSecondary)
                        Spacer()
                        if !h.isActive { Text("Hidden").font(.caption).foregroundStyle(Theme.textSecondary) }
                        else if !h.countsForScore { Text("Not in score").font(.caption).foregroundStyle(Theme.textSecondary) }
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.textSecondary)
                    }
                    .font(.subheadline)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                Divider().overlay(Theme.hairline)
            }
        }
        .card()
    }
}

struct SupplementRow: View {
    let supplement: Supplement
    let logs: [SupplementLog]
    let day: Date
    @Environment(\.modelContext) private var context

    private var taken: [SupplementLog] { logs.filter { $0.supplementID == supplement.id && $0.day == day.startOfDay } }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(supplement.name).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text)
                Text("\(supplement.dosage.isEmpty ? "" : supplement.dosage + " · ")\(supplement.time.title)")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Button {
                Haptics.tap()
                if let t = taken.first {
                    context.delete(t)
                } else {
                    context.insert(SupplementLog(supplementID: supplement.id, day: day, dosage: supplement.dosage))
                }
                context.saveQuietly()
            } label: {
                Image(systemName: taken.isEmpty ? "circle" : "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(taken.isEmpty ? Theme.hairline : Theme.orange)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(supplement.name), \(taken.isEmpty ? "not taken" : "taken")")
        }
    }
}

// MARK: - Habit editor

struct HabitEditor: View {
    let habit: Habit?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var habits: [Habit]
    @State private var name = ""
    @State private var icon = "checkmark.circle"
    @State private var active = true
    @State private var counts = true
    @State private var confirmDelete = false

    private let icons = ["checkmark.circle", "drop.fill", "pills.fill", "dumbbell.fill", "figure.flexibility", "moon.zzz.fill",
                         "fork.knife", "book.closed.fill", "figure.walk", "brain.head.profile", "leaf.fill", "sun.max.fill",
                         "heart.fill", "cup.and.saucer.fill", "sparkles", "pencil", "phone.down.fill", "shower.fill"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Habit name", text: $name)
                    Toggle("Show in my daily list", isOn: $active).tint(Theme.orange)
                    Toggle("Counts toward Transformation Score", isOn: $counts).tint(Theme.orange)
                }.listRowBackground(Theme.card)
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(icons, id: \.self) { i in
                            Button { icon = i } label: {
                                Image(systemName: i)
                                    .frame(width: 40, height: 40)
                                    .foregroundStyle(icon == i ? Color.white : Theme.accentText)
                                    .background(Circle().fill(icon == i ? AnyShapeStyle(Theme.buttonGradient) : AnyShapeStyle(Theme.softAccent)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }.listRowBackground(Theme.card)
                if let h = habit, let d = DefaultHabits.autoDescription(h.autoKey) {
                    Section { Text(d).font(.footnote).foregroundStyle(Theme.textSecondary) }.listRowBackground(Color.clear)
                }
                if habit != nil {
                    Section {
                        Button("Delete habit", role: .destructive) { confirmDelete = true }
                    }.listRowBackground(Theme.card)
                }
            }
            .warmForm()
            .navigationTitle(habit == nil ? "New habit" : "Edit habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { Button("Save") { save() }.fontWeight(.semibold).disabled(name.trimmed.isEmpty) }
            }
            .confirmationDialog("Delete this habit and its history?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let h = habit {
                        let all = (try? context.fetch(FetchDescriptor<HabitLog>())) ?? []
                        all.filter { $0.habitID == h.id }.forEach { context.delete($0) }
                        context.delete(h)
                        context.saveQuietly()
                    }
                    dismiss()
                }
            }
            .onAppear {
                if let h = habit { name = h.name; icon = h.icon; active = h.isActive; counts = h.countsForScore }
            }
        }
    }

    private func save() {
        if let h = habit {
            h.name = name.trimmed; h.icon = icon; h.isActive = active; h.countsForScore = counts
        } else {
            let h = Habit(name: name.trimmed, icon: icon, sortOrder: (habits.map(\.sortOrder).max() ?? 0) + 1)
            h.isActive = active
            h.countsForScore = counts
            context.insert(h)
        }
        context.saveQuietly()
        dismiss()
    }
}

/// Compact checklist used by the Home quick action.
struct HabitChecklistSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            WithScore { engine in ChecklistBody(engine: engine) }
                .navigationTitle("Habits")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.fontWeight(.semibold) } }
        }
        .presentationDetents([.medium, .large])
    }

    private struct ChecklistBody: View {
        let engine: ScoreEngine
        @Environment(\.modelContext) private var context
        @Query private var logs: [HabitLog]
        var body: some View {
            List(engine.activeHabits) { h in
                let done = engine.isDone(h, on: Date())
                let auto = engine.isAutoDone(h, on: Date()) && !engine.isManuallyDone(h, on: Date())
                Button {
                    Haptics.tap()
                    context.toggleHabit(h, on: Date(), logs: logs)
                } label: {
                    HStack {
                        Image(systemName: h.icon).foregroundStyle(Theme.accentText).frame(width: 28)
                        Text(h.name).foregroundStyle(Theme.text)
                        Spacer()
                        if auto { Text("Auto").font(.caption).foregroundStyle(Theme.textSecondary) }
                        Image(systemName: done ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(done ? Theme.orange : Theme.hairline).font(.title3)
                    }
                }
                .disabled(auto)
                .listRowBackground(Theme.card)
            }
            .warmForm()
        }
    }
}

// MARK: - Supplements

struct SupplementsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Supplement.createdAt) private var supplements: [Supplement]
    @Query private var logs: [SupplementLog]
    @State private var editing: Supplement?
    @State private var creating = false

    var body: some View {
        List {
            if supplements.isEmpty {
                EmptyState(icon: "pills", title: "No supplements yet",
                           message: "Add what you take, set a schedule and a dose, and log it daily.",
                           actionTitle: "Add supplement") { creating = true }
                    .listRowBackground(Color.clear)
            }
            ForEach(supplements) { s in
                VStack(alignment: .leading, spacing: 8) {
                    Button { editing = s } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.name).font(.headline).foregroundStyle(s.isActive ? Theme.text : Theme.textSecondary)
                                Text("\(s.dosage.isEmpty ? "" : s.dosage + " · ")\(s.time.title) · \(daysSummary(s.weekdayMask))")
                                    .font(.caption).foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            if s.reminderEnabled { Image(systemName: "bell.fill").foregroundStyle(Theme.orange).font(.caption) }
                        }
                    }
                    .buttonStyle(.plain)
                    let n = logs.filter { $0.supplementID == s.id && $0.day >= Date().startOfDay.addingDays(-6) }.count
                    Text("Taken \(n) of the last 7 days").font(.caption2).foregroundStyle(Theme.textSecondary)
                }
                .listRowBackground(Theme.card)
            }
            .onDelete { idx in
                for i in idx {
                    let s = supplements[i]
                    NotificationService.cancelSupplement(id: s.id)
                    logs.filter { $0.supplementID == s.id }.forEach { context.delete($0) }
                    context.delete(s)
                }
                context.saveQuietly()
            }
        }
        .warmForm()
        .navigationTitle("Supplements")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { creating = true } label: { Image(systemName: "plus") } } }
        .sheet(item: $editing) { SupplementEditor(supplement: $0) }
        .sheet(isPresented: $creating) { SupplementEditor(supplement: nil) }
    }

    private func daysSummary(_ mask: Int) -> String {
        if mask == 127 { return "Daily" }
        return (1...7).filter { mask & (1 << ($0 - 1)) != 0 }
            .map { String(Calendar.current.shortWeekdaySymbols[$0 - 1]) }.joined(separator: " ")
    }
}

struct SupplementEditor: View {
    let supplement: Supplement?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var dosage = ""
    @State private var time: SupplementTime = .morning
    @State private var mask = 127
    @State private var active = true
    @State private var reminder = false
    @State private var reminderTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var notes = ""
    @State private var notifDenied = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name (e.g. Creatine monohydrate)", text: $name)
                    TextField("Dosage (e.g. 5 g)", text: $dosage)
                    Picker("When", selection: $time) {
                        ForEach(SupplementTime.allCases) { Text($0.title).tag($0) }
                    }
                    Toggle("Active", isOn: $active).tint(Theme.orange)
                }.listRowBackground(Theme.card)
                Section("Days") {
                    HStack(spacing: 6) {
                        ForEach(1...7, id: \.self) { d in
                            let on = mask & (1 << (d - 1)) != 0
                            Button { mask ^= (1 << (d - 1)) } label: {
                                Text(String(Calendar.current.veryShortWeekdaySymbols[d - 1]))
                                    .font(.system(.subheadline, design: .default, weight: .bold))
                                    .frame(maxWidth: .infinity).frame(height: 38)
                                    .foregroundStyle(on ? Color.white : Theme.text)
                                    .background(Circle().fill(on ? AnyShapeStyle(Theme.buttonGradient) : AnyShapeStyle(Theme.cardAlt)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }.listRowBackground(Theme.card)
                Section {
                    Toggle("Reminder", isOn: $reminder).tint(Theme.orange)
                    if reminder { DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute) }
                    TextField("Notes", text: $notes, axis: .vertical)
                } footer: {
                    if notifDenied { Text("Notifications are off for Forge. Enable them in Settings › Notifications.") }
                }.listRowBackground(Theme.card)
            }
            .warmForm()
            .navigationTitle(supplement == nil ? "New supplement" : "Edit supplement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { Task { await save() } }.fontWeight(.semibold).disabled(name.trimmed.isEmpty || mask == 0)
                }
            }
            .onAppear {
                guard let s = supplement else { return }
                name = s.name; dosage = s.dosage; time = s.time; mask = s.weekdayMask; active = s.isActive
                reminder = s.reminderEnabled; notes = s.notes
                reminderTime = Calendar.current.date(bySettingHour: s.reminderHour, minute: s.reminderMinute, second: 0, of: Date()) ?? Date()
            }
        }
    }

    private func save() async {
        let s = supplement ?? Supplement(name: name, dosage: dosage, time: time)
        if supplement == nil { context.insert(s) }
        s.name = name.trimmed; s.dosage = dosage.trimmed; s.time = time; s.weekdayMask = mask
        s.isActive = active; s.notes = notes
        let comps = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        s.reminderHour = comps.hour ?? 9
        s.reminderMinute = comps.minute ?? 0
        s.reminderEnabled = reminder
        context.saveQuietly()
        if reminder {
            let ok = await NotificationService.requestAuthorization()
            if ok {
                await NotificationService.scheduleSupplement(s)
            } else {
                s.reminderEnabled = false
                context.saveQuietly()
                notifDenied = true
                return
            }
        } else {
            NotificationService.cancelSupplement(id: s.id)
        }
        dismiss()
    }
}
