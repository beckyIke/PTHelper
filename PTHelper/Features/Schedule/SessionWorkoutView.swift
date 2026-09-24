import SwiftUI
import SwiftData
internal import Combine

struct SessionWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let session: ScheduledSession

    @State private var currentIndex = 0
    @State private var logEntries: [LogEntry] = []
    @State private var confettiTrigger = 0

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
                VStack(spacing: 6) {
                    PTProgressBar(value: progress)
                        .padding(.horizontal)
                    Text(allDone ? "All done!" : "Exercise \(currentIndex + 1) of \(exercises.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .contentTransition(.numericText())
                }
                .padding(.top, 8)
                .padding(.bottom, 12)

                if allDone {
                    finishedView
                } else if currentIndex < exercises.count && currentIndex < logEntries.count {
                    ExerciseInputView(
                        routineExercise: exercises[currentIndex],
                        entry: $logEntries[currentIndex],
                        onSkip: nextExercise,
                        onNext: nextExercise,
                        isLast: currentIndex == exercises.count - 1
                    )
                    .id(currentIndex)
                    // Each exercise slides in from the right as the previous one leaves.
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .background { PTAmbientBackground().ignoresSafeArea() }
            .overlay { PTConfetti(trigger: confettiTrigger).ignoresSafeArea() }
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
            Image(systemName: "checkmark")
                .font(.system(size: 52, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 120, height: 120)
                .glassEffect(.regular.tint(.ptSecondary), in: .circle)
                .symbolEffect(.bounce, value: confettiTrigger)
                .ptEntrance()
            Text("Workout Complete!")
                .font(.ptSerif(.title, weight: .bold))
                .ptEntrance(index: 2)
            Text("Tap Finish to save your results.")
                .foregroundColor(.secondary)
                .ptEntrance(index: 3)
            Spacer()
            Button {
                finishWorkout()
            } label: {
                Text("Save & Finish")
                    .font(.ptSerif(.body, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .ptPrimaryButton()
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            .ptEntrance(index: 4)
        }
        .onAppear { confettiTrigger += 1 }
        .sensoryFeedback(.success, trigger: confettiTrigger)
        .transition(.scale(scale: 0.9).combined(with: .opacity))
    }

    private func setupEntries() {
        logEntries = exercises.map { re in
            LogEntry(sets: re.sets, reps: re.reps, durationSeconds: re.durationSeconds,
                     painLevel: 0, notes: "")
        }
    }

    private func nextExercise() {
        withAnimation(PTMotion.bouncy) { currentIndex += 1 }
    }

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
                            .foregroundColor(.ptAccent)
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
                    .ptEntrance()
                }

                // Timer (timed exercises only) — runs every set/side with a break in between
                if routineExercise.isTimeBased {
                    PTGlassSection(title: "Timer", systemImage: "timer") {
                        TimedExerciseRunner(routineExercise: routineExercise) { completedSets in
                            entry.sets = completedSets
                            entry.durationSeconds = routineExercise.durationSeconds
                        }
                    }
                    .padding(.horizontal)
                    .ptEntrance(index: 1)
                }

                // Log inputs
                PTGlassSection(title: "Log Your Performance", systemImage: "pencil") {
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
                            .font(.callout)
                            .padding(12)
                            .glassEffect(.regular, in: .rect(cornerRadius: PTRadius.sm))
                    }
                }
                .padding(.horizontal)
                .ptEntrance(index: 2)

                // Actions
                VStack(spacing: 12) {
                    Button(action: onNext) {
                        Label(isLast ? "Complete Workout" : "Next Exercise",
                              systemImage: isLast ? "flag.checkered" : "arrow.right")
                            .font(.ptSerif(.body, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .ptPrimaryButton()
                    Button("Skip", action: onSkip)
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .ptEntrance(index: 3)
            }
        }
        .scrollDismissesKeyboard(.interactively)
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
                    .stroke(Color.primary.opacity(0.08), lineWidth: 8)
                    .frame(width: 140, height: 140)

                // Progress ring (countdown only)
                if isCountdown {
                    Circle()
                        .trim(from: 0, to: ringProgress)
                        .stroke(
                            isComplete ? Color.ptSecondary : Color.ptAccent,
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
                        .foregroundColor(isComplete ? .ptSecondary : .primary)
                        .contentTransition(.numericText(countsDown: isCountdown))
                        .animation(.default, value: displaySeconds)
                    Text(isComplete ? "Done!" : isCountdown ? "remaining" : "elapsed")
                        .font(.caption)
                        .foregroundColor(isComplete ? .ptSecondary : .secondary)
                }
            }

            // Controls
            GlassEffectContainer(spacing: 24) {
                HStack(spacing: 24) {
                    PTGlassIconButton(systemImage: "arrow.counterclockwise", accessibilityLabel: "Reset") {
                        elapsed = 0
                        isRunning = false
                        isComplete = false
                    }

                    PTGlassIconButton(
                        systemImage: isRunning ? "pause.fill" : "play.fill",
                        size: 64,
                        prominent: true,
                        tint: isComplete ? .ptSecondary : .ptAccent,
                        accessibilityLabel: isRunning ? "Pause" : "Start"
                    ) {
                        guard !isComplete else { return }
                        isRunning.toggle()
                    }
                    .disabled(isComplete)

                    // ±30 s nudge (useful for time-based rest periods)
                    PTGlassIconButton(
                        systemImage: isCountdown ? "minus" : "plus",
                        accessibilityLabel: isCountdown ? "Subtract 30 seconds" : "Add 30 seconds"
                    ) {
                        if isCountdown {
                            elapsed = max(0, elapsed - 30)
                        } else {
                            elapsed += 30
                        }
                    }
                    .disabled(isComplete)
                }
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
