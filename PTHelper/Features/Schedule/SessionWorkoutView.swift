import SwiftUI
import SwiftData
internal import Combine

struct SessionWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let session: ScheduledSession

    @State private var currentIndex = 0
    @State private var logEntries: [LogEntry] = []

    struct LogEntry {
        var sets: Int
        var reps: Int
        var durationSeconds: Int
        var painLevel: Int
        var notes: String
    }

    var exercises: [RoutineExercise] {
        (session.routine?.exercises ?? []).sorted { $0.order < $1.order }
    }

    var allDone: Bool { currentIndex >= exercises.count }

    var progress: Double {
        exercises.isEmpty ? 0 : Double(currentIndex) / Double(exercises.count)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 4) {
                    SwiftUI.ProgressView(value: progress)
                        .tint(.ptTerracotta)
                        .padding(.horizontal)
                    Text(allDone ? "All done!" : "Exercise \(currentIndex + 1) of \(exercises.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
                .padding(.bottom, 12)

                if allDone {
                    finishedView
                } else if currentIndex < exercises.count && currentIndex < logEntries.count {
                    ExerciseInputView(
                        routineExercise: exercises[currentIndex],
                        entry: $logEntries[currentIndex],
                        onSkip: { currentIndex += 1 },
                        onNext: nextExercise,
                        isLast: currentIndex == exercises.count - 1
                    )
                    .id(currentIndex)
                }
            }
            .background(Color.ptBackground.ignoresSafeArea())
            .navigationTitle(session.routine?.name ?? "Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Exit") { dismiss() }
                        .foregroundColor(.red)
                }
                if allDone {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Finish") { finishWorkout() }
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .onAppear { setupEntries() }
        .interactiveDismissDisabled()
    }

    private var finishedView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundColor(.green)
            Text("Workout Complete!")
                .font(.title)
                .fontWeight(.bold)
            Text("Tap Finish to save your results.")
                .foregroundColor(.secondary)
            Spacer()
            Button {
                finishWorkout()
            } label: {
                Text("Save & Finish")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.ptTerracotta)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    private func setupEntries() {
        logEntries = exercises.map { re in
            LogEntry(sets: re.sets, reps: re.reps, durationSeconds: re.durationSeconds,
                     painLevel: 0, notes: "")
        }
    }

    private func nextExercise() { currentIndex += 1 }

    private func finishWorkout() {
        for (index, re) in exercises.enumerated() {
            guard index < logEntries.count, let exercise = re.exercise else { continue }
            let entry = logEntries[index]
            modelContext.insert(ExerciseLog(
                exercise: exercise,
                session: session,
                setsCompleted: entry.sets,
                repsCompleted: entry.reps,
                durationSeconds: entry.durationSeconds,
                notes: entry.notes,
                painLevel: entry.painLevel
            ))
        }
        session.isCompleted = true
        session.completedAt = Date()
        dismiss()
    }
}

// MARK: - Exercise Input

struct ExerciseInputView: View {
    let routineExercise: RoutineExercise
    @Binding var entry: SessionWorkoutView.LogEntry
    let onSkip: () -> Void
    let onNext: () -> Void
    let isLast: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // Header
                if let exercise = routineExercise.exercise {
                    VStack(spacing: 6) {
                        Text(exercise.name)
                            .font(.ptSerif(.title2, weight: .bold))
                            .multilineTextAlignment(.center)
                        Text(exercise.bodyPart)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Target: \(routineExercise.displayTarget)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.ptTerracotta)
                        if !exercise.exerciseDescription.isEmpty {
                            Text(exercise.exerciseDescription)
                                .font(.callout)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .padding(.top, 2)
                        }
                    }
                    .padding(.top, 8)
                }

                // Timer (timed exercises only) — runs every set/side with a break in between
                if routineExercise.isTimeBased {
                    GroupBox {
                        TimedExerciseRunner(routineExercise: routineExercise) { completedSets in
                            entry.sets = completedSets
                            entry.durationSeconds = routineExercise.durationSeconds
                        }
                    } label: {
                        Label("Timer", systemImage: "timer")
                            .font(.subheadline)
                    }
                    .padding(.horizontal)
                }

                // Log inputs
                GroupBox {
                    VStack(spacing: 16) {
                        Stepper("Sets completed: \(entry.sets)", value: $entry.sets, in: 0...20)

                        if routineExercise.isTimeBased {
                            Stepper("Duration: \(entry.durationSeconds)s",
                                    value: $entry.durationSeconds, in: 0...600, step: 5)
                        } else {
                            Stepper("Reps completed: \(entry.reps)", value: $entry.reps, in: 0...200)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Pain level: \(entry.painLevel)/10")
                                    .font(.subheadline)
                                Spacer()
                                Text(painLabel(for: entry.painLevel))
                                    .font(.caption)
                                    .foregroundColor(painColor(for: entry.painLevel))
                            }
                            Slider(
                                value: Binding(
                                    get: { Double(entry.painLevel) },
                                    set: { entry.painLevel = Int($0) }
                                ),
                                in: 0...10, step: 1
                            )
                            .tint(painColor(for: entry.painLevel))
                        }

                        TextField("Notes (optional)", text: $entry.notes, axis: .vertical)
                            .lineLimit(2...4)
                            .textFieldStyle(.roundedBorder)
                            .font(.callout)
                    }
                    .padding(4)
                } label: {
                    Label("Log Your Performance", systemImage: "pencil")
                        .font(.subheadline)
                }
                .padding(.horizontal)

                // Actions
                VStack(spacing: 12) {
                    Button(action: onNext) {
                        Text(isLast ? "Complete Workout" : "Next Exercise")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.ptTerracotta)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                            .fontWeight(.semibold)
                    }
                    Button("Skip", action: onSkip)
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }

    private func painLabel(for level: Int) -> String {
        switch level {
        case 0: return "None"
        case 1...3: return "Mild"
        case 4...6: return "Moderate"
        case 7...9: return "Severe"
        default: return "Worst"
        }
    }

    private func painColor(for level: Int) -> Color {
        switch level {
        case 0: return .green
        case 1...3: return .yellow
        case 4...6: return .orange
        default: return .red
        }
    }
}

// MARK: - Timer

struct ExerciseTimerView: View {
    /// Pass > 0 for countdown mode; 0 for stopwatch (count-up) mode.
    let targetSeconds: Int
    /// Called with the actual elapsed seconds when a countdown finishes.
    var onComplete: ((Int) -> Void)? = nil

    @State private var elapsed: Int = 0
    @State private var isRunning = false
    @State private var isComplete = false
    @State private var completionTrigger = false

    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var isCountdown: Bool { targetSeconds > 0 }
    private var displaySeconds: Int {
        isCountdown ? max(0, targetSeconds - elapsed) : elapsed
    }
    private var ringProgress: CGFloat {
        guard isCountdown, targetSeconds > 0 else { return 1 }
        return CGFloat(max(0, targetSeconds - elapsed)) / CGFloat(targetSeconds)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Dial
            ZStack {
                // Track ring
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 8)
                    .frame(width: 140, height: 140)

                // Progress ring (countdown only)
                if isCountdown {
                    Circle()
                        .trim(from: 0, to: ringProgress)
                        .stroke(
                            isComplete ? Color.ptSage : Color.ptTerracotta,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 140, height: 140)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: elapsed)
                }

                // Time label
                VStack(spacing: 2) {
                    Text(timeString(displaySeconds))
                        .font(.system(size: 34, weight: .bold, design: .monospaced))
                        .foregroundColor(isComplete ? .green : .primary)
                        .contentTransition(.numericText())
                    Text(isComplete ? "Done!" : isCountdown ? "remaining" : "elapsed")
                        .font(.caption)
                        .foregroundColor(isComplete ? .green : .secondary)
                }
            }

            // Controls
            HStack(spacing: 24) {
                // Reset
                Button {
                    elapsed = 0
                    isRunning = false
                    isComplete = false
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 48, height: 48)
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .clipShape(Circle())
                }

                // Play / Pause
                Button {
                    guard !isComplete else { return }
                    isRunning.toggle()
                } label: {
                    Image(systemName: isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .frame(width: 60, height: 60)
                        .background(isComplete ? Color.ptSage : Color.ptTerracotta)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
                .disabled(isComplete)

                // +30 s nudge (useful for time-based rest periods)
                Button {
                    if isCountdown {
                        elapsed = max(0, elapsed - 30)
                    } else {
                        elapsed += 30
                    }
                } label: {
                    Image(systemName: isCountdown ? "minus.circle" : "plus.circle")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 48, height: 48)
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .clipShape(Circle())
                }
                .disabled(isComplete)
            }

            if isCountdown {
                Text(isComplete ? "Timer complete — adjust the duration above if needed."
                               : "Timer will auto-fill duration when it reaches zero.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .onReceive(clock) { _ in
            guard isRunning else { return }
            elapsed += 1
            if isCountdown && elapsed >= targetSeconds {
                isRunning = false
                isComplete = true
                completionTrigger.toggle()
                onComplete?(elapsed)
            }
        }
        .sensoryFeedback(.success, trigger: completionTrigger)
    }

    private func timeString(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
