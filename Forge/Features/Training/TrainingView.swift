import SwiftUI
import SwiftData
import Charts

struct TrainingView: View {
    enum Section: String, CaseIterable, Identifiable {
        case gym = "Gym", mobility = "Mobility"
        var id: String { rawValue }
    }
    @State private var section: Section = .gym

    var body: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $section) {
                ForEach(Section.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Theme.pad)
            .padding(.vertical, 8)
            switch section {
            case .gym: GymView()
            case .mobility: MobilityView()
            }
        }
        .screenBackground()
        .navigationTitle("Training")
    }
}

// MARK: - Gym

struct GymView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var appState: AppState
    @Query(sort: \Routine.sortOrder) private var routines: [Routine]
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @Query private var profiles: [UserProfile]

    @State private var editing: Routine?
    @State private var creating = false
    @State private var showTemplates = false
    @State private var activeSession: WorkoutSession?
    @State private var pendingDelete: Routine?

    private var finished: [WorkoutSession] { sessions.filter { $0.isFinished } }
    private var open: WorkoutSession? { sessions.first { !$0.isFinished } }
    private var weekSessions: [WorkoutSession] {
        let start = Date().startOfWeek
        return finished.filter { $0.date >= start }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let open { resumeCard(open) }
                weekCard
                routinesSection
                libraryLinks
                recentSection
            }
            .padding(.horizontal, Theme.pad)
            .padding(.bottom, 40)
        }
        .sheet(item: $editing) { RoutineEditor(routine: $0) }
        .sheet(isPresented: $creating) { RoutineEditor(routine: nil) }
        .sheet(isPresented: $showTemplates) { TemplatePicker() }
        .fullScreenCover(item: $activeSession) { WorkoutSessionView(session: $0) }
        .onChange(of: appState.startWorkoutRequest) { _, v in
            if v {
                appState.startWorkoutRequest = false
                start(nil)
            }
        }
        .confirmationDialog("Delete this routine?", isPresented: Binding(get: { pendingDelete != nil },
                                                                         set: { if !$0 { pendingDelete = nil } }),
                            titleVisibility: .visible) {
            Button("Delete routine", role: .destructive) {
                if let r = pendingDelete { context.delete(r); context.saveQuietly() }
                pendingDelete = nil
            }
        } message: { Text("Past workouts stay in your history.") }
    }

    private func start(_ r: Routine?) {
        activeSession = WorkoutLauncher.start(routine: r, context: context, sessions: sessions)
    }

    // MARK: Pieces

    private func resumeCard(_ s: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Workout in progress", systemImage: "play.circle.fill")
                .font(.headline).foregroundStyle(Theme.accentText)
            Text("\(s.name) · started \(s.date.timeString)").font(.subheadline).foregroundStyle(Theme.textSecondary)
            Button("Resume") { activeSession = s }.buttonStyle(PrimaryButtonStyle())
        }
        .card(fill: Theme.softAccent)
    }

    private var weekCard: some View {
        let vol = weekSessions.reduce(0) { $0 + $1.totalVolume }
        let target = max(1, profiles.first?.weeklyTrainingDays ?? 3)
        return VStack(alignment: .leading, spacing: 14) {
            SectionTitle("This week", subtitle: "\(weekSessions.count) workouts · \(Int(vol).formatted()) kg volume")
            HStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { i in
                    let d = Date().startOfWeek.addingDays(i)
                    let trained = finished.contains { $0.date.isSameDay(as: d) }
                    let planned = routines.contains { $0.weekday == d.weekday }
                    VStack(spacing: 6) {
                        Text(d.weekdayInitial).font(.caption2.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                        ZStack {
                            Circle().fill(trained ? AnyShapeStyle(Theme.buttonGradient) : AnyShapeStyle(Theme.cardAlt))
                            if trained { Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(.white) }
                            else if planned { Circle().stroke(Theme.orange, lineWidth: 1.5).padding(6) }
                        }
                        .frame(width: 34, height: 34)
                        .overlay(Circle().stroke(d.isToday ? Theme.orange : .clear, lineWidth: 1.5).padding(-3))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            LinearProgressBar(progress: Double(weekSessions.count) / Double(target))
        }
        .card()
    }

    private var routinesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Routines", subtitle: routines.isEmpty ? nil : "Organised by training day") {
                Menu {
                    Button { creating = true } label: { Label("New routine", systemImage: "plus") }
                    Button { showTemplates = true } label: { Label("From template", systemImage: "square.on.square") }
                } label: {
                    Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(Theme.orange)
                }
            }
            if routines.isEmpty {
                VStack(spacing: 10) {
                    EmptyState(icon: "dumbbell", title: "Build your first routine",
                               message: "Create your own, or start from a template and edit it.")
                    HStack {
                        Button("New routine") { creating = true }.buttonStyle(PrimaryButtonStyle(compact: true))
                        Button("Templates") { showTemplates = true }.buttonStyle(SoftButtonStyle(compact: true))
                    }
                }
                .card()
            }
            ForEach(routines) { r in
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        IconBadge(systemName: r.type.icon, size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(r.name).font(.headline).foregroundStyle(Theme.text)
                            Text("\(r.type.title) · \(weekdayName(r.weekday)) · \(r.exercises.count) exercises")
                                .font(.caption).foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                        Menu {
                            Button { editing = r } label: { Label("Edit", systemImage: "pencil") }
                            Button { duplicate(r) } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
                            Button(role: .destructive) { pendingDelete = r } label: { Label("Delete", systemImage: "trash") }
                        } label: {
                            Image(systemName: "ellipsis.circle").font(.title3).foregroundStyle(Theme.textSecondary)
                        }
                    }
                    if !r.exercises.isEmpty {
                        Text(r.exercises.prefix(4).map(\.name).joined(separator: " · ") + (r.exercises.count > 4 ? " …" : ""))
                            .font(.footnote).foregroundStyle(Theme.textSecondary).lineLimit(2)
                    }
                    Button("Start") { start(r) }.buttonStyle(SoftButtonStyle(compact: true))
                }
                .card()
            }
            Button { start(nil) } label: { Label("Quick workout (no routine)", systemImage: "bolt") }
                .buttonStyle(SoftButtonStyle())
        }
    }

    private func duplicate(_ r: Routine) {
        let copy = Routine(name: r.name + " copy", type: r.type, weekday: 0, exercises: r.exercises)
        copy.sortOrder = (routines.map(\.sortOrder).max() ?? 0) + 1
        context.insert(copy)
        context.saveQuietly()
    }

    private var libraryLinks: some View {
        VStack(spacing: 10) {
            NavigationLink { ExerciseListView() } label: {
                linkRow("chart.line.uptrend.xyaxis", "Exercises & personal records", "Progress chart for every lift")
            }
            NavigationLink { WorkoutHistoryView() } label: {
                linkRow("clock.arrow.circlepath", "Workout history", "\(finished.count) sessions logged")
            }
        }
        .buttonStyle(.plain)
    }

    private func linkRow(_ icon: String, _ title: String, _ sub: String) -> some View {
        HStack(spacing: 14) {
            IconBadge(systemName: icon, size: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text)
                Text(sub).font(.caption).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.textSecondary)
        }
        .card(padding: 14)
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !finished.isEmpty {
                SectionTitle("Recent")
                ForEach(finished.prefix(3)) { s in
                    NavigationLink { WorkoutDetailView(session: s) } label: { sessionRow(s) }
                        .buttonStyle(.plain)
                }
            }
        }
    }
}

func weekdayName(_ weekday: Int) -> String {
    guard (1...7).contains(weekday) else { return "Any day" }
    return Calendar.current.weekdaySymbols[weekday - 1]
}

func sessionRow(_ s: WorkoutSession) -> some View {
    HStack(spacing: 12) {
        IconBadge(systemName: s.type.icon, size: 40)
        VStack(alignment: .leading, spacing: 2) {
            Text(s.name).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text)
            Text("\(s.date.formatted("EEEdMMM")) · \(formatMinutes(s.durationSeconds)) · \(s.totalSets) sets")
                .font(.caption).foregroundStyle(Theme.textSecondary)
        }
        Spacer()
        Text("\(Int(s.totalVolume).formatted()) kg").font(.caption.weight(.semibold)).foregroundStyle(Theme.accentText)
    }
    .card(padding: 14)
}

// MARK: - Routine editor

struct RoutineEditor: View {
    let routine: Routine?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var routines: [Routine]

    @State private var name = ""
    @State private var type: TrainingType = .hypertrophy
    @State private var weekday = 0
    @State private var notes = ""
    @State private var exercises: [RoutineExercise] = []
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Routine name (e.g. Push Day)", text: $name)
                    Picker("Type", selection: $type) {
                        ForEach(TrainingType.allCases) { Label($0.title, systemImage: $0.icon).tag($0) }
                    }
                    Picker("Training day", selection: $weekday) {
                        Text("Any day").tag(0)
                        ForEach(1...7, id: \.self) { Text(weekdayName($0)).tag($0) }
                    }
                }.listRowBackground(Theme.card)

                Section("Exercises") {
                    ForEach($exercises) { $ex in
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Exercise", text: $ex.name).font(.headline)
                            Toggle("Timed", isOn: $ex.isTimed).tint(Theme.orange)
                            IntStepperRow(title: "Sets", value: $ex.sets, range: 1...20)
                            IntStepperRow(title: ex.isTimed ? "Minutes / set" : "Reps", value: $ex.reps, range: 1...100)
                            IntStepperRow(title: "Rest", value: $ex.restSeconds, range: 0...600, step: 15, unit: "s")
                            TextField("Notes", text: $ex.notes)
                                .font(.footnote).foregroundStyle(Theme.textSecondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { exercises.remove(atOffsets: $0) }
                    .onMove { exercises.move(fromOffsets: $0, toOffset: $1) }
                    Button { exercises.append(RoutineExercise(name: "")) } label: {
                        Label("Add exercise", systemImage: "plus")
                    }
                }.listRowBackground(Theme.card)

                Section("Notes") {
                    TextField("Routine notes", text: $notes, axis: .vertical).lineLimit(2...5)
                }.listRowBackground(Theme.card)
            }
            .warmForm()
            .keyboardDoneToolbar()
            .navigationTitle(routine == nil ? "New routine" : "Edit routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }.fontWeight(.semibold).disabled(name.trimmed.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) { EditButton() }
            }
            .onAppear {
                guard !loaded, let r = routine else { return }
                name = r.name; type = r.type; weekday = r.weekday; notes = r.notes; exercises = r.exercises
                loaded = true
            }
        }
    }

    private func save() {
        let cleaned = exercises.filter { !$0.name.trimmed.isEmpty }
        if let r = routine {
            r.name = name.trimmed; r.type = type; r.weekday = weekday; r.notes = notes; r.exercises = cleaned
        } else {
            let r = Routine(name: name.trimmed, type: type, weekday: weekday, exercises: cleaned)
            r.notes = notes
            r.sortOrder = (routines.map(\.sortOrder).max() ?? 0) + 1
            context.insert(r)
        }
        context.saveQuietly()
        Haptics.success()
        dismiss()
    }
}

struct TemplatePicker: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var routines: [Routine]

    var body: some View {
        NavigationStack {
            List(RoutineTemplates.all) { t in
                Button {
                    let r = Routine(name: t.name, type: t.type, weekday: 0, exercises: t.exercises)
                    r.sortOrder = (routines.map(\.sortOrder).max() ?? 0) + 1
                    context.insert(r)
                    context.saveQuietly()
                    Haptics.success()
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        IconBadge(systemName: t.type.icon, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t.name).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text)
                            Text("\(t.type.title) · " + t.exercises.map(\.name).prefix(3).joined(separator: ", "))
                                .font(.caption).foregroundStyle(Theme.textSecondary).lineLimit(1)
                        }
                    }
                }
                .listRowBackground(Theme.card)
            }
            .warmForm()
            .navigationTitle("Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } } }
        }
    }
}

// MARK: - History & records

struct WorkoutHistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    private var finished: [WorkoutSession] { sessions.filter { $0.isFinished } }

    var body: some View {
        List {
            if finished.isEmpty {
                EmptyState(icon: "clock.arrow.circlepath", title: "No workouts yet", message: "Finished sessions appear here.")
                    .listRowBackground(Color.clear)
            }
            ForEach(finished) { s in
                NavigationLink { WorkoutDetailView(session: s) } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.name).font(.subheadline.weight(.semibold))
                        Text("\(s.date.formatted("EEEdMMMy")) · \(formatMinutes(s.durationSeconds)) · \(Int(s.totalVolume).formatted()) kg")
                            .font(.caption).foregroundStyle(Theme.textSecondary)
                    }
                }
                .listRowBackground(Theme.card)
            }
            .onDelete { idx in
                for i in idx { context.delete(finished[i]) }
                context.saveQuietly()
            }
        }
        .warmForm()
        .navigationTitle("History")
    }
}

struct WorkoutDetailView: View {
    let session: WorkoutSession
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    StatTile(value: formatMinutes(session.durationSeconds), label: "Duration")
                    StatTile(value: "\(session.totalSets)", label: "Sets")
                    StatTile(value: Int(session.totalVolume).formatted(), label: "Volume kg")
                }
                ForEach(session.exercises) { ex in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(ex.name).font(Theme.display(19))
                        ForEach(Array(ex.sets.filter { $0.done }.enumerated()), id: \.element.id) { i, s in
                            HStack {
                                Text(s.isWarmup ? "Warm-up" : "Set \(i + 1)").foregroundStyle(Theme.textSecondary)
                                Spacer()
                                Text(ex.isTimed ? "\(s.durationMin.clean) min" : "\(s.weightKg.clean) kg × \(s.reps)")
                                    .fontWeight(.semibold).monospacedDigit()
                            }
                            .font(.subheadline)
                        }
                        if !ex.notes.isEmpty { Text(ex.notes).font(.footnote).foregroundStyle(Theme.textSecondary) }
                    }
                    .card()
                }
                if !session.notes.isEmpty { Text(session.notes).card() }
                Button("Delete workout", role: .destructive) {
                    context.delete(session)
                    context.saveQuietly()
                    dismiss()
                }
                .frame(maxWidth: .infinity)
            }
            .padding(Theme.pad)
        }
        .screenBackground()
        .navigationTitle(session.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ExerciseListView: View {
    @Query private var sessions: [WorkoutSession]
    @State private var search = ""

    private var names: [String] {
        let all = ExerciseAnalytics.exerciseNames(in: sessions.filter { $0.isFinished })
        return search.isEmpty ? all : all.filter { $0.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        List {
            if names.isEmpty {
                EmptyState(icon: "chart.line.uptrend.xyaxis", title: "No exercises yet",
                           message: "Complete a workout and every lift gets its own progression chart.")
                    .listRowBackground(Color.clear)
            }
            ForEach(names, id: \.self) { n in
                let r = ExerciseAnalytics.records(for: n, in: sessions)
                NavigationLink { ExerciseHistoryView(name: n) } label: {
                    HStack {
                        Text(n).font(.subheadline.weight(.semibold))
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("\(r.heaviest.clean) kg").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accentText)
                            Text("best").font(.caption2).foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
                .listRowBackground(Theme.card)
            }
        }
        .warmForm()
        .searchable(text: $search)
        .navigationTitle("Exercises")
    }
}

struct ExerciseHistoryView: View {
    let name: String
    @Query private var sessions: [WorkoutSession]
    @State private var metric: Metric = .weight

    enum Metric: String, CaseIterable, Identifiable {
        case weight = "Top weight", e1rm = "Est. 1RM", volume = "Volume"
        var id: String { rawValue }
    }

    var body: some View {
        let pts = ExerciseAnalytics.history(for: name, in: sessions)
        let rec = ExerciseAnalytics.records(for: name, in: sessions)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 10) {
                    StatTile(value: "\(rec.heaviest.clean) kg", label: "Heaviest", icon: "trophy")
                    StatTile(value: "\(rec.best1RM.whole) kg", label: "Est. 1RM", icon: "bolt")
                    StatTile(value: Int(rec.bestSetVolume).formatted(), label: "Best set kg", icon: "scalemass")
                }
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Metric", selection: $metric) {
                        ForEach(Metric.allCases) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.segmented)
                    if pts.count < 2 {
                        Text("Log this exercise in at least two workouts to see a trend.")
                            .font(.footnote).foregroundStyle(Theme.textSecondary).padding(.vertical, 30)
                    } else {
                        Chart(pts) { p in
                            LineMark(x: .value("Date", p.date), y: .value(metric.rawValue, value(p)))
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(Theme.orange)
                                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            PointMark(x: .value("Date", p.date), y: .value(metric.rawValue, value(p)))
                                .foregroundStyle(Theme.deepOrange)
                        }
                        .chartYScale(domain: .automatic(includesZero: false))
                        .frame(height: 200)
                        if let first = pts.first, let last = pts.last {
                            let d = value(last) - value(first)
                            Text("\(d >= 0 ? "+" : "−")\(abs(d).clean) since \(first.date.shortDate)")
                                .font(.footnote.weight(.semibold)).foregroundStyle(Theme.accentText)
                        }
                    }
                }
                .card()
                VStack(alignment: .leading, spacing: 8) {
                    SectionTitle("Sessions")
                    ForEach(pts.reversed()) { p in
                        HStack {
                            Text(p.date.formatted("dMMMy")).foregroundStyle(Theme.textSecondary)
                            Spacer()
                            Text("\(p.bestWeight.clean) kg · vol \(Int(p.volume).formatted())").monospacedDigit()
                        }
                        .font(.subheadline)
                        Divider().overlay(Theme.hairline)
                    }
                }
                .card()
            }
            .padding(Theme.pad)
        }
        .screenBackground()
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func value(_ p: ExercisePoint) -> Double {
        switch metric {
        case .weight: return p.bestWeight
        case .e1rm: return p.bestE1RM
        case .volume: return p.volume
        }
    }
}
