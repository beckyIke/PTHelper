"""Build every authored exercise animation into the app bundle.

    python3 build.py [output_dir] [name filter]

Writes <exercise-name>.json (same naming as ExerciseAnimation.resourceName) to
PTHelper/Resources/ExerciseAnimations/ by default.
"""
import os, re, sys, traceback
from library import ALL

out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), '../../../PTHelper/Resources/ExerciseAnimations')
only = sys.argv[2].lower() if len(sys.argv) > 2 else None

def resource_name(name):
    return '-'.join(w for w in re.split(r'[^a-z0-9]+', name.lower()) if w)

failures = 0
for make in ALL:
    try:
        ex = make()
        if only and only not in ex.name.lower():
            continue
        ex.build()
        path = os.path.join(out, resource_name(ex.name) + '.json')
        ex.export(path)
        print(f'{ex.name:38s} {len(ex.frames3d) / ex.fps:5.1f}s  → {os.path.basename(path)}')
    except Exception:
        failures += 1
        print('FAILED', make.__name__)
        traceback.print_exc()
sys.exit(1 if failures else 0)
