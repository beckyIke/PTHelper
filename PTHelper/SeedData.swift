import Foundation
import SwiftData

struct SeedData {
    static func seedIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<Exercise>()
        guard let count = try? context.fetchCount(descriptor), count == 0 else { return }

        let S = ExerciseCategory.strength.rawValue
        let F = ExerciseCategory.flexibility.rawValue
        let B = ExerciseCategory.balance.rawValue
        let R = ExerciseCategory.rangeOfMotion.rawValue
        let C = ExerciseCategory.core.rawValue

        let knee = BodyPart.knee.rawValue
        let hip = BodyPart.hip.rawValue
        let ankle = BodyPart.ankle.rawValue
        let shoulder = BodyPart.shoulder.rawValue
        let lowerBack = BodyPart.lowerBack.rawValue
        let neck = BodyPart.neck.rawValue
        let core = BodyPart.core.rawValue
        let full = BodyPart.fullBody.rawValue

        let exercises: [Exercise] = [
            // Knee – Strength
            Exercise(name: "Quad Sets",
                description: "Lie on your back with leg straight. Tighten the thigh muscle by pressing the back of your knee down toward the floor. Hold 5–10 seconds, then relax.",
                category: S, bodyPart: knee, defaultSets: 3, defaultReps: 10),
            Exercise(name: "Straight Leg Raises",
                description: "Lie on your back with one knee bent and the other leg straight. Tighten the thigh of the straight leg and raise it to the height of the bent knee. Lower slowly.",
                category: S, bodyPart: knee, defaultSets: 3, defaultReps: 15),
            Exercise(name: "Short Arc Quads",
                description: "Place a rolled towel under your knee. Keeping the back of your knee on the towel, raise your foot until your leg is straight. Hold 2 seconds, then lower slowly.",
                category: S, bodyPart: knee, defaultSets: 3, defaultReps: 10),
            Exercise(name: "Terminal Knee Extension",
                description: "Attach a band above knee level. Stand with slight knee bend and straighten against band resistance. Keep foot flat and core engaged.",
                category: S, bodyPart: knee, defaultSets: 3, defaultReps: 15),
            Exercise(name: "Wall Sit",
                description: "Stand with your back flat against a wall. Slide down until your knees are at 90°. Hold the position with weight through your heels.",
                category: S, bodyPart: knee, defaultSets: 3, defaultReps: 0, defaultDurationSeconds: 30),
            Exercise(name: "Step Ups",
                description: "Stand in front of a step. Step up with one foot, bring the other up, then step back down leading with the same foot. Use a controlled motion.",
                category: S, bodyPart: knee, defaultSets: 3, defaultReps: 10),

            // Hip – Strength
            Exercise(name: "Clamshells",
                description: "Lie on your side with hips stacked and knees bent at 45°. Keeping feet together, raise the top knee as high as comfortable without rotating your pelvis. Lower slowly.",
                category: S, bodyPart: hip, defaultSets: 3, defaultReps: 15),
            Exercise(name: "Glute Bridges",
                description: "Lie on your back with knees bent and feet flat. Press through your heels to lift your hips until your body forms a straight line from shoulders to knees. Squeeze glutes at the top.",
                category: S, bodyPart: hip, defaultSets: 3, defaultReps: 15),
            Exercise(name: "Side-Lying Hip Abduction",
                description: "Lie on your side with legs straight. Keep toes pointing forward and raise the top leg to about 45°. Hold briefly and lower with control.",
                category: S, bodyPart: hip, defaultSets: 3, defaultReps: 15),
            Exercise(name: "Donkey Kicks",
                description: "On hands and knees, keep one knee bent at 90° and kick that foot toward the ceiling, squeezing the glute at the top. Keep your back flat.",
                category: S, bodyPart: hip, defaultSets: 3, defaultReps: 12),

            // Shoulder – Strength
            Exercise(name: "External Rotation with Band",
                description: "Hold a band with your elbow bent to 90° at your side. Keeping the elbow close to your body, rotate your forearm outward against the band resistance. Return slowly.",
                category: S, bodyPart: shoulder, defaultSets: 3, defaultReps: 15),
            Exercise(name: "Internal Rotation with Band",
                description: "Hold a band anchored to your side. With elbow at 90°, rotate forearm inward across your body against resistance. Return slowly.",
                category: S, bodyPart: shoulder, defaultSets: 3, defaultReps: 15),
            Exercise(name: "Shoulder Rows",
                description: "With a band or cable, pull toward your mid-torso keeping elbows close to your sides. Squeeze shoulder blades together at the end.",
                category: S, bodyPart: shoulder, defaultSets: 3, defaultReps: 12),
            Exercise(name: "Scapular Retraction",
                description: "Sit or stand tall. Without moving your arms, squeeze your shoulder blades together and hold for 5 seconds. Release and repeat.",
                category: S, bodyPart: shoulder, defaultSets: 3, defaultReps: 10),

            // Ankle – Strength
            Exercise(name: "Heel Raises",
                description: "Stand with feet hip-width apart. Rise onto your toes as high as comfortable, hold briefly, and lower slowly. Progress to single-leg.",
                category: S, bodyPart: ankle, defaultSets: 3, defaultReps: 15),
            Exercise(name: "Ankle Eversion with Band",
                description: "Sit with leg extended and a band around the foot. Turn the sole of your foot outward against the band. Return with control.",
                category: S, bodyPart: ankle, defaultSets: 3, defaultReps: 15),
            Exercise(name: "Towel Scrunches",
                description: "Sit with a small towel on the floor under your foot. Use your toes to scrunch the towel toward you. Straighten toes and repeat.",
                category: S, bodyPart: ankle, defaultSets: 3, defaultReps: 10),

            // Core
            Exercise(name: "Dead Bug",
                description: "Lie on your back with arms pointing up and knees at 90°. Keep your lower back pressed flat. Lower one arm overhead while extending the opposite leg toward the floor. Return and alternate.",
                category: C, bodyPart: core, defaultSets: 3, defaultReps: 10),
            Exercise(name: "Bird Dog",
                description: "On hands and knees with back flat, extend your opposite arm and leg simultaneously until they form a straight line. Hold 2 seconds and return. Alternate sides.",
                category: C, bodyPart: core, defaultSets: 3, defaultReps: 10),
            Exercise(name: "Pelvic Tilts",
                description: "Lie on your back with knees bent. Tighten your abdominals to flatten your lower back against the floor. Hold briefly and release.",
                category: C, bodyPart: core, defaultSets: 3, defaultReps: 10),
            Exercise(name: "Plank",
                description: "Hold a forearm plank with elbows under shoulders. Keep your body in a straight line from head to heels. Breathe steadily.",
                category: C, bodyPart: core, defaultSets: 3, defaultReps: 0, defaultDurationSeconds: 30),
            Exercise(name: "Supine Marching",
                description: "Lie on your back with knees bent. Keeping your lower back stable, alternately lift each foot a few inches off the floor in a marching motion.",
                category: C, bodyPart: core, defaultSets: 3, defaultReps: 10),

            // Flexibility
            Exercise(name: "Hamstring Stretch",
                description: "Lie on your back. Loop a strap around your foot or use your hands to gently pull one straight leg toward you until you feel a stretch in the back of the thigh.",
                category: F, bodyPart: knee, defaultSets: 3, defaultReps: 0, defaultDurationSeconds: 30),
            Exercise(name: "Quad Stretch",
                description: "Stand near a wall for balance. Bend one knee and grasp your ankle, pulling your foot toward your buttock. Keep knees together and stand tall.",
                category: F, bodyPart: knee, defaultSets: 3, defaultReps: 0, defaultDurationSeconds: 30),
            Exercise(name: "Hip Flexor Stretch",
                description: "Kneel on one knee with the other foot forward. Push your hips gently forward until you feel a stretch in the front of the kneeling hip. Keep your trunk upright.",
                category: F, bodyPart: hip, defaultSets: 3, defaultReps: 0, defaultDurationSeconds: 30),
            Exercise(name: "Piriformis Stretch",
                description: "Lie on your back. Cross your right ankle over your left knee. Pull both legs toward your chest until you feel a stretch deep in your right buttock.",
                category: F, bodyPart: hip, defaultSets: 3, defaultReps: 0, defaultDurationSeconds: 30),
            Exercise(name: "Calf Stretch (Gastrocnemius)",
                description: "Stand facing a wall with one foot back, knee straight, heel flat. Lean forward until you feel the stretch in the upper calf.",
                category: F, bodyPart: ankle, defaultSets: 3, defaultReps: 0, defaultDurationSeconds: 30),
            Exercise(name: "IT Band Stretch",
                description: "Stand with your right foot crossed behind the left. Lean your upper body to the left while pushing your right hip out to the right. You should feel a stretch along the outer right thigh.",
                category: F, bodyPart: hip, defaultSets: 3, defaultReps: 0, defaultDurationSeconds: 30),
            Exercise(name: "Thoracic Rotation",
                description: "Sit upright in a chair with feet flat. Cross your arms over your chest. Rotate your upper body as far to each side as is comfortable. Hold at end range.",
                category: F, bodyPart: lowerBack, defaultSets: 2, defaultReps: 10),
            Exercise(name: "Shoulder Cross-Body Stretch",
                description: "Bring one arm straight across your chest. Use your other hand to gently apply pressure just above the elbow. Feel the stretch in the back of the shoulder.",
                category: F, bodyPart: shoulder, defaultSets: 3, defaultReps: 0, defaultDurationSeconds: 30),
            Exercise(name: "Neck Stretch",
                description: "Sit or stand tall. Tilt your ear gently toward your shoulder until you feel a stretch on the opposite side of your neck. Hold, then repeat on the other side.",
                category: F, bodyPart: neck, defaultSets: 3, defaultReps: 0, defaultDurationSeconds: 30),

            // Balance
            Exercise(name: "Single Leg Stance",
                description: "Stand near a wall or chair for safety. Lift one foot slightly and balance on the other leg. Try to minimize swaying. Progress by closing your eyes.",
                category: B, bodyPart: ankle, defaultSets: 3, defaultReps: 0, defaultDurationSeconds: 30),
            Exercise(name: "Tandem Stance",
                description: "Stand with one foot directly in front of the other, heel touching toe. Hold position with minimal support. Alternate which foot is in front.",
                category: B, bodyPart: ankle, defaultSets: 3, defaultReps: 0, defaultDurationSeconds: 20),
            Exercise(name: "Single Leg Balance with Arm Reach",
                description: "Stand on one leg. Reach forward, sideways, and diagonally with the opposite arm while maintaining balance. Control the movement.",
                category: B, bodyPart: full, defaultSets: 3, defaultReps: 10),

            // Range of Motion
            Exercise(name: "Ankle Alphabet",
                description: "Sit with your leg elevated and unsupported. Use your big toe as a pointer to draw all 26 letters of the alphabet in the air. Move only your ankle.",
                category: R, bodyPart: ankle, defaultSets: 1, defaultReps: 1),
            Exercise(name: "Knee Flexion/Extension",
                description: "Sit in a chair. Slowly bend your knee as far as comfortable, then straighten it fully. Move through the complete pain-free range of motion.",
                category: R, bodyPart: knee, defaultSets: 3, defaultReps: 15),
            Exercise(name: "Cervical Range of Motion",
                description: "Sit upright. Slowly look up and down, turn left and right, and tilt ear to shoulder in each direction. Move to the end of your comfortable range.",
                category: R, bodyPart: neck, defaultSets: 2, defaultReps: 5),
            Exercise(name: "Shoulder Pendulum",
                description: "Lean forward supported on a table with the uninvolved arm. Let your other arm hang free. Use your body to gently swing the arm in small circles and side-to-side.",
                category: R, bodyPart: shoulder, defaultSets: 3, defaultReps: 10),
            Exercise(name: "Shoulder Circles",
                description: "Stand relaxed. Roll both shoulders in large, slow circles forward, then reverse direction. Keep movements smooth and controlled.",
                category: R, bodyPart: shoulder, defaultSets: 2, defaultReps: 10),
            Exercise(name: "Hip Circles",
                description: "Stand with feet shoulder-width apart and hands on hips. Make large, slow circles with your hips, moving through your comfortable range.",
                category: R, bodyPart: hip, defaultSets: 2, defaultReps: 10),
            Exercise(name: "Lumbar Flexion/Extension",
                description: "Stand with feet shoulder-width apart. Gently bend forward from the hips, then extend backward. Move slowly through your comfortable range.",
                category: R, bodyPart: lowerBack, defaultSets: 2, defaultReps: 10),
        ]

        for exercise in exercises {
            context.insert(exercise)
        }

        try? context.save()
    }
}
