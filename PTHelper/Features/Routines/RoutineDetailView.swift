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
    @State private var activeWorkoutSession: ScheduledSession?
    @State private var activeLaunch: WorkoutLauncher.Launch?

    var sortedExercises: [RoutineExercise] {
        routine.exercises.sorted { $0.order < $1.order }
    }

    var body: some View {
        List {
            if !routine.exercises.isEmpty {
                Section {
                    Button {
                        startWorkout()
                    } label: {
                        Label("Start Workout", systemImage: "play.fill")
                            .labelStyle(.titleAndIcon)
                            .font(.ptSerif(.body, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .ptPrimaryButton()
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .ptEntrance()
                }
            }

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
                Section {
                    ForEach(Array(sortedExercises.enumerated()), id: \.element.id) { index, re in
                        if let exercise = re.exercise {
                            RoutineExerciseRow(routineExercise: re, exercise: exercise)
                                .ptGlassRow()
                                .ptEntrance(index: index + 1)
                        }
                    }
                    .onDelete(perform: removeExercises)
                } header: {
                    PTSectionHeader("Exercises")
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
                PTSectionHeader("Recurrence")
            } footer: {
                if routine.recurrence != .none {
                    Text(routine.recurrenceSummary)
                }
            }
            .ptGlassRow()

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
            .ptGlassRow()
        }
        .listRowSpacing(8)
        .animation(PTMotion.snappy, value: routine.recurrence)
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
        .sheet(item: $activeWorkoutSession, onDismiss: {
            if let activeLaunch { WorkoutLauncher.finish(activeLaunch, context: modelContext) }
            activeLaunch = nil
        }) { session in
            SessionWorkoutView(session: session)
        }
    }

    private func startWorkout() {
        let launch = WorkoutLauncher.start(routine, context: modelContext)
        activeLaunch = launch
        activeWorkoutSession = launch.session
    }

    private func removeExercises(offsets: IndexSet) {
        let sorted = sortedExercises
        for index in offsets {
            modelContext.delete(sorted[index])
        }
    }

    private func removePendingRecurringSessions() {
        // Only remove today's and future sessions — past missed sessions stay as history for streaks.
        let today = Calendar.current.startOfDay(for: Date())
        let pending = routine.sessions.filter { !$0.isCompleted && $0.scheduledDate >= today }
        for session in pending {
            modelContext.delete(session)
        }
    }
}

// MARK: - Weekday Picker

struct WeekdayPicker: View {
    @Binding var selectedDays: Set<Int>

    // Calendar.weekday: 1=Sun, 2=Mon … 7=Sat
    private let days: [(Int, String)] = [
        (1, "S"), (2, "M"), (3, "T"), (4, "W"), (5, "T"), (6, "F"), (7, "S")
    ]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(days, id: \.0) { number, label in
                let isOn = selectedDays.contains(number)
                Button {
                    if isOn { selectedDays.remove(number) } else { selectedDays.insert(number) }
                } label: {
                    Text(label)
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .foregroundStyle(isOn ? .white : .primary)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.tint(isOn ? .ptAccent : nil).interactive(), in: .circle)
                .scaleEffect(isOn ? 1.08 : 1)
                .animation(PTMotion.bouncy, value: isOn)
                .sensoryFeedback(.selection, trigger: isOn)
                .accessibilityLabel(Calendar.current.weekdaySymbols[number - 1])
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                    if routineExercise.isTimeBased {
                        Stepper("Duration: \(routineExercise.durationSeconds)s",
                                value: $routineExercise.durationSeconds, in: 5...600, step: 5)
                        Toggle("Each Side", isOn: $routineExercise.perSide)
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
}
