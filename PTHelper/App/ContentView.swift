import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AuthViewModel.self) private var authVM

    var body: some View {
        if authVM.isSignedIn {
            MainTabView()
        } else {
            AuthView()
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
