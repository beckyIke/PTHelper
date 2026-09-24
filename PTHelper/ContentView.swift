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
    @State private var activeWorkout: ScheduledSession?

    var body: some View {
        TabView {
            Tab("Library", systemImage: "books.vertical") {
                LibraryView()
            }
            Tab("Routines", systemImage: "list.bullet.clipboard") {
                RoutinesView()
            }
            Tab("Schedule", systemImage: "calendar") {
                ScheduleView()
            }
            Tab("Progress", systemImage: "chart.line.uptrend.xyaxis") {
                ActivityView()
            }
            Tab("Profile", systemImage: "person.circle") {
                NavigationStack {
                    ProfileView()
                }
            }
        }
        .tint(.ptAccent)
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            NextSessionAccessory { activeWorkout = $0 }
        }
        .fullScreenCover(item: $activeWorkout) { session in
            SessionWorkoutView(session: session)
        }
        // Session ended by the server — keep the app usable and offer to sign back in.
        .safeAreaInset(edge: .top) {
            if authVM.sessionExpired {
                SessionExpiredBanner { showingSignIn = true }
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(PTMotion.bouncy, value: authVM.sessionExpired)
        .sheet(isPresented: $showingSignIn) {
            AuthView()
        }
        .onChange(of: authVM.sessionExpired) { _, expired in
            if !expired { showingSignIn = false }
        }
    }
}

/// Mini-player style accessory above the tab bar: today's next session with a one-tap start,
/// or the next upcoming session when today is a rest day.
private struct NextSessionAccessory: View {
    @Query(filter: #Predicate<ScheduledSession> { !$0.isCompleted }, sort: \ScheduledSession.scheduledDate)
    private var pending: [ScheduledSession]
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    let onStart: (ScheduledSession) -> Void

    private var today: ScheduledSession? {
        let calendar = Calendar.current
        return pending.first { calendar.isDateInToday($0.scheduledDate) }
    }

    private var next: ScheduledSession? {
        pending.first { $0.scheduledDate > Date() }
    }

    var body: some View {
        HStack(spacing: 10) {
            if let session = today {
                Image(systemName: "figure.strengthtraining.functional")
                    .symbolEffect(.bounce, options: .repeat(.periodic(delay: 4)))
                    .foregroundStyle(Color.ptAccent)
                VStack(alignment: .leading, spacing: 0) {
                    Text(session.routine?.name ?? "Workout")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if placement != .inline {
                        Text("Today · \(session.scheduledDate.formatted(date: .omitted, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                Button {
                    onStart(session)
                } label: {
                    Image(systemName: "play.fill")
                }
                .accessibilityLabel("Start \(session.routine?.name ?? "workout")")
            } else {
                Image(systemName: "leaf.fill")
                    .symbolEffect(.breathe)
                    .foregroundStyle(Color.ptSecondary)
                Text(next.map { "Rest day · next \($0.scheduledDate.formatted(.dateTime.weekday(.wide)))" }
                     ?? "Rest day")
                    .font(.subheadline)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 16)
    }
}

private struct SessionExpiredBanner: View {
    let onSignIn: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .foregroundColor(.ptAccent)
            Text("You've been signed out.")
                .font(.subheadline)
            Spacer()
            Button("Sign In", action: onSignIn)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.ptAccent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .ptGlass(cornerRadius: PTRadius.md, tint: .ptAccentSoft)
        .padding(.horizontal, PTSpacing.md)
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
