import SwiftUI
import SwiftData

struct SessionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let session: ScheduledSession

    @State private var showingWorkout = false

    var sortedExercises: [RoutineExercise] {
        (session.routine?.exercises ?? []).sorted { $0.order < $1.order }
    }

    var body: some View {
        List {
            // Status banner
            Section {
                SessionStatusBanner(session: session)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            // Session metadata
            Section {
                LabeledContent("Routine") {
                    Text(session.routine?.name ?? "Unknown")
                        .font(.ptSerif(.body))
                        .foregroundColor(.primary)
                }
                LabeledContent("Scheduled",
                    value: session.scheduledDate.formatted(date: .abbreviated, time: .shortened))
                if session.isCompleted, let completedAt = session.completedAt {
                    LabeledContent("Completed",
                        value: completedAt.formatted(date: .abbreviated, time: .shortened))
                }
            } header: {
                Text("Session")
                    .font(.ptSerif(.subheadline, weight: .semibold))
            }
            .ptGlassRow()

            // Exercise list
            if !sortedExercises.isEmpty {
                Section {
                    ForEach(sortedExercises) { re in
                        HStack {
                            Text(re.exercise?.name ?? "Unknown")
                                .font(.ptSerif(.body))
                            Spacer()
                            Text(re.displayTarget)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    PTSectionHeader("Exercises (\(sortedExercises.count))")
                }
                .ptGlassRow()
            }

            // Results (after completion)
            if !session.logs.isEmpty {
                Section {
                    ForEach(session.logs, id: \.persistentModelID) { log in
                        SessionLogRow(log: log)
                    }
                } header: {
                    PTSectionHeader("Results")
                }
                .ptGlassRow()
            }

            // Start workout CTA
            if !session.isCompleted {
                Section {
                    Button {
                        showingWorkout = true
                    } label: {
                        Label("Start Workout", systemImage: "play.fill")
                            .labelStyle(.titleAndIcon)
                            .font(.ptSerif(.body, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .ptPrimaryButton()
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
        }
        .listRowSpacing(8)
        .ptBackground()
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showingWorkout) {
            SessionWorkoutView(session: session)
        }
    }
}

// MARK: - Status banner

private struct SessionStatusBanner: View {
    let session: ScheduledSession

    private var isOverdue: Bool {
        !session.isCompleted && session.scheduledDate < Date()
    }

    private var bannerColor: Color {
        if session.isCompleted { return .ptSecondary }
        if isOverdue            { return .orange }
        return .ptAccent
    }

    private var icon: String {
        if session.isCompleted { return "checkmark.circle.fill" }
        if isOverdue            { return "exclamationmark.circle.fill" }
        return "calendar"
    }

    private var statusText: String {
        if session.isCompleted { return "Completed" }
        if isOverdue            { return "Overdue" }
        return "Upcoming"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
                .symbolEffect(.bounce, options: .nonRepeating, value: session.isCompleted)

            VStack(alignment: .leading, spacing: 2) {
                Text(statusText)
                    .font(.ptSerif(.headline, weight: .semibold))
                    .foregroundColor(.white)
                Text(session.scheduledDate, format: .dateTime.weekday(.wide).month().day().hour().minute())
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.85))
            }

            Spacer()
        }
        .padding(18)
        .glassEffect(.regular.tint(bannerColor), in: .rect(cornerRadius: PTRadius.lg))
    }
}

// MARK: - Log row

private struct SessionLogRow: View {
    let log: ExerciseLog

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(log.exercise?.name ?? "Unknown")
                .font(.ptSerif(.subheadline, weight: .semibold))
            HStack(spacing: 8) {
                if log.durationSeconds > 0 && log.repsCompleted == 0 {
                    Text("\(log.setsCompleted) sets × \(log.durationSeconds)s")
                        .font(.caption).foregroundColor(.secondary)
                } else {
                    Text("\(log.setsCompleted) sets × \(log.repsCompleted) reps")
                        .font(.caption).foregroundColor(.secondary)
                }
                if log.painLevel > 0 {
                    Text("· Pain \(log.painLevel)/10")
                        .font(.caption)
                        .foregroundColor(log.painLevel > 5 ? .red : .orange)
                }
            }
            if !log.notes.isEmpty {
                Text(log.notes)
                    .font(.caption).foregroundColor(.secondary).lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }
}
