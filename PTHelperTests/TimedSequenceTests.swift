import Testing
@testable import PTHelper

@MainActor
struct TimedSequenceTests {
    private func run(_ sequence: inout TimedSequence, seconds: Int, breakSeconds: Int = 5) -> [TimedSequence.Event] {
        (0..<seconds).compactMap { _ in sequence.tick(breakSeconds: breakSeconds) }
    }

    @Test func buildsOneStepPerSetAndSide() {
        let sequence = TimedSequence(sets: 2, perSide: true, holdSeconds: 30)
        #expect(sequence.steps.map(\.title) == [
            "Set 1 of 2 · Left side", "Set 1 of 2 · Right side",
            "Set 2 of 2 · Left side", "Set 2 of 2 · Right side",
        ])
        #expect(TimedSequence(sets: 3, perSide: false, holdSeconds: 30).steps.map(\.title)
                == ["Set 1 of 3", "Set 2 of 3", "Set 3 of 3"])
    }

    @Test func breakStartsAfterHoldAndNextHoldStartsAfterBreak() {
        var sequence = TimedSequence(sets: 2, perSide: false, holdSeconds: 10)

        #expect(run(&sequence, seconds: 10) == [.holdFinished])
        #expect(sequence.phase == .rest)
        #expect(sequence.remaining == 5)
        #expect(sequence.completedSets == 1)

        #expect(run(&sequence, seconds: 5) == [.breakFinished])
        #expect(sequence.phase == .hold)
        #expect(sequence.remaining == 10)
        #expect(sequence.currentStep.set == 2)

        #expect(run(&sequence, seconds: 10) == [.allFinished])
        #expect(sequence.phase == .finished)
        #expect(sequence.completedSets == 2)
        #expect(sequence.tick(breakSeconds: 5) == nil)
    }

    @Test func breaksBetweenSidesCountFullSetsOnly() {
        var sequence = TimedSequence(sets: 2, perSide: true, holdSeconds: 3)
        _ = run(&sequence, seconds: 3, breakSeconds: 2) // left side done
        #expect(sequence.phase == .rest)
        #expect(sequence.nextStep?.side == .right)
        #expect(sequence.completedSets == 0)

        _ = run(&sequence, seconds: 2 + 3, breakSeconds: 2) // break, then right side
        #expect(sequence.completedSets == 1)
        #expect(sequence.nextStep?.title == "Set 2 of 2 · Left side")
    }

    @Test func zeroBreakGoesStraightToNextHold() {
        var sequence = TimedSequence(sets: 2, perSide: false, holdSeconds: 4)
        #expect(run(&sequence, seconds: 4, breakSeconds: 0) == [.holdFinished])
        #expect(sequence.phase == .hold)
        #expect(sequence.currentStep.set == 2)
    }

    @Test func skippingABreakStartsTheNextHold() {
        var sequence = TimedSequence(sets: 2, perSide: false, holdSeconds: 4)
        _ = run(&sequence, seconds: 4)
        #expect(sequence.endPhase(breakSeconds: 5) == .breakFinished)
        #expect(sequence.phase == .hold)
        #expect(sequence.remaining == 4)
    }

    @Test func restartAndReset() {
        var sequence = TimedSequence(sets: 1, perSide: false, holdSeconds: 10)
        _ = run(&sequence, seconds: 6)
        sequence.restartPhase()
        #expect(sequence.remaining == 10)

        _ = run(&sequence, seconds: 10)
        #expect(sequence.phase == .finished)
        sequence.reset()
        #expect(sequence.phase == .hold)
        #expect(sequence.completedSets == 0)
        #expect(sequence.remaining == 10)
    }
}
