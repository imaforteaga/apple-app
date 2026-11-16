import SwiftUI
import SwiftData

enum WorkoutLauncher {
    /// Starts a session from a routine (or empty). Resumes an unfinished session if one exists.
    @MainActor
    static func start(routine: Routine?, context: ModelContext, sessions: [WorkoutSession]) -> WorkoutSession {
        if let open = sessions.first(where: { !$0.isFinished }) { return open }

        var logged: [LoggedExercise] = []
        if let r = routine {
            for ex in r.exercises {
                let last = ExerciseAnalytics.lastPerformance(of: ex.name, in: sessions)
                let lastSets = (last?.sets ?? []).filter { $0.done && !$0.isWarmup }
                var sets: [LoggedSet] = []
                for i in 0..<max(ex.sets, 1) {
                    var s = LoggedSet()
                    if ex.isTimed {
                        s.durationMin = Double(ex.reps)
                    } else {
                        s.reps = ex.reps
                        if i < lastSets.count {
                            s.weightKg = lastSets[i].weightKg
                            s.reps = lastSets[i].reps
                        } else if let w = lastSets.last?.weightKg {
                            s.weightKg = w
                        }
                    }
                    sets.append(s)
                }
                logged.append(LoggedExercise(name: ex.name, notes: "", isTimed: ex.isTimed,
                                             restSeconds: ex.restSeconds, sets: sets))
            }
        }
        let session = WorkoutSession(name: routine?.name ?? "Quick workout",
                                     type: routine?.type ?? .hypertrophy,
                                     routineID: routine?.id, exercises: logged)
        session.date = Date()
        context.insert(session)
        context.saveQuietly()
        return session
    }
}

struct WorkoutSessionView: View {
    @Bindable var session: WorkoutSession
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @Query private var allSessions: [WorkoutSession]

    @State private var now = Date()
    @State private var restEnd: Date?
    @State private var restTotal = 0
    @State private var showAdd = false
    @State private var confirmFinish = false
    @State private var confirmDiscard = false
    @State private var summary: WorkoutSummary?

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var exercises: [LoggedExercise] { session.exercises }
    private var finishedBefore: [WorkoutSession] { allSessions.filter { $0.isFinished && $0.id != session.id } }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 16) {
                        header
                        if exercises.isEmpty {
                            EmptyState(icon: "dumbbell", title: "No exercises yet",
                                       message: "Add the exercises you want to do in this session.",
                                       actionTitle: "Add exercise") { showAdd = true }
                        }
                        ForEach(exercises) { ex in
                            ExerciseCard(
                                exercise: ex,
                                last: ExerciseAnalytics.lastPerformance(of: ex.name, in: finishedBefore),
                                update: { mutation in update(ex.id, mutation) },
                                onSetCompleted: { startRest(ex.restSeconds) },
                                onRemove: { remove(ex.id) })
                        }
                        Button { showAdd = true } label: { Label("Add exercise", systemImage: "plus") }
                            .buttonStyle(SoftButtonStyle())
                        TextField("Session notes", text: $session.notes, axis: .vertical)
                            .lineLimit(2...5)
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.card))
                        Button("Discard workout", role: .destructive) { confirmDiscard = true }
                            .font(.footnote)
                            .padding(.top, 6)
                        Color.clear.frame(height: restEnd == nil ? 20 : 90)
                    }
                    .padding(Theme.pad)
                }
                .scrollDismissesKeyboard(.interactively)

                if let restEnd {
                    restBar(end: restEnd)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .screenBackground()
            .navigationTitle(session.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "chevron.down") }
                        .accessibilityLabel("Minimize workout")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Finish") { confirmFinish = true }.fontWeight(.semibold)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddExerciseSheet(history: finishedBefore) { name, timed in addExercise(name, timed: timed) }
            }
            .sheet(item: $summary, onDismiss: { dismiss() }) { s in
                WorkoutSummaryView(summary: s)
            }
            .confirmationDialog("Finish workout?", isPresented: $confirmFinish, titleVisibility: .visible) {
                Button("Finish and save") { finish() }
                Button("Keep training", role: .cancel) {}
            } message: {
                Text("Only completed sets are counted.")
            }
            .confirmationDialog("Discard this workout?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("Discard", role: .destructive) {
                    NotificationService.cancelRestEnd()
                    context.delete(session)
                    context.saveQuietly()
                    dismiss()
                }
            }
            .onReceive(ticker) { t in
                now = t
                if let end = restEnd, t >= end {
                    Haptics.success()
                    withAnimation(Motion.soft) { restEnd = nil }
                }
            }
        }
    }

    // MARK: Header

    private var header: some View {
        let done = exercises.reduce(0) { $0 + $1.completedSets }
        let total = exercises.reduce(0) { $0 + $1.sets.count }
        return VStack(spacing: 12) {
            HStack {
                statBlock(formatDuration(Int(now.timeIntervalSince(session.date))), "Time")
                statBlock("\(done)/\(total)", "Sets")
                statBlock(Int(session.totalVolume).formatted(), "Volume kg")
            }
            LinearProgressBar(progress: total == 0 ? 0 : Double(done) / Double(total), height: 8)
        }
        .card()
    }

    private func statBlock(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(Theme.number(24)).foregroundStyle(Theme.text).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Rest timer

    private func restBar(end: Date) -> some View {
        let remaining = max(0, Int(ceil(end.timeIntervalSince(now))))
        return HStack(spacing: 14) {
            ZStack {
                ProgressRing(progress: restTotal > 0 ? Double(remaining) / Double(restTotal) : 0, lineWidth: 5)
                    .frame(width: 44, height: 44)
                Image(systemName: "timer").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.orange)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(formatDuration(remaining)).font(Theme.number(28)).monospacedDigit().foregroundStyle(Theme.text)
                Text("Rest").font(.caption).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Button("+15s") { extendRest(15) }.buttonStyle(SoftButtonStyle(compact: true))
            Button("Skip") { stopRest() }.buttonStyle(PrimaryButtonStyle(compact: true))
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.card))
        .shadow(color: .black.opacity(0.15), radius: 16, y: 6)
        .padding(.horizontal, Theme.pad)
        .padding(.bottom, 8)
    }

    private func startRest(_ seconds: Int) {
        guard seconds > 0 else { return }
        restTotal = seconds
        now = Date()
        withAnimation(Motion.soft) { restEnd = Date().addingTimeInterval(TimeInterval(seconds)) }
        NotificationService.scheduleRestEnd(after: seconds)
    }

    private func extendRest(_ s: Int) {
        guard let e = restEnd else { return }
        restEnd = e.addingTimeInterval(TimeInterval(s))
        restTotal += s
        NotificationService.scheduleRestEnd(after: max(1, Int(restEnd!.timeIntervalSinceNow)))
    }

    private func stopRest() {
        NotificationService.cancelRestEnd()
        withAnimation(Motion.soft) { restEnd = nil }
    }

    // MARK: Mutations

    private func update(_ id: UUID, _ mutation: (inout LoggedExercise) -> Void) {
        var list = session.exercises
        guard let i = list.firstIndex(where: { $0.id == id }) else { return }
        mutation(&list[i])
        session.exercises = list
        context.saveQuietly()
    }

    private func remove(_ id: UUID) {
        var list = session.exercises
        list.removeAll { $0.id == id }
        session.exercises = list
        context.saveQuietly()
    }

    private func addExercise(_ name: String, timed: Bool) {
        var list = session.exercises
        let last = ExerciseAnalytics.lastPerformance(of: name, in: finishedBefore)
        var sets: [LoggedSet] = []
        let lastSets = (last?.sets ?? []).filter { $0.done && !$0.isWarmup }
        if lastSets.isEmpty {
            sets = (0..<3).map { _ in LoggedSet(reps: timed ? 0 : 10, durationMin: timed ? 10 : 0) }
        } else {
            sets = lastSets.map { LoggedSet(reps: $0.reps, weightKg: $0.weightKg, durationMin: $0.durationMin) }
        }
        list.append(LoggedExercise(name: name, isTimed: timed, restSeconds: timed ? 60 : 90, sets: sets))
        session.exercises = list
        context.saveQuietly()
    }

    private func finish() {
        stopRest()
        // Drop exercises with no completed sets so history stays clean.
        let kept = session.exercises.filter { $0.completedSets > 0 }
        if kept.isEmpty {
            context.delete(session)
            context.saveQuietly()
            dismiss()
            return
        }
        session.exercises = kept
        session.isFinished = true
        session.endDate = Date()
        context.saveQuietly()

        var prs: [String] = []
        for ex in kept where !ex.isTimed {
            let prev = ExerciseAnalytics.records(for: ex.name, in: finishedBefore).heaviest
            let best = ex.sets.filter { $0.done && !$0.isWarmup }.map(\.weightKg).max() ?? 0
            if best > prev && best > 0 { prs.append("\(ex.name): \(best.clean) kg") }
        }
        summary = WorkoutSummary(name: session.name, duration: session.durationSeconds,
                                 volume: session.totalVolume, sets: session.totalSets, prs: prs)

        let completed = MilestoneSync.sync(context)
        if let first = completed.first {
            appState.achievement = AchievementInfo(title: first.title, subtitle: "Your training made this happen.")
        }
        Haptics.success()
    }
}

struct WorkoutSummary: Identifiable {
    let id = UUID()
    let name: String
    let duration: Int
    let volume: Double
    let sets: Int
    let prs: [String]
}

struct WorkoutSummaryView: View {
    let summary: WorkoutSummary
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "checkmark")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(Circle().fill(Theme.brandGradient))
                .padding(.top, 30)
            Text("Workout complete").font(Theme.display(28)).foregroundStyle(Theme.text)
            Text(summary.name).foregroundStyle(Theme.textSecondary)
            HStack(spacing: 10) {
                StatTile(value: formatMinutes(summary.duration), label: "Duration")
                StatTile(value: "\(summary.sets)", label: "Sets")
                StatTile(value: Int(summary.volume).formatted(), label: "Volume kg")
            }
            if !summary.prs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("New personal records", systemImage: "trophy")
                        .font(.headline).foregroundStyle(Theme.accentText)
                    ForEach(summary.prs, id: \.self) { Text($0).font(.subheadline) }
                }
                .card()
            }
            Spacer()
            Button("Done") { dismiss() }.buttonStyle(PrimaryButtonStyle())
        }
        .padding(Theme.pad)
        .screenBackground()
        .presentationDetents([.large])
    }
}

// MARK: - Exercise card

private struct ExerciseCard: View {
    let exercise: LoggedExercise
    let last: LoggedExercise?
    let update: ((inout LoggedExercise) -> Void) -> Void
    let onSetCompleted: () -> Void
    let onRemove: () -> Void

    @State private var notes = ""
    @State private var showNotes = false

    private var lastText: String? {
        guard let last else { return nil }
        let sets = last.sets.filter { $0.done && !$0.isWarmup }
        guard !sets.isEmpty else { return nil }
        if last.isTimed { return "Last: " + sets.map { "\($0.durationMin.clean) min" }.joined(separator: ", ") }
        return "Last: " + sets.prefix(4).map { "\($0.weightKg.clean)×\($0.reps)" }.joined(separator: "  ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(exercise.name).font(Theme.display(20)).foregroundStyle(Theme.text)
                    if let lastText {
                        Text(lastText).font(.caption).foregroundStyle(Theme.textSecondary)
                    }
                }
                Spacer()
                Menu {
                    Button { showNotes.toggle() } label: { Label("Notes", systemImage: "note.text") }
                    Button { update { $0.sets.append(LoggedSet(reps: 0, weightKg: 0, isWarmup: true)) } } label: {
                        Label("Add warm-up set", systemImage: "flame")
                    }
                    Button(role: .destructive, action: onRemove) { Label("Remove exercise", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis.circle").font(.title3).foregroundStyle(Theme.textSecondary)
                }
            }

            HStack(spacing: 8) {
                Text("SET").frame(width: 34, alignment: .leading)
                Text(exercise.isTimed ? "MINUTES" : "KG").frame(maxWidth: .infinity)
                Text(exercise.isTimed ? "" : "REPS").frame(maxWidth: .infinity)
                Color.clear.frame(width: 40, height: 1)
            }
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Theme.textSecondary)

            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { idx, set in
                setRow(idx: idx, set: set)
            }

            HStack {
                Button { addSet() } label: { Label("Add set", systemImage: "plus") }
                    .buttonStyle(SoftButtonStyle(compact: true))
                if exercise.sets.count > 1 {
                    Button { update { $0.sets.removeLast() } } label: { Label("Remove", systemImage: "minus") }
                        .buttonStyle(SoftButtonStyle(compact: true))
                }
                Spacer()
                if !exercise.isTimed {
                    Text("Vol \(Int(exercise.volume)) kg").font(.caption).foregroundStyle(Theme.textSecondary)
                }
            }

            if showNotes || !exercise.notes.isEmpty {
                TextField("Exercise notes", text: Binding(
                    get: { exercise.notes },
                    set: { n in update { $0.notes = n } }), axis: .vertical)
                    .font(.footnote)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.cardAlt))
            }
        }
        .card()
    }

    private func setRow(idx: Int, set: LoggedSet) -> some View {
        let warm = set.isWarmup
        return HStack(spacing: 8) {
            Text(warm ? "W" : "\(exercise.sets[0..<idx].filter { !$0.isWarmup }.count + 1)")
                .font(.system(.subheadline, design: .default, weight: .bold))
                .foregroundStyle(warm ? Theme.orange : Theme.text)
                .frame(width: 34, alignment: .leading)
            if exercise.isTimed {
                field(Binding(get: { set.durationMin },
                              set: { v in update { $0.sets[idx].durationMin = v } }))
                Color.clear.frame(maxWidth: .infinity, minHeight: 1)
            } else {
                field(Binding(get: { set.weightKg },
                              set: { v in update { $0.sets[idx].weightKg = v } }))
                TextField("0", value: Binding(get: { set.reps },
                                              set: { v in update { $0.sets[idx].reps = max(0, v) } }),
                          format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(Theme.number(18))
                    .padding(.vertical, 9)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.cardAlt))
            }
            Button {
                let willBeDone = !set.done
                update { $0.sets[idx].done = willBeDone }
                Haptics.medium()
                if willBeDone && !warm { onSetCompleted() }
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(set.done ? Color.white : Theme.hairline)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(set.done ? AnyShapeStyle(Theme.buttonGradient) : AnyShapeStyle(Theme.cardAlt)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(set.done ? "Set \(idx + 1) completed" : "Complete set \(idx + 1)")
        }
        .opacity(set.done ? 0.75 : 1)
    }

    private func field(_ binding: Binding<Double>) -> some View {
        TextField("0", value: binding, format: .number)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.center)
            .font(Theme.number(18))
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.cardAlt))
    }

    private func addSet() {
        update { ex in
            var s = ex.sets.last(where: { !$0.isWarmup }) ?? LoggedSet()
            s.id = UUID()
            s.done = false
            s.isWarmup = false
            ex.sets.append(s)
        }
    }
}

// MARK: - Add exercise

struct AddExerciseSheet: View {
    let history: [WorkoutSession]
    var onAdd: (String, Bool) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var timed = false

    private static let common = [
        "Bench Press", "Incline Dumbbell Press", "Overhead Press", "Lateral Raise", "Triceps Pushdown",
        "Pull-Up", "Barbell Row", "Seated Cable Row", "Lat Pulldown", "Face Pull", "Biceps Curl",
        "Back Squat", "Front Squat", "Deadlift", "Romanian Deadlift", "Leg Press", "Leg Curl",
        "Walking Lunge", "Hip Thrust", "Standing Calf Raise", "Power Clean", "Dips", "Push-Up"
    ]

    private var suggestions: [String] {
        var seen = Set<String>()
        let pool = ExerciseAnalytics.exerciseNames(in: history) + Self.common
        let q = name.trimmed.lowercased()
        return pool.filter { n in
            let k = n.lowercased()
            guard !seen.contains(k) else { return false }
            seen.insert(k)
            return q.isEmpty || k.contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Exercise name", text: $name)
                    Toggle("Timed (minutes instead of reps)", isOn: $timed).tint(Theme.orange)
                    if !name.trimmed.isEmpty {
                        Button("Add “\(name.trimmed)”") { add(name.trimmed) }.fontWeight(.semibold)
                    }
                }.listRowBackground(Theme.card)
                Section("Suggestions") {
                    ForEach(suggestions.prefix(40), id: \.self) { s in
                        Button(s) { add(s) }.foregroundStyle(Theme.text)
                    }
                }.listRowBackground(Theme.card)
            }
            .warmForm()
            .navigationTitle("Add exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } } }
        }
    }

    private func add(_ n: String) {
        onAdd(n, timed)
        dismiss()
    }
}
