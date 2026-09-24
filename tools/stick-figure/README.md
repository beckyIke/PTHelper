# Stick-figure exercise animations

Builds the looping activity figures shown by `ExerciseFigureView`. All 41 built-in exercises are authored
from their descriptions in `PTHelper/Services/SeedData.swift`, using the shared fitness renderer: lime figures
on a dark stage, subtly marked joints, rounded limbs, and movement captions. Everything runs locally.

The app looks for `PTHelper/Resources/ExerciseAnimations/<exercise-name>.json`, where the file name is the
exercise's library name lowercased with dashes ("Bird Dog" → `bird-dog.json`). Adding a file there is all it
takes for the animation to appear on that exercise's detail screen and in workouts.

## Two ways to make an animation

1. **Authored from the description (`author/`) — used for all 41 library exercises.** Key poses are
   written in plain PT terms (hip flex 45°, knee flex 90°, …) on a small 3D skeleton with realistic proportions,
   then blended with easing, kept planted with pins and IK, and projected through a camera. Props (wall, chair,
   step, band, strap, towel), muscle glows, close-up framing and toe trails are supported. This is the reliable
   route for lying-down exercises and small movements that video tracking can't see.
2. **Traced from video (the optional legacy pipeline below).** Vision detects joints in a real video;
   a solver turns them into a clean loop. Bird Dog now uses the authored rig too, with opposite limbs and
   two-second holds on each side.

### Authoring workflow

```sh
# From the repository root:
python3 -B tools/stick-figure/author/build.py
python3 -B tools/stick-figure/author/build.py /tmp/pthelper-poses "wall sit"
python3 -B -m unittest discover -s tools/stick-figure/author -p 'test_*.py'

# Preview contact sheets using the app's own renderer:
swiftc -O -o /tmp/pthelper-preview PTHelper/Models/ExerciseAnimation.swift \
    PTHelper/Features/Library/ExerciseFigureRenderer.swift \
    tools/stick-figure/preview/Shim.swift tools/stick-figure/preview/main.swift
/tmp/pthelper-preview PTHelper/Resources/ExerciseAnimations /tmp/pthelper-review --gifs
python3 -B tools/stick-figure/preview/gallery.py /tmp/pthelper-review
```

To add an exercise: write a function in `author/library.py` (copy the closest existing one), add it to `ALL`,
build, and check the preview against the exercise's written description. Name must match the library exactly.
`rig.py` documents the angle conventions (e.g. shoulder `flex` = arm forward/up, knee `flex` = heel to buttock).
`cues.py` supplies phase instructions; exercises with dynamic sequences supply their own cues. The full
description audit is in [DESCRIPTION_AUDIT.md](DESCRIPTION_AUDIT.md).

Explicit 2–5 second holds are demonstrated at their stated duration. Long timed exercises show a shorter
representative hold; the animation is not the workout timer. Ankle Alphabet traces all 26 letters at a readable
pace (~95 seconds), with a fresh trail for each letter. Bounds are cached at decode time so the long sequence
does not require rescanning every frame during playback.

## Video pipeline

```sh
cd tools/stick-figure
for s in inspect sheet overlay pose render; do swiftc -O $s.swift -o $s; done

# 1. Look at the video: duration, size, fps, plus 8 sample frames.
./inspect ~/Desktop/exercise.mp4 frames && ./sheet sheet.png frames/*.png

# 2. Detect body joints on every other frame (~30 fps). Last two args crop to the figure: <top y> <height>.
./pose ~/Desktop/exercise.mp4 raw.json 0 720

# 3. (Optional) Draw the detections over chosen frames to see where tracking struggles.
./overlay ~/Desktop/exercise.mp4 raw.json overlays 0 720 20 60 100 140

# 4. Build a clean loop from the detections — see the two solvers below.
python3 solve_bird_dog.py raw.json bird-dog.json

# 5. Preview: an MP4 (loop played 3×) plus review stills.
mkdir -p stills && ./render bird-dog.json bird-dog.mp4 stills 3

# 6. Ship it.
cp bird-dog.json ../../PTHelper/Resources/ExerciseAnimations/
```

## Solvers

Raw detections are too jittery to use directly, and Vision loses joints in some poses, so each exercise gets
a small solver that turns detections into a clean, seamlessly looping skeleton. Two approaches so far:

- **`solve_bird_dog.py` — key poses + synthesized motion (preferred).** Measures a few key poses from the
  video (median over each hold) and the timing of each move, then blends between them with eased joint-angle
  interpolation. Limbs keep their length and sweep in arcs, and the loop is perfectly smooth. Best for
  exercises made of distinct positions (most PT exercises). Edit `key_pose(...)` time ranges and `TIMELINE`.
- **`solve_around_the_world.py` — continuous tracking + a body model.** For flowing movements without
  distinct holds. Tracks the hands around the hips, smooths heavily (Gaussian), removes drift so the loop
  closes, and rotates an idealized standing template toward the hands. Edit `T0`/`T1` (loop segment) and `HOLD`.

## Output format

```json
{ "name": "Bird Dog", "fps": 30, "farSide": "r",
  "frames": [ { "root": [x, y], "neck": [x, y], "head": [x, y], "lShoulder": ..., "rAnkle": ... }, ... ] }
```

Coordinates are 0…1 with y pointing up. `farSide` (`"l"` or `"r"`) is the side farther from the camera; those
limbs are drawn behind the body in a secondary shade. Joints: `root neck head lShoulder rShoulder lElbow rElbow lHand
rHand lHip rHip lKnee rKnee lAnkle rAnkle`.

`figureStyle` is optional and defaults to `classic`. The `fitness` style uses a lime activity figure on a
dark stage, with slimmer rounded limbs, a tapered torso, and subtle joint markers. All bundled animations
opt in. Optional `cues` entries (`startFrame`, `label`) display short instructions
in a reserved caption area beneath that figure. In `author/library.py`, set `figure_style='fitness'` and
provide a `cues` dictionary keyed by pose or transition name; the exporter derives frame timings.
Authored frames also include `lumbar` for the small lower-back contour change in Pelvic Tilts. Optional
trail `resetOnCue` prevents one alphabet letter's trail from carrying into the next.

## Tips

- Side-on video works best for floor exercises; front-on for standing ones. A steady camera helps.
- Real people track far better than stylized animated characters.
- Only use videos you have the right to use.
