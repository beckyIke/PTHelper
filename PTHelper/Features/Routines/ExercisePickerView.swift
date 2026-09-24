import SwiftUI
import SwiftData

struct ExercisePickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    let routine: Routine

    @State private var searchText = ""
    @State private var selectedCategory: ExerciseCategory?
    @State private var recentlyAdded: Set<PersistentIdentifier> = []

    var alreadyInRoutine: Set<PersistentIdentifier> {
        Set(routine.exercises.compactMap { $0.exercise?.persistentModelID })
    }

    var filtered: [Exercise] {
        exercises.filter { ex in
            let matchesSearch = searchText.isEmpty || ex.name.localizedCaseInsensitiveContains(searchText)
            let matchesCategory = selectedCategory == nil || ex.category == selectedCategory?.rawValue
            return matchesSearch && matchesCategory
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(title: "All", isSelected: selectedCategory == nil) {
                            selectedCategory = nil
                        }
                        ForEach(ExerciseCategory.allCases) { cat in
                            FilterChip(title: cat.rawValue, isSelected: selectedCategory == cat) {
                                selectedCategory = selectedCategory == cat ? nil : cat
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .padding(.vertical, 4)

                ForEach(filtered) { exercise in
                    let inRoutine = alreadyInRoutine.contains(exercise.persistentModelID)
                    let justAdded = recentlyAdded.contains(exercise.persistentModelID)

                    Button {
                        guard !inRoutine && !justAdded else { return }
                        addExercise(exercise)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(exercise.name)
                                    .foregroundColor(inRoutine ? .secondary : .primary)
                                Text(exercise.bodyPart)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if inRoutine {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.secondary)
                            } else if justAdded {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else {
                                Image(systemName: "plus.circle")
                                    .foregroundColor(.ptAccent)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func addExercise(_ exercise: Exercise) {
        let re = RoutineExercise(
            exercise: exercise,
            sets: exercise.defaultSets,
            reps: exercise.defaultReps,
            durationSeconds: exercise.defaultDurationSeconds,
            order: routine.exercises.count
        )
        re.routine = routine
        modelContext.insert(re)
        recentlyAdded.insert(exercise.persistentModelID)
    }
}
