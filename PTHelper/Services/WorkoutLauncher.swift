import Foundation
import SwiftData

/// Chooses which session a workout started from a routine's page should fill in, and cleans up after
/// workouts that are abandoned.
enum WorkoutLauncher {
    struct Launch {
        let session: ScheduledSession
        /// True when the session was created just for this run (nothing was scheduled today).
        let isAdHoc: Bool
    }

    /// Reuses the routine's earliest pending session today, so a manual run completes what was scheduled.
    /// Only when nothing is pending today does it create (and save) a new session.
    static func start(_ routine: Routine, context: ModelContext, now: Date = Date(),
                      calendar: Calendar = .current) -> Launch {
        let scheduledToday = routine.sessions
            .filter { !$0.isCompleted && calendar.isDate($0.scheduledDate, inSameDayAs: now) }
            .min { $0.scheduledDate < $1.scheduledDate }
        if let scheduledToday {
            return Launch(session: scheduledToday, isAdHoc: false)
        }

        let session = ScheduledSession(routine: routine, scheduledDate: now)
        context.insert(session)
        // Save now so the session's ID is permanent. Otherwise the first autosave mid-workout changes the ID,
        // and `.sheet(item:)` dismisses and re-presents the workout from the start.
        try? context.save()
        return Launch(session: session, isAdHoc: true)
    }

    /// Call when the workout screen closes. Deletes a session created just for this run if it wasn't finished,
    /// so an exited manual run doesn't linger as an unfinished (and later overdue) session.
    /// Scheduled sessions are always kept.
    static func finish(_ launch: Launch, context: ModelContext) {
        guard launch.isAdHoc, !launch.session.isCompleted else { return }
        context.delete(launch.session)
        try? context.save()
    }
}
