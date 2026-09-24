"""Bird dog: key poses measured from the video, motion synthesized with eased joint-angle blending.

Side view, facing left. Vision's 'left' side is the near side (visible ~92% of frames); the far arm is often
hidden behind the near arm, so at rest it copies the near arm with a small depth offset.
"""
import json, math, sys

RAW, OUT = sys.argv[1], sys.argv[2]
F = json.load(open(RAW))
FPS = 30

NAMES = {'root': None, 'neck': 'neck_1_joint', 'head': 'head_joint',
         'lShoulder': 'left_shoulder_1_joint', 'rShoulder': 'right_shoulder_1_joint',
         'lElbow': 'left_forearm_joint', 'rElbow': 'right_forearm_joint',
         'lHand': 'left_hand_joint', 'rHand': 'right_hand_joint',
         'lHip': 'left_upLeg_joint', 'rHip': 'right_upLeg_joint',
         'lKnee': 'left_leg_joint', 'rKnee': 'right_leg_joint',
         'lAnkle': 'left_foot_joint', 'rAnkle': 'right_foot_joint'}

def median(xs):
    xs = sorted(xs); n = len(xs)
    return xs[n // 2] if n % 2 else (xs[n // 2 - 1] + xs[n // 2]) / 2

def key_pose(t0, t1, conf=0.4):
    frames = [f for f in F if t0 <= f['t'] <= t1]
    pose = {}
    for short, name in NAMES.items():
        if name is None: continue
        pts = [f['joints'][name] for f in frames if name in f['joints'] and f['joints'][name][2] > conf]
        pose[short] = (median([p[0] for p in pts]), median([p[1] for p in pts])) if len(pts) >= 5 else None
    return pose

rest = key_pose(1.0, 6.5)
diagA = key_pose(9.0, 12.0)    # far (right) arm forward, near (left) leg back
diagB = key_pose(16.0, 19.0)   # near (left) arm forward, far (right) leg back

# Fill joints Vision couldn't see: the far limbs at rest sit right behind the near ones.
for pose in (rest, diagA, diagB):
    for near, far in (('lElbow', 'rElbow'), ('lHand', 'rHand'), ('lKnee', 'rKnee'), ('lAnkle', 'rAnkle'),
                      ('lShoulder', 'rShoulder'), ('lHip', 'rHip')):
        if pose[far] is None: pose[far] = rest[near]
        if pose[near] is None: pose[near] = rest[near]
# Diagonal A keeps the near arm planted and the far leg planted (as at rest), and vice versa for B.
for k in ('lElbow', 'lHand'): diagA[k] = rest[k]
for k in ('rKnee', 'rAnkle'): diagA[k] = rest['lKnee' if k == 'rKnee' else 'lAnkle']
for k in ('rElbow', 'rHand'): diagB[k] = rest['lElbow' if k == 'rElbow' else 'lHand']
for k in ('lKnee', 'lAnkle'): diagB[k] = rest[k]
for pose in (rest, diagA, diagB):
    # Side view: both hips/shoulders project to one point — use their midpoint as the joint.
    pose['root'] = ((pose['lHip'][0] + pose['rHip'][0]) / 2, (pose['lHip'][1] + pose['rHip'][1]) / 2)
    shoulder = ((pose['lShoulder'][0] + pose['rShoulder'][0]) / 2, (pose['lShoulder'][1] + pose['rShoulder'][1]) / 2)
    pose['lShoulder'] = pose['rShoulder'] = shoulder
    pose['lHip'] = pose['rHip'] = pose['root']

# ---------- Skeleton as bone angles with lengths fixed from the rest pose ----------
BONES = [  # (parent, child)
    ('root', 'lShoulder'), ('lShoulder', 'neck'), ('neck', 'head'),
    ('lShoulder', 'lElbow'), ('lElbow', 'lHand'), ('lShoulder', 'rElbow'), ('rElbow', 'rHand'),
    ('root', 'lKnee'), ('lKnee', 'lAnkle'), ('root', 'rKnee'), ('rKnee', 'rAnkle'),
]
def dist(a, b): return math.hypot(a[0] - b[0], a[1] - b[1])
def near(name):
    """Far-side limb joints share the near side's bone lengths (measured most reliably)."""
    return {'rElbow': 'lElbow', 'rHand': 'lHand', 'rKnee': 'lKnee', 'rAnkle': 'lAnkle'}.get(name, name)
LENGTHS = {child: dist(rest[near(parent)], rest[near(child)]) for parent, child in BONES}

def to_angles(pose):
    return {child: math.atan2(pose[child][1] - pose[parent][1], pose[child][0] - pose[parent][0]) for parent, child in BONES}

def build(root, angles):
    J = {'root': root}
    for parent, child in BONES:
        p = J[parent]
        J[child] = (p[0] + math.cos(angles[child]) * LENGTHS[child], p[1] + math.sin(angles[child]) * LENGTHS[child])
    J['rShoulder'] = J['lShoulder']
    J['lHip'] = J['rHip'] = J['root']
    return J

def lerp_angle(a, b, w):
    d = (b - a + math.pi) % (2 * math.pi) - math.pi
    return a + d * w

POSES = {'rest': (rest['root'], to_angles(rest)), 'A': (diagA['root'], to_angles(diagA)), 'B': (diagB['root'], to_angles(diagB))}

# ---------- Timeline (seconds): timing of the reach/return taken from the video (~1.5 s out, ~1.2 s back) ----------
TIMELINE = [('rest', 0.8), ('rest>A', 1.5), ('A', 2.0), ('A>rest', 1.2), ('rest', 0.6),
            ('rest>B', 1.5), ('B', 2.0), ('B>rest', 1.2), ('rest', 0.4)]

def ease(w):  # smoothstep-style ease-in-out with gentle ends
    return w * w * w * (w * (w * 6 - 15) + 10)

frames = []
for step, seconds in TIMELINE:
    count = int(round(seconds * FPS))
    for k in range(count):
        if '>' in step:
            a, b = step.split('>')
            w = ease(k / count)
            (ra, aa), (rb, ab) = POSES[a], POSES[b]
            root = (ra[0] + (rb[0] - ra[0]) * w, ra[1] + (rb[1] - ra[1]) * w)
            angles = {c: lerp_angle(aa[c], ab[c], w) for c in aa}
        else:
            root, angles = POSES[step]
        frames.append(build(root, angles))

# Normalize into a shared square box (y up, 0..1).
xs = [v[0] for J in frames for v in J.values()]
ys = [v[1] for J in frames for v in J.values()]
cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
span = max(max(xs) - min(xs), max(ys) - min(ys)) * 1.18
def norm(v): return [round((v[0] - cx) / span + 0.5, 4), round((v[1] - cy) / span + 0.5, 4)]
out = [{k: norm(v) for k, v in J.items()} for J in frames]
json.dump({'name': 'Bird Dog', 'fps': FPS, 'farSide': 'r', 'frames': out}, open(OUT, 'w'), separators=(',', ':'))
print('wrote', len(out), 'frames', f'({len(out) / FPS:.1f}s)')
for name, pose in (('rest', rest), ('A', diagA), ('B', diagB)):
    print(name, {k: (round(v[0]), round(v[1])) for k, v in pose.items() if k in ('root', 'lShoulder', 'lHand', 'rHand', 'lAnkle', 'rAnkle')})
