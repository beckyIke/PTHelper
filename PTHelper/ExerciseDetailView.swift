import SwiftUI
import SwiftData

struct ExerciseDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var exercise: Exercise

    @State private var showingAddToRoutine = false
    @State private var isEditing = false

    var recentLogs: [ExerciseLog] {
        exercise.logs.sorted { $0.completedAt > $1.completedAt }.prefix(5).map { $0 }
    }

    var body: some View {
        List {
            Section("Details") {
                LabeledContent("Category", value: exercise.category)
                LabeledContent("Body Part", value: exercise.bodyPart)
                LabeledContent("Default Sets", value: "\(exercise.defaultSets)")
                if exercise.isTimeBased {
                    LabeledContent("Duration", value: "\(exercise.defaultDurationSeconds)s per set")
                } else {
                    LabeledContent("Default Reps", value: "\(exercise.defaultReps)")
                }
            }

            if !exercise.exerciseDescription.isEmpty {
                Section("Instructions") {
                    Text(exercise.exerciseDescription)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }

            if !exercise.notes.isEmpty {
                Section("Notes") {
                    Text(exercise.notes)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }

            if !recentLogs.isEmpty {
                Section("Recent History") {
                    ForEach(recentLogs, id: \.persistentModelID) { log in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(log.completedAt, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                if log.painLevel > 0 {
                                    Label("\(log.painLevel)/10", systemImage: "waveform.path.ecg")
                                        .font(.caption)
                                        .foregroundColor(log.painLevel > 5 ? .red : .orange)
                                }
                            }
                            if log.durationSeconds > 0 && log.repsCompleted == 0 {
                                Text("\(log.setsCompleted) sets × \(log.durationSeconds)s")
                                    .font(.subheadline)
                            } else {
                                Text("\(log.setsCompleted) sets × \(log.repsCompleted) reps")
                                    .font(.subheadline)
                            }
                            if !log.notes.isEmpty {
                                Text(log.notes)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddToRoutine = true
                } label: {
                    Label("Add to Routine", systemImage: "plus.rectangle.on.rectangle")
                }
            }
        }
        .sheet(isPresented: $showingAddToRoutine) {
            AddToRoutineView(exercise: exercise)
        }
    }
}
