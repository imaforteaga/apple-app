import SwiftUI
import SwiftData
import UserNotifications

struct ProfileView: View {
    @Query private var profiles: [UserProfile]
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]
    @Query private var photos: [ProgressPhoto]
    @Query private var sessions: [WorkoutSession]
    @Query private var journal: [JournalEntry]

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let p = profile { header(p) }
                group("Discipline & spirit") {
                    link("book.closed", "Bible & verse of the day") { BibleView() }
                    link("square.and.pencil", "Journal") { JournalView() }
                    link("checklist", "Habits") { HabitsView() }
                    link("pills", "Supplements") { SupplementsView() }
                    link("flag", "Milestones") { MilestonesView() }
                    link("flame", "Transformation Score") { ScoreView() }
                }
                group("Personal") {
                    link("person.text.rectangle", "Edit profile & goals") { EditProfileView() }
                    link("target", "Nutrition goals") { NutritionGoalsView() }
                    link("bell", "Reminders") { RemindersView() }
                    link("calendar", "Calendar & reports") { CalendarView() }
                }
                group("Data & privacy") {
                    link("lock.shield", "Privacy, backup & export") { PrivacyView() }
                }
                Text("Forge keeps everything on this iPhone. No account, no tracking.")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, Theme.pad)
            .padding(.bottom, 40)
        }
        .screenBackground()
        .navigationTitle("Profile")
    }

    private func header(_ p: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Text(String(p.name.prefix(1)).uppercased().isEmpty ? "F" : String(p.name.prefix(1)).uppercased())
                    .font(Theme.display(28)).foregroundStyle(.white)
                    .frame(width: 62, height: 62).background(Circle().fill(Theme.brandGradient))
                VStack(alignment: .leading, spacing: 2) {
                    Text(p.name.isEmpty ? "Your profile" : p.name).font(Theme.display(24)).foregroundStyle(Theme.text)
                    Text("\(p.objective.title) · \(p.experience.title)").font(.footnote).foregroundStyle(Theme.textSecondary)
                }
            }
            HStack(spacing: 10) {
                StatTile(value: "\((weights.first?.kg ?? p.startWeightKg).clean) kg", label: "Weight")
                StatTile(value: "\(sessions.filter { $0.isFinished }.count)", label: "Workouts")
                StatTile(value: "\(photos.count)", label: "Photos")
                StatTile(value: "\(journal.count)", label: "Entries")
            }
        }
        .card()
    }

    private func group<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased()).font(.system(size: 11, weight: .semibold, design: .default)).tracking(1).foregroundStyle(Theme.accentText)
            VStack(spacing: 0) { content() }.card(padding: 4)
        }
    }

    private func link<D: View>(_ icon: String, _ title: String, @ViewBuilder destination: @escaping () -> D) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 12) {
                IconBadge(systemName: icon, size: 36)
                Text(title).font(.subheadline.weight(.medium)).foregroundStyle(Theme.text)
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.textSecondary)
            }
            .padding(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Edit profile

struct EditProfileView: View {
    @Query private var profiles: [UserProfile]
    var body: some View {
        if let p = profiles.first { Editor(profile: p) } else { EmptyState(icon: "person", title: "No profile", message: "Finish onboarding first.") }
    }

    private struct Editor: View {
        @Bindable var profile: UserProfile
        @Environment(\.modelContext) private var context
        @State private var showWeight = false

        var body: some View {
            Form {
                Section("About you") {
                    TextField("Name", text: $profile.name)
                    HStack {
                        Text("Age")
                        Spacer()
                        TextField("25", value: $profile.age, format: .number).keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing).frame(maxWidth: 80)
                    }
                    NumberField("Height", required: $profile.heightCm, unit: "cm")
                    Button("Log a new weight") { showWeight = true }
                }.listRowBackground(Theme.card)

                Section("Training") {
                    Picker("Main objective", selection: $profile.objectiveRaw) {
                        ForEach(Objective.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                    Picker("Experience", selection: $profile.experienceRaw) {
                        ForEach(Experience.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                    IntStepperRow(title: "Training days / week", value: $profile.weeklyTrainingDays, range: 1...7)
                }.listRowBackground(Theme.card)

                Section("Targets") {
                    targetRow("Calories", $profile.calorieTarget, "kcal")
                    targetRow("Protein", $profile.proteinTarget, "g")
                    targetRow("Water", $profile.waterTargetMl, "ml")
                    HStack {
                        Text("Sleep")
                        Spacer()
                        Stepper(value: $profile.sleepTargetHours, in: 4...12, step: 0.5) {
                            Text("\(profile.sleepTargetHours.clean) h").frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                }.listRowBackground(Theme.card)
            }
            .warmForm()
            .keyboardDoneToolbar()
            .navigationTitle("Profile & goals")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showWeight) { AddWeightView() }
            .onDisappear { context.saveQuietly() }
        }

        private func targetRow(_ title: String, _ value: Binding<Int>, _ unit: String) -> some View {
            HStack {
                Text(title)
                Spacer()
                TextField("0", value: value, format: .number).keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing).frame(maxWidth: 90)
                Text(unit).foregroundStyle(Theme.textSecondary).frame(width: 34, alignment: .leading)
            }
        }
    }
}

// MARK: - Reminders

struct RemindersView: View {
    @State private var status: UNAuthorizationStatus = .notDetermined

    var body: some View {
        Form {
            if status == .denied {
                Section {
                    Label("Notifications are off for Forge. Turn them on in Settings › Notifications.", systemImage: "bell.slash")
                        .font(.footnote)
                }.listRowBackground(Theme.card)
            }
            Section {
                ForEach(ReminderKind.allCases) { ReminderRow(kind: $0, onDenied: { status = .denied }) }
            } footer: {
                Text("Reminders are scheduled on your device. Nothing is sent to a server.")
            }.listRowBackground(Theme.card)
        }
        .warmForm()
        .navigationTitle("Reminders")
        .task { status = await NotificationService.authorizationStatus() }
    }
}

private struct ReminderRow: View {
    let kind: ReminderKind
    var onDenied: () -> Void
    @AppStorage private var on: Bool
    @AppStorage private var hour: Int
    @AppStorage private var minute: Int

    init(kind: ReminderKind, onDenied: @escaping () -> Void) {
        self.kind = kind
        self.onDenied = onDenied
        _on = AppStorage(wrappedValue: false, kind.enabledKey)
        _hour = AppStorage(wrappedValue: kind.defaultHour, kind.hourKey)
        _minute = AppStorage(wrappedValue: 0, kind.minuteKey)
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: { Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date() },
            set: {
                let c = Calendar.current.dateComponents([.hour, .minute], from: $0)
                hour = c.hour ?? hour
                minute = c.minute ?? minute
                if on { Task { await NotificationService.schedule(kind, hour: hour, minute: minute) } }
            })
    }

    var body: some View {
        VStack(spacing: 8) {
            Toggle(isOn: Binding(get: { on }, set: { toggle($0) })) {
                Label(kind.title, systemImage: kind.icon)
            }
            .tint(Theme.orange)
            if on {
                DatePicker("Time", selection: timeBinding, displayedComponents: .hourAndMinute)
                    .font(.subheadline)
            }
        }
    }

    private func toggle(_ enable: Bool) {
        if enable {
            Task {
                if await NotificationService.requestAuthorization() {
                    on = true
                    await NotificationService.schedule(kind, hour: hour, minute: minute)
                } else {
                    on = false
                    onDenied()
                }
            }
        } else {
            on = false
            NotificationService.cancel(kind)
        }
    }
}

// MARK: - Privacy, backup, export

struct PrivacyView: View {
    @EnvironmentObject private var lock: AppLock
    @Environment(\.modelContext) private var context
    @State private var lockOn = UserDefaults.standard.bool(forKey: AppLock.defaultsKey)
    @State private var exporting = false
    @State private var exportURL: URL?
    @State private var errorMessage: String?
    @State private var confirmDelete = false
    @State private var deleteText = ""

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(get: { lockOn }, set: { newValue in
                    Task {
                        let ok = await lock.setEnabled(newValue)
                        lockOn = ok ? newValue : lockOn
                    }
                })) {
                    Label("Lock with \(lock.biometryName)", systemImage: "faceid")
                }
                .tint(Theme.orange)
                if let m = lock.errorMessage { Text(m).font(.footnote).foregroundStyle(.red) }
            } header: { Text("App lock") } footer: {
                Text("Forge locks when you leave the app. If Face ID fails you can use your device passcode.")
            }.listRowBackground(Theme.card)

            Section {
                Button {
                    export()
                } label: {
                    HStack {
                        Label("Export all my data", systemImage: "square.and.arrow.up")
                        if exporting { Spacer(); ProgressView() }
                    }
                }
                .disabled(exporting)
            } header: { Text("Backup & export") } footer: {
                Text("Creates a .zip with your data (JSON) and original photos. Save it to Files, AirDrop it, or keep it in your own cloud. Forge never uploads it.")
            }.listRowBackground(Theme.card)

            Section {
                Label("Stored only on this iPhone", systemImage: "iphone")
                Label("Included in your encrypted iPhone / iCloud device backup if you have that enabled", systemImage: "icloud")
                    .font(.footnote)
                Label(AppConfig.enableCloudKitSync ? "iCloud sync is ON" : "iCloud sync is off (optional, see README)", systemImage: "arrow.triangle.2.circlepath.icloud")
                    .font(.footnote)
            } header: { Text("Where your data lives") }.listRowBackground(Theme.card)

            Section {
                Label("Camera and photo access are requested only when you add a progress photo.", systemImage: "camera")
                Label("No account, analytics or advertising.", systemImage: "eye.slash")
            } header: { Text("Privacy") }
            .font(.footnote)
            .listRowBackground(Theme.card)

            Section {
                Button("Delete all my data…", role: .destructive) { confirmDelete = true }
            } footer: { Text("Permanently removes every entry and photo from this device.") }
            .listRowBackground(Theme.card)
        }
        .warmForm()
        .navigationTitle("Privacy & data")
        .sheet(item: Binding(get: { exportURL.map { ExportItem(url: $0) } }, set: { if $0 == nil { exportURL = nil } })) {
            ShareSheet(items: [$0.url])
        }
        .alert("Export failed", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
        .alert("Delete everything?", isPresented: $confirmDelete) {
            TextField("Type DELETE", text: $deleteText)
            Button("Delete all", role: .destructive) { if deleteText == "DELETE" { wipe() }; deleteText = "" }
            Button("Cancel", role: .cancel) { deleteText = "" }
        } message: { Text("This cannot be undone. Export a backup first if you might want your data later.") }
    }

    private struct ExportItem: Identifiable {
        let url: URL
        var id: String { url.absoluteString }
    }

    private func export() {
        exporting = true
        Task { @MainActor in
            do {
                exportURL = try BackupService.exportAll(from: context)
            } catch {
                errorMessage = error.localizedDescription
            }
            exporting = false
        }
    }

    private func wipe() {
        do {
            try context.delete(model: UserProfile.self)
            try context.delete(model: WeightEntry.self)
            try context.delete(model: BodyMeasurement.self)
            try context.delete(model: ProgressPhoto.self)
            try context.delete(model: PhotoCollection.self)
            try context.delete(model: SleepEntry.self)
            try context.delete(model: WaterEntry.self)
            try context.delete(model: CustomFood.self)
            try context.delete(model: FoodEntry.self)
            try context.delete(model: FavoriteMeal.self)
            try context.delete(model: Routine.self)
            try context.delete(model: WorkoutSession.self)
            try context.delete(model: MobilityRoutine.self)
            try context.delete(model: MobilitySession.self)
            try context.delete(model: Habit.self)
            try context.delete(model: HabitLog.self)
            try context.delete(model: Supplement.self)
            try context.delete(model: SupplementLog.self)
            try context.delete(model: JournalEntry.self)
            try context.delete(model: Milestone.self)
            try context.delete(model: MilestoneUpdate.self)
            try context.delete(model: FavoriteVerse.self)
            try context.save()
            try? FileManager.default.removeItem(at: PhotoStore.directory)
            try? FileManager.default.createDirectory(at: PhotoStore.directory, withIntermediateDirectories: true)
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
