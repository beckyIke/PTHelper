import SwiftUI
import SwiftData

struct RoutineDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var routine: Routine

    @State private var showingExercisePicker = false
    @State private var showingScheduler = false
    @State private var showingRename = false
    @State private var pendingName = ""
    @State private var showingClearRecurrenceAlert = false

    var sortedExercises: [RoutineExercise] {
        routine.exercises.sorted { $0.order < $1.order }
    }

    var body: some View {
        List {
            if routine.exercises.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No Exercises",
                        systemImage: "dumbbell",
                        description: Text("Tap 'Add Exercise' to build your routine.")
                    )
                    .listRowBackground(Color.clear)
                }
            } else {
                Section("Exercises") {
                    ForEach(sortedExercises) { re in
                        if let exercise = re.exercise {
                            RoutineExerciseRow(routineExercise: re, exercise: exercise)
                        }
                    }
                    .onDelete(perform: removeExercises)
                }
            }

            Section {
                Picker("Repeat", selection: Binding(
                    get: { routine.recurrence },
                    set: { newValue in
                        let turningOff = newValue == .none
                        routine.recurrence = newValue
                        if turningOff {
                            showingClearRecurrenceAlert = true
                        } else {
                            RecurrenceManager.regenerate(for: routine, context: modelContext)
                        }
                    }
                )) {
                    ForEach(RecurrenceType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }

                if routine.recurrence == .weekly {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Repeat on")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        WeekdayPicker(selectedDays: Binding(
                            get: { Set(routine.weekdayInts) },
                            set: { newDays in
                                routine.weekdayInts = Array(newDays)
                                RecurrenceManager.regenerate(for: routine, context: modelContext)
                            }
                        ))
                    }
                    .padding(.vertical, 4)
                }

                if routine.recurrence != .none {
                    DatePicker(
                        "Session time",
                        selection: Binding(
                            get: { routine.recurrenceTime },
                            set: { routine.recurrenceTime = $0 }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                }
            } header: {
                Text("Recurrence")
            } footer: {
                if routine.recurrence != .none {
                    Text(routine.recurrenceSummary)
                }
            }

            Section {
                Button {
                    showingExercisePicker = true
                } label: {
                    Label("Add Exercise", systemImage: "plus.circle")
                }

                Button {
                    showingScheduler = true
                } label: {
                    Label("Schedule Session", systemImage: "calendar.badge.plus")
                }
            }
        }
        .ptBackground()
        .navigationTitle(routine.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        pendingName = routine.name
                        showingRename = true
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        // deletion is handled from RoutinesView
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                EditButton()
            }
        }
        .alert("Rename Routine", isPresented: $showingRename) {
            TextField("Name", text: $pendingName)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                let trimmed = pendingName.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { routine.name = trimmed }
            }
        }
        .alert("Remove Upcoming Sessions?", isPresented: $showingClearRecurrenceAlert) {
            Button("Keep Sessions", role: .cancel) {}
            Button("Remove Pending", role: .destructive) {
                removePendingRecurringSessions()
            }
        } message: {
            Text("Do you want to remove the unfinished sessions that were auto-scheduled for this routine?")
        }
        .sheet(isPresented: $showingExercisePicker) {
            ExercisePickerView(routine: routine)
        }
        .sheet(isPresented: $showingScheduler) {
            AddSessionView(preselectedRoutine: routine)
        }
    }

    private func removeExercises(offsets: IndexSet) {
        let sorted = sortedExercises
        for index in offsets {
            modelContext.delete(sorted[index])
        }
    }

    private func removePendingRecurringSessions() {
        let pending = routine.sessions.filter { !$0.isCompleted }
        for session in pending {
            modelContext.delete(session)
        }
    }
}

struct RoutineExerciseRow: View {
    @Bindable var routineExercise: RoutineExercise
    let exercise: Exercise

    @State private var showingEditor = false

    var body: some View {
        Button { showingEditor = true } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .foregroundColor(.primary)
                    Text(routineExercise.displayTarget)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $showingEditor) {
            EditRoutineExerciseView(routineExercise: routineExercise, exercise: exercise)
        }
    }
}

struct EditRoutineExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var routineExercise: RoutineExercise
    let exercise: Exercise

    var body: some View {
        NavigationStack {
            Form {
                Section(exercise.name) {
                    Stepper("Sets: \(routineExercise.sets)", value: $routineExercise.sets, in: 1...20)
                    Toggle("Use Timer", isOn: timerMode)
                    if routineExercise.isTimeBased {
                        Stepper("Duration: \(routineExercise.durationSeconds)s",
                                value: $routineExercise.durationSeconds, in: 5...600, step: 5)
                        Toggle("Time Both Sides", isOn: $routineExercise.timesBothSides)
                        if routineExercise.timesBothSides {
                            Stepper("Rest Between Sides: \(routineExercise.restSeconds)s",
                                    value: $routineExercise.restSeconds, in: 5...120, step: 5)
                        }
                    } else {
                        Stepper("Reps: \(routineExercise.reps)", value: $routineExercise.reps, in: 1...100)
                    }
                }
                Section("Notes") {
                    TextField("Notes (optional)", text: $routineExercise.notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var timerMode: Binding<Bool> {
        Binding(
            get: { routineExercise.isTimeBased },
            set: { usesTimer in
                if usesTimer {
                    routineExercise.reps = 0
                    routineExercise.durationSeconds = max(routineExercise.durationSeconds, 30)
                } else {
                    routineExercise.reps = max(routineExercise.reps, 10)
                    routineExercise.durationSeconds = 0
                    routineExercise.timesBothSides = false
                }
            }
        )
    }
}
