import Foundation

// MARK: - Inputs

/// Plain-value copy of a `ScheduledSession`, so stats can be computed and tested without SwiftData.
struct SessionRecord {
    let scheduledDate: Date
    let isCompleted: Bool
    let completedAt: Date?
}

/// Plain-value copy of an `ExerciseLog`.
struct LogRecord {
    let completedAt: Date
    let exerciseName: String
    let setsCompleted: Int
    let repsCompleted: Int
    let durationSeconds: Int
    let painLevel: Int
}

// MARK: - Summaries

enum DayStatus {
    /// Nothing scheduled — never breaks or extends a streak.
    case rest
    /// Every session scheduled that day was completed.
    case complete
    /// Some, but not all, sessions were completed.
    case partial
    /// A past day where nothing was completed.
    case missed
    /// Today (not yet finished) or a future day.
    case upcoming
}

struct DaySummary: Identifiable {
    let date: Date
    let scheduled: Int
    let completed: Int
    let status: DayStatus
    /// Whether this day counts toward completion rates. Past days always count; today only once it's complete,
    /// so users aren't penalised for a day that isn't over yet.
    let isDue: Bool

    var id: Date { date }
}

struct WeekSummary: Identifiable {
    let start: Date
    let days: [DaySummary]
    let isFinished: Bool

    var id: Date { start }

    var scheduledDays: Int { days.filter { $0.scheduled > 0 }.count }
    var completeDays: Int { days.filter { $0.status == .complete }.count }

    /// Fraction (0…1) of due sessions completed, or nil when nothing was due.
    var completionRate: Double? {
        let due = days.filter(\.isDue)
        let scheduled = due.map(\.scheduled).reduce(0, +)
        guard scheduled > 0 else { return nil }
        return Double(due.map(\.completed).reduce(0, +)) / Double(scheduled)
    }

    /// A finished week where every scheduled day was completed.
    var isPerfect: Bool { isFinished && scheduledDays > 0 && completeDays == scheduledDays }

    /// Perfect, or missing no more than `ProgressStats.graceDaysPerWeek` days — keeps the weeks streak alive.
    var keepsStreak: Bool {
        isFinished && completeDays > 0 && scheduledDays - completeDays <= ProgressStats.graceDaysPerWeek
    }

    var usedGrace: Bool { keepsStreak && !isPerfect }
}

struct PersonalRecord: Identifiable {
    let exerciseName: String
    /// Seconds when `isDuration`, otherwise reps.
    let value: Int
    let isDuration: Bool
    let achievedAt: Date

    var id: String { exerciseName }
}

// MARK: - Stats

struct ProgressStats {
    /// Missed days allowed per week before the weeks streak breaks.
    static let graceDaysPerWeek = 1
    /// Number of weeks shown in the history chart and heatmap.
    static let historyWeeks = 12

    /// Oldest first; the last entry is the current week.
    let weeklyHistory: [WeekSummary]
    var thisWeek: WeekSummary { weeklyHistory[weeklyHistory.count - 1] }

    /// Days this week where every scheduled session was completed.
    let perfectDaysThisWeek: Int
    /// Days this week with at least one scheduled session.
    let scheduledDaysThisWeek: Int

    /// Consecutive finished weeks that kept the streak (perfect, or within the grace allowance).
    let weekStreak: Int
    /// The most recent week in the streak was saved by a grace day.
    let streakUsedGrace: Bool
    /// Finished weeks where every scheduled day was completed, all time.
    let totalPerfectWeeks: Int

    /// Fraction (0…1) of due sessions completed over the last 30 days, or nil when nothing was due.
    let consistency30Day: Double?
    /// Best completion rate of any week.
    let bestWeekRate: Double?
    /// Average pain over the last 7 days minus the average 3–5 weeks ago. Negative means less pain.
    let painTrend: Double?
    /// The user completed a session today or yesterday after missing their previous scheduled day.
    let isComeback: Bool

    let sessionsThisMonth: Int
    let exercisesThisMonth: Int
    let repsThisMonth: Int

    /// Most recently set personal bests, newest first.
    let personalRecords: [PersonalRecord]

    init(sessions: [SessionRecord], logs: [LogRecord], now: Date = Date(), calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: now)

        // Scheduled / completed counts per day, keyed by the day the session was scheduled for.
        var buckets: [Date: (scheduled: Int, completed: Int)] = [:]
        for session in sessions {
            let day = calendar.startOfDay(for: session.scheduledDate)
            buckets[day, default: (0, 0)].scheduled += 1
            if session.isCompleted { buckets[day, default: (0, 0)].completed += 1 }
        }

        func summary(for day: Date) -> DaySummary {
            let counts = buckets[day] ?? (0, 0)
            let status: DayStatus
            if counts.scheduled == 0 {
                status = .rest
            } else if counts.completed >= counts.scheduled {
                status = .complete
            } else if day >= today {
                status = counts.completed > 0 ? .partial : .upcoming
            } else {
                status = counts.completed > 0 ? .partial : .missed
            }
            let isDue = day < today || (day == today && status == .complete)
            return DaySummary(date: day, scheduled: counts.scheduled, completed: counts.completed,
                              status: status, isDue: isDue)
        }

        func addingDays(_ days: Int, to date: Date) -> Date {
            calendar.date(byAdding: .day, value: days, to: date)!
        }

        // Every week from the first scheduled session (or the start of the chart window) through this week.
        let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: today)!.start
        let historyStart = calendar.date(byAdding: .weekOfYear, value: -(Self.historyWeeks - 1), to: thisWeekStart)!
        let firstSessionWeek = sessions.map(\.scheduledDate).min()
            .map { calendar.dateInterval(of: .weekOfYear, for: $0)!.start }
        var weekStart = min(firstSessionWeek ?? historyStart, historyStart)
        var allWeeks: [WeekSummary] = []
        while weekStart <= thisWeekStart {
            let days = (0..<7).map { summary(for: addingDays($0, to: weekStart)) }
            let weekEnd = addingDays(7, to: weekStart)
            allWeeks.append(WeekSummary(start: weekStart, days: days, isFinished: weekEnd <= today))
            weekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart)!
        }

        weeklyHistory = Array(allWeeks.suffix(Self.historyWeeks))
        let currentWeek = allWeeks[allWeeks.count - 1]
        perfectDaysThisWeek = currentWeek.completeDays
        scheduledDaysThisWeek = currentWeek.scheduledDays

        // Weeks streak — walk back through finished weeks; weeks with nothing scheduled are skipped.
        var streak = 0
        var usedGrace = false
        for week in allWeeks.reversed() where week.isFinished && week.scheduledDays > 0 {
            guard week.keepsStreak else { break }
            if streak == 0 { usedGrace = week.usedGrace }
            streak += 1
        }
        // If this week has already missed more days than the grace allowance, the streak is over.
        let missedSoFar = currentWeek.days.filter { $0.isDue && $0.scheduled > 0 && $0.status != .complete }.count
        if missedSoFar > Self.graceDaysPerWeek {
            streak = 0
            usedGrace = false
        }
        weekStreak = streak
        streakUsedGrace = usedGrace
        totalPerfectWeeks = allWeeks.filter(\.isPerfect).count
        bestWeekRate = allWeeks.compactMap(\.completionRate).max()

        // 30-day consistency
        let last30 = (0..<30).map { summary(for: addingDays(-$0, to: today)) }.filter(\.isDue)
        let scheduled30 = last30.map(\.scheduled).reduce(0, +)
        consistency30Day = scheduled30 > 0
            ? Double(last30.map(\.completed).reduce(0, +)) / Double(scheduled30)
            : nil

        // Pain trend — last 7 days vs. the same length of time about a month ago.
        func averagePain(from start: Date, to end: Date) -> Double? {
            let levels = logs.filter { $0.completedAt >= start && $0.completedAt < end }.map(\.painLevel)
            guard !levels.isEmpty else { return nil }
            return Double(levels.reduce(0, +)) / Double(levels.count)
        }
        let tomorrow = addingDays(1, to: today)
        if let recent = averagePain(from: addingDays(-6, to: today), to: tomorrow),
           let baseline = averagePain(from: addingDays(-34, to: today), to: addingDays(-20, to: today)) {
            painTrend = recent - baseline
        } else {
            painTrend = nil
        }

        // Comeback — completed something today or yesterday after missing the previous scheduled day.
        let sortedDays = buckets.keys.filter { $0 <= today }.sorted(by: >)
        if let lastActive = sortedDays.first(where: { buckets[$0]!.completed > 0 }),
           lastActive >= addingDays(-1, to: today),
           let previous = sortedDays.first(where: { $0 < lastActive && buckets[$0]!.scheduled > 0 }) {
            isComeback = buckets[previous]!.completed == 0
        } else {
            isComeback = false
        }

        // This month
        let month = calendar.dateInterval(of: .month, for: today)!
        sessionsThisMonth = sessions.filter {
            $0.isCompleted && month.contains($0.completedAt ?? $0.scheduledDate)
        }.count
        let monthLogs = logs.filter { month.contains($0.completedAt) }
        exercisesThisMonth = monthLogs.count
        repsThisMonth = monthLogs.map { $0.setsCompleted * $0.repsCompleted }.reduce(0, +)

        // Personal records — best hold or rep count per exercise, once there's something to beat.
        var records: [PersonalRecord] = []
        for (name, exerciseLogs) in Dictionary(grouping: logs, by: \.exerciseName) where exerciseLogs.count >= 2 {
            let timed = exerciseLogs.filter { $0.durationSeconds > 0 && $0.repsCompleted == 0 }
            let isDuration = !timed.isEmpty
            let relevant = isDuration ? timed : exerciseLogs
            let value: (LogRecord) -> Int = { isDuration ? $0.durationSeconds : $0.repsCompleted }
            guard let best = relevant.map(value).max(), best > 0,
                  let firstBest = relevant.filter({ value($0) == best }).min(by: { $0.completedAt < $1.completedAt })
            else { continue }
            records.append(PersonalRecord(exerciseName: name, value: best, isDuration: isDuration,
                                          achievedAt: firstBest.completedAt))
        }
        personalRecords = Array(records.sorted { $0.achievedAt > $1.achievedAt }.prefix(5))
    }
}
