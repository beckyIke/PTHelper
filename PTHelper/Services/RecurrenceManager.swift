import Foundation
import SwiftData

struct RecurrenceManager {
    /// Generates upcoming sessions for all recurring routines within the next `weeksAhead` weeks.
    /// Safe to call on every launch — skips dates that already have a pending session.
    static func generateUpcomingSessions(context: ModelContext, weeksAhead: Int = 4) {
        let descriptor = FetchDescriptor<Routine>()
        guard let routines = try? context.fetch(descriptor) else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let endDate = calendar.date(byAdding: .weekOfYear, value: weeksAhead, to: today) else { return }

        for routine in routines {
            let recurrence = routine.recurrence
            guard recurrence != .none else { continue }

            let weekdays = routine.weekdayInts
            if recurrence == .weekly && weekdays.isEmpty { continue }

            // Dates in [today, endDate) that match the recurrence pattern
            var targetDays: [Date] = []
            var cursor = today
            while cursor < endDate {
                let matches = recurrence == .daily
                    || weekdays.contains(calendar.component(.weekday, from: cursor))
                if matches { targetDays.append(cursor) }
                cursor = calendar.date(byAdding: .day, value: 1, to: cursor)!
            }

            // Days that already have a session for this routine. Completed sessions count too,
            // otherwise finishing today's workout would schedule a second one on the next launch.
            let existingDays = Set(
                routine.sessions.map { calendar.startOfDay(for: $0.scheduledDate) }
            )

            let timeComponents = calendar.dateComponents([.hour, .minute], from: routine.recurrenceTime)
            let hour   = timeComponents.hour   ?? 9
            let minute = timeComponents.minute ?? 0

            for day in targetDays where !existingDays.contains(day) {
                guard let sessionDate = calendar.date(
                    bySettingHour: hour, minute: minute, second: 0, of: day
                ) else { continue }
                context.insert(ScheduledSession(routine: routine, scheduledDate: sessionDate))
            }
        }

        try? context.save()
    }

    /// Call after changing a routine's recurrence settings to immediately populate new sessions.
    static func regenerate(for routine: Routine, context: ModelContext, weeksAhead: Int = 4) {
        generateUpcomingSessions(context: context, weeksAhead: weeksAhead)
    }
}
