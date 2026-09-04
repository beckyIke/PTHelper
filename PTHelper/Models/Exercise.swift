import Foundation
import SwiftData

enum ExerciseCategory: String, Codable, CaseIterable, Identifiable {
    case strength = "Strength"
    case flexibility = "Flexibility"
    case balance = "Balance"
    case rangeOfMotion = "Range of Motion"
    case core = "Core"
    case cardio = "Cardio"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .strength: return "dumbbell"
        case .flexibility: return "figure.flexibility"
        case .balance: return "figure.stand"
        case .rangeOfMotion: return "arrow.clockwise"
        case .core: return "figure.core.training"
        case .cardio: return "heart.circle"
        }
    }
}

enum BodyPart: String, Codable, CaseIterable, Identifiable {
    case ankle = "Ankle/Foot"
    case knee = "Knee"
    case hip = "Hip"
    case lowerBack = "Lower Back"
    case shoulder = "Shoulder"
    case elbowWrist = "Elbow/Wrist"
    case neck = "Neck"
    case core = "Core"
    case fullBody = "Full Body"

    var id: String { rawValue }
}

@Model final class Exercise {
    var name: String
    var exerciseDescription: String
    var category: String
    var bodyPart: String
    var defaultSets: Int
    var defaultReps: Int
    var defaultDurationSeconds: Int
    var notes: String
    var isCustom: Bool
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \RoutineExercise.exercise)
    var routineExercises: [RoutineExercise] = []

    @Relationship(deleteRule: .nullify, inverse: \ExerciseLog.exercise)
    var logs: [ExerciseLog] = []

    init(
        name: String,
        description: String = "",
        category: String,
        bodyPart: String,
        defaultSets: Int = 3,
        defaultReps: Int = 10,
        defaultDurationSeconds: Int = 0,
        notes: String = "",
        isCustom: Bool = false
    ) {
        self.name = name
        self.exerciseDescription = description
        self.category = category
        self.bodyPart = bodyPart
        self.defaultSets = defaultSets
        self.defaultReps = defaultReps
        self.defaultDurationSeconds = defaultDurationSeconds
        self.notes = notes
        self.isCustom = isCustom
        self.createdAt = Date()
    }
}

extension Exercise {
    var isTimeBased: Bool { defaultDurationSeconds > 0 && defaultReps == 0 }

    var displayTarget: String {
        if isTimeBased {
            return "\(defaultSets) × \(defaultDurationSeconds)s"
        }
        return "\(defaultSets) × \(defaultReps) reps"
    }
}
