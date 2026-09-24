import SwiftUI
import SwiftData

@main
struct PTHelperApp: App {
    @State private var authVM = AuthViewModel()

    init() {
        applyAppearance()
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Exercise.self,
            Routine.self,
            RoutineExercise.self,
            ScheduledSession.self,
            ExerciseLog.self,
        ])

        do {
            return try ModelContainer(for: schema)
        } catch {
            // Schema changed — delete old store and start fresh
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            if let files = try? FileManager.default.contentsOfDirectory(at: appSupport, includingPropertiesForKeys: nil) {
                for file in files where file.lastPathComponent.contains(".store") {
                    try? FileManager.default.removeItem(at: file)
                }
            }
            do {
                return try ModelContainer(for: schema)
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

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

/// Serif bar titles on transparent bars, so the system Liquid Glass bars and scroll-edge effects show through.
private func applyAppearance() {
    let navAppearance = UINavigationBarAppearance()
    navAppearance.configureWithTransparentBackground()

    if let serifDescriptor = UIFont.systemFont(ofSize: 34, weight: .bold)
        .fontDescriptor.withDesign(.serif) {
        navAppearance.largeTitleTextAttributes = [
            .font: UIFont(descriptor: serifDescriptor, size: 34),
            .foregroundColor: UIColor.label,
        ]
    }
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
}
