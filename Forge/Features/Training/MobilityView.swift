import SwiftUI
import SwiftData

struct MobilityView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \MobilityRoutine.createdAt) private var custom: [MobilityRoutine]
    @Query(sort: \MobilitySession.date, order: .reverse) private var sessions: [MobilitySession]

    @State private var playing: MobilityRoutineInfo?
    @State private var editing: MobilityRoutine?
    @State private var creating = false
    @State private var manual = false

    private var all: [MobilityRoutineInfo] {
        MobilityLibrary.builtIn + custom.map {
            MobilityRoutineInfo(id: $0.id.uuidString, name: $0.name, category: $0.category, steps: $0.steps, isBuiltIn: false)
        }
    }
    private var weekCount: Int { sessions.filter { $0.date >= Date().startOfWeek }.count }
    private var weekSeconds: Int { sessions.filter { $0.date >= Date().startOfWeek }.reduce(0) { $0 + $1.durationSeconds } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                consistencyCard
                ForEach(MobilityCategory.allCases) { cat in
                    let items = all.filter { $0.category == cat }
                    if !items.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionTitle(cat.title)
                            ForEach(items) { r in routineRow(r) }
                        }
                    }
                }
                HStack {
                    Button { creating = true } label: { Label("Custom routine", systemImage: "plus") }
                        .buttonStyle(PrimaryButtonStyle(compact: true))
                    Button { manual = true } label: { Label("Log session", systemImage: "square.and.pencil") }
                        .buttonStyle(SoftButtonStyle(compact: true))
                }
                recent
                Text("Move gently and stop if you feel sharp pain. This is general guidance, not medical advice.")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, Theme.pad)
            .padding(.bottom, 40)
        }
        .fullScreenCover(item: $playing) { MobilityPlayerView(routine: $0) }
        .sheet(item: $editing) { MobilityRoutineEditor(routine: $0) }
        .sheet(isPresented: $creating) { MobilityRoutineEditor(routine: nil) }
        .sheet(isPresented: $manual) { ManualMobilitySheet() }
    }

    private var consistencyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle("Consistency", subtitle: "\(weekCount) sessions · \(formatMinutes(weekSeconds)) this week")
            HStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { i in
                    let d = Date().startOfWeek.addingDays(i)
                    let n = sessions.filter { $0.date.isSameDay(as: d) }.count
                    VStack(spacing: 6) {
                        Text(d.weekdayInitial).font(.caption2.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                        Circle()
                            .fill(n > 0 ? AnyShapeStyle(Theme.buttonGradient) : AnyShapeStyle(Theme.cardAlt))
                            .frame(width: 30, height: 30)
                            .overlay(Group { if n > 0 { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.white) } })
                            .overlay(Circle().stroke(d.isToday ? Theme.orange : .clear, lineWidth: 1.5).padding(-3))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .card()
    }

    private func routineRow(_ r: MobilityRoutineInfo) -> some View {
        HStack(spacing: 12) {
            IconBadge(systemName: r.category.icon, size: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text(r.name).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text)
                Text("\(formatMinutes(r.totalSeconds)) · \(r.steps.count) moves").font(.caption).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            if !r.isBuiltIn, let model = custom.first(where: { $0.id.uuidString == r.id }) {
                Menu {
                    Button { editing = model } label: { Label("Edit", systemImage: "pencil") }
                    Button(role: .destructive) { context.delete(model); context.saveQuietly() } label: { Label("Delete", systemImage: "trash") }
                } label: { Image(systemName: "ellipsis.circle").foregroundStyle(Theme.textSecondary) }
            }
            Button { playing = r } label: {
                Image(systemName: "play.fill").font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 38, height: 38).background(Circle().fill(Theme.buttonGradient))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Start \(r.name)")
        }
        .card(padding: 14)
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !sessions.isEmpty {
                SectionTitle("Recent sessions")
                ForEach(sessions.prefix(6)) { s in
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(s.routineName).font(.subheadline.weight(.medium))
                            Text(s.date.formatted("EEEdMMM") + " · " + formatMinutes(s.durationSeconds))
                                .font(.caption).foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                        Button(role: .destructive) { context.delete(s); context.saveQuietly() } label: {
                            Image(systemName: "trash").foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .card(padding: 12)
                }
            }
        }
    }
}

// MARK: - Guided player

struct MobilityPlayerView: View {
    let routine: MobilityRoutineInfo
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var index = 0
    @State private var remaining = 0
    @State private var running = false
    @State private var elapsed = 0
    @State private var finished = false

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private var step: MobilityStep { routine.steps[min(index, routine.steps.count - 1)] }

    var body: some View {
        VStack(spacing: 22) {
            HStack {
                Button { dismiss() } label: { Image(systemName: "xmark").font(.headline) }
                Spacer()
                Text(routine.name).font(Theme.display(18))
                Spacer()
                Color.clear.frame(width: 24)
            }
            .foregroundStyle(Theme.text)

            if finished {
                completion
            } else {
                Text("Move \(index + 1) of \(routine.steps.count)")
                    .font(.caption.weight(.bold)).tracking(1).textCase(.uppercase).foregroundStyle(Theme.accentText)
                Text(step.name).font(Theme.display(30)).multilineTextAlignment(.center).foregroundStyle(Theme.text)
                ProgressRing(progress: step.seconds > 0 ? Double(remaining) / Double(step.seconds) : 0, lineWidth: 16) {
                    Text(formatDuration(remaining)).font(Theme.number(54)).monospacedDigit().foregroundStyle(Theme.text)
                }
                .frame(width: 240, height: 240)
                Text(step.detail).font(.body).multilineTextAlignment(.center).foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal)
                Spacer()
                HStack(spacing: 14) {
                    Button { goTo(index - 1) } label: { Image(systemName: "backward.fill") }
                        .buttonStyle(SoftButtonStyle(compact: true)).disabled(index == 0)
                    Button { running.toggle(); Haptics.tap() } label: {
                        Label(running ? "Pause" : "Start", systemImage: running ? "pause.fill" : "play.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    Button { next() } label: { Image(systemName: "forward.fill") }
                        .buttonStyle(SoftButtonStyle(compact: true))
                }
                Button("Finish early") { complete() }
                    .font(.footnote).foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(Theme.pad)
        .screenBackground()
        .onAppear { remaining = routine.steps.first?.seconds ?? 0 }
        .onReceive(ticker) { _ in
            guard running, !finished else { return }
            elapsed += 1
            if remaining > 0 { remaining -= 1 }
            if remaining == 0 { next() }
        }
        .onChange(of: running) { _, r in UIApplication.shared.isIdleTimerDisabled = r }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    private var completion: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "checkmark").font(.system(size: 34, weight: .bold)).foregroundStyle(.white)
                .frame(width: 84, height: 84).background(Circle().fill(Theme.brandGradient))
            Text("Session logged").font(Theme.display(28)).foregroundStyle(Theme.text)
            Text("\(routine.name) · \(formatMinutes(elapsed))").foregroundStyle(Theme.textSecondary)
            Spacer()
            Button("Done") { dismiss() }.buttonStyle(PrimaryButtonStyle())
        }
    }

    private func goTo(_ i: Int) {
        guard i >= 0, i < routine.steps.count else { return }
        index = i
        remaining = routine.steps[i].seconds
        Haptics.select()
    }

    private func next() {
        if index + 1 < routine.steps.count {
            goTo(index + 1)
            Haptics.medium()
        } else {
            complete()
        }
    }

    private func complete() {
        running = false
        guard !finished else { return }
        if elapsed >= 20 {
            context.insert(MobilitySession(routineName: routine.name, category: routine.category, durationSeconds: elapsed))
            context.saveQuietly()
            _ = MilestoneSync.sync(context)
            Haptics.success()
            finished = true
        } else {
            dismiss()
        }
    }
}

// MARK: - Editors

struct MobilityRoutineEditor: View {
    let routine: MobilityRoutine?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var category: MobilityCategory = .custom
    @State private var steps: [MobilityStep] = []
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Routine name", text: $name)
                    Picker("Category", selection: $category) {
                        ForEach(MobilityCategory.allCases) { Text($0.title).tag($0) }
                    }
                }.listRowBackground(Theme.card)
                Section("Moves") {
                    ForEach($steps) { $s in
                        VStack(alignment: .leading, spacing: 6) {
                            TextField("Move name", text: $s.name).font(.headline)
                            IntStepperRow(title: "Duration", value: $s.seconds, range: 10...600, step: 5, unit: "s")
                            TextField("Cue or note", text: $s.detail).font(.footnote)
                        }
                    }
                    .onDelete { steps.remove(atOffsets: $0) }
                    .onMove { steps.move(fromOffsets: $0, toOffset: $1) }
                    Button { steps.append(MobilityStep(name: "")) } label: { Label("Add move", systemImage: "plus") }
                }.listRowBackground(Theme.card)
            }
            .warmForm()
            .keyboardDoneToolbar()
            .navigationTitle(routine == nil ? "New routine" : "Edit routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }.fontWeight(.semibold)
                        .disabled(name.trimmed.isEmpty || steps.filter { !$0.name.trimmed.isEmpty }.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) { EditButton() }
            }
            .onAppear {
                guard !loaded, let r = routine else { return }
                name = r.name; category = r.category; steps = r.steps; loaded = true
            }
        }
    }

    private func save() {
        let cleaned = steps.filter { !$0.name.trimmed.isEmpty }
        if let r = routine {
            r.name = name.trimmed; r.category = category; r.steps = cleaned
        } else {
            context.insert(MobilityRoutine(name: name.trimmed, category: category, steps: cleaned))
        }
        context.saveQuietly()
        dismiss()
    }
}

struct ManualMobilitySheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var category: MobilityCategory = .custom
    @State private var minutes = 10
    @State private var date = Date()

    var body: some View {
        NavigationStack {
            Form {
                TextField("What did you do? (e.g. Yoga)", text: $name)
                Picker("Category", selection: $category) {
                    ForEach(MobilityCategory.allCases) { Text($0.title).tag($0) }
                }
                IntStepperRow(title: "Duration", value: $minutes, range: 1...180, unit: "min")
                DatePicker("When", selection: $date, in: ...Date())
            }
            .warmForm()
            .navigationTitle("Log session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        context.insert(MobilitySession(date: date, routineName: name.trimmed.isEmpty ? category.title : name.trimmed,
                                                       category: category, durationSeconds: minutes * 60))
                        context.saveQuietly()
                        _ = MilestoneSync.sync(context)
                        Haptics.success()
                        dismiss()
                    }.fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
