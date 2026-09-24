"""Turn noisy Vision detections of 'Around the World' into a clean, looping skeleton.

Model: legs come from a standing template with planted feet (knees solved with 2-bone IK);
the upper body (torso, head, arms) is the standing template rotated to point at the hands and
shortened along its length as the hands come toward the camera (foreshortening in the forward fold).
"""
import json, math, sys

RAW, OUT = sys.argv[1], sys.argv[2]
T0, T1 = 6.0, 11.4          # loop segment: standing -> full circle -> standing
HOLD = (3.3, 6.5)           # clean standing frames for the template
FPS = 30

F = json.load(open(RAW))

def get(f, k, c=0.3):
    v = f['joints'].get(k)
    return (v[0], v[1]) if v and v[2] > c else None

def mid(a, b): return ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
def sub(a, b): return (a[0] - b[0], a[1] - b[1])
def add(a, b): return (a[0] + b[0], a[1] + b[1])
def mul(a, s): return (a[0] * s, a[1] * s)
def length(a): return math.hypot(a[0], a[1])
def median(xs):
    xs = sorted(xs); n = len(xs)
    return xs[n // 2] if n % 2 else (xs[n // 2 - 1] + xs[n // 2]) / 2

def root_of(f):
    l, r = get(f, 'left_upLeg_joint'), get(f, 'right_upLeg_joint')
    return mid(l, r) if l and r else None

def hand_of(f):
    hs = [p for p in (get(f, 'left_hand_joint'), get(f, 'right_hand_joint')) if p]
    return (sum(p[0] for p in hs) / len(hs), sum(p[1] for p in hs) / len(hs)) if hs else None

# ---------- Standing template (offsets from root, root-local frame where 'up' is +y) ----------
NAMES = ['neck_1_joint', 'head_joint', 'left_shoulder_1_joint', 'right_shoulder_1_joint',
         'left_forearm_joint', 'right_forearm_joint', 'left_hand_joint', 'right_hand_joint',
         'left_upLeg_joint', 'right_upLeg_joint', 'left_leg_joint', 'right_leg_joint',
         'left_foot_joint', 'right_foot_joint']
hold = [f for f in F if HOLD[0] <= f['t'] <= HOLD[1] and root_of(f)]
template = {}
for n in NAMES:
    offs = [sub(get(f, n), root_of(f)) for f in hold if get(f, n)]
    template[n] = (median([o[0] for o in offs]), median([o[1] for o in offs]))
hands_t = mid(template['left_hand_joint'], template['right_hand_joint'])
R_STAND = length(hands_t)

# Idealize the standing pose for a clean stick figure: mirror left/right from the measured averages,
# and follow the technique cue "arms stretched above your head with hands together" — elbows angled out,
# hands meeting in a single point above the head.
def sym(l, r):
    lx, ly = template[l]; rx_, ry_ = template[r]
    cx = (lx + rx_) / 2
    x = (abs(lx - cx) + abs(rx_ - cx)) / 2
    y = (ly + ry_) / 2
    return (x, y)
neck_y = template['neck_1_joint'][1]
for left, right in (('left_upLeg_joint', 'right_upLeg_joint'), ('left_leg_joint', 'right_leg_joint'),
                    ('left_foot_joint', 'right_foot_joint'), ('left_shoulder_1_joint', 'right_shoulder_1_joint')):
    x, y = sym(left, right)
    template[left], template[right] = (x, y), (-x, y)
template['neck_1_joint'] = (0, neck_y)
template['head_joint'] = (0, neck_y + 40)
shoulder_x = template['left_shoulder_1_joint'][0]
elbow_y = neck_y + (R_STAND - neck_y) * 0.42
template['left_forearm_joint'], template['right_forearm_joint'] = (shoulder_x * 1.9, elbow_y), (-shoulder_x * 1.9, elbow_y)
template['left_hand_joint'] = template['right_hand_joint'] = (0, R_STAND)
print('template from', len(hold), 'frames; standing hand reach', round(R_STAND))

# ---------- Resample the loop segment and clean the hand circle ----------
seg = [f for f in F if T0 <= f['t'] <= T1]
ts = [f['t'] for f in seg]
roots = [root_of(f) for f in seg]
hvec = [sub(hand_of(f), root_of(f)) if hand_of(f) and root_of(f) else None for f in seg]

def fill(series):
    """Linear interpolation over gaps (None)."""
    out = list(series); n = len(out)
    known = [i for i, v in enumerate(out) if v is not None]
    for i in range(n):
        if out[i] is None:
            lo = max([k for k in known if k < i], default=None)
            hi = min([k for k in known if k > i], default=None)
            if lo is None: out[i] = out[hi]
            elif hi is None: out[i] = out[lo]
            else:
                w = (i - lo) / (hi - lo)
                out[i] = out[lo] + (out[hi] - out[lo]) * w
    return out

def median_filter(series, k):
    out = []
    for i in range(len(series)):
        win = [v for v in series[max(0, i - k):i + k + 1] if v is not None]
        out.append(median(win) if win and series[i] is not None else None)
    return out

def smooth(series, k):
    return [sum(series[max(0, i - k):i + k + 1]) / len(series[max(0, i - k):i + k + 1]) for i in range(len(series))]

def gaussian(series, sigma):
    """Gaussian smoothing with clamped edges (both loop ends are held still, so clamping is safe)."""
    r = int(3 * sigma)
    weights = [math.exp(-(j * j) / (2 * sigma * sigma)) for j in range(-r, r + 1)]
    n = len(series)
    return [sum(w * series[min(max(i + j, 0), n - 1)] for w, j in zip(weights, range(-r, r + 1))) / sum(weights)
            for i in range(n)]

# Polar hand path, unwrapped so the angle climbs continuously through the circle.
theta, radius, prev = [], [], None
for v in hvec:
    if v is None or length(v) < 60:
        theta.append(None); radius.append(None); continue
    a = math.atan2(v[1], v[0])
    if prev is not None:
        while a - prev > math.pi: a -= 2 * math.pi
        while a - prev < -math.pi: a += 2 * math.pi
    theta.append(a); radius.append(length(v)); prev = a

# Reject outliers (Vision sometimes grabs one hand at the wrong spot), then fill and smooth.
theta = fill(median_filter(theta, 3))
radius = fill(median_filter(radius, 4))
# The hand circle only ever rotates one way; enforce monotonic angle to remove backward twitches,
# then smooth heavily (~0.3 s) so the stalls that creates become an even, gliding sweep.
for i in range(1, len(theta)):
    theta[i] = max(theta[i], theta[i - 1])
theta = gaussian(theta, 9)
radius = gaussian(radius, 11)
# Exactly one turn, so the loop closes without a hitch.
turn = theta[-1] - theta[0]
theta = [theta[0] + (a - theta[0]) * (2 * math.pi / turn) for a in theta]
# Ends of the loop are both 'standing': ease the reach back to the standing length at each end.
EASE = 12
for i in range(EASE):
    w = 0.5 - 0.5 * math.cos(math.pi * i / EASE)   # 0 → 1
    radius[i] = R_STAND + (radius[i] - R_STAND) * w
    radius[-1 - i] = R_STAND + (radius[-1 - i] - R_STAND) * w
print('hand angle travels', round(math.degrees(theta[-1] - theta[0])), 'degrees')

# Root sway: smooth, then remove the linear drift between the loop ends.
rx = gaussian(fill(median_filter([r[0] if r else None for r in roots], 4)), 14)
ry = gaussian(fill(median_filter([r[1] if r else None for r in roots], 4)), 14)
n = len(seg)
rx = [rx[i] - (rx[-1] - rx[0]) * i / (n - 1) for i in range(n)]
ry = [ry[i] - (ry[-1] - ry[0]) * i / (n - 1) for i in range(n)]
# Calm the hip sway/bob to half its tracked size — enough to feel natural without bouncing.
mx, my = sum(rx) / n, sum(ry) / n
rx = [mx + (v - mx) * 0.5 for v in rx]
ry = [my + (v - my) * 0.5 for v in ry]

# Feet stay planted: absolute ankle positions from the segment medians.
root_avg = (sum(rx) / n, sum(ry) / n)
ankle_abs = {side: add(root_avg, template[f'{side}_foot_joint']) for side in ('left', 'right')}

def solve_knee(hip, ankle, l1, l2, outward):
    d = length(sub(ankle, hip))
    d = min(d, l1 + l2 - 1e-3)
    a = (l1 * l1 - l2 * l2 + d * d) / (2 * d)
    h = math.sqrt(max(l1 * l1 - a * a, 0))
    u = mul(sub(ankle, hip), 1 / length(sub(ankle, hip)))
    p = add(hip, mul(u, a))
    perp = (-u[1], u[0])
    c1, c2 = add(p, mul(perp, h)), add(p, mul(perp, -h))
    return c1 if (c1[0] - p[0]) * outward >= (c2[0] - p[0]) * outward else c2

UPPER = ['neck_1_joint', 'head_joint', 'left_shoulder_1_joint', 'right_shoulder_1_joint',
         'left_forearm_joint', 'right_forearm_joint', 'left_hand_joint', 'right_hand_joint']
frames = []
for i in range(n):
    root = (rx[i], ry[i])
    u = (math.cos(theta[i]), math.sin(theta[i]))       # along the upper body, toward the hands
    p = (u[1], -u[0])                                  # across the body (x axis when standing)
    s = radius[i] / R_STAND                            # foreshortening along the body
    J = {}
    for name in UPPER:
        ox, oy = template[name]
        J[name] = add(root, add(mul(p, ox), mul(u, oy * s)))
    for side, outward in (('left', 1), ('right', -1)):
        hip = add(root, template[f'{side}_upLeg_joint'])
        knee_t, ankle_t = template[f'{side}_leg_joint'], template[f'{side}_foot_joint']
        l1 = length(sub(knee_t, template[f'{side}_upLeg_joint']))
        l2 = length(sub(ankle_t, knee_t))
        ankle = ankle_abs[side]
        # Which way the knee points in the image: the side it sits on in the standing template.
        side_sign = 1 if knee_t[0] - (template[f'{side}_upLeg_joint'][0] + ankle_t[0]) / 2 >= 0 else -1
        J[f'{side}_upLeg_joint'] = hip
        # Mostly straight legs: knee on the hip→ankle line, with a hint of the solved bend.
        straight = add(hip, mul(sub(ankle, hip), l1 / (l1 + l2)))
        bent = solve_knee(hip, ankle, l1, l2, side_sign)
        J[f'{side}_leg_joint'] = add(straight, mul(sub(bent, straight), 0.3))
        J[f'{side}_foot_joint'] = ankle
    J['root'] = root
    frames.append(J)

# Normalize into a square box shared by all frames (y up, 0..1), with margin.
xs = [v[0] for J in frames for v in J.values()]
ys = [v[1] for J in frames for v in J.values()]
cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
span = max(max(xs) - min(xs), max(ys) - min(ys)) * 1.12
def norm(v): return [round((v[0] - cx) / span + 0.5, 4), round((v[1] - cy) / span + 0.5, 4)]

short = {'root': 'root', 'neck_1_joint': 'neck', 'head_joint': 'head',
         'left_shoulder_1_joint': 'lShoulder', 'right_shoulder_1_joint': 'rShoulder',
         'left_forearm_joint': 'lElbow', 'right_forearm_joint': 'rElbow',
         'left_hand_joint': 'lHand', 'right_hand_joint': 'rHand',
         'left_upLeg_joint': 'lHip', 'right_upLeg_joint': 'rHip',
         'left_leg_joint': 'lKnee', 'right_leg_joint': 'rKnee',
         'left_foot_joint': 'lAnkle', 'right_foot_joint': 'rAnkle'}
# Resample to an exact FPS timeline for playback.
out_frames = []
duration = ts[-1] - ts[0]
count = int(round(duration * FPS))
for k in range(count):
    t = ts[0] + k / FPS
    j = max(i for i in range(n) if ts[i] <= t) if t >= ts[0] else 0
    j2 = min(j + 1, n - 1)
    w = 0 if j2 == j else (t - ts[j]) / (ts[j2] - ts[j])
    J = {short[name]: norm(add(mul(frames[j][name], 1 - w), mul(frames[j2][name], w))) for name in frames[j]}
    out_frames.append(J)

json.dump({'name': 'Around the World', 'fps': FPS, 'frames': out_frames}, open(OUT, 'w'), separators=(',', ':'))
print('wrote', len(out_frames), 'frames', f'({len(out_frames) / FPS:.1f}s)')
