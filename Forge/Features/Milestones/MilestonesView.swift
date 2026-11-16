import SwiftUI
import SwiftData
import Charts

struct MilestonesView: View {
    @Query(sort: \Milestone.createdAt, order: .reverse) private var milestones: [Milestone]
    @Query private var updates: [MilestoneUpdate]
    @State private var tab = 0
    @State private var creating = false
    @State private var updating: Milestone?

    private var active: [Milestone] { milestones.filter { !$0.isCompleted } }
    private var completed: [Milestone] {
        milestones.filter { $0.isCompleted }.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Picker("Tab", selection: $tab) {
                    Text("Active (\(active.count))").tag(0)
                    Text("Completed (\(completed.count))").tag(1)
                }.pickerStyle(.segmented)

                if tab == 0 { activeView } else { completedView }
            }
            .padding(.horizontal, Theme.pad)
            .padding(.bottom, 40)
        }
        .screenBackground()
        .navigationTitle("Milestones")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button { creating = true } label: { Image(systemName: "plus") } }
        }
        .sheet(isPresented: $creating) { MilestoneEditor(milestone: nil) }
        .sheet(item: $updating) { UpdateMilestoneSheet(milestone: $0) }
    }

    // MARK: Active

    private var activeView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if active.isEmpty {
                EmptyState(icon: "flag", title: "Set a measurable goal",
                           message: "Reach a weight, lift a number, build a streak. Track real progress toward it.",
                           actionTitle: "New milestone") { creating = true }
            } else {
                weeklyCard
                ForEach(active) { m in
                    NavigationLink { MilestoneDetailView(milestone: m) } label: { card(m) }.buttonStyle(.plain)
                }
            }
        }
    }

    private var weeklyCard: some View {
        let weekAgo = Date().addingDays(-7)
        let rows: [WeeklyRow] = active.map { m in
            WeeklyRow(milestone: m, delta: m.currentValue - MilestoneMath.value(of: m, on: weekAgo, updates: updates))
        }
        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle("This week", subtitle: "Progress since last week")
            ForEach(rows) { row in
                HStack {
                    Text(row.milestone.title).font(.subheadline).lineLimit(1)
                    Spacer()
                    Text("\(row.delta >= 0 ? "+" : "−")\(abs(row.delta).clean) \(row.milestone.unit)")
                        .font(.subheadline.weight(.semibold)).monospacedDigit()
                        .foregroundStyle(row.delta == 0 ? Theme.textSecondary : Theme.accentText)
                }
            }
        }
        .card()
    }

    private func card(_ m: Milestone) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                IconBadge(systemName: m.category.icon, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(m.title).font(.headline).foregroundStyle(Theme.text)
                    Text(m.category.title + (m.source != .manual ? " · Auto" : "")).font(.caption).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Text("\(Int((m.progress * 100).rounded()))%").font(Theme.number(20)).foregroundStyle(Theme.accentText)
            }
            LinearProgressBar(progress: m.progress, height: 10)
            HStack {
                Text("\(m.currentValue.clean) / \(m.targetValue.clean) \(m.unit)")
                    .font(.footnote).foregroundStyle(Theme.textSecondary)
                Spacer()
                if let d = m.targetDate {
                    let left = daysBetween(Date(), d)
                    Text(left >= 0 ? "\(left) days left" : "\(-left) days overdue")
                        .font(.footnote).foregroundStyle(left >= 0 ? Theme.textSecondary : Theme.deepOrange)
                }
            }
            if m.source == .manual {
                Button("Log progress") { updating = m }.buttonStyle(SoftButtonStyle(compact: true))
            }
        }
        .card()
    }

    // MARK: Completed

    private var completedView: some View {
        VStack(alignment: .leading, spacing: 14) {
            if completed.isEmpty {
                EmptyState(icon: "checkmark.seal", title: "Nothing completed yet",
                           message: "Finished milestones are kept here as a record of what you've built.")
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(completed) { m in
                    NavigationLink { MilestoneDetailView(milestone: m) } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                                .frame(width: 32, height: 32).background(Circle().fill(Theme.brandGradient))
                            Text(m.title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text)
                                .multilineTextAlignment(.leading).lineLimit(3)
                            Text("\(m.targetValue.clean) \(m.unit)").font(.caption).foregroundStyle(Theme.textSecondary)
                            if let d = m.completedAt {
                                Text(d.formatted("dMMMy")).font(.caption2).foregroundStyle(Theme.accentText)
                            }
                        }
                        .card(padding: 14)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct WeeklyRow: Identifiable {
    var id: UUID { milestone.id }
    var milestone: Milestone
    var delta: Double
}

enum MilestoneMath {
    /// Value a milestone had on a given date, from its update history.
    static func value(of m: Milestone, on date: Date, updates: [MilestoneUpdate]) -> Double {
        let ups = updates.filter { $0.milestoneID == m.id && $0.date <= date }.sorted { $0.date < $1.date }
        return ups.last?.value ?? m.startValue
    }
}

// MARK: - Detail

struct MilestoneDetailView: View {
    let milestone: Milestone
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @Query private var allUpdates: [MilestoneUpdate]
    @State private var editing = false
    @State private var updating = false
    @State private var confirmDelete = false

    private var updates: [MilestoneUpdate] {
        allUpdates.filter { $0.milestoneID == milestone.id }.sorted { $0.date < $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(spacing: 14) {
                    ProgressRing(progress: milestone.progress, lineWidth: 14) {
                        VStack(spacing: 0) {
                            Text("\(Int((milestone.progress * 100).rounded()))%").font(Theme.number(30)).foregroundStyle(Theme.text)
                            if milestone.isCompleted { Text("Completed").font(.caption).foregroundStyle(Theme.accentText) }
                        }
                    }
                    .frame(width: 140, height: 140)
                    Text("\(milestone.currentValue.clean) of \(milestone.targetValue.clean) \(milestone.unit)")
                        .font(.headline).foregroundStyle(Theme.text)
                    Text("Started at \(milestone.startValue.clean) \(milestone.unit) · \(milestone.createdAt.formatted("dMMMy"))")
                        .font(.footnote).foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity).card()

                if !milestone.details.isEmpty { Text(milestone.details).foregroundStyle(Theme.text).card() }

                if updates.count >= 2 {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle("Progress over time")
                        Chart {
                            ForEach(updates) { u in
                                LineMark(x: .value("Date", u.date), y: .value("Value", u.value))
                                    .foregroundStyle(Theme.orange).interpolationMethod(.stepEnd)
                                PointMark(x: .value("Date", u.date), y: .value("Value", u.value)).foregroundStyle(Theme.deepOrange)
                            }
                            RuleMark(y: .value("Target", milestone.targetValue))
                                .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [4, 4])).foregroundStyle(Theme.textSecondary)
                        }
                        .chartYScale(domain: .automatic(includesZero: false))
                        .frame(height: 170)
                    }
                    .card()
                }

                VStack(alignment: .leading, spacing: 8) {
                    SectionTitle("History")
                    ForEach(updates.reversed()) { u in
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("\(u.value.clean) \(milestone.unit)").font(.subheadline.weight(.semibold))
                                if !u.note.isEmpty { Text(u.note).font(.caption).foregroundStyle(Theme.textSecondary) }
                            }
                            Spacer()
                            Text(u.date.formatted("dMMMy")).font(.caption).foregroundStyle(Theme.textSecondary)
                        }
                        Divider().overlay(Theme.hairline)
                    }
                }
                .card()

                VStack(spacing: 10) {
                    if !milestone.isCompleted {
                        if milestone.source == .manual {
                            Button("Log progress") { updating = true }.buttonStyle(PrimaryButtonStyle())
                        }
                        Button("Mark as completed") { complete() }.buttonStyle(SoftButtonStyle())
                    } else {
                        Button("Reopen milestone") {
                            milestone.isCompleted = false
                            milestone.completedAt = nil
                            context.saveQuietly()
                        }.buttonStyle(SoftButtonStyle())
                    }
                    Button("Delete milestone", role: .destructive) { confirmDelete = true }.font(.footnote)
                }
            }
            .padding(Theme.pad)
        }
        .screenBackground()
        .navigationTitle(milestone.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Edit") { editing = true } } }
        .sheet(isPresented: $editing) { MilestoneEditor(milestone: milestone) }
        .sheet(isPresented: $updating) { UpdateMilestoneSheet(milestone: milestone) }
        .confirmationDialog("Delete this milestone?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                updates.forEach { context.delete($0) }
                context.delete(milestone)
                context.saveQuietly()
                dismiss()
            }
        }
    }

    private func complete() {
        milestone.isCompleted = true
        milestone.completedAt = Date()
        context.saveQuietly()
        appState.achievement = AchievementInfo(title: milestone.title, subtitle: "Marked as complete.")
    }
}

// MARK: - Update sheet

struct UpdateMilestoneSheet: View {
    let milestone: Milestone
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var value: Double?
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NumberField("New value", value: $value, unit: milestone.unit, placeholder: milestone.currentValue.clean)
                    TextField("Note (optional)", text: $note)
                } footer: { Text("Current: \(milestone.currentValue.clean) \(milestone.unit) · Target: \(milestone.targetValue.clean) \(milestone.unit)") }
                .listRowBackground(Theme.card)
            }
            .warmForm()
            .keyboardDoneToolbar()
            .navigationTitle("Log progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { Button("Save") { save() }.fontWeight(.semibold).disabled(value == nil) }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        guard let value else { return }
        milestone.currentValue = value
        context.insert(MilestoneUpdate(milestoneID: milestone.id, value: value, note: note.trimmed))
        var reached = false
        if milestone.reachedTarget && !milestone.isCompleted {
            milestone.isCompleted = true
            milestone.completedAt = Date()
            reached = true
        }
        context.saveQuietly()
        dismiss()
        if reached {
            appState.achievement = AchievementInfo(title: milestone.title, subtitle: "You reached \(milestone.targetValue.clean) \(milestone.unit).")
        } else {
            Haptics.success()
        }
    }
}

// MARK: - Editor

struct MilestoneEditor: View {
    let milestone: Milestone?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var weights: [WeightEntry]
    @Query private var sessions: [WorkoutSession]

    @State private var title = ""
    @State private var details = ""
    @State private var category: MilestoneCategory = .physique
    @State private var source: MilestoneSource = .manual
    @State private var exercise = ""
    @State private var unit = ""
    @State private var start: Double?
    @State private var target: Double?
    @State private var hasDate = false
    @State private var date = Date().addingDays(90)

    private struct Preset: Identifiable {
        let id = UUID()
        let title: String, category: MilestoneCategory, unit: String, source: MilestoneSource, target: Double
        var exercise: String = ""
    }
    private let presets: [Preset] = [
        Preset(title: "Reach 80 kg", category: .physique, unit: "kg", source: .bodyWeight, target: 80),
        Preset(title: "Bench press 100 kg", category: .strength, unit: "kg", source: .exerciseBest, target: 100, exercise: "Bench Press"),
        Preset(title: "Perform 15 pull-ups", category: .strength, unit: "reps", source: .manual, target: 15),
        Preset(title: "20 workouts this month", category: .fitness, unit: "workouts", source: .workoutsThisMonth, target: 20),
        Preset(title: "10 mobility sessions this month", category: .mobility, unit: "sessions", source: .mobilityThisMonth, target: 10),
        Preset(title: "30 days of consistent nutrition", category: .nutrition, unit: "days", source: .manual, target: 30),
        Preset(title: "Read the Bible 30 days in a row", category: .spirituality, unit: "days", source: .manual, target: 30)
    ]

    private var canSave: Bool { !title.trimmed.isEmpty && start != nil && target != nil && start != target }

    var body: some View {
        NavigationStack {
            Form {
                if milestone == nil {
                    Section("Ideas") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(presets) { p in
                                    Button(p.title) { apply(p) }.buttonStyle(SoftButtonStyle(compact: true))
                                }
                            }
                        }
                    }.listRowBackground(Color.clear)
                }
                Section {
                    TextField("Goal title", text: $title)
                    TextField("Description (optional)", text: $details, axis: .vertical)
                    Picker("Category", selection: $category) {
                        ForEach(MilestoneCategory.allCases) { Label($0.title, systemImage: $0.icon).tag($0) }
                    }
                }.listRowBackground(Theme.card)
                Section {
                    Picker("Tracking", selection: $source) {
                        ForEach(MilestoneSource.allCases) { Text($0.title).tag($0) }
                    }
                    if source == .exerciseBest {
                        TextField("Exercise name (as logged)", text: $exercise)
                    }
                    TextField("Unit (kg, reps, days…)", text: $unit)
                    NumberField("Starting value", value: $start)
                    NumberField("Target value", value: $target)
                } header: { Text("Measure") } footer: {
                    Text("Targets can go up (bench 100 kg) or down (reach 80 kg from 90 kg).")
                }.listRowBackground(Theme.card)
                Section {
                    Toggle("Target date", isOn: $hasDate).tint(Theme.orange)
                    if hasDate { DatePicker("Date", selection: $date, in: Date()..., displayedComponents: .date) }
                }.listRowBackground(Theme.card)
            }
            .warmForm()
            .keyboardDoneToolbar()
            .navigationTitle(milestone == nil ? "New milestone" : "Edit milestone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { Button("Save") { save() }.fontWeight(.semibold).disabled(!canSave) }
            }
            .onAppear {
                guard let m = milestone else { return }
                title = m.title; details = m.details; category = m.category; source = m.source
                exercise = m.autoExercise; unit = m.unit; start = m.startValue; target = m.targetValue
                if let d = m.targetDate { hasDate = true; date = d }
            }
        }
    }

    private func apply(_ p: Preset) {
        title = p.title; category = p.category; unit = p.unit; source = p.source; target = p.target; exercise = p.exercise
        switch p.source {
        case .bodyWeight: start = weights.sorted { $0.date > $1.date }.first?.kg
        case .exerciseBest:
            let best = ExerciseAnalytics.records(for: p.exercise, in: sessions).heaviest
            start = best > 0 ? best : nil
        case .workoutsThisMonth, .mobilityThisMonth: start = 0
        case .manual: start = nil
        }
        Haptics.select()
    }

    private func save() {
        guard let start, let target else { return }
        let m = milestone ?? Milestone(title: title)
        m.title = title.trimmed
        m.details = details.trimmed
        m.category = category
        m.source = source
        m.autoExercise = exercise.trimmed
        m.unit = unit.trimmed
        m.targetValue = target
        m.targetDate = hasDate ? date : nil
        if milestone == nil {
            m.startValue = start
            m.currentValue = start
            context.insert(m)
            context.insert(MilestoneUpdate(milestoneID: m.id, value: start, note: "Started"))
        } else {
            m.startValue = start
        }
        context.saveQuietly()
        _ = MilestoneSync.sync(context)
        Haptics.success()
        dismiss()
    }
}
