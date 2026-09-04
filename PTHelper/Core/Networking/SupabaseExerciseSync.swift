import Foundation
import SwiftData
import Supabase

// Codable mirror of the exercises table row
private struct RemoteExercise: Codable {
    let id: UUID
    let name: String
    let description: String
    let category: String
    let bodyPart: String
    let defaultSets: Int
    let defaultReps: Int
    let defaultDurationSeconds: Int
    let notes: String
    let isCustom: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, description, category, notes
        case bodyPart                = "body_part"
        case defaultSets             = "default_sets"
        case defaultReps             = "default_reps"
        case defaultDurationSeconds  = "default_duration_seconds"
        case isCustom                = "is_custom"
    }
}

struct SupabaseExerciseSync {
    // Fetches global exercises from Supabase and upserts them into the local
    // SwiftData store. Existing exercises matched by name are updated in place;
    // unknown exercises are inserted. Falls back to SeedData if the fetch fails.
    @MainActor
    static func sync(context: ModelContext) async {
        do {
            let remote: [RemoteExercise] = try await supabase
                .from("exercises")
                .select()
                .eq("is_custom", value: false)
                .execute()
                .value

            guard !remote.isEmpty else {
                SeedData.seedIfNeeded(context: context)
                return
            }

            let existing = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
            var byName = Dictionary(uniqueKeysWithValues: existing.map { ($0.name, $0) })

            for row in remote {
                if let local = byName[row.name] {
                    // Update fields that may have changed
                    local.exerciseDescription   = row.description
                    local.category              = row.category
                    local.bodyPart              = row.bodyPart
                    local.defaultSets           = row.defaultSets
                    local.defaultReps           = row.defaultReps
                    local.defaultDurationSeconds = row.defaultDurationSeconds
                    local.notes                 = row.notes
                } else {
                    let exercise = Exercise(
                        name:                   row.name,
                        description:            row.description,
                        category:               row.category,
                        bodyPart:               row.bodyPart,
                        defaultSets:            row.defaultSets,
                        defaultReps:            row.defaultReps,
                        defaultDurationSeconds: row.defaultDurationSeconds,
                        notes:                  row.notes,
                        isCustom:               false
                    )
                    context.insert(exercise)
                    byName[row.name] = exercise
                }
            }

            try? context.save()
        } catch {
            // Network unavailable or not signed in — seed locally so the app
            // still works offline on first launch.
            SeedData.seedIfNeeded(context: context)
        }
    }
}
