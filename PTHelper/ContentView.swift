import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AuthViewModel.self) private var authVM

    var body: some View {
        if authVM.isAuthorized {
            MainTabView()
        } else {
            AuthView()
        }
    }
}

// MARK: - Main app tabs (shown when authenticated)

struct MainTabView: View {
    var body: some View {
        TabView {
            LibraryView()
                .tabItem { Label("Library", systemImage: "books.vertical") }
                .ptTabBarBackground()

            RoutinesView()
                .tabItem { Label("Routines", systemImage: "list.bullet.clipboard") }
                .ptTabBarBackground()

            ScheduleView()
                .tabItem { Label("Schedule", systemImage: "calendar") }
                .ptTabBarBackground()

            ActivityView()
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
                .ptTabBarBackground()

            NavigationStack {
                ProfileView()
            }
            .tabItem { Label("Profile", systemImage: "person.circle") }
            .ptTabBarBackground()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(
            for: [Exercise.self, Routine.self, RoutineExercise.self, ScheduledSession.self, ExerciseLog.self],
            inMemory: true
        )
        .environment(AuthViewModel())
}
