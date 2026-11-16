import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]

    @State private var step = 0
    private let lastStep = 5

    @State private var name = ""
    @State private var ageText = ""
    @State private var heightText = ""
    @State private var weightText = ""
    @State private var objective: Objective = .muscleGain
    @State private var experience: Experience = .beginner
    @State private var trainingDays = 4
    @State private var kcalText = ""
    @State private var proteinText = ""
    @State private var waterText = ""
    @State private var targetsTouched = false
    @State private var remindersOn = false
    @State private var error: String?
    @State private var forward = true

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            Theme.warmWash.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        stepContent
                            .id(step)
                            .transition(.asymmetric(
                                insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                                removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)))
                        if let error {
                            Label(error, systemImage: "exclamationmark.circle")
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal, Theme.pad)
                    .padding(.top, 10)
                    .padding(.bottom, 30)
                }
                .scrollDismissesKeyboard(.interactively)
                footer
            }
        }
    }

    // MARK: Chrome

    private var header: some View {
        HStack(spacing: 6) {
            ForEach(0...lastStep, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? AnyShapeStyle(Theme.brandGradient) : AnyShapeStyle(Theme.cardAlt))
                    .frame(height: 5)
            }
        }
        .padding(.horizontal, Theme.pad)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .animation(.easeInOut, value: step)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if step > 0 {
                Button("Back") { move(to: step - 1) }
                    .buttonStyle(SoftButtonStyle())
                    .frame(maxWidth: 110)
            }
            Button(step == lastStep ? "Start my journey" : "Continue") { next() }
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, Theme.pad)
        .padding(.vertical, 14)
        .background(Theme.background.opacity(0.9))
    }

    // MARK: Steps

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0: welcome
        case 1: about
        case 2: objectiveStep
        case 3: trainingStep
        case 4: targetsStep
        default: finalStep
        }
    }

    private func titleBlock(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Theme.display(34))
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 26) {
            Spacer(minLength: 30)
            Image(systemName: "flame.fill")
                .font(.system(size: 38))
                .foregroundStyle(.white)
                .frame(width: 80, height: 80)
                .background(Circle().fill(Theme.brandGradient))
                .shadow(color: Theme.orange.opacity(0.35), radius: 18, y: 8)
            titleBlock("Forge",
                       "Your private operating system for becoming stronger, healthier and more consistent. Body, performance, nutrition, discipline and faith, in one place.")
            VStack(alignment: .leading, spacing: 8) {
                Text("What should I call you?")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                TextField("Your name", text: $name)
                    .textContentType(.givenName)
                    .font(.title3)
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.card))
            }
            Label("No account. Everything stays on your iPhone.", systemImage: "lock.shield")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: 22) {
            titleBlock("About you", "Used for your starting point and target suggestions. You can change this any time.")
            VStack(spacing: 12) {
                OnboardField(title: "Age", text: $ageText, unit: "years", keyboard: .numberPad)
                OnboardField(title: "Height", text: $heightText, unit: "cm", keyboard: .decimalPad)
                OnboardField(title: "Current weight", text: $weightText, unit: "kg", keyboard: .decimalPad)
            }
        }
    }

    private var objectiveStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            titleBlock("Main objective", "Pick what matters most right now.")
            VStack(spacing: 10) {
                ForEach(Objective.allCases) { o in
                    Button {
                        Haptics.select()
                        objective = o
                    } label: {
                        HStack(spacing: 14) {
                            IconBadge(systemName: o.icon, size: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(o.title).font(.headline).foregroundStyle(Theme.text)
                                Text(o.blurb).font(.footnote).foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: objective == o ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(objective == o ? Theme.orange : Theme.hairline)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Theme.card)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(objective == o ? Theme.orange : Color.clear, lineWidth: 1.5))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var trainingStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            titleBlock("Training", "Your experience and how often you want to train.")
            VStack(alignment: .leading, spacing: 10) {
                Text("Experience").font(.footnote.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                HStack(spacing: 8) {
                    ForEach(Experience.allCases) { e in
                        VStack(spacing: 2) {
                            Text(e.title).font(.subheadline.weight(.semibold))
                            Text(e.detail).font(.caption2)
                        }
                        .foregroundStyle(experience == e ? Color.white : Theme.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(experience == e ? AnyShapeStyle(Theme.buttonGradient) : AnyShapeStyle(Theme.card)))
                        .onTapGesture {
                            Haptics.select()
                            experience = e
                        }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("Training days per week").font(.footnote.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                HStack {
                    Text("\(trainingDays)")
                        .font(Theme.number(44))
                        .foregroundStyle(Theme.accentText)
                        .frame(minWidth: 50, alignment: .leading)
                    Spacer()
                    Stepper("", value: $trainingDays, in: 1...7)
                        .labelsHidden()
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.card))
            }
        }
    }

    private var targetsStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            titleBlock("Daily targets", "A starting estimate from your details. These are rough, not medical advice. Adjust them to fit you.")
            VStack(spacing: 12) {
                OnboardField(title: "Calories", text: touched($kcalText), unit: "kcal", keyboard: .numberPad)
                OnboardField(title: "Protein", text: touched($proteinText), unit: "g", keyboard: .numberPad)
                OnboardField(title: "Water", text: touched($waterText), unit: "ml", keyboard: .numberPad)
            }
            Button {
                applySuggestion()
            } label: {
                Label("Recalculate suggestion", systemImage: "wand.and.stars")
            }
            .buttonStyle(SoftButtonStyle(compact: true))
        }
        .onAppear {
            if !targetsTouched || kcalText.isEmpty { applySuggestion() }
        }
    }

    private var finalStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            titleBlock("You're set", "Forge is ready. Reminders are optional and can be fine-tuned in Profile.")
            Toggle(isOn: $remindersOn) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily reminders").font(.headline)
                    Text("Verse of the day (7:00) and evening journal (21:00)")
                        .font(.footnote).foregroundStyle(Theme.textSecondary)
                }
            }
            .tint(Theme.orange)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.card))

            VStack(alignment: .leading, spacing: 12) {
                privacyRow("lock.shield", "Private by design", "No account. Photos, measurements and journal stay on this device.")
                privacyRow("faceid", "Optional Face ID", "Turn on app lock any time in Profile › Privacy.")
                privacyRow("camera", "Permissions on demand", "Camera and photo access are only requested when you add a progress photo.")
            }
            .card()
        }
    }

    private func privacyRow(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            IconBadge(systemName: icon, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text)
                Text(detail).font(.footnote).foregroundStyle(Theme.textSecondary)
            }
        }
    }

    // MARK: Logic

    private func touched(_ binding: Binding<String>) -> Binding<String> {
        Binding(get: { binding.wrappedValue },
                set: { binding.wrappedValue = $0; targetsTouched = true })
    }

    private func move(to newStep: Int) {
        forward = newStep > step
        error = nil
        withAnimation(Motion.soft) { step = newStep }
    }

    private func next() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        if let message = validate(step) {
            error = message
            Haptics.warning()
            return
        }
        if step == lastStep {
            finish()
        } else {
            Haptics.tap()
            move(to: step + 1)
        }
    }

    private func validate(_ s: Int) -> String? {
        switch s {
        case 1:
            guard let a = Int(ageText), (12...100).contains(a) else { return "Enter an age between 12 and 100." }
            guard let h = parseDouble(heightText), (100...250).contains(h) else { return "Enter a height between 100 and 250 cm." }
            guard let w = parseDouble(weightText), (30...300).contains(w) else { return "Enter a weight between 30 and 300 kg." }
        case 4:
            guard let k = Int(kcalText), (1000...8000).contains(k) else { return "Calories should be between 1000 and 8000." }
            guard let p = Int(proteinText), (20...500).contains(p) else { return "Protein should be between 20 and 500 g." }
            guard let w = Int(waterText), (500...10000).contains(w) else { return "Water should be between 500 and 10000 ml." }
        default: break
        }
        return nil
    }

    private func applySuggestion() {
        guard let w = parseDouble(weightText), let h = parseDouble(heightText), let a = Int(ageText) else { return }
        let t = NutritionPlanner.suggest(goal: NutritionPlanner.goal(for: objective),
                                         weightKg: w, heightCm: h, age: a, trainingDays: trainingDays)
        kcalText = String(t.calories)
        proteinText = String(t.protein)
        waterText = String(t.waterMl)
        targetsTouched = false
    }

    private func finish() {
        guard let age = Int(ageText), let height = parseDouble(heightText), let weight = parseDouble(weightText),
              let kcal = Int(kcalText), let protein = Int(proteinText), let water = Int(waterText) else {
            error = "Some details are missing. Please go back and check them."
            return
        }
        let profile = profiles.first ?? UserProfile()
        if profiles.first == nil { context.insert(profile) }
        profile.name = name.trimmed
        profile.age = age
        profile.heightCm = height
        profile.startWeightKg = weight
        profile.objective = objective
        profile.experience = experience
        profile.weeklyTrainingDays = trainingDays
        profile.calorieTarget = kcal
        profile.proteinTarget = protein
        // Derive carbs/fat from the chosen calories & protein.
        let fat = max(Int((Double(kcal) * 0.25 / 9).rounded()), 20)
        profile.fatTarget = fat
        profile.carbTarget = max(0, Int((Double(kcal - protein * 4 - fat * 9) / 4).rounded()))
        profile.waterTargetMl = water
        profile.createdAt = Date()
        profile.hasOnboarded = true

        context.insert(WeightEntry(date: Date(), kg: weight, note: "Starting weight"))
        Seeder.seedHabitsIfNeeded(context)
        context.saveQuietly()

        if remindersOn {
            Task {
                if await NotificationService.requestAuthorization() {
                    for kind in [ReminderKind.verse, .journal] {
                        UserDefaults.standard.set(true, forKey: kind.enabledKey)
                        UserDefaults.standard.set(kind.defaultHour, forKey: kind.hourKey)
                        UserDefaults.standard.set(0, forKey: kind.minuteKey)
                        await NotificationService.schedule(kind, hour: kind.defaultHour, minute: 0)
                    }
                }
            }
        }
        Haptics.success()
    }
}

struct OnboardField: View {
    let title: String
    @Binding var text: String
    var unit: String
    var keyboard: UIKeyboardType = .decimalPad

    var body: some View {
        HStack {
            Text(title).font(.body).foregroundStyle(Theme.text)
            Spacer()
            TextField("0", text: $text)
                .keyboardType(keyboard)
                .multilineTextAlignment(.trailing)
                .font(Theme.number(22))
                .frame(maxWidth: 120)
            Text(unit)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .frame(minWidth: 34, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.card))
    }
}
