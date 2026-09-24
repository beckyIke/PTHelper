import SwiftUI

// MARK: - Sequence

/// One hold of a timed exercise — a single set, on one side when the exercise is done per side.
struct TimedStep: Equatable {
    enum Side: String { case left = "Left", right = "Right" }

    let set: Int
    let totalSets: Int
    let side: Side?

    var title: String {
        let setText = "Set \(set) of \(totalSets)"
        guard let side else { return setText }
        return "\(setText) · \(side.rawValue) side"
    }
}

/// Steps through every hold of a timed exercise with a break between each one.
/// Breaks start automatically when a hold ends, and the next hold starts automatically when a break ends.
struct TimedSequence {
    enum Phase: Equatable { case hold, rest, finished }

    enum Event: Equatable {
        case holdFinished   // a hold ended and a break (or the next hold) began
        case breakFinished  // a break ended and the next hold began
        case allFinished
    }

    let steps: [TimedStep]
    let holdSeconds: Int
    private(set) var stepIndex = 0
    private(set) var phase: Phase = .hold
    private(set) var remaining: Int
    private(set) var completedSteps = 0
    private(set) var phaseLength: Int

    init(sets: Int, perSide: Bool, holdSeconds: Int) {
        let totalSets = max(sets, 1)
        let sides: [TimedStep.Side?] = perSide ? [.left, .right] : [nil]
        steps = (1...totalSets).flatMap { set in
            sides.map { TimedStep(set: set, totalSets: totalSets, side: $0) }
        }
        self.holdSeconds = max(holdSeconds, 1)
        remaining = self.holdSeconds
        phaseLength = self.holdSeconds
    }

    var currentStep: TimedStep { steps[min(stepIndex, steps.count - 1)] }
    var nextStep: TimedStep? { stepIndex + 1 < steps.count ? steps[stepIndex + 1] : nil }

    private var stepsPerSet: Int { steps.count / max(currentStep.totalSets, 1) }
    /// Sets where every side has been held.
    var completedSets: Int { completedSteps / stepsPerSet }

    /// Advance one second. Returns an event when the current phase ends.
    mutating func tick(breakSeconds: Int) -> Event? {
        guard phase != .finished else { return nil }
        remaining -= 1
        return remaining > 0 ? nil : endPhase(breakSeconds: breakSeconds)
    }

    /// End the current hold or break now, as if its timer ran out.
    @discardableResult
    mutating func endPhase(breakSeconds: Int) -> Event? {
        switch phase {
        case .hold:
            completedSteps = stepIndex + 1
            if nextStep == nil {
                phase = .finished
                remaining = 0
                return .allFinished
            }
            if breakSeconds > 0 {
                start(.rest, seconds: breakSeconds)
            } else {
                stepIndex += 1
                start(.hold, seconds: holdSeconds)
            }
            return .holdFinished
        case .rest:
            stepIndex += 1
            start(.hold, seconds: holdSeconds)
            return .breakFinished
        case .finished:
            return nil
        }
    }

    /// Restart the countdown for the current hold or break.
    mutating func restartPhase() {
        remaining = phaseLength
    }

    /// Go back to the first hold.
    mutating func reset() {
        stepIndex = 0
        completedSteps = 0
        start(.hold, seconds: holdSeconds)
    }

    private mutating func start(_ phase: Phase, seconds: Int) {
        self.phase = phase
        remaining = seconds
        phaseLength = seconds
    }
}

// MARK: - View

/// Countdown for timed exercises that runs every set (and side) with an adjustable break between holds.
struct TimedExerciseRunner: View {
    let routineExercise: RoutineExercise
    /// Called when a set is completed, with the number of sets completed so far.
    var onSetsCompleted: (Int) -> Void

    @AppStorage("timedBreakSeconds") private var breakSeconds = 5
    @State private var sequence: TimedSequence
    @State private var isRunning = false
    @State private var hasStarted = false
    @State private var phaseChangeTrigger = 0
    @State private var finishTrigger = 0

    init(routineExercise: RoutineExercise, onSetsCompleted: @escaping (Int) -> Void) {
        self.routineExercise = routineExercise
        self.onSetsCompleted = onSetsCompleted
        _sequence = State(initialValue: TimedSequence(
            sets: routineExercise.sets,
            perSide: routineExercise.perSide,
            holdSeconds: routineExercise.durationSeconds
        ))
    }

    private var isResting: Bool { sequence.phase == .rest }
    private var isFinished: Bool { sequence.phase == .finished }
    private var ringColor: Color { isResting || isFinished ? .ptSage : .ptTerracotta }

    private var ringProgress: CGFloat {
        guard sequence.phaseLength > 0 else { return 0 }
        return CGFloat(sequence.remaining) / CGFloat(sequence.phaseLength)
    }

    var body: some View {
        VStack(spacing: 16) {
            header
            dial
            stepProgress
            controls
            Divider()
            Stepper(value: $breakSeconds, in: 0...120) {
                Label("Break between holds: \(breakSeconds)s", systemImage: "pause.circle")
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 8)
        .task(id: isRunning) {
            guard isRunning else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                handle(sequence.tick(breakSeconds: breakSeconds))
            }
        }
        .onChange(of: isRunning) { _, running in
            // Keep the screen awake so the timer keeps running hands-free.
            UIApplication.shared.isIdleTimerDisabled = running
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .sensoryFeedback(.impact(weight: .heavy), trigger: phaseChangeTrigger)
        .sensoryFeedback(.success, trigger: finishTrigger)
    }

    // MARK: Subviews

    private var header: some View {
        VStack(spacing: 4) {
            Text(isFinished ? "All sets done!" : isResting ? "Break" : sequence.currentStep.title)
                .font(.headline)
                .foregroundColor(isResting || isFinished ? .ptSage : .primary)
                .contentTransition(.opacity)
            if isResting, let next = sequence.nextStep {
                Text("Up next: \(next.title)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else if !hasStarted {
                Text("Tap play to start. Each hold and break runs automatically.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: sequence.phase)
    }

    private var dial: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 8)
            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: sequence.remaining)
                // New ring per hold/break, so it snaps to full instead of sweeping back up.
                .id("\(sequence.stepIndex)-\(sequence.phase)")
            VStack(spacing: 2) {
                if isFinished {
                    Image(systemName: "checkmark")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.ptSage)
                } else {
                    Text(timeString(sequence.remaining))
                        .font(.system(size: 34, weight: .bold, design: .monospaced))
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.default, value: sequence.remaining)
                    Text(isResting ? "rest" : "hold")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(width: 140, height: 140)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isFinished ? "All sets done"
                            : "\(isResting ? "Break" : sequence.currentStep.title), \(sequence.remaining) seconds left")
    }

    /// One capsule per hold, filled once that hold is done.
    private var stepProgress: some View {
        HStack(spacing: 4) {
            ForEach(sequence.steps.indices, id: \.self) { index in
                Capsule()
                    .fill(index < sequence.completedSteps ? Color.ptSage
                          : index == sequence.stepIndex && !isResting ? Color.ptTerracotta
                          : Color(.systemGray5))
                    .frame(height: 6)
            }
        }
        .frame(maxWidth: 240)
        .animation(.easeInOut, value: sequence.completedSteps)
        .accessibilityHidden(true)
    }

    private var controls: some View {
        HStack(spacing: 24) {
            // Restart the current hold/break, or the whole exercise once finished
            controlButton(isFinished ? "arrow.counterclockwise.circle" : "arrow.counterclockwise",
                          label: isFinished ? "Start over" : "Restart timer") {
                if isFinished {
                    sequence.reset()
                    onSetsCompleted(0)
                } else {
                    sequence.restartPhase()
                }
            }

            Button {
                if !hasStarted {
                    // From now on, log the sets actually completed rather than the target.
                    hasStarted = true
                    onSetsCompleted(sequence.completedSets)
                }
                isRunning.toggle()
            } label: {
                Image(systemName: isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .frame(width: 60, height: 60)
                    .background(isFinished ? Color.ptSage : Color.ptTerracotta)
                    .foregroundColor(.white)
                    .clipShape(Circle())
            }
            .disabled(isFinished)
            .accessibilityLabel(isRunning ? "Pause" : "Start")

            // Skip the break, or end the hold early
            controlButton("forward.end.fill", label: isResting ? "Skip break" : "End hold") {
                handle(sequence.endPhase(breakSeconds: breakSeconds))
            }
            .disabled(isFinished)
        }
    }

    private func controlButton(_ systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 48, height: 48)
                .background(Color(.systemGray5))
                .foregroundColor(.primary)
                .clipShape(Circle())
        }
        .accessibilityLabel(label)
    }

    // MARK: Helpers

    private func handle(_ event: TimedSequence.Event?) {
        guard let event else { return }
        if event != .breakFinished { onSetsCompleted(sequence.completedSets) }
        if event == .allFinished {
            isRunning = false
            finishTrigger += 1
        } else {
            phaseChangeTrigger += 1
        }
    }

    private func timeString(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
