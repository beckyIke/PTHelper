# Stick-figure exercise animations

Turns a video of someone doing an exercise into the looping stick-figure animations shown by
`ExerciseFigureView` in the app. Everything runs locally on a Mac with Apple's frameworks
(AVFoundation for video, Vision for body-pose detection) — no extra dependencies.

The app looks for `PTHelper/Resources/ExerciseAnimations/<exercise-name>.json`, where the file name is the
exercise's library name lowercased with dashes ("Bird Dog" → `bird-dog.json`). Adding a file there is all it
takes for the animation to appear on that exercise's detail screen and in workouts.

## Two ways to make an animation

1. **Authored from the description (`author/`) — used for 40 of the 41 library exercises.** Key poses are
   written in plain PT terms (hip flex 45°, knee flex 90°, …) on a small 3D skeleton with realistic proportions,
   then blended with easing, kept planted with pins and IK, and projected through a camera. Props (wall, chair,
   step, band, strap, towel), muscle glows, close-up framing and toe trails are supported. This is the reliable
   route for lying-down exercises and small movements that video tracking can't see.
2. **Traced from video (the pipeline below) — used for Bird Dog.** Vision detects joints in a real video;
   a solver turns them into a clean loop.

### Authoring workflow

```sh
cd tools/stick-figure/author
python3 build.py                      # writes every exercise in library.py into the app bundle
python3 build.py /tmp/out "wall sit"  # or just one, somewhere else

# Preview contact sheets using the app's own renderer:
APP=../../../PTHelper
swiftc -O -o preview $APP/Models/ExerciseAnimation.swift $APP/Features/Library/ExerciseFigureRenderer.swift \
    ../preview/Shim.swift ../preview/main.swift
./preview $APP/Resources/ExerciseAnimations/wall-sit.json wall-sit.png 6 12   # columns, frames
```

To add an exercise: write a function in `author/library.py` (copy the closest existing one), add it to `ALL`,
build, and check the preview against the exercise's written description. Name must match the library exactly.
`rig.py` documents the angle conventions (e.g. shoulder `flex` = arm forward/up, knee `flex` = heel to buttock).

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
limbs are drawn lighter and behind the body. Joints: `root neck head lShoulder rShoulder lElbow rElbow lHand
rHand lHip rHip lKnee rKnee lAnkle rAnkle`.

## Tips

- Side-on video works best for floor exercises; front-on for standing ones. A steady camera helps.
- Real people track far better than stylized animated characters.
- Only use videos you have the right to use.
