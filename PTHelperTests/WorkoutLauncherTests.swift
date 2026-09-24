import Foundation
import SwiftData
import Testing
@testable import PTHelper

@MainActor
struct WorkoutLauncherTests {
    private let container: ModelContainer
    private let context: ModelContext
    private let routine: Routine

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        calendar.firstWeekday = 2
        return calendar
    }()

    /// Wednesday 2026-09-23, noon.
    private let now = WorkoutLauncherTests.date(23, hour: 12)

    init() throws {
        container = try ModelContainer(
            for: Exercise.self, Routine.self, RoutineExercise.self, ScheduledSession.self, ExerciseLog.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = container.mainContext
        routine = Routine(name: "Hip Rehab")
        context.insert(routine)
    }

    private static func date(_ day: Int, hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour))!
    }

    @discardableResult
    private func schedule(_ routine: Routine, day: Int, hour: Int, done: Bool = false) -> ScheduledSession {
        let session = ScheduledSession(routine: routine, scheduledDate: Self.date(day, hour: hour))
        session.isCompleted = done
        context.insert(session)
        return session
    }

    private func sessionCount() throws -> Int {
        try context.fetchCount(FetchDescriptor<ScheduledSession>())
    }

    private func start() -> WorkoutLauncher.Launch {
        WorkoutLauncher.start(routine, context: context, now: now, calendar: Self.calendar)
    }

    // MARK: Choosing a session

    @Test func reusesTodaysScheduledSession() throws {
        let scheduled = schedule(routine, day: 23, hour: 18)
        let before = try sessionCount()

        let launch = start()

        #expect(launch.session === scheduled)
        #expect(!launch.isAdHoc)
        #expect(try sessionCount() == before)
    }

    @Test func picksEarliestPendingSessionToday() {
        schedule(routine, day: 23, hour: 18)
        let morning = schedule(routine, day: 23, hour: 8)

        #expect(start().session === morning)
    }

    @Test func createsSessionWhenTodaysIsAlreadyDone() throws {
        schedule(routine, day: 23, hour: 9, done: true)

        let launch = start()

        #expect(launch.isAdHoc)
        #expect(!launch.session.isCompleted)
        #expect(try sessionCount() == 2)
    }

    @Test func ignoresOtherDaysAndOtherRoutines() {
        schedule(routine, day: 22, hour: 18)   // yesterday, overdue
        schedule(routine, day: 24, hour: 9)    // tomorrow
        let other = Routine(name: "Knee Mobility")
        context.insert(other)
        schedule(other, day: 23, hour: 18)     // today, but a different routine

        let launch = start()

        #expect(launch.isAdHoc)
        #expect(launch.session.routine === routine)
        #expect(Self.calendar.isDate(launch.session.scheduledDate, inSameDayAs: now))
    }

    // MARK: Cleaning up

    @Test func exitingAnAdHocRunDeletesIt() throws {
        let launch = start()
        #expect(launch.isAdHoc)

        WorkoutLauncher.finish(launch, context: context)

        #expect(try sessionCount() == 0)
    }

    @Test func finishedAdHocRunIsKept() throws {
        let launch = start()
        launch.session.isCompleted = true
        launch.session.completedAt = now

        WorkoutLauncher.finish(launch, context: context)

        #expect(try sessionCount() == 1)
    }

    @Test func exitingAScheduledSessionKeepsIt() throws {
        schedule(routine, day: 23, hour: 18)
        let launch = start()

        WorkoutLauncher.finish(launch, context: context)

        #expect(try sessionCount() == 1)
        #expect(!launch.session.isCompleted)
    }

    // MARK: End to end with progress

    @Test func manualRunOnAScheduledDayCountsAsComplete() throws {
        schedule(routine, day: 23, hour: 18)

        let launch = start()
        launch.session.isCompleted = true
        launch.session.completedAt = now
        WorkoutLauncher.finish(launch, context: context)

        let sessions = try context.fetch(FetchDescriptor<ScheduledSession>()).map {
            SessionRecord(scheduledDate: $0.scheduledDate, isCompleted: $0.isCompleted, completedAt: $0.completedAt)
        }
        let stats = ProgressStats(sessions: sessions, logs: [], now: now, calendar: Self.calendar)
        #expect(stats.thisWeek.days[2].status == .complete)
        #expect(stats.perfectDaysThisWeek == 1)
    }
}
