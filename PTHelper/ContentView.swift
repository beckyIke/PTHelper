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
    @Environment(AuthViewModel.self) private var authVM
    @State private var showingSignIn = false

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
        // Session ended by the server — keep the app usable and offer to sign back in.
        .safeAreaInset(edge: .top) {
            if authVM.sessionExpired {
                SessionExpiredBanner { showingSignIn = true }
            }
        }
        .sheet(isPresented: $showingSignIn) {
            AuthView()
        }
        .onChange(of: authVM.sessionExpired) { _, expired in
            if !expired { showingSignIn = false }
        }
    }
}

private struct SessionExpiredBanner: View {
    let onSignIn: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .foregroundColor(.ptTerracotta)
            Text("You've been signed out.")
                .font(.subheadline)
            Spacer()
            Button("Sign In", action: onSignIn)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.ptTerracotta)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.ptSalmon.opacity(0.6))
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
