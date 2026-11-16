import SwiftUI
import SwiftData

@main
struct ForgeApp: App {
    private let container: ModelContainer?
    private let loadError: String?
    @StateObject private var appState = AppState()
    @StateObject private var lock = AppLock()

    init() {
        Self.configureAppearance()
        let schema = Schema([
            UserProfile.self, WeightEntry.self, BodyMeasurement.self, ProgressPhoto.self,
            PhotoCollection.self, SleepEntry.self, WaterEntry.self,
            CustomFood.self, FoodEntry.self, FavoriteMeal.self,
            Routine.self, WorkoutSession.self, MobilityRoutine.self, MobilitySession.self,
            Habit.self, HabitLog.self, Supplement.self, SupplementLog.self,
            JournalEntry.self, Milestone.self, MilestoneUpdate.self, FavoriteVerse.self
        ])
        let config = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: AppConfig.enableCloudKitSync ? .automatic : .none)
        do {
            container = try ModelContainer(for: schema, configurations: [config])
            loadError = nil
        } catch {
            container = nil
            loadError = error.localizedDescription
        }
    }

    var body: some Scene {
        WindowGroup {
            if let container {
                RootView()
                    .modelContainer(container)
                    .environmentObject(appState)
                    .environmentObject(lock)
                    .tint(Theme.orange)
            } else {
                StorageErrorView(message: loadError ?? "Unknown error")
            }
        }
    }

    private static func configureAppearance() {
        let base = UIFont.systemFont(ofSize: 34, weight: .semibold)
        let serifDescriptor = base.fontDescriptor.withDesign(.serif) ?? base.fontDescriptor
        let large = UIFont(descriptor: serifDescriptor, size: 34)
        let smallBase = UIFont.systemFont(ofSize: 17, weight: .semibold)
        let small = UIFont(descriptor: smallBase.fontDescriptor.withDesign(.serif) ?? smallBase.fontDescriptor, size: 17)

        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.backgroundColor = UIColor(Theme.background).withAlphaComponent(0.92)
        nav.largeTitleTextAttributes = [.font: large, .foregroundColor: UIColor(Theme.text)]
        nav.titleTextAttributes = [.font: small, .foregroundColor: UIColor(Theme.text)]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = {
            let a = UINavigationBarAppearance()
            a.configureWithTransparentBackground()
            a.largeTitleTextAttributes = [.font: large, .foregroundColor: UIColor(Theme.text)]
            a.titleTextAttributes = [.font: small, .foregroundColor: UIColor(Theme.text)]
            return a
        }()

        let tab = UITabBarAppearance()
        tab.configureWithDefaultBackground()
        tab.backgroundColor = UIColor(Theme.background).withAlphaComponent(0.94)
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
    }
}

struct StorageErrorView: View {
    let message: String
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(Theme.orange)
            Text("Your data couldn't be opened")
                .font(Theme.display(24))
            Text("Nothing has been deleted. Restart the app, and if this continues make sure the device has free storage and is updated to the latest iOS.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textSecondary)
            Text(message)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
}
