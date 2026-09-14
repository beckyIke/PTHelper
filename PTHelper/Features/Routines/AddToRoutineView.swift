import SwiftUI
import SwiftData

struct AddToRoutineView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Routine.name) private var routines: [Routine]

    let exercise: Exercise
    @State private var addedTo: Set<PersistentIdentifier> = []

    var body: some View {
        NavigationStack {
            Group {
                if routines.isEmpty {
                    ContentUnavailableView(
                        "No Routines",
                        systemImage: "list.bullet.clipboard",
                        description: Text("Create a routine in the Routines tab first.")
                    )
                } else {
                    List(routines) { routine in
                        let alreadyInRoutine = routine.exercises.contains { $0.exercise?.persistentModelID == exercise.persistentModelID }
                        let justAdded = addedTo.contains(routine.persistentModelID)

                        Button {
                            guard !alreadyInRoutine && !justAdded else { return }
                            addExercise(to: routine)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(routine.name)
                                        .foregroundColor(.primary)
                                    Text("\(routine.exercises.count) exercise\(routine.exercises.count == 1 ? "" : "s")")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if alreadyInRoutine {
                                    Text("Already added")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else if justAdded {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                } else {
                                    Image(systemName: "plus.circle")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add to Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func addExercise(to routine: Routine) {
        let order = routine.exercises.count
        let re = RoutineExercise(
            exercise: exercise,
            sets: exercise.defaultSets,
            reps: exercise.defaultReps,
            durationSeconds: exercise.defaultDurationSeconds,
            timesBothSides: exercise.defaultTimesBothSides,
            restSeconds: exercise.defaultRestSeconds,
            order: order
        )
        re.routine = routine
        modelContext.insert(re)
        addedTo.insert(routine.persistentModelID)
    }
}
