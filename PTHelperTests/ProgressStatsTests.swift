import Foundation
import Testing
@testable import PTHelper

@MainActor
struct ProgressStatsTests {
    /// Gregorian, Monday-first, fixed time zone so results don't depend on the machine running the tests.
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        calendar.firstWeekday = 2
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 9) -> Date {
        Self.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func session(_ day: Date, done: Bool) -> SessionRecord {
        SessionRecord(scheduledDate: day, isCompleted: done, completedAt: done ? day : nil)
    }

    private func stats(_ sessions: [SessionRecord], logs: [LogRecord] = [], now: Date) -> ProgressStats {
        ProgressStats(sessions: sessions, logs: logs, now: now, calendar: Self.calendar)
    }

    // Wednesday 2026-09-23; the week starts Monday 2026-09-21.
    private var wednesday: Date { date(2026, 9, 23, hour: 12) }

    @Test func countsPerfectDaysThisWeek() {
        let result = stats([
            session(date(2026, 9, 21), done: true),
            session(date(2026, 9, 22), done: true),
            session(date(2026, 9, 22, hour: 18), done: false), // Tuesday partial
            session(date(2026, 9, 23), done: false),           // today, not done yet
            session(date(2026, 9, 25), done: false),           // Friday, upcoming
        ], now: wednesday)

        #expect(result.perfectDaysThisWeek == 1)
        #expect(result.scheduledDaysThisWeek == 4)
        #expect(result.thisWeek.days.map(\.status) == [.complete, .partial, .upcoming, .rest, .upcoming, .rest, .rest])
    }

    @Test func todayCountsOnceComplete() {
        let result = stats([session(date(2026, 9, 23), done: true)], now: wednesday)
        #expect(result.perfectDaysThisWeek == 1)
        #expect(result.thisWeek.days[2].status == .complete)
    }

    @Test func pastDayWithNothingDoneIsMissed() {
        let result = stats([session(date(2026, 9, 22), done: false)], now: wednesday)
        #expect(result.thisWeek.days[1].status == .missed)
    }

    @Test func weeksStreakCountsConsecutivePerfectWeeks() {
        // Mon/Wed/Fri for the three previous weeks, all completed.
        let starts = [date(2026, 8, 31), date(2026, 9, 7), date(2026, 9, 14)]
        let sessions = starts.flatMap { start in
            [0, 2, 4].map { session(Self.calendar.date(byAdding: .day, value: $0, to: start)!, done: true) }
        }
        let result = stats(sessions, now: wednesday)
        #expect(result.weekStreak == 3)
        #expect(result.totalPerfectWeeks == 3)
        #expect(!result.streakUsedGrace)
    }

    @Test func oneMissedDayIsForgiven() {
        let result = stats([
            session(date(2026, 9, 7), done: true),
            session(date(2026, 9, 14), done: true),
            session(date(2026, 9, 16), done: false), // one miss — grace day
            session(date(2026, 9, 18), done: true),
        ], now: wednesday)
        #expect(result.weekStreak == 2)
        #expect(result.streakUsedGrace)
        #expect(result.totalPerfectWeeks == 1)
    }

    @Test func twoMissedDaysBreakTheStreak() {
        let result = stats([
            session(date(2026, 9, 7), done: true),
            session(date(2026, 9, 14), done: true),
            session(date(2026, 9, 16), done: false),
            session(date(2026, 9, 18), done: false),
        ], now: wednesday)
        #expect(result.weekStreak == 0)
        #expect(result.totalPerfectWeeks == 1)
    }

    @Test func weeksWithNothingScheduledAreSkipped() {
        let result = stats([
            session(date(2026, 9, 1), done: true),
            // Nothing scheduled the week of Sep 7
            session(date(2026, 9, 15), done: true),
        ], now: wednesday)
        #expect(result.weekStreak == 2)
    }

    @Test func currentWeekBreaksStreakOnceGraceIsUsedUp() {
        let result = stats([
            session(date(2026, 9, 14), done: true),
            session(date(2026, 9, 21), done: false),
            session(date(2026, 9, 22), done: false),
        ], now: wednesday)
        #expect(result.weekStreak == 0)
    }

    @Test func streakCrossesYearBoundary() {
        let newYear = date(2027, 1, 6, hour: 12) // Wednesday
        let result = stats([
            session(date(2026, 12, 23), done: true),
            session(date(2026, 12, 30), done: true),
        ], now: newYear)
        #expect(result.weekStreak == 2)
    }

    @Test func sundayFirstCalendarGroupsWeeksDifferently() {
        var sundayCalendar = Self.calendar
        sundayCalendar.firstWeekday = 1
        let result = ProgressStats(
            sessions: [session(date(2026, 9, 20), done: true)], // Sunday
            logs: [],
            now: wednesday,
            calendar: sundayCalendar
        )
        #expect(result.perfectDaysThisWeek == 1)
        #expect(result.thisWeek.days.first?.status == .complete)
    }

    @Test func consistencyIgnoresTodayUntilDone() {
        let result = stats([
            session(date(2026, 9, 21), done: true),
            session(date(2026, 9, 22), done: false),
            session(date(2026, 9, 23), done: false), // today — not counted yet
        ], now: wednesday)
        #expect(result.consistency30Day == 0.5)
    }

    @Test func detectsComeback() {
        let result = stats([
            session(date(2026, 9, 20), done: true),
            session(date(2026, 9, 21), done: false),
            session(date(2026, 9, 22), done: false),
            session(date(2026, 9, 23), done: true),
        ], now: wednesday)
        #expect(result.isComeback)

        let steady = stats([
            session(date(2026, 9, 22), done: true),
            session(date(2026, 9, 23), done: true),
        ], now: wednesday)
        #expect(!steady.isComeback)
    }

    @Test func painTrendComparesToAMonthAgo() {
        func log(_ day: Date, pain: Int) -> LogRecord {
            LogRecord(completedAt: day, exerciseName: "Bridge", setsCompleted: 3, repsCompleted: 10,
                      durationSeconds: 0, painLevel: pain)
        }
        let result = stats([], logs: [
            log(date(2026, 8, 25), pain: 6),
            log(date(2026, 8, 27), pain: 4),
            log(date(2026, 9, 22), pain: 2),
        ], now: wednesday)
        #expect(result.painTrend == -3)
    }

    @Test func personalRecordsNeedSomethingToBeat() {
        func log(_ name: String, _ day: Date, reps: Int = 0, seconds: Int = 0) -> LogRecord {
            LogRecord(completedAt: day, exerciseName: name, setsCompleted: 3, repsCompleted: reps,
                      durationSeconds: seconds, painLevel: 0)
        }
        let result = stats([], logs: [
            log("Plank", date(2026, 9, 10), seconds: 30),
            log("Plank", date(2026, 9, 20), seconds: 45),
            log("Bridge", date(2026, 9, 21), reps: 12),
            log("Bridge", date(2026, 9, 22), reps: 10),
            log("Clamshell", date(2026, 9, 22), reps: 15), // only one log — no record yet
        ], now: wednesday)
        #expect(result.personalRecords.map(\.exerciseName) == ["Bridge", "Plank"])
        #expect(result.personalRecords.first { $0.exerciseName == "Plank" }?.value == 45)
        #expect(result.personalRecords.first { $0.exerciseName == "Plank" }?.isDuration == true)
    }
}
