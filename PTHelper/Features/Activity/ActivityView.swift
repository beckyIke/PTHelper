import SwiftUI
import SwiftData

struct ActivityView: View {
    @Query(sort: \ExerciseLog.completedAt, order: .reverse) private var allLogs: [ExerciseLog]
    @Query(sort: \ScheduledSession.scheduledDate, order: .reverse) private var allSessions: [ScheduledSession]

    private var completedSessions: [ScheduledSession] { allSessions.filter(\.isCompleted) }

    private var weekAgo: Date {
        Calendar.current.date(byAdding: .day, value: -7, to: Date())!
    }
    private var sessionsThisWeek: Int {
        completedSessions.filter { $0.scheduledDate >= weekAgo }.count
    }
    private var logsThisWeek: [ExerciseLog] {
        allLogs.filter { $0.completedAt >= weekAgo }
    }

    /// Number of consecutive days ending today on which at least one session was completed.
    private var currentStreak: Int {
        let calendar = Calendar.current
        var streak = 0
        var day = calendar.startOfDay(for: Date())
        let completedDays = Set(
            completedSessions.map { calendar.startOfDay(for: $0.completedAt ?? $0.scheduledDate) }
        )
        while completedDays.contains(day) {
            streak += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return streak
    }

    var body: some View {
        NavigationStack {
            List {
                // Stat cards — match the image's three-card layout
                Section {
                    HStack(spacing: 10) {
                        StatCard(
                            value: "\(sessionsThisWeek)",
                            label: "Completed",
                            background: .ptSalmon,
                            foreground: .ptTerracotta
                        )
                        StatCard(
                            value: "\(logsThisWeek.count)",
                            label: "Exercises",
                            background: .ptSage,
                            foreground: .white
                        )
                        StatCard(
                            value: "\(currentStreak)",
                            label: "Day Streak",
                            background: .ptTerracotta,
                            foreground: .white
                        )
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                } header: {
                    Text("This Week")
                        .font(.ptSerif(.subheadline, weight: .semibold))
                }

                Section {
                    LabeledContent("Sessions Completed", value: "\(completedSessions.count)")
                    LabeledContent("Exercises Logged", value: "\(allLogs.count)")
                    if !allLogs.isEmpty {
                        let painful = allLogs.filter { $0.painLevel > 0 }
                        let avg = painful.isEmpty ? 0.0
                            : Double(painful.map(\.painLevel).reduce(0, +)) / Double(painful.count)
                        LabeledContent("Avg Pain Level", value: String(format: "%.1f / 10", avg))
                    }
                } header: {
                    Text("All Time")
                        .font(.ptSerif(.subheadline, weight: .semibold))
                }

                if allLogs.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "No Activity Yet",
                            systemImage: "chart.line.uptrend.xyaxis",
                            description: Text("Complete a workout to see your progress here.")
                        )
                        .listRowBackground(Color.clear)
                    }
                } else {
                    Section {
                        ForEach(allLogs.prefix(30), id: \.persistentModelID) { log in
                            ActivityLogRow(log: log)
                        }
                    } header: {
                        Text("Recent Activity")
                            .font(.ptSerif(.subheadline, weight: .semibold))
                    }
                }
            }
            .ptBackground()
            .navigationTitle("Progress")
        }
    }
}

struct ActivityLogRow: View {
    let log: ExerciseLog

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(log.exercise?.name ?? "Unknown")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(log.completedAt, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            HStack(spacing: 6) {
                if log.durationSeconds > 0 && log.repsCompleted == 0 {
                    Text("\(log.setsCompleted) × \(log.durationSeconds)s\(log.performedBothSides ? "/side" : "")")
                        .font(.caption).foregroundColor(.secondary)
                } else {
                    Text("\(log.setsCompleted) × \(log.repsCompleted) reps")
                        .font(.caption).foregroundColor(.secondary)
                }
                if log.painLevel > 0 {
                    Text("· Pain \(log.painLevel)/10")
                        .font(.caption)
                        .foregroundColor(log.painLevel > 5 ? .red : .orange)
                }
                if !log.notes.isEmpty {
                    Text("· \(log.notes)")
                        .font(.caption).foregroundColor(.secondary).lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
