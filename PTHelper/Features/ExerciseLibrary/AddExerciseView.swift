import SwiftUI
import SwiftData

struct AddExerciseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var category = ExerciseCategory.strength
    @State private var bodyPart = BodyPart.fullBody
    @State private var sets = 3
    @State private var reps = 10
    @State private var isTimeBased = false
    @State private var durationSeconds = 30
    @State private var timesBothSides = false
    @State private var restSeconds = 15
    @State private var notes = ""

    var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise Info") {
                    TextField("Name", text: $name)
                    Picker("Category", selection: $category) {
                        ForEach(ExerciseCategory.allCases) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                    Picker("Body Part", selection: $bodyPart) {
                        ForEach(BodyPart.allCases) { part in
                            Text(part.rawValue).tag(part)
                        }
                    }
                }

                Section("Targets") {
                    Stepper("Sets: \(sets)", value: $sets, in: 1...10)
                    Toggle("Time-Based Exercise", isOn: $isTimeBased)
                    if isTimeBased {
                        Stepper("Duration: \(durationSeconds)s", value: $durationSeconds, in: 5...300, step: 5)
                        Toggle("Time Both Sides", isOn: $timesBothSides)
                        if timesBothSides {
                            Stepper("Rest Between Sides: \(restSeconds)s", value: $restSeconds, in: 5...120, step: 5)
                        }
                    } else {
                        Stepper("Reps: \(reps)", value: $reps, in: 1...100)
                    }
                }

                Section("Instructions") {
                    TextField("Describe how to perform this exercise", text: $description, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section("Notes") {
                    TextField("Any additional notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("New Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
            }
        }
    }

    private func save() {
        let exercise = Exercise(
            name: name.trimmingCharacters(in: .whitespaces),
            description: description,
            category: category.rawValue,
            bodyPart: bodyPart.rawValue,
            defaultSets: sets,
            defaultReps: isTimeBased ? 0 : reps,
            defaultDurationSeconds: isTimeBased ? durationSeconds : 0,
            defaultTimesBothSides: isTimeBased && timesBothSides,
            defaultRestSeconds: restSeconds,
            notes: notes,
            isCustom: true
        )
        modelContext.insert(exercise)
        dismiss()
    }
}
