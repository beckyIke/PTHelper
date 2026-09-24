import CoreGraphics
import Foundation
import SwiftData
import Testing
@testable import PTHelper

@MainActor
struct ExerciseAnimationTests {
    private func birdDog() throws -> ExerciseAnimation {
        try #require(ExerciseAnimation.named("Bird Dog"))
    }

    @Test func birdDogIsBundled() throws {
        let animation = try birdDog()
        #expect(animation.name == "Bird Dog")
        #expect(animation.fps == 30)
        #expect(animation.farSide == .right)
        #expect(animation.duration > 5)
    }

    @Test func everyFrameHasEveryJoint() throws {
        let animation = try birdDog()
        for frame in animation.frames {
            #expect(Set(frame.keys).isSuperset(of: ExerciseAnimation.joints))
        }
    }

    @Test func lookupIgnoresCaseAndSpacing() {
        #expect(ExerciseAnimation.resourceName(for: "Bird Dog") == "bird-dog")
        #expect(ExerciseAnimation.resourceName(for: "  bird   DOG ") == "bird-dog")
        #expect(ExerciseAnimation.resourceName(for: "Around-the-World!") == "around-the-world")
        #expect(ExerciseAnimation.named("bird dog") != nil)
    }

    @Test func missingAnimationIsNil() {
        #expect(ExerciseAnimation.named("Not A Real Exercise") == nil)
    }

    @Test func playbackLoopsAndInterpolates() throws {
        let animation = try birdDog()
        let first = animation.frames[0]["lHand"]!
        let looped = animation.pose(at: animation.duration)["lHand"]!
        #expect(abs(looped.x - first.x) < 1e-9 && abs(looped.y - first.y) < 1e-9)

        // Halfway between two frames lands halfway between their positions.
        let i = animation.frames.count / 3
        let a = animation.frames[i]["rHand"]!, b = animation.frames[i + 1]["rHand"]!
        let mid = animation.pose(at: (Double(i) + 0.5) / animation.fps)["rHand"]!
        #expect(abs(mid.x - (a.x + b.x) / 2) < 1e-9 && abs(mid.y - (a.y + b.y) / 2) < 1e-9)
    }

    @Test func stillPoseIsAnExtendedDiagonal() throws {
        let animation = try birdDog()
        let rest = animation.frames[0], still = animation.stillPose
        // In the still, one hand has reached forward (further left) and one ankle has lifted off the floor.
        let reach = min(still["lHand"]!.x, still["rHand"]!.x) < min(rest["lHand"]!.x, rest["rHand"]!.x) - 0.05
        let lift = max(still["lAnkle"]!.y, still["rAnkle"]!.y) > max(rest["lAnkle"]!.y, rest["rAnkle"]!.y) + 0.05
        #expect(reach && lift)
    }

    // MARK: Whole library

    private func libraryExerciseNames() throws -> [String] {
        let container = try ModelContainer(
            for: Exercise.self, Routine.self, RoutineExercise.self, ScheduledSession.self, ExerciseLog.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        SeedData.seedIfNeeded(context: container.mainContext)
        return try container.mainContext.fetch(FetchDescriptor<Exercise>()).map(\.name)
    }

    @Test func everyLibraryExerciseHasAnAnimation() throws {
        let names = try libraryExerciseNames()
        #expect(names.count == 41)
        let missing = names.filter { ExerciseAnimation.named($0) == nil }
        #expect(missing.isEmpty, "No animation for: \(missing)")
    }

    @Test func libraryAnimationsAreCompleteAndLoopSeamlessly() throws {
        for name in try libraryExerciseNames() {
            let animation = try #require(ExerciseAnimation.named(name))
            #expect(animation.name == name)
            #expect(animation.duration > 2 && animation.duration < 20, "\(name) is \(animation.duration)s")
            for frame in animation.frames {
                #expect(Set(frame.keys).isSuperset(of: ExerciseAnimation.joints), "\(name) is missing joints")
            }
            // Last frame flows back into the first without a visible jump.
            let first = animation.frames[0], last = animation.frames[animation.frames.count - 1]
            let jump = ExerciseAnimation.joints.map { hypot(first[$0]!.x - last[$0]!.x, first[$0]!.y - last[$0]!.y) }.max()!
            #expect(jump < 0.02, "\(name) jumps \(jump) at the loop seam")
            // Close-ups and glows only reference joints that exist.
            for joint in animation.focus + animation.glows.flatMap(\.joints) {
                #expect(first[joint] != nil, "\(name) references unknown joint \(joint)")
            }
            for glow in animation.glows {
                #expect(glow.intensity.count == animation.frames.count)
            }
        }
    }
}
