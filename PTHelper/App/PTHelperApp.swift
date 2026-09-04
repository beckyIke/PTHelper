import SwiftUI
import SwiftData

@main
struct PTHelperApp: App {
    @State private var authVM = AuthViewModel()

    init() {
        applyAppearance()
    }

    private let sharedModelContainer = ModelContainerFactory.make()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authVM)
                .onAppear {
                    let ctx = sharedModelContainer.mainContext
                    Task {
                        await SupabaseExerciseSync.sync(context: ctx)
                        RecurrenceManager.generateUpcomingSessions(context: ctx)
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}

// MARK: - UIAppearance

private func applyAppearance() {
    let cream = UIColor(Color.ptBackground)
    let terracotta = UIColor(Color.ptTerracotta)

    // --- Navigation bar ---
    let navAppearance = UINavigationBarAppearance()
    navAppearance.configureWithOpaqueBackground()
    navAppearance.backgroundColor = cream
    navAppearance.shadowColor = .clear

    // Serif large title
    if let serifDescriptor = UIFont.systemFont(ofSize: 34, weight: .bold)
        .fontDescriptor.withDesign(.serif) {
        navAppearance.largeTitleTextAttributes = [
            .font: UIFont(descriptor: serifDescriptor, size: 34),
            .foregroundColor: UIColor.label,
        ]
    }
    // Serif inline title
    if let serifDescriptor = UIFont.systemFont(ofSize: 17, weight: .semibold)
        .fontDescriptor.withDesign(.serif) {
        navAppearance.titleTextAttributes = [
            .font: UIFont(descriptor: serifDescriptor, size: 17),
            .foregroundColor: UIColor.label,
        ]
    }

    UINavigationBar.appearance().standardAppearance   = navAppearance
    UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
    UINavigationBar.appearance().compactAppearance    = navAppearance
    UINavigationBar.appearance().tintColor = terracotta

    // --- Tab bar ---
    let tabAppearance = UITabBarAppearance()
    tabAppearance.configureWithOpaqueBackground()
    tabAppearance.backgroundColor = cream
    tabAppearance.shadowColor = .clear

    // Selected item colour
    tabAppearance.stackedLayoutAppearance.selected.iconColor   = terracotta
    tabAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: terracotta]

    UITabBar.appearance().standardAppearance   = tabAppearance
    UITabBar.appearance().scrollEdgeAppearance = tabAppearance
}
