import Foundation
import SwiftData

enum RecurrenceType: String, CaseIterable, Identifiable {
    case none    = "none"
    case daily   = "daily"
    case weekly  = "weekly"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none:   return "None"
        case .daily:  return "Daily"
        case .weekly: return "Weekly"
        }
    }
}

@Model final class Routine {
    var name: String
    var createdAt: Date

    // Recurrence — stored as raw strings so SwiftData doesn't need Codable enums
    var recurrenceType: String = RecurrenceType.none.rawValue
    /// Comma-separated Calendar.weekday integers (1=Sun … 7=Sat), e.g. "2,4,6"
    var recurrenceWeekdays: String = ""
    /// Stores only the time-of-day portion; date component is ignored
    var recurrenceTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()

    @Relationship(deleteRule: .cascade, inverse: \RoutineExercise.routine)
    var exercises: [RoutineExercise] = []

    @Relationship(deleteRule: .nullify, inverse: \ScheduledSession.routine)
    var sessions: [ScheduledSession] = []

    init(name: String) {
        self.name = name
        self.createdAt = Date()
    }
}

extension Routine {
    var recurrence: RecurrenceType {
        get { RecurrenceType(rawValue: recurrenceType) ?? .none }
        set { recurrenceType = newValue.rawValue }
    }

    var weekdayInts: [Int] {
        get {
            recurrenceWeekdays
                .split(separator: ",")
                .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        }
        set {
            recurrenceWeekdays = newValue.sorted().map(String.init).joined(separator: ",")
        }
    }

    var recurrenceSummary: String {
        switch recurrence {
        case .none:
            return "No repeat"
        case .daily:
            return "Repeats daily"
        case .weekly:
            let days = weekdayInts
            guard !days.isEmpty else { return "Weekly (no days set)" }
            let names = days.sorted().compactMap { Self.shortWeekdayName($0) }
            return "Weekly: " + names.joined(separator: ", ")
        }
    }

    static func shortWeekdayName(_ weekday: Int) -> String? {
        let names = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        guard (1...7).contains(weekday) else { return nil }
        return names[weekday]
    }
}

@Model final class RoutineExercise {
    var sets: Int
    var reps: Int
    var durationSeconds: Int
    var order: Int
    var notes: String

    var routine: Routine?
    var exercise: Exercise?

    init(
        exercise: Exercise,
        sets: Int,
        reps: Int,
        durationSeconds: Int = 0,
        order: Int = 0,
        notes: String = ""
    ) {
        self.exercise = exercise
        self.sets = sets
        self.reps = reps
        self.durationSeconds = durationSeconds
        self.order = order
        self.notes = notes
    }
}

extension RoutineExercise {
    var isTimeBased: Bool { durationSeconds > 0 && reps == 0 }

    var displayTarget: String {
        if isTimeBased {
            return "\(sets) × \(durationSeconds)s"
        }
        return "\(sets) × \(reps) reps"
    }
}
