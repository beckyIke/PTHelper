import Foundation
import SwiftData

@Model final class ExerciseLog {
    var completedAt: Date
    var setsCompleted: Int
    var repsCompleted: Int
    var durationSeconds: Int
    var performedBothSides: Bool = false
    var notes: String
    var painLevel: Int // 0–10, 0 = no pain

    var exercise: Exercise?
    var session: ScheduledSession?

    init(
        exercise: Exercise,
        session: ScheduledSession? = nil,
        setsCompleted: Int,
        repsCompleted: Int,
        durationSeconds: Int = 0,
        performedBothSides: Bool = false,
        notes: String = "",
        painLevel: Int = 0
    ) {
        self.exercise = exercise
        self.session = session
        self.setsCompleted = setsCompleted
        self.repsCompleted = repsCompleted
        self.durationSeconds = durationSeconds
        self.performedBothSides = performedBothSides
        self.notes = notes
        self.painLevel = painLevel
        self.completedAt = Date()
    }
}
