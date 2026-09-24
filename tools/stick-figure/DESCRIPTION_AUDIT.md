# Library animation description audit

Source: the 41 built-in exercise descriptions in `PTHelper/Services/SeedData.swift`.
All use the approved fitness figure and palette, joint markers, phase captions, readable props,
and looping eased movement. The descriptions themselves were not changed.

This is a software/visual consistency review, not a clinical certification. Long prescribed holds
are represented by shorter demonstration holds; the app's separate exercise timer remains authoritative.
Explicit two-second holds and the five-second minimum for contractions are shown in full.

| Exercise | Description requirements checked / treatment |
| --- | --- |
| Quad Sets | Supine, straighten/press knee down, thigh contraction, five-second hold, release. |
| Straight Leg Raises | Opposite knee bent, raised knee stays straight; corrected lift to bent-knee height and slow lowering. |
| Short Arc Quads | Towel beneath stationary knee; straighten lower leg, hold two seconds, lower. |
| Terminal Knee Extension | Band anchored above knee, slight bend to straight; fixed both feet to stop drifting. |
| Wall Sit | Back at wall, feet planted, slide to approximately 90° knees, hold, slide back. |
| Step Ups | Left leads up, right joins, the same left foot leads down, then right follows. |
| Clamshells | Side-lying, bent knees, stacked hips; top knee opens while ankles, heels and toes remain together. |
| Glute Bridges | Supine with bent knees and fixed feet; corrected shoulder–hip–knee alignment at the top. |
| Side-Lying Hip Abduction | Stacked hips, straight legs, top leg lifts approximately 45° without turning the pelvis. |
| Donkey Kicks | Hands/knee support and a flat back; moving knee stays bent 90°, foot lifts toward ceiling. |
| External Rotation with Band | Elbow at side and bent 90°; forearm rotates outward against an anchored band. |
| Internal Rotation with Band | Elbow at side and bent 90°; forearm rotates inward across body against an anchored band. |
| Shoulder Rows | Both hands pull bands toward mid-torso, elbows stay close, shoulder blades retract. |
| Scapular Retraction | Removed deliberate arm swing and trunk extension; shoulder blades retract with relaxed arms, hold five seconds. |
| Heel Raises | Toes remain planted while heels and body rise; pause, then lower slowly. |
| Ankle Eversion with Band | Seated, extended leg, outward foot movement with band attached at foot; close-up emphasizes ankle. |
| Towel Scrunches | Seated with towel at foot; toes curl/release and the towel endpoint follows the toes. |
| Dead Bug | Supine, arms up and knees at 90°; alternating opposite arm/leg extensions with stable trunk. |
| Bird Dog | Reauthored on the common rig; alternate opposite arm/leg pairs, straight back, two-second holds. |
| Pelvic Tilts | Supine with knees bent and stable feet; subtle lumbar contour flattens with abdominal contraction. |
| Plank | Forearms with elbows directly under shoulders, straight knees and body, toes supported; representative breathing hold. |
| Supine Marching | Alternate small foot lifts (~11 cm), with lower back/pelvis stable. |
| Hamstring Stretch | Supine, strap from hands around raised foot, knee stays straight, gentle hold and release. |
| Quad Stretch | Wall support, bend knee and grasp ankle, upright trunk; grasp now eases in/out without snapping. |
| Hip Flexor Stretch | Half-kneeling, forward foot fixed, hips glide forward, trunk upright; improved rear-foot orientation. |
| Piriformis Stretch | Right ankle remains over left knee while hands draw the supporting thigh toward chest. |
| Calf Stretch (Gastrocnemius) | Wall support, rear knee stays straight and heel fixed while hips/trunk move forward. |
| IT Band Stretch | Right foot behind left; trunk leans left while right hip moves outward. |
| Thoracic Rotation | Seated with feet flat and arms crossed; upper body turns both ways with holds and stable pelvis. |
| Shoulder Cross-Body Stretch | Straight arm across chest, opposite hand just above elbow; gradual grasp and release. |
| Neck Stretch | Upright, ear toward shoulder on each side, holds and controlled return; upper-body framing. |
| Single Leg Stance | Nearby support, small foot lift and minimal sway, controlled return. Optional eyes-closed progression is not depicted. |
| Tandem Stance | Heel-to-toe feet in one line; holds with each foot in front, controlled stepping transitions. |
| Single Leg Balance with Arm Reach | Preserved right-arm reach paths; changed support to left leg to match “opposite arm.” Forward, sideways and diagonal reaches. |
| Ankle Alphabet | Expanded A–C to all A–Z; only the ankle moves while leg is suspended; letter labels and resetting toe trail. |
| Knee Flexion/Extension | Seated with stable thigh, full extension then comfortable flexion; chair supports the seated figure. |
| Cervical Range of Motion | Seated, look up/down, turn left/right, tilt both ways; face marker retained in fitness renderer. |
| Shoulder Pendulum | Opposite hand supported on table, relaxed hanging arm, small circles and side-to-side movement. |
| Shoulder Circles | Both shoulders roll forward then backward; hands follow relaxed below shoulders instead of swinging outward. |
| Hip Circles | Fixed shoulder-width feet, outward elbows/hands at hips; hip circle and reverse direction. |
| Lumbar Flexion/Extension | Fixed feet, forward hip hinge, return, gentle backward extension, return. |

## Verification

- Production SwiftUI renderer contact sheets for all 41 animations, including light-mode prop contrast,
  close-up clipping, caption wrapping, and depth ordering. Animated GIFs can be regenerated with the preview tool.
- `author/test_library.py`: 3D description-level checks for limb lengths, loop seams, fixed supports,
  contraction timing, opposite limbs, raise height, bridge alignment, plank support, and ankle-only A–Z motion.
- `PTHelperTests/ExerciseAnimationTests.swift`: bundled coverage, playback/interpolation, loop seams,
  frame integrity, fitness metadata, cue order, complete alphabet, and face-direction data.

Custom exercises or descriptions changed after seeding are outside this built-in catalog audit.
