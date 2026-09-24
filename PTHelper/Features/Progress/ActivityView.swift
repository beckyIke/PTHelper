import SwiftUI
import SwiftData

struct ActivityView: View {
    @Query(sort: \ExerciseLog.completedAt, order: .reverse) private var allLogs: [ExerciseLog]
    @Query(sort: \ScheduledSession.scheduledDate, order: .reverse) private var allSessions: [ScheduledSession]

    /// Drives the entrance animations; reset on disappear so they replay each time the tab opens.
    @State private var appeared = false

    private var completedSessions: [ScheduledSession] { allSessions.filter(\.isCompleted) }

    private var stats: ProgressStats {
        ProgressStats(
            sessions: allSessions.map {
                SessionRecord(scheduledDate: $0.scheduledDate, isCompleted: $0.isCompleted, completedAt: $0.completedAt)
            },
            logs: allLogs.map {
                LogRecord(
                    completedAt: $0.completedAt,
                    exerciseName: $0.exercise?.name ?? "Unknown",
                    setsCompleted: $0.setsCompleted,
                    repsCompleted: $0.repsCompleted,
                    durationSeconds: $0.durationSeconds,
                    painLevel: $0.painLevel
                )
            }
        )
    }

    var body: some View {
        let stats = stats
        NavigationStack {
            List {
                if let message = encouragement(for: stats) {
                    Section {
                        EncouragementBanner(message: message)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 0, trailing: 16))
                            .listRowBackground(Color.clear)
                    }
                }

                // Streaks — ring for perfect days this week, flame for the weeks streak
                Section {
                    VStack(spacing: 20) {
                        HStack(spacing: 20) {
                            WeekRingView(
                                perfectDays: stats.perfectDaysThisWeek,
                                scheduledDays: stats.scheduledDaysThisWeek,
                                appeared: appeared
                            )
                            WeeksStreakView(
                                streak: stats.weekStreak,
                                totalPerfectWeeks: stats.totalPerfectWeeks,
                                usedGrace: stats.streakUsedGrace,
                                appeared: appeared
                            )
                        }
                        WeekDayStrip(days: stats.thisWeek.days, appeared: appeared)
                    }
                    .padding(16)
                    .ptCardStyle()
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                } header: {
                    PTSectionHeader("This Week")
                }

                Section {
                    HStack(spacing: 10) {
                        StatCard(
                            value: stats.consistency30Day.map { "\(Int(($0 * 100).rounded()))%" } ?? "—",
                            label: "30-Day Consistency",
                            background: .ptSecondary,
                            foreground: .white
                        )
                        StatCard(
                            value: painTrendText(stats.painTrend),
                            label: "Pain vs. Last Month",
                            background: .ptAccentSoft,
                            foreground: .primary
                        )
                        StatCard(
                            value: stats.bestWeekRate.map { "\(Int(($0 * 100).rounded()))%" } ?? "—",
                            label: "Best Week",
                            background: .ptAccent,
                            foreground: .white
                        )
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                }

                Section {
                    WeeklyHistoryChart(weeks: stats.weeklyHistory, appeared: appeared)
                        .padding(16)
                        .ptCardStyle()
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                } header: {
                    PTSectionHeader("Weekly Completion")
                }

                Section {
                    ActivityHeatmap(weeks: stats.weeklyHistory, appeared: appeared)
                        .padding(16)
                        .ptCardStyle()
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                } header: {
                    PTSectionHeader("Last \(ProgressStats.historyWeeks) Weeks")
                }

                Section {
                    LabeledContent("Sessions Completed", value: "\(stats.sessionsThisMonth)")
                    LabeledContent("Exercises Logged", value: "\(stats.exercisesThisMonth)")
                    LabeledContent("Total Reps", value: "\(stats.repsThisMonth)")
                } header: {
                    PTSectionHeader("This Month")
                }
                .ptGlassRow()

                if !stats.personalRecords.isEmpty {
                    Section {
                        ForEach(stats.personalRecords) { record in
                            PersonalRecordRow(record: record)
                        }
                    } header: {
                        PTSectionHeader("Personal Bests")
                    }
                    .ptGlassRow()
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
                    PTSectionHeader("All Time")
                }
                .ptGlassRow()

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
                        PTSectionHeader("Recent Activity")
                    }
                    .ptGlassRow()
                }
            }
            .listRowSpacing(8)
            .ptBackground()
            .navigationTitle("Progress")
            .onAppear { appeared = true }
            .onDisappear { appeared = false }
        }
    }

    private func painTrendText(_ trend: Double?) -> String {
        guard let trend else { return "—" }
        if abs(trend) < 0.05 { return "Same" }
        return String(format: "%@%.1f", trend < 0 ? "↓" : "↑", abs(trend))
    }

    /// A short, positive message for the top of the screen — comeback first, then streak/pain wins.
    private func encouragement(for stats: ProgressStats) -> String? {
        if stats.isComeback {
            return "Welcome back! Picking it up again is what builds progress."
        }
        if stats.streakUsedGrace {
            return "One missed day didn't break your streak — keep it going this week."
        }
        if let trend = stats.painTrend, trend <= -0.5 {
            return String(format: "Your pain is down %.1f points from a month ago. The work is paying off.", -trend)
        }
        return nil
    }
}

struct EncouragementBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundColor(.ptAccent)
                .symbolEffect(.wiggle, options: .repeat(.periodic(delay: 3)))
            Text(message)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .ptGlass(cornerRadius: PTRadius.md, tint: .ptAccentSoft)
        .ptEntrance()
    }
}

struct PersonalRecordRow: View {
    let record: PersonalRecord

    var body: some View {
        HStack {
            Image(systemName: "trophy.fill")
                .foregroundColor(.ptAccent)
            VStack(alignment: .leading, spacing: 2) {
                Text(record.exerciseName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(record.achievedAt, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(record.isDuration ? "\(record.value)s hold" : "\(record.value) reps")
                .font(.subheadline.weight(.semibold))
        }
        .accessibilityElement(children: .combine)
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
                    Text("\(log.setsCompleted) × \(log.durationSeconds)s")
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

// MARK: - Preview

#if DEBUG
extension ModelContainer {
    /// In-memory store with ~10 weeks of Mon/Wed/Fri sessions, a few misses and easing pain.
    @MainActor static var progressPreview: ModelContainer {
        let container = try! ModelContainer(
            for: Exercise.self, Routine.self, RoutineExercise.self, ScheduledSession.self, ExerciseLog.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let calendar = Calendar.current
        let bridge = Exercise(name: "Glute Bridge", category: "Strength", bodyPart: "Hip")
        let plank = Exercise(name: "Plank", category: "Core", bodyPart: "Core", defaultReps: 0, defaultDurationSeconds: 30)
        let routine = Routine(name: "Hip Rehab")
        context.insert(bridge)
        context.insert(plank)
        context.insert(routine)

        let today = calendar.startOfDay(for: Date())
        let missedDaysAgo: Set<Int> = [23, 40, 41]
        for daysAgo in 0..<70 {
            let day = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
            guard [2, 4, 6].contains(calendar.component(.weekday, from: day)) else { continue }
            let scheduled = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day)!
            let session = ScheduledSession(routine: routine, scheduledDate: scheduled)
            context.insert(session)
            guard daysAgo > 0, !missedDaysAgo.contains(daysAgo) else { continue }
            session.isCompleted = true
            session.completedAt = scheduled
            let pain = max(0, 6 - (70 - daysAgo) / 12)
            let bridgeLog = ExerciseLog(exercise: bridge, session: session, setsCompleted: 3,
                                        repsCompleted: 10 + (70 - daysAgo) / 15, painLevel: pain)
            let plankLog = ExerciseLog(exercise: plank, session: session, setsCompleted: 3, repsCompleted: 0,
                                       durationSeconds: 20 + (70 - daysAgo) / 3, painLevel: pain)
            bridgeLog.completedAt = scheduled
            plankLog.completedAt = scheduled
            context.insert(bridgeLog)
            context.insert(plankLog)
        }
        return container
    }
}

#Preview {
    ActivityView()
        .modelContainer(.progressPreview)
}
#endif
