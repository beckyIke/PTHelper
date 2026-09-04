import Foundation
import SwiftData

enum ModelContainerFactory {
    static func make() -> ModelContainer {
        let schema = Schema([
            Exercise.self,
            Routine.self,
            RoutineExercise.self,
            ScheduledSession.self,
            ExerciseLog.self,
        ])

        do {
            return try ModelContainer(for: schema)
        } catch {
            // Schema changed — delete the old store and start fresh.
            let appSupport = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first!
            if let files = try? FileManager.default.contentsOfDirectory(
                at: appSupport,
                includingPropertiesForKeys: nil
            ) {
                for file in files where file.lastPathComponent.contains(".store") {
                    try? FileManager.default.removeItem(at: file)
                }
            }

            do {
                return try ModelContainer(for: schema)
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }
}
