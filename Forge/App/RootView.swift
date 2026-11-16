import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var lock: AppLock
    @Query private var profiles: [UserProfile]

    private var onboarded: Bool { profiles.first?.hasOnboarded ?? false }

    var body: some View {
        ZStack {
            Group {
                if onboarded {
                    MainTabView()
                } else {
                    OnboardingView()
                }
            }

            if lock.isEnabled && (scenePhase != .active || lock.isLocked) {
                if lock.isLocked {
                    LockView().transition(.opacity).zIndex(10)
                } else {
                    PrivacyShield().zIndex(10)
                }
            }

            if let a = appState.achievement {
                AchievementOverlay(title: a.title, subtitle: a.subtitle) {
                    withAnimation(Motion.soft) { appState.achievement = nil }
                }
                .zIndex(20)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: lock.isLocked)
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: lock.lockIfNeeded()
            case .active: runMilestoneSync()
            default: break
            }
        }
        .task {
            Seeder.seedHabitsIfNeeded(context)
            runMilestoneSync()
        }
    }

    private func runMilestoneSync() {
        let completed = MilestoneSync.sync(context)
        if let first = completed.first {
            appState.achievement = AchievementInfo(
                title: first.title,
                subtitle: completed.count > 1 ? "and \(completed.count - 1) more milestone(s) completed." : "Consistency made this possible.")
        }
    }
}

struct PrivacyShield: View {
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            Image(systemName: "flame.fill")
                .font(.system(size: 44))
                .foregroundStyle(Theme.brandGradient)
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView(selection: $appState.tab) {
            NavigationStack { HomeView() }
                .tabItem { Label(AppTab.home.title, systemImage: AppTab.home.icon) }
                .tag(AppTab.home)
            NavigationStack { NutritionView() }
                .tabItem { Label(AppTab.nutrition.title, systemImage: AppTab.nutrition.icon) }
                .tag(AppTab.nutrition)
            NavigationStack { TrainingView() }
                .tabItem { Label(AppTab.training.title, systemImage: AppTab.training.icon) }
                .tag(AppTab.training)
            NavigationStack { ProgressHubView() }
                .tabItem { Label(AppTab.progress.title, systemImage: AppTab.progress.icon) }
                .tag(AppTab.progress)
            NavigationStack { ProfileView() }
                .tabItem { Label(AppTab.profile.title, systemImage: AppTab.profile.icon) }
                .tag(AppTab.profile)
        }
        .tint(Theme.orange)
        .animation(Motion.soft, value: appState.tab)
        .sensoryFeedback(.selection, trigger: appState.tab)
    }
}

/// Wraps content with a freshly-built `ScoreEngine` that reacts to stored data changes.
struct WithScore<Content: View>: View {
    @Query private var profiles: [UserProfile]
    @Query private var foods: [FoodEntry]
    @Query private var water: [WaterEntry]
    @Query private var workouts: [WorkoutSession]
    @Query private var mobility: [MobilitySession]
    @Query private var habits: [Habit]
    @Query private var habitLogs: [HabitLog]
    @Query private var sleep: [SleepEntry]
    @Query private var supplements: [Supplement]
    @Query private var supplementLogs: [SupplementLog]
    @Query private var milestones: [Milestone]
    @Query private var updates: [MilestoneUpdate]
    @Query private var routines: [Routine]

    let content: (ScoreEngine) -> Content

    init(@ViewBuilder content: @escaping (ScoreEngine) -> Content) {
        self.content = content
    }

    var body: some View {
        content(ScoreEngine(
            profile: profiles.first, foodEntries: foods, water: water, workouts: workouts,
            mobility: mobility, habits: habits, habitLogs: habitLogs, sleep: sleep,
            supplements: supplements, supplementLogs: supplementLogs, milestones: milestones,
            milestoneUpdates: updates, routines: routines))
    }
}
