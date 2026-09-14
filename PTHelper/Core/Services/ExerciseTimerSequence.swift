import Foundation

struct ExerciseTimerSequence {
    enum Phase: Equatable {
        case exercise
        case rightSide
        case rest
        case leftSide
        case complete
    }

    enum Event: Equatable {
        case none
        case phaseChanged
        case completed
    }

    let targetSeconds: Int
    let timesBothSides: Bool
    let restSeconds: Int

    private(set) var phase: Phase
    private(set) var phaseElapsed = 0

    init(targetSeconds: Int, timesBothSides: Bool, restSeconds: Int) {
        self.targetSeconds = targetSeconds
        self.timesBothSides = timesBothSides
        self.restSeconds = restSeconds
        phase = timesBothSides && targetSeconds > 0 ? .rightSide : .exercise
    }

    var isCountdown: Bool { targetSeconds > 0 }
    var isComplete: Bool { phase == .complete }
    var phaseDuration: Int { phase == .rest ? restSeconds : targetSeconds }
    var displaySeconds: Int {
        isCountdown ? max(0, phaseDuration - phaseElapsed) : phaseElapsed
    }

    @discardableResult
    mutating func tick() -> Event {
        guard !isComplete else { return .none }
        phaseElapsed += 1
        guard isCountdown, phaseElapsed >= phaseDuration else { return .none }
        return advance()
    }

    @discardableResult
    mutating func skipRest() -> Event {
        guard phase == .rest else { return .none }
        phase = .leftSide
        phaseElapsed = 0
        return .phaseChanged
    }

    mutating func adjustElapsed(by seconds: Int) {
        phaseElapsed = max(0, phaseElapsed + seconds)
    }

    mutating func reset() {
        phase = timesBothSides && isCountdown ? .rightSide : .exercise
        phaseElapsed = 0
    }

    private mutating func advance() -> Event {
        phaseElapsed = 0

        switch phase {
        case .rightSide:
            phase = restSeconds > 0 ? .rest : .leftSide
            return .phaseChanged
        case .rest:
            phase = .leftSide
            return .phaseChanged
        case .exercise, .leftSide:
            phase = .complete
            return .completed
        case .complete:
            return .none
        }
    }
}
