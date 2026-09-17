import Foundation
import SwiftData

@Model final class ScheduledSession {
    var scheduledDate: Date
    var isCompleted: Bool
    var completedAt: Date?

    var routine: Routine?

    @Relationship(deleteRule: .cascade, inverse: \ExerciseLog.session)
    var logs: [ExerciseLog] = []

    init(routine: Routine, scheduledDate: Date) {
        self.routine = routine
        self.scheduledDate = scheduledDate
        self.isCompleted = false
    }
}
