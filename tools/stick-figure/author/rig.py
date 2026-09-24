"""Author stick-figure exercise animations from key poses.

A small 3D skeleton with realistic proportions (metres, standing height ~1.75 m). Each exercise is a set of key
poses (joint angles in plain PT terms: flex, abd, rot, ...) plus a timeline; frames are produced by eased
blending of the angles, forward kinematics, optional pins (keep joints planted) and 2-bone IK (hands/feet to
targets), then an orthographic camera projection. Output matches the format `ExerciseFigureView` renders.

Axes: x = the figure's left, y = up, z = the direction the figure faces when standing.
"""
import json
import math

# ---------------------------------------------------------------- vector / matrix helpers

def add(a, b): return (a[0] + b[0], a[1] + b[1], a[2] + b[2])
def sub(a, b): return (a[0] - b[0], a[1] - b[1], a[2] - b[2])
def mul(a, s): return (a[0] * s, a[1] * s, a[2] * s)
def dot(a, b): return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
def norm(a): return math.sqrt(dot(a, a))
def unit(a):
    n = norm(a)
    return mul(a, 1 / n) if n > 1e-9 else (0, 0, 0)
def lerp(a, b, w): return add(a, mul(sub(b, a), w))

def mm(A, B): return [[sum(A[i][k] * B[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
def mv(A, v): return tuple(sum(A[i][k] * v[k] for k in range(3)) for i in range(3))
I3 = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]

def Rx(d):
    c, s = math.cos(math.radians(d)), math.sin(math.radians(d))
    return [[1, 0, 0], [0, c, -s], [0, s, c]]
def Ry(d):
    c, s = math.cos(math.radians(d)), math.sin(math.radians(d))
    return [[c, 0, s], [0, 1, 0], [-s, 0, c]]
def Rz(d):
    c, s = math.cos(math.radians(d)), math.sin(math.radians(d))
    return [[c, -s, 0], [s, c, 0], [0, 0, 1]]

# ---------------------------------------------------------------- skeleton

# (bone end joint, parent joint, rest offset from parent, rotation that drives this bone)
BONES = [
    ('chest', 'root', (0, 0.46, 0), 'spine'),
    ('neck', 'chest', (0, 0.09, 0), None),
    ('head', 'neck', (0, 0.13, 0), 'neck'),
    ('nose', 'head', (0, 0, 0.12), None),
    ('lShoulder', 'chest', (0.17, -0.02, 0), 'lScap'),
    ('rShoulder', 'chest', (-0.17, -0.02, 0), 'rScap'),
    ('lElbow', 'lShoulder', (0, -0.29, 0), 'lShoulder'),
    ('rElbow', 'rShoulder', (0, -0.29, 0), 'rShoulder'),
    ('lHand', 'lElbow', (0, -0.29, 0), 'lElbow'),
    ('rHand', 'rElbow', (0, -0.29, 0), 'rElbow'),
    ('lHip', 'root', (0.10, 0, 0), None),
    ('rHip', 'root', (-0.10, 0, 0), None),
    ('lKnee', 'lHip', (0, -0.44, 0), 'lHip'),
    ('rKnee', 'rHip', (0, -0.44, 0), 'rHip'),
    ('lAnkle', 'lKnee', (0, -0.43, 0), 'lKnee'),
    ('rAnkle', 'rKnee', (0, -0.43, 0), 'rKnee'),
    ('lBall', 'lAnkle', (0, -0.06, 0.13), 'lAnkle'),
    ('rBall', 'rAnkle', (0, -0.06, 0.13), 'rAnkle'),
    ('lToe', 'lBall', (0, 0, 0.06), 'lToe'),
    ('rToe', 'rBall', (0, 0, 0.06), 'rToe'),
    ('lHeel', 'lAnkle', (0, -0.06, -0.05), None),
    ('rHeel', 'rAnkle', (0, -0.06, -0.05), None),
]
LENGTH = {b: norm(v) for b, _, v, _ in BONES}
PARENT = {b: p for b, p, _, _ in BONES}
EXPORT = ['root', 'chest', 'neck', 'head', 'nose', 'lShoulder', 'rShoulder', 'lElbow', 'rElbow', 'lHand', 'rHand',
          'lHip', 'rHip', 'lKnee', 'rKnee', 'lAnkle', 'rAnkle', 'lBall', 'rBall', 'lToe', 'rToe', 'lHeel', 'rHeel']


def local_rotation(joint, c):
    """Joint angles in PT terms → local rotation matrix. Positive values:
    spine/neck: flex = bend forward, lat = bend toward own left, rot = turn to own left.
    lScap/rScap: elev = shrug up, retract = pull shoulder back.
    shoulder/hip: flex = limb forward/up, abd = away from midline, rot = external rotation,
                  hadd = horizontal adduction (across the body, after flexing).
    elbow: flex. knee: flex (heel toward buttock). ankle: dorsi = toes up, evert = sole/toes outward.
    toe: flex = curl down."""
    g = lambda k: c.get(k, 0.0)
    if joint in ('spine', 'neck'):
        return mm(mm(Rx(g('flex')), Rz(-g('lat'))), Ry(g('rot')))
    side = 1 if joint[0] == 'l' else -1
    kind = joint[1:]
    if kind == 'Scap':
        return mm(Rz(side * g('elev')), Ry(side * g('retract')))
    if kind in ('Shoulder', 'Hip'):
        return mm(mm(mm(Ry(-side * g('hadd')), Rx(-g('flex'))), Rz(side * g('abd'))), Ry(side * g('rot')))
    if kind == 'Elbow':
        return Rx(-g('flex'))
    if kind == 'Knee':
        return Rx(g('flex'))
    if kind == 'Ankle':
        return mm(Rx(-g('dorsi')), Ry(side * g('evert')))
    if kind == 'Toe':
        return Rx(g('flex'))
    raise ValueError(joint)


def root_transform(c):
    g = lambda k: c.get(k, 0.0)
    R = mm(mm(Ry(g('yaw')), Rx(g('pitch'))), Rz(g('roll')))
    return R, (g('x'), g('y'), g('z'))


def forward_kinematics(pose):
    R0, t = root_transform(pose.get('root', {}))
    acc, pos = {'root': R0}, {'root': t}
    for bone, parent, rest, joint in BONES:
        R = acc[parent]
        if joint:
            R = mm(R, local_rotation(joint, pose.get(joint, {})))
        acc[bone] = R
        pos[bone] = add(pos[parent], mv(R, rest))
    return pos, acc

# ---------------------------------------------------------------- pose helpers

LATERAL = {'spine': ('lat', 'rot'), 'neck': ('lat', 'rot'), 'root': ('yaw', 'roll', 'x')}

def mirror(pose):
    """Same pose on the other side of the body."""
    out = {}
    for key, comps in pose.items():
        if key[0] in 'lr' and key[1:2].isupper():
            out[('r' if key[0] == 'l' else 'l') + key[1:]] = dict(comps)
        elif key in LATERAL:
            out[key] = {k: (-v if k in LATERAL[key] else v) for k, v in comps.items()}
        elif key == 'ik':
            out[key] = {('r' if j[0] == 'l' else 'l') + j[1:]: mirror_target(t) for j, t in comps.items()}
        else:
            out[key] = comps
    return out

def mirror_target(t):
    kind = t[0]
    if kind == 'world':
        return ('world', (-t[1][0], t[1][1], t[1][2]))
    if kind in ('joint', 'base'):
        name = ('r' if t[1][0] == 'l' else 'l') + t[1][1:] if t[1][0] in 'lr' and t[1][1:2].isupper() else t[1]
        off = t[2] if len(t) > 2 else (0, 0, 0)
        return (kind, name, (-off[0], off[1], off[2]))
    return t

def both(**joints):
    """{'Hip': {...}} → {'lHip': {...}, 'rHip': {...}}"""
    out = {}
    for name, comps in joints.items():
        out['l' + name] = dict(comps)
        out['r' + name] = dict(comps)
    return out

def merge(*poses):
    out = {}
    for p in poses:
        for k, v in p.items():
            out[k] = {**out.get(k, {}), **v} if isinstance(v, dict) and k != 'ik' else (
                {**out.get(k, {}), **v} if k == 'ik' else v)
    return out

def blend(a, b, w):
    out = {}
    for key in set(a) | set(b):
        if key in ('ik', 'glow'):
            continue
        ca, cb = a.get(key, {}), b.get(key, {})
        out[key] = {k: ca.get(k, 0.0) + (cb.get(k, 0.0) - ca.get(k, 0.0)) * w for k in set(ca) | set(cb)}
    return out

# ---------------------------------------------------------------- IK

def two_bone(a, mid_hint, target, l1, l2, fallback=(0, 0, 1)):
    d_vec = sub(target, a)
    d = min(max(norm(d_vec), abs(l1 - l2) + 1e-4), l1 + l2 - 1e-4)
    direction = unit(d_vec)
    along = (l1 * l1 - l2 * l2 + d * d) / (2 * d)
    h = math.sqrt(max(l1 * l1 - along * along, 0))
    pole = sub(mid_hint, a)
    pole = sub(pole, mul(direction, dot(pole, direction)))
    if norm(pole) < 0.02:   # limb started straight: bend knees forward / elbows back by default
        pole = sub(fallback, mul(direction, dot(fallback, direction)))
    pole = unit(pole)
    return add(add(a, mul(direction, along)), mul(pole, h)), add(a, mul(direction, d))

CHAINS = {  # end joint → (upper, middle)
    'lAnkle': ('lHip', 'lKnee'), 'rAnkle': ('rHip', 'rKnee'),
    'lHand': ('lShoulder', 'lElbow'), 'rHand': ('rShoulder', 'rElbow'),
}

def resolve_target(t, pos, base):
    kind = t[0]
    if kind == 'world':
        return t[1]
    if kind == 'joint':
        return add(pos[t[1]], t[2] if len(t) > 2 else (0, 0, 0))
    if kind == 'base':
        return add(base[t[1]], t[2] if len(t) > 2 else (0, 0, 0))
    if kind == 'between':   # ('between', jointA, jointB, fraction[, offset])
        return add(lerp(pos[t[1]], pos[t[2]], t[3]), t[4] if len(t) > 4 else (0, 0, 0))
    raise ValueError(t)

# ---------------------------------------------------------------- exercise → frames

def ease(w):
    return w * w * w * (w * (w * 6 - 15) + 10)


class Exercise:
    def __init__(self, name, poses, timeline, camera=(90, 0), contacts=(), pins=(), props=(), glows=(),
                 face=False, trails=(), fps=30, flat_feet=(), focus=(), linear=False, far=None):
        self.name, self.poses, self.timeline = name, poses, timeline
        self.camera, self.contacts, self.pins = camera, contacts, pins
        self.props, self.glows, self.face, self.trails, self.fps = props, glows, face, trails, fps
        self.flat_feet = flat_feet   # 'l'/'r': keep that foot flat on the floor (heel down, toes forward)
        self.focus = list(focus)     # joints to frame as a close-up
        self.linear = linear         # constant-speed blending (for continuous paths like circles and letters)
        self.far = far               # force which side is drawn as the far side ('l' or 'r')
        self.ground = 0.0

    def _solve(self, pose, base):
        pos, acc = forward_kinematics(pose)
        forward = mv(acc['root'], (0, 0, 1))
        pos = {k: add(v, (0, self.ground, 0)) for k, v in pos.items()}
        if self.pins and base is not None:
            now = [pos[j] for j in self.pins]
            then = [base[j] for j in self.pins]
            shift = mul(sub(tuple(map(sum, zip(*then))), tuple(map(sum, zip(*now)))), 1 / len(self.pins))
            pos = {k: add(v, shift) for k, v in pos.items()}
        for end, target in (pose.get('ik') or {}).items():
            if base is None and target[0] == 'base':
                continue
            upper, middle = CHAINS[end]
            goal = resolve_target(target, pos, base if base is not None else pos)
            foot_joints = [end[0] + j for j in ('Ball', 'Toe', 'Heel')] if 'Ankle' in end else []
            foot = [sub(pos[j], pos[end]) for j in foot_joints]
            fallback = forward if 'Ankle' in end else mul(forward, -1)
            pos[middle], pos[end] = two_bone(pos[upper], pos[middle], goal, LENGTH[middle], LENGTH[end], fallback)
            for j, offset in zip(foot_joints, foot):
                pos[j] = add(pos[end], offset)
        for side in self.flat_feet:
            ankle = pos[side + 'Ankle']
            d = sub(pos[side + 'Ball'], ankle)
            fwd = unit((d[0], 0, d[2]))
            ball = add(ankle, add(mul(fwd, 0.13), (0, -0.06, 0)))
            pos[side + 'Ball'], pos[side + 'Toe'] = ball, add(ball, mul(fwd, 0.06))
            pos[side + 'Heel'] = add(ankle, add(mul(fwd, -0.05), (0, -0.06, 0)))
        return pos

    def build(self):
        first = self.poses[self.timeline[0][0].split('>')[0]]
        # Ground: lift the first pose so its contact points (joint, radius) rest on the floor (y = 0).
        self.ground = 0.0
        if self.contacts:
            solved = self._solve(first, None)
            self.ground = -min(solved[j][1] - r for j, r in self.contacts)
        base = self._solve(first, None)
        self.base = base

        frames, glow_frames = [], []
        for step, seconds in self.timeline:
            count = max(1, int(round(seconds * self.fps)))
            for k in range(count):
                if '>' in step:
                    a, b = step.split('>')
                    w = k / count if self.linear else ease(k / count)
                    pa, pb = self.poses[a], self.poses[b]
                    pose = blend(pa, pb, w)
                    ik = {}
                    for end in set(pa.get('ik', {})) | set(pb.get('ik', {})):
                        ta, tb = pa.get('ik', {}).get(end), pb.get('ik', {}).get(end)
                        if ta and tb:
                            ik[end] = ('lerp', ta, tb, w)
                        else:
                            ik[end] = ta or tb
                    pose['ik'] = ik
                    glow = {g: pa.get('glow', {}).get(g, 0) + (pb.get('glow', {}).get(g, 0) - pa.get('glow', {}).get(g, 0)) * w
                            for g in set(pa.get('glow', {})) | set(pb.get('glow', {}))}
                else:
                    pose = self.poses[step]
                    glow = dict(pose.get('glow', {}))
                    # Gentle pulse while holding a contraction.
                    for g in glow:
                        glow[g] *= 0.75 + 0.25 * math.sin(math.pi * 2 * k / max(count, 1) * max(1, round(seconds / 1.2)))
                frames.append(self._solve_frame(pose, base))
                glow_frames.append(glow)
        self.frames3d, self.glow_frames = frames, glow_frames
        return self

    def _solve_frame(self, pose, base):
        ik = pose.get('ik') or {}
        resolved = {}
        # Resolve interpolated targets after FK/pins so joint-relative targets use this frame's positions.
        plain = {k: v for k, v in pose.items() if k != 'ik'}
        pos = self._solve(plain, base)
        for end, t in ik.items():
            if t[0] == 'lerp':
                a = resolve_target(t[1], pos, base)
                b = resolve_target(t[2], pos, base)
                resolved[end] = ('world', lerp(a, b, t[3]))
            else:
                resolved[end] = t
        plain['ik'] = resolved
        return self._solve(plain, base)

    # ------------------------------------------------------------ projection & export

    def project(self, p):
        yaw, pitch = self.camera
        cy, sy = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
        cp, sp = math.cos(math.radians(pitch)), math.sin(math.radians(pitch))
        x = p[0] * cy - p[2] * sy
        depth = p[0] * sy + p[2] * cy
        y = p[1] * cp - depth * sp
        return (x, y), depth

    def export(self, path, span=2.4):
        frames2d = [{j: self.project(f[j])[0] for j in EXPORT} for f in self.frames3d]
        # Far side = the side whose limbs sit farther from the camera on average.
        depth = {s: sum(self.project(f[s + j])[1] for f in self.frames3d for j in ('Hip', 'Knee', 'Ankle', 'Shoulder', 'Elbow', 'Hand'))
                 for s in 'lr'}
        far = self.far or ('l' if depth['l'] < depth['r'] - 1e-6 else 'r')

        props = [self._prop(p) for p in self.props]
        pts = [v for f in frames2d for v in f.values()] + [q for p in props for q in p.pop('_extent')]
        xs, ys = [p[0] for p in pts], [p[1] for p in pts]
        cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
        n = lambda p: [round((p[0] - cx) / span + 0.5, 3), round((p[1] - cy) / span + 0.5, 3)]
        nl = lambda v: round(v / span, 4)
        for p in props:
            for key in ('points', 'center', 'rect'):
                if key in p:
                    if key == 'points':
                        p[key] = [q if isinstance(q, str) else n(q) for q in p[key]]
                    elif key == 'center':
                        p[key] = p[key] if isinstance(p[key], str) else n(p[key])
                    else:
                        x, y, w, h = p[key]
                        p[key] = n((x, y)) + [nl(w), nl(h)]
            for key in ('width', 'radius'):
                if key in p:
                    p[key] = nl(p[key])

        glows = []
        for g in self.glows:
            glows.append({'joints': g['joints'], 'intensity': [round(gf.get(g['name'], 0.0), 3) for gf in self.glow_frames]})

        data = {'name': self.name, 'fps': self.fps, 'farSide': far,
                'frames': [{j: n(v) for j, v in f.items()} for f in frames2d]}
        if props: data['props'] = props
        if glows: data['glows'] = glows
        if self.face: data['face'] = True
        if self.focus: data['focus'] = self.focus
        if self.trails: data['trails'] = [dict(t) for t in self.trails]
        json.dump(data, open(path, 'w'), separators=(',', ':'))
        return data

    def _prop(self, spec):
        """World-space prop → 2D (points may reference joints by name, or 'base:<joint>' for its base position)."""
        spec = dict(spec)
        extent = []
        def point(p):
            if isinstance(p, tuple) and p and p[0] == 'base':   # ('base', joint, offset)
                q = self.project(add(self.base[p[1]], p[2] if len(p) > 2 else (0, 0, 0)))[0]
                extent.append(q)
                return q
            if isinstance(p, str) and p.startswith('base:'):
                name, _, off = p[5:].partition('+')
                q = self.project(self.base[name])[0]
                extent.append(q)
                return q
            if isinstance(p, str):
                return p
            q = self.project(p)[0]
            extent.append(q)
            return q
        if 'points' in spec:
            spec['points'] = [point(p) for p in spec['points']]
        if 'center' in spec:
            spec['center'] = point(spec['center'])
        if 'box' in spec:   # axis-aligned 3D box → its projected 2D bounding rect
            (x0, y0, z0), (x1, y1, z1) = spec.pop('box')
            corners = [self.project((x, y, z))[0] for x in (x0, x1) for y in (y0, y1) for z in (z0, z1)]
            xs, ys = [c[0] for c in corners], [c[1] for c in corners]
            spec['rect'] = (min(xs), min(ys), max(xs) - min(xs), max(ys) - min(ys))
            extent += corners
        spec['_extent'] = extent
        return spec
