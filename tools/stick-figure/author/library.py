"""Key poses and timing for every exercise in the PTHelper library, written from each exercise's description
(see PTHelper/Services/SeedData.swift).

Conventions (see rig.py): side views face screen-left; the figure's left side is nearest the camera when standing,
its right side when lying on its back. Long holds (e.g. "hold 30 seconds") are shortened to a few seconds so the
loop stays watchable; the glow pulses during holds to show the muscle is working.
"""
import math
from rig import Exercise, both, merge
from alphabet import LETTERS

SIDE = (78, 6)  # Slight three-quarter view keeps both limbs distinguishable.
T_R, L_R, F_R = 0.145, 0.075, 0.06          # torso, limb and foot radii (m)
FEET = [('lHeel', F_R), ('rHeel', F_R), ('lBall', F_R), ('rBall', F_R)]
LEG_HINT = both(Hip={'flex': 12}, Knee={'flex': 24})     # gives IK legs a forward knee bend
ARMS_DOWN = both(Shoulder={'abd': 6})
SUPINE = {'root': {'yaw': 180, 'pitch': -90}}   # on the back, head screen-left; right side nearest
PRONE = {'root': {'pitch': 90}}                 # face down, head screen-left; left side nearest
SIDE_LYING = {'root': {'roll': 90}}             # on the right side, left side up, facing the camera
LYING = [('chest', T_R), ('root', T_R)]
KNEES_BENT = both(Hip={'flex': 50}, Knee={'flex': 100})
SEATED = merge({'root': {'y': 0.56}}, both(Hip={'flex': 90}, Knee={'flex': 90}), both(Shoulder={'abd': 6, 'flex': 12}, Elbow={'flex': 30}))
UPPER_BODY = ['head', 'neck', 'chest', 'lShoulder', 'rShoulder', 'lElbow', 'rElbow', 'lHand', 'rHand', 'root']
HANDS_ON_THIGHS = {'ik': {'lHand': ('between', 'lHip', 'lKnee', 0.65, (0, 0.09, 0)),
                          'rHand': ('between', 'rHip', 'rKnee', 0.65, (0, 0.09, 0))}}

def planted(*sides, lift=None):
    return {'ik': {s + 'Ankle': ('base', s + 'Ankle') for s in sides}}

def box(a, b, style='prop'):
    return {'type': 'rect', 'box': (a, b), 'style': style}

def line(points, width=0.02, style='band'):
    return {'type': 'line', 'points': list(points), 'width': width, 'style': style}

def chair(front=0.16, back=-0.30, half=0.24, seat=0.50, top=0.98):
    """Line-drawn chair under a seated figure whose root is at z = 0 — reads from any camera angle."""
    w = 0.03
    corners = [(half, seat, front), (-half, seat, front), (-half, seat, back), (half, seat, back), (half, seat, front)]
    parts = [line(corners, width=w, style='prop')]
    for x in (half, -half):
        parts.append(line([(x, 0, front), (x, seat, front)], width=w, style='prop'))
        parts.append(line([(x, 0, back), (x, top, back)], width=w, style='prop'))
    parts.append(line([(half, top, back), (-half, top, back)], width=w, style='prop'))
    return parts

def wall(z0, z1, height=1.95):
    return box((-0.5, 0.0, z0), (0.5, height, z1))

def cycle(steps):
    """[('a', 0.5), ('b', 1.0), ...] → holds and eased transitions: a (hold) → a>b → b (hold) …"""
    out = []
    for i, step in enumerate(steps):
        name, hold = step[0], step[1]
        if i:
            prev, move = steps[i - 1][0], steps[i][2] if len(steps[i]) > 2 else 1.0
            out.append((f'{prev}>{name}', move))
        if hold:
            out.append((name, hold))
    return out

def seq(*items):
    """('a', hold) or ('a', hold, move_in_seconds). The last pose should equal the first for a seamless loop."""
    return cycle(list(items))

# ------------------------------------------------------------------ knee

def quad_sets():
    rest = merge(SUPINE, {'rHip': {'flex': 5}, 'rKnee': {'flex': 10}}, both(Shoulder={'abd': 10}))
    press = merge(SUPINE, both(Shoulder={'abd': 10}), {'glow': {'quad': 1.0}})
    return Exercise('Quad Sets', {'rest': rest, 'press': press},
                    seq(('rest', 0.8), ('press', 5.0, 0.5), ('rest', 0.5, 0.7)),
                    camera=SIDE, contacts=LYING + [('lHeel', F_R)],
                    glows=[{'name': 'quad', 'joints': ['rHip', 'rKnee']}])

def straight_leg_raises():
    base = merge(SUPINE, {'lHip': {'flex': 45}, 'lKnee': {'flex': 90}}, both(Shoulder={'abd': 10}), planted('l'))
    # The ankle should reach the bent knee's height, not rise far above it.
    up = merge(base, {'rHip': {'flex': 22}, 'glow': {'quad': 1.0}})
    return Exercise('Straight Leg Raises', {'down': base, 'up': up},
                    seq(('down', 0.6), ('up', 0.5, 1.3), ('down', 0.4, 1.8)),
                    camera=SIDE, contacts=LYING + [('rHeel', F_R), ('lHeel', F_R)], flat_feet='l',
                    glows=[{'name': 'quad', 'joints': ['rHip', 'rKnee']}])

def short_arc_quads():
    bent = merge(SUPINE, {'rHip': {'flex': 20}, 'rKnee': {'flex': 38}}, both(Shoulder={'abd': 10}))
    straight = merge(bent, {'rKnee': {'flex': 0}, 'glow': {'quad': 1.0}})
    roll = {'type': 'circle', 'center': ('base', 'rKnee', (0, -0.18, 0)), 'radius': 0.11, 'style': 'towel'}
    return Exercise('Short Arc Quads', {'bent': bent, 'straight': straight},
                    seq(('bent', 0.6), ('straight', 2.0, 1.1), ('bent', 0.4, 1.4)),
                    camera=SIDE, contacts=LYING + [('rHeel', F_R), ('lHeel', F_R)], props=[roll],
                    glows=[{'name': 'quad', 'joints': ['rHip', 'rKnee']}])

def terminal_knee_extension():
    feet = {'lAnkle': ('world', (0.1, 0.12, 0.02)), 'rAnkle': ('world', (-0.1, 0.12, 0.02))}
    bent = merge(ARMS_DOWN, LEG_HINT, {'root': {'y': 0.96, 'z': 0.02}, 'ik': feet})
    straight = merge(bent, {'root': {'y': 0.9898}, 'lHip': {'flex': 0}, 'lKnee': {'flex': 0}, 'glow': {'quad': 1.0}})
    anchor = line([(0.1, 0.72, 0.85), 'lKnee'], width=0.022)
    post = box((0.0, 0.0, 0.85), (0.2, 0.9, 0.92))
    return Exercise('Terminal Knee Extension', {'bent': bent, 'straight': straight},
                    seq(('bent', 0.5), ('straight', 0.7, 1.0), ('bent', 0.3, 1.2)),
                    camera=SIDE, flat_feet='lr', props=[post, anchor],
                    glows=[{'name': 'quad', 'joints': ['lHip', 'lKnee']}])

def wall_sit():
    feet = {'lAnkle': ('world', (0.1, 0.12, 0.42)), 'rAnkle': ('world', (-0.1, 0.12, 0.42))}
    hands = {'lHand': ('joint', 'lKnee', (0, 0.09, -0.12)), 'rHand': ('joint', 'rKnee', (0, 0.09, -0.12))}
    top = merge({'root': {'y': 0.80}}, both(Hip={'flex': 35}, Knee={'flex': 50}), ARMS_DOWN, {'ik': {**feet, **hands}})
    bottom = merge({'root': {'y': 0.55}}, both(Hip={'flex': 90}, Knee={'flex': 90}), ARMS_DOWN,
                   {'ik': {**feet, **hands}, 'glow': {'quad': 1.0}})
    return Exercise('Wall Sit', {'top': top, 'bottom': bottom},
                    seq(('top', 0.6), ('bottom', 3.0, 1.6), ('top', 0.4, 1.6)),
                    camera=SIDE, props=[wall(-0.30, -0.16)], flat_feet='lr',
                    glows=[{'name': 'quad', 'joints': ['lHip', 'lKnee']}])

def step_ups():
    legs = merge(LEG_HINT, ARMS_DOWN)
    def pose(root, l, r):
        return merge(legs, {'root': {'y': root[0], 'z': root[1]}}, {'ik': {'lAnkle': ('world', l), 'rAnkle': ('world', r)}})
    floor_l, floor_r = (0.1, 0.12, 0.02), (-0.1, 0.12, 0.02)
    step_l, step_r = (0.1, 0.33, 0.52), (-0.1, 0.33, 0.52)
    poses = {
        'floor': pose((0.95, 0.0), floor_l, floor_r),
        'liftL': pose((0.95, 0.06), (0.1, 0.45, 0.34), floor_r),
        'leadUp': pose((0.97, 0.16), step_l, floor_r),
        'liftR': pose((1.13, 0.46), step_l, (-0.1, 0.46, 0.36)),
        'top': pose((1.16, 0.52), step_l, step_r),
        'liftDown': pose((1.14, 0.44), (0.1, 0.44, 0.24), step_r),
        'leadDown': pose((0.98, 0.26), floor_l, step_r),
        'trailDown': pose((0.95, 0.08), floor_l, (-0.1, 0.42, 0.28)),
    }
    step = box((-0.4, 0.0, 0.3), (0.4, 0.21, 0.8))
    return Exercise('Step Ups', poses,
                    seq(('floor', 0.4), ('liftL', 0, 0.45), ('leadUp', 0, 0.4), ('liftR', 0, 0.55), ('top', 0.5, 0.4),
                        ('liftDown', 0, 0.45), ('leadDown', 0, 0.4), ('trailDown', 0, 0.45), ('floor', 0.3, 0.4)),
                    camera=SIDE, props=[step], flat_feet='lr')

# ------------------------------------------------------------------ hip

def clamshells():
    base = merge(SIDE_LYING, both(Hip={'flex': 45}, Knee={'flex': 45}),
                 {'rShoulder': {'flex': 170}, 'rElbow': {'flex': 20}, 'lShoulder': {'flex': 10}, 'neck': {'lat': -15}})
    base['ik'] = {'lAnkle': ('joint', 'rAnkle', (0, 0.065, 0))}
    opened = merge(base, {'lHip': {'flex': 45, 'abd': 38}, 'glow': {'glute': 1.0}})
    opened['ik'] = dict(base['ik'])
    return Exercise('Clamshells', {'closed': base, 'open': opened},
                    seq(('closed', 0.6), ('open', 0.6, 1.2), ('closed', 0.3, 1.4)),
                    camera=(0, 20), contacts=[('rHip', L_R), ('rShoulder', L_R), ('rKnee', L_R)], far='r',
                    joined_feet=[('l', 'r')],
                    glows=[{'name': 'glute', 'joints': ['lHip']}])

def glute_bridges():
    down = merge(SUPINE, KNEES_BENT, both(Shoulder={'abd': 10}))
    up = merge(down, {'root': {'yaw': 180, 'pitch': -114.7}, 'neck': {'flex': 25}, 'glow': {'glutes': 1.0}})
    ik = {'lAnkle': ('base', 'lAnkle'), 'rAnkle': ('base', 'rAnkle'), 'lHand': ('base', 'lHand'), 'rHand': ('base', 'rHand')}
    down['ik'], up['ik'] = dict(ik), dict(ik)
    return Exercise('Glute Bridges', {'down': down, 'up': up},
                    seq(('down', 0.6), ('up', 1.2, 1.4), ('down', 0.4, 1.4)),
                    camera=SIDE, contacts=LYING, pins=['chest'], flat_feet='lr',
                    glows=[{'name': 'glutes', 'joints': ['root']}])

def side_lying_hip_abduction():
    base = merge(SIDE_LYING, {'rShoulder': {'flex': 170}, 'rElbow': {'flex': 20}, 'neck': {'lat': -15}})
    up = merge(base, {'lHip': {'abd': 45}, 'glow': {'glute': 1.0}})
    return Exercise('Side-Lying Hip Abduction', {'down': base, 'up': up},
                    seq(('down', 0.6), ('up', 0.6, 1.2), ('down', 0.3, 1.4)),
                    camera=(0, 15), contacts=[('rHip', L_R), ('rShoulder', L_R), ('rAnkle', L_R)], far='r',
                    glows=[{'name': 'glute', 'joints': ['lHip']}])

def donkey_kicks():
    quad = merge(PRONE, both(Hip={'flex': 90}, Knee={'flex': 90}, Shoulder={'flex': 90}))
    kick = merge(quad, {'lHip': {'flex': -12}, 'glow': {'glute': 1.0}})
    return Exercise('Donkey Kicks', {'quad': quad, 'kick': kick},
                    seq(('quad', 0.6), ('kick', 0.5, 1.0), ('quad', 0.3, 1.1)),
                    camera=SIDE, contacts=[('lHand', L_R), ('rHand', L_R), ('lKnee', L_R), ('rKnee', L_R)],
                    pins=['lHand', 'rHand', 'rKnee'],
                    glows=[{'name': 'glute', 'joints': ['lHip']}])

def hip_flexor_stretch():
    kneel = merge({'lHip': {'flex': 0}, 'lKnee': {'flex': 90}, 'lAnkle': {'dorsi': -65},
                   'rHip': {'flex': 90}, 'rKnee': {'flex': 90}}, ARMS_DOWN)
    ik = {'lAnkle': ('base', 'lAnkle'), 'rAnkle': ('base', 'rAnkle')}
    kneel['ik'] = dict(ik)
    push = merge(kneel, {'root': {'z': 0.13, 'y': -0.03}, 'lHip': {'flex': -18},
                         'lAnkle': {'dorsi': -47}, 'glow': {'flexor': 1.0}})
    push['ik'] = dict(ik)
    return Exercise('Hip Flexor Stretch', {'kneel': kneel, 'push': push},
                    seq(('kneel', 0.6), ('push', 2.5, 1.4), ('kneel', 0.4, 1.4)),
                    camera=SIDE, contacts=[('lKnee', L_R), ('rHeel', F_R), ('rBall', F_R)], flat_feet='r',
                    glows=[{'name': 'flexor', 'joints': ['lHip']}])

PIRI_CAMERA = (120, 30)
EVERT_CAMERA = (30, 30)

def piriformis_stretch():
    hands = {'lHand': ('between', 'lHip', 'lKnee', 0.8, (0, 0.06, 0)), 'rHand': ('between', 'lHip', 'lKnee', 0.8, (0, 0.06, 0))}
    cross = merge(SUPINE, {'lHip': {'flex': 60}, 'lKnee': {'flex': 105}},
                  {'rHip': {'flex': 70, 'abd': 35, 'rot': 45}, 'rKnee': {'flex': 95}},
                  {'ik': {'rAnkle': ('joint', 'lKnee', (0, 0.09, 0)), **hands}})
    pull = merge(cross, {'lHip': {'flex': 100}, 'rHip': {'flex': 105, 'abd': 35, 'rot': 45}, 'glow': {'glute': 1.0}})
    pull['ik'] = dict(cross['ik'])
    return Exercise('Piriformis Stretch', {'cross': cross, 'pull': pull},
                    seq(('cross', 0.6), ('pull', 2.5, 1.4), ('cross', 0.4, 1.4)),
                    camera=PIRI_CAMERA, contacts=LYING + [('lHeel', F_R)],
                    glows=[{'name': 'glute', 'joints': ['rHip']}])

def it_band_stretch():
    feet = {'lAnkle': ('world', (0.04, 0.12, 0.04)), 'rAnkle': ('world', (0.2, 0.12, -0.14))}
    upright = merge({'root': {'x': 0.1, 'y': 0.93}}, LEG_HINT, ARMS_DOWN, {'ik': dict(feet)})
    lean = merge(upright, {'root': {'x': -0.02, 'y': 0.92}, 'spine': {'lat': 24}, 'glow': {'itb': 1.0}})
    lean['ik'] = dict(feet)
    return Exercise('IT Band Stretch', {'upright': upright, 'lean': lean},
                    seq(('upright', 0.6), ('lean', 2.5, 1.4), ('upright', 0.4, 1.4)),
                    camera=(0, 0), flat_feet='lr',
                    glows=[{'name': 'itb', 'joints': ['rHip', 'rKnee']}])

def hip_circles():
    hands = {'lHand': ('joint', 'lHip', (0.11, 0.1, 0)), 'rHand': ('joint', 'rHip', (-0.11, 0.1, 0))}
    feet = {'lAnkle': ('world', (0.14, 0.12, 0.03)), 'rAnkle': ('world', (-0.14, 0.12, 0.03))}
    poses, steps = {}, []
    for i in range(9):
        a = 2 * math.pi * (i % 8) / 8
        poses[f'c{i}'] = merge(LEG_HINT, both(Shoulder={'abd': 45, 'flex': -12}, Elbow={'flex': 90}),
                               {'root': {'x': 0.09 * math.cos(a), 'z': 0.09 * math.sin(a), 'y': 0.955},
                                          'spine': {'lat': -9 * math.cos(a), 'flex': -7 * math.sin(a)}},
                               {'ik': {**hands, **feet}})
    poses['c8'] = poses['c0']
    steps = [('c0', 0)] + [(f'c{i}', 0, 0.36) for i in range(1, 9)] * 1
    loop = steps + [(f'c{i}', 0, 0.36) for i in range(1, 9)]
    reverse = [(f'c{i}', 0, 0.36) for i in range(7, -1, -1)] * 2
    return Exercise('Hip Circles', poses, seq(*(loop + reverse)),
                    camera=(30, 25), flat_feet='lr', linear=True,
                    cues={**{f'c{i}': 'Circle hips · feet stay still' for i in range(9)},
                          **{f'c{i}>c{i - 1}': 'Reverse the hip circle' for i in range(1, 9)}})

# ------------------------------------------------------------------ shoulder

def external_rotation_with_band():
    base = merge(ARMS_DOWN, {'lShoulder': {'abd': 4, 'rot': 0}, 'lElbow': {'flex': 90}})
    out = merge(base, {'lShoulder': {'abd': 4, 'rot': 65}, 'glow': {'cuff': 1.0}})
    band = line([(-0.4, 1.05, 0.42), 'lHand'], width=0.022)
    return Exercise('External Rotation with Band', {'in': base, 'out': out},
                    seq(('in', 0.5), ('out', 0.4, 1.1), ('in', 0.3, 1.4)),
                    camera=(25, 40), contacts=FEET, flat_feet='lr', props=[band],
                    glows=[{'name': 'cuff', 'joints': ['lShoulder']}])

def internal_rotation_with_band():
    base = merge(ARMS_DOWN, {'lShoulder': {'abd': 4, 'rot': 35}, 'lElbow': {'flex': 90}})
    across = merge(base, {'lShoulder': {'abd': 4, 'rot': -60}, 'glow': {'cuff': 1.0}})
    band = line([(0.62, 1.05, 0.32), 'lHand'], width=0.022)
    return Exercise('Internal Rotation with Band', {'out': base, 'in': across},
                    seq(('out', 0.5), ('in', 0.4, 1.1), ('out', 0.3, 1.4)),
                    camera=(25, 40), contacts=FEET, flat_feet='lr', props=[band],
                    glows=[{'name': 'cuff', 'joints': ['lShoulder']}])

def shoulder_rows():
    reach = merge(both(Shoulder={'flex': 75}, Elbow={'flex': 5}, Scap={'retract': -8}))
    pull = merge(both(Shoulder={'flex': -18}, Elbow={'flex': 105}, Scap={'retract': 18}), {'glow': {'back': 1.0}})
    bands = [line([(0.05, 1.18, 1.15), 'lHand'], width=0.02), line([(-0.05, 1.18, 1.15), 'rHand'], width=0.02)]
    post = box((-0.1, 0.0, 1.15), (0.1, 1.3, 1.22))
    return Exercise('Shoulder Rows', {'reach': reach, 'pull': pull},
                    seq(('reach', 0.5), ('pull', 0.8, 1.0), ('reach', 0.3, 1.3)),
                    camera=SIDE, contacts=FEET, flat_feet='lr', props=[post] + bands,
                    glows=[{'name': 'back', 'joints': ['chest']}])

def scapular_retraction():
    rest = merge(ARMS_DOWN)
    squeeze = merge(ARMS_DOWN, both(Scap={'retract': 22}), {'glow': {'back': 1.0}})
    return Exercise('Scapular Retraction', {'rest': rest, 'squeeze': squeeze},
                    seq(('rest', 0.6), ('squeeze', 5.0, 0.8), ('rest', 0.3, 0.8)),
                    camera=(145, 8), contacts=FEET, flat_feet='lr', focus=UPPER_BODY,
                    glows=[{'name': 'back', 'joints': ['chest']}])

def shoulder_cross_body_stretch():
    rest = merge(ARMS_DOWN)
    stretch = merge({'lShoulder': {'flex': 90, 'hadd': 70}, 'rShoulder': {'abd': 6}},
                    {'ik': {'rHand': ('between', 'lShoulder', 'lElbow', 0.95, (0, 0, 0.1))}}, {'glow': {'shoulder': 1.0}})
    rest['ik'] = {}
    return Exercise('Shoulder Cross-Body Stretch', {'rest': rest, 'stretch': stretch},
                    seq(('rest', 0.5), ('stretch', 2.5, 1.3), ('rest', 0.4, 1.2)),
                    camera=(0, 10), contacts=FEET, flat_feet='lr',
                    glows=[{'name': 'shoulder', 'joints': ['lShoulder']}])

def shoulder_pendulum():
    table = box((-0.75, 0.74, 0.35), (-0.05, 0.79, 1.05))
    table_leg = box((-0.72, 0.0, 0.95), (-0.66, 0.74, 1.01))
    feet = {'lAnkle': ('world', (0.12, 0.12, 0.0)), 'rAnkle': ('world', (-0.14, 0.12, 0.12))}
    lean = merge({'root': {'pitch': 22, 'y': 0.93}}, LEG_HINT, {'spine': {'flex': 48}, 'rShoulder': {'flex': 60}},
                 {'ik': {**feet, 'rHand': ('world', (-0.33, 0.81, 0.62))}})
    poses, steps = {}, []
    def hang(flex, abd, sway=0.0):
        p = merge(lean, {'lShoulder': {'flex': 70 + flex, 'abd': abd}, 'root': {'pitch': 22, 'y': 0.93, 'x': sway}})
        p['ik'] = dict(lean['ik'])
        return p
    poses['n'] = hang(0, 0)
    for i in range(8):
        a = 2 * math.pi * i / 8
        poses[f'c{i}'] = hang(11 * math.cos(a), 11 * math.sin(a), 0.02 * math.sin(a))
    poses['sL'], poses['sR'] = hang(0, 15, 0.025), hang(0, -12, -0.025)
    circle = [(f'c{i}', 0, 0.26) for i in list(range(1, 8)) + [0]]
    steps = [('n', 0.3), ('c0', 0, 0.35)] + circle + circle + [('n', 0, 0.35), ('sL', 0, 0.6), ('sR', 0, 0.9),
                                                           ('sL', 0, 0.9), ('n', 0.2, 0.6)]
    return Exercise('Shoulder Pendulum', poses, seq(*steps), camera=(50, 15), props=[table, table_leg],
                    flat_feet='lr', linear=True)

def shoulder_circles():
    poses = {}
    for i in range(8):
        a = math.pi / 2 - 2 * math.pi * i / 8      # forward roll: up → forward → down → back
        poses[f'p{i}'] = merge(both(Shoulder={'abd': 6}, Scap={'retract': -20 * math.cos(a), 'elev': 18 * math.sin(a)}),
                               {'ik': {'lHand': ('joint', 'lShoulder', (0.05, -0.575, 0)),
                                       'rHand': ('joint', 'rShoulder', (-0.05, -0.575, 0))}})
    forward = [(f'p{i % 8}', 0, 0.22) for i in range(1, 17)]
    backward = [(f'p{i % 8}', 0, 0.22) for i in range(15, -1, -1)]
    return Exercise('Shoulder Circles', poses, seq(('p0', 0.2), *forward, *backward),
                    camera=(60, 5), contacts=FEET, flat_feet='lr', linear=True, focus=UPPER_BODY,
                    cues={**{f'p{i}': 'Roll both shoulders forward' for i in range(8)},
                          **{f'p{i}>p{(i - 1) % 8}': 'Roll both shoulders backward' for i in range(8)}})

# ------------------------------------------------------------------ ankle / foot

def heel_raises():
    flat = merge(ARMS_DOWN)
    up = merge(ARMS_DOWN, both(Ankle={'dorsi': -32}, Toe={'flex': -32}), {'glow': {'calf': 1.0}})
    return Exercise('Heel Raises', {'flat': flat, 'up': up},
                    seq(('flat', 0.6), ('up', 0.8, 1.1), ('flat', 0.3, 1.4)),
                    camera=SIDE, contacts=FEET, pins=['lBall', 'rBall'],
                    glows=[{'name': 'calf', 'joints': ['lKnee', 'lAnkle']}])

LONG_SIT_HANDS = {'lHand': ('world', (0.3, 0.07, -0.26)), 'rHand': ('world', (-0.3, 0.07, -0.26))}

def ankle_eversion_with_band():
    sit = merge(both(Hip={'flex': 90}, Shoulder={'flex': -25, 'abd': 12}), {'ik': dict(LONG_SIT_HANDS)})
    evert = merge(sit, {'lAnkle': {'evert': 28}, 'glow': {'peroneal': 1.0}})
    evert['ik'] = dict(LONG_SIT_HANDS)
    band = line(['lBall', ('base', 'rBall')], width=0.02)
    return Exercise('Ankle Eversion with Band', {'sit': sit, 'evert': evert},
                    seq(('sit', 0.5), ('evert', 0.4, 0.9), ('sit', 0.3, 1.1)),
                    camera=EVERT_CAMERA, contacts=[('root', T_R), ('lHeel', F_R), ('rHeel', F_R)], props=[band],
                    focus=['lKnee', 'lAnkle', 'lBall', 'lToe', 'lHeel', 'rKnee', 'rAnkle', 'rBall'],
                    glows=[{'name': 'peroneal', 'joints': ['lKnee', 'lAnkle']}])

def towel_scrunches():
    sit = merge(SEATED, HANDS_ON_THIGHS)
    curl = merge(sit, {'lAnkle': {'dorsi': 6}, 'lToe': {'flex': 55}, 'glow': {'foot': 1.0}})
    curl['ik'] = dict(HANDS_ON_THIGHS['ik'])
    towel = line([('base', 'lHeel', (0, -0.035, -0.06)), 'lToe'], width=0.03, style='towel')
    bunch = {'type': 'circle', 'center': 'lToe', 'radius': 0.04, 'style': 'towel'}
    return Exercise('Towel Scrunches', {'flat': sit, 'curl': curl},
                    seq(('flat', 0.4), ('curl', 0.4, 0.6), ('flat', 0.3, 0.6), ('curl', 0.4, 0.6), ('flat', 0.3, 0.6)),
                    camera=SIDE, props=chair() + [towel, bunch], flat_feet='r',
                    glows=[{'name': 'foot', 'joints': ['lBall']}],
                    focus=['lHip', 'lKnee', 'lAnkle', 'lBall', 'lToe', 'lHeel'])

def ankle_alphabet():
    base = merge(SEATED, {'lHip': {'flex': 90}, 'lKnee': {'flex': 0}}, HANDS_ON_THIGHS)
    poses, steps, cues = {}, [], {}
    for letter, points in LETTERS.items():
        for i, (u, v) in enumerate(points):
            key = f'{letter}{i}'
            # Only the ankle changes. The suspended thigh/shin and the other foot stay still.
            poses[key] = merge(base, {'lAnkle': {'evert': u * 24, 'dorsi': v * 22}})
            cues[key] = f'Trace {letter} with your toe'
            move = 0.55 if i == 0 else max(0.15, math.dist(points[i - 1], (u, v)) * 0.4)
            steps.append((key, 0.35 if i == 0 else 0, move))
    steps.append(('A0', 0, 0.65))
    return Exercise('Ankle Alphabet', poses, seq(*steps), camera=(40, 12), props=chair(), flat_feet='r',
                    linear=True, trails=[{'joint': 'lToe', 'frames': 150, 'resetOnCue': True}], cues=cues,
                    focus=['lKnee', 'lAnkle', 'lBall', 'lToe', 'lHeel'])

# ------------------------------------------------------------------ core

def dead_bug():
    start = merge(SUPINE, both(Shoulder={'flex': 90}, Hip={'flex': 90}, Knee={'flex': 90}))
    a = merge(start, {'rShoulder': {'flex': 172}, 'lHip': {'flex': 22}, 'lKnee': {'flex': 0}, 'glow': {'core': 0.7}})
    b = merge(start, {'lShoulder': {'flex': 172}, 'rHip': {'flex': 22}, 'rKnee': {'flex': 0}, 'glow': {'core': 0.7}})
    return Exercise('Dead Bug', {'start': start, 'a': a, 'b': b},
                    seq(('start', 0.5), ('a', 0.4, 1.3), ('start', 0.4, 1.2), ('b', 0.4, 1.3), ('start', 0.1, 1.2)),
                    camera=(78, 12), contacts=LYING,
                    glows=[{'name': 'core', 'joints': ['root', 'chest']}])

def bird_dog():
    rest = merge(PRONE, both(Hip={'flex': 90}, Knee={'flex': 90}, Shoulder={'flex': 90}))
    a = merge(rest, {'rShoulder': {'flex': 180}, 'lHip': {'flex': 0}, 'lKnee': {'flex': 0}})
    b = merge(rest, {'lShoulder': {'flex': 180}, 'rHip': {'flex': 0}, 'rKnee': {'flex': 0}})
    return Exercise('Bird Dog', {'rest': rest, 'a': a, 'b': b},
                    seq(('rest', 0.8), ('a', 2.0, 1.5), ('rest', 0.6, 1.2),
                        ('b', 2.0, 1.5), ('rest', 0.4, 1.2)),
                    camera=(78, 8), far='r',
                    contacts=[('lHand', L_R), ('rHand', L_R), ('lKnee', L_R), ('rKnee', L_R)])

def pelvic_tilts():
    rest = merge(SUPINE, KNEES_BENT, both(Shoulder={'abd': 15}), planted('l', 'r'), {'spine': {'arch': 0.045}})
    tilt = merge(rest, {'root': {'yaw': 180, 'pitch': -104}, 'spine': {'flex': 14, 'arch': 0}, 'glow': {'abs': 1.0}})
    tilt['ik'] = dict(rest['ik'])
    return Exercise('Pelvic Tilts', {'rest': rest, 'tilt': tilt},
                    seq(('rest', 0.6), ('tilt', 1.0, 0.8), ('rest', 0.4, 0.8)),
                    camera=SIDE, contacts=LYING, pins=['chest'], flat_feet='lr',
                    glows=[{'name': 'abs', 'joints': ['root', 'chest']}])

def plank():
    knees = merge({'root': {'pitch': 71.1}}, both(Shoulder={'flex': 71.1}, Elbow={'flex': 90}, Knee={'flex': 18.9},
                                               Ankle={'dorsi': -60}, Toe={'flex': -150}))
    full = merge({'root': {'pitch': 83}}, both(Shoulder={'flex': 83}, Elbow={'flex': 90},
                                               Ankle={'dorsi': 0}, Toe={'flex': -83}),
                 {'glow': {'core': 1.0}})
    return Exercise('Plank', {'knees': knees, 'full': full},
                    seq(('knees', 0.6), ('full', 3.0, 1.0), ('knees', 0.4, 1.0)),
                    camera=SIDE, contacts=[('lElbow', 0.047), ('rElbow', 0.047), ('lKnee', 0.052), ('rKnee', 0.052)],
                    pins=['lElbow', 'rElbow'],
                    glows=[{'name': 'core', 'joints': ['root', 'chest']}])

def supine_marching():
    rest = merge(SUPINE, KNEES_BENT, both(Shoulder={'abd': 10}), planted('l', 'r'))
    def lift(side):
        p = merge(rest, {side + 'Hip': {'flex': 62}})
        p['ik'] = {**rest['ik'], side + 'Ankle': ('base', side + 'Ankle', (0, 0.11, 0))}
        return p
    return Exercise('Supine Marching', {'rest': rest, 'r': lift('r'), 'l': lift('l')},
                    seq(('rest', 0.3), ('r', 0.3, 0.6), ('rest', 0.2, 0.6), ('l', 0.3, 0.6), ('rest', 0.0, 0.6)),
                    camera=SIDE, contacts=LYING, flat_feet='lr')

# ------------------------------------------------------------------ stretches

def hamstring_stretch():
    hands = {'lHand': ('between', 'chest', 'rBall', 0.34), 'rHand': ('between', 'chest', 'rBall', 0.34)}
    flat = merge(SUPINE, {'ik': dict(hands)})
    up = merge(SUPINE, {'rHip': {'flex': 75}, 'glow': {'ham': 1.0}}, {'ik': dict(hands)})
    straps = [line(['lHand', 'rBall'], width=0.02, style='strap'), line(['rHand', 'rBall'], width=0.02, style='strap')]
    return Exercise('Hamstring Stretch', {'flat': flat, 'up': up},
                    seq(('flat', 0.5), ('up', 2.5, 1.5), ('flat', 0.4, 1.4)),
                    camera=SIDE, contacts=LYING + [('lHeel', F_R)], props=straps,
                    glows=[{'name': 'ham', 'joints': ['rHip', 'rKnee']}])

def quad_stretch():
    wall_hand = ('world', (-0.2, 1.25, 0.52))
    stand = merge(ARMS_DOWN, {'ik': {'rHand': wall_hand}})
    stretch = merge({'lHip': {'flex': -8}, 'lKnee': {'flex': 150}, 'rShoulder': {'flex': 70}},
                    {'ik': {'rHand': wall_hand, 'lHand': ('joint', 'lAnkle')}}, {'glow': {'quad': 1.0}})
    return Exercise('Quad Stretch', {'stand': stand, 'stretch': stretch},
                    seq(('stand', 0.5), ('stretch', 2.5, 1.4), ('stand', 0.4, 1.3)),
                    camera=SIDE, contacts=FEET, pins=['rBall'], flat_feet='r', props=[wall(0.56, 0.64)],
                    glows=[{'name': 'quad', 'joints': ['lHip', 'lKnee']}])

def calf_stretch():
    feet = {'lAnkle': ('world', (0.1, 0.12, -0.36)), 'rAnkle': ('world', (-0.1, 0.12, 0.34))}
    hands = {'lHand': ('world', (0.2, 1.3, 0.84)), 'rHand': ('world', (-0.2, 1.3, 0.84))}
    # Keep the rear hip-to-ankle distance within a straight leg's reach, so the heel stays down.
    upright = merge({'root': {'z': 0.0, 'y': 0.12 + math.sqrt(0.8698**2 - 0.36**2), 'pitch': 8}},
                    LEG_HINT, {'ik': {**feet, **hands}})
    lean = merge({'root': {'z': 0.2, 'y': 0.12 + math.sqrt(0.8698**2 - 0.56**2), 'pitch': 18}},
                 LEG_HINT, {'ik': {**feet, **hands}}, {'glow': {'calf': 1.0}})
    return Exercise('Calf Stretch (Gastrocnemius)', {'upright': upright, 'lean': lean},
                    seq(('upright', 0.6), ('lean', 2.5, 1.4), ('upright', 0.4, 1.4)),
                    camera=SIDE, props=[wall(0.86, 0.94)], flat_feet='lr',
                    glows=[{'name': 'calf', 'joints': ['lKnee', 'lAnkle']}])

def thoracic_rotation():
    crossed = {'lHand': ('joint', 'rShoulder', (0, -0.04, 0.1)), 'rHand': ('joint', 'lShoulder', (0, -0.04, 0.1))}
    base = merge(SEATED, both(Shoulder={'flex': 60}), {'ik': dict(crossed)})
    left = merge(base, {'spine': {'rot': 40}, 'neck': {'rot': 10}})
    right = merge(base, {'spine': {'rot': -40}, 'neck': {'rot': -10}})
    left['ik'], right['ik'] = dict(crossed), dict(crossed)
    return Exercise('Thoracic Rotation', {'center': base, 'left': left, 'right': right},
                    seq(('center', 0.4), ('left', 1.0, 1.2), ('center', 0.2, 1.0), ('right', 1.0, 1.2), ('center', 0.2, 1.0)),
                    camera=(20, 30), props=chair(), flat_feet='lr', face=True)

def neck_stretch():
    tall = merge(ARMS_DOWN)
    left = merge(ARMS_DOWN, {'neck': {'lat': 42}})
    right = merge(ARMS_DOWN, {'neck': {'lat': -42}})
    return Exercise('Neck Stretch', {'tall': tall, 'left': left, 'right': right},
                    seq(('tall', 0.5), ('left', 2.2, 1.2), ('tall', 0.3, 1.0), ('right', 2.2, 1.2), ('tall', 0.0, 1.0)),
                    camera=(0, 0), contacts=FEET, flat_feet='lr', focus=UPPER_BODY)

def cervical_range_of_motion():
    tall = merge(SEATED, HANDS_ON_THIGHS)
    def look(**neck):
        p = merge(tall, {'neck': neck})
        p['ik'] = dict(HANDS_ON_THIGHS['ik'])
        return p
    poses = {'n': tall, 'up': look(flex=-35), 'down': look(flex=40), 'tl': look(rot=65), 'tr': look(rot=-65),
             'sl': look(lat=35), 'sr': look(lat=-35)}
    order = []
    for p in ('up', 'down', 'tl', 'tr', 'sl', 'sr'):
        order += [(p, 0.5, 0.9), ('n', 0.2, 0.9)]
    return Exercise('Cervical Range of Motion', poses, seq(('n', 0.3), *order),
                    camera=(28, 5), props=chair(), flat_feet='lr', face=True, focus=UPPER_BODY)

# ------------------------------------------------------------------ balance

def single_leg_stance():
    stand = merge(ARMS_DOWN)
    lift = merge(both(Shoulder={'abd': 10}), {'lHip': {'flex': 12}, 'lKnee': {'flex': 55}})
    sway_a = merge(lift, {'rAnkle': {'dorsi': 1.8}})
    sway_b = merge(lift, {'rAnkle': {'dorsi': -1.5}})
    chair_back = [box((-0.25, 0.0, 0.55), (0.25, 0.9, 0.6)), box((-0.25, 0.43, 0.55), (0.25, 0.47, 1.0)),
                  box((-0.25, 0.0, 0.96), (0.25, 0.43, 1.0))]
    return Exercise('Single Leg Stance', {'stand': stand, 'lift': lift, 'a': sway_a, 'b': sway_b},
                    seq(('stand', 0.5), ('lift', 0.2, 0.8), ('a', 0, 0.9), ('b', 0, 1.1), ('lift', 0.3, 0.9),
                        ('stand', 0.3, 0.8)),
                    camera=SIDE, contacts=FEET, pins=['rBall'], flat_feet='r', props=chair_back)

def tandem_stance():
    arms = both(Shoulder={'abd': 22})
    def stance(l, r, root_z, lift=None):
        p = merge(arms, LEG_HINT, {'root': {'y': 0.975, 'z': root_z}}, {'ik': {'lAnkle': ('world', l), 'rAnkle': ('world', r)}})
        return p
    L0, R0 = (0.1, 0.12, 0.0), (-0.1, 0.12, 0.0)
    poses = {
        'neutral': stance(L0, R0, 0.0),
        'aStep': stance((0.05, 0.26, 0.08), R0, 0.03),
        'aHalf': stance((0.0, 0.12, 0.13), R0, 0.05),
        'aShift': stance((0.0, 0.12, 0.13), (-0.05, 0.24, -0.06), 0.02),
        'a': stance((0.0, 0.12, 0.13), (0.0, 0.12, -0.11), 0.01),
        'bStep': stance(L0, (-0.05, 0.26, 0.08), 0.03),
        'bHalf': stance(L0, (0.0, 0.12, 0.13), 0.05),
        'bShift': stance((0.05, 0.24, -0.06), (0.0, 0.12, 0.13), 0.02),
        'b': stance((0.0, 0.12, -0.11), (0.0, 0.12, 0.13), 0.01),
    }
    return Exercise('Tandem Stance', poses,
                    seq(('neutral', 0.3), ('aStep', 0, 0.4), ('aHalf', 0, 0.35), ('aShift', 0, 0.4), ('a', 2.0, 0.35),
                        ('aShift', 0, 0.35), ('aHalf', 0, 0.4), ('aStep', 0, 0.35), ('neutral', 0.3, 0.4),
                        ('bStep', 0, 0.4), ('bHalf', 0, 0.35), ('bShift', 0, 0.4), ('b', 2.0, 0.35),
                        ('bShift', 0, 0.35), ('bHalf', 0, 0.4), ('bStep', 0, 0.35), ('neutral', 0.0, 0.4)),
                    camera=(40, 15), flat_feet='lr')

def single_leg_balance_with_arm_reach():
    # The description specifies the arm opposite the standing leg: right arm, left support.
    arms = {'lShoulder': {'abd': 16, 'flex': -8}, 'lElbow': {'flex': 12},
            'rShoulder': {'abd': 12, 'flex': 8}, 'rElbow': {'flex': 24}}
    stand = merge(arms)
    lifted = merge(arms, {'rHip': {'flex': 30, 'abd': 12}, 'rKnee': {'flex': 80}})
    fwd = merge(lifted, {'rShoulder': {'flex': 88, 'abd': 4}, 'rElbow': {'flex': 8}, 'spine': {'flex': 4}})
    side = merge(lifted, {'rShoulder': {'flex': 0, 'abd': 88}, 'rElbow': {'flex': 8}, 'spine': {'lat': 3}})
    # Keep the diagonal path below and beside the face, rather than obscuring the head.
    diag = merge(lifted, {'rShoulder': {'flex': 110, 'abd': 4, 'hadd': 25}, 'rElbow': {'flex': 8}})
    return Exercise('Single Leg Balance with Arm Reach',
                    {'stand': stand, 'lifted': lifted, 'fwd': fwd, 'side': side, 'diag': diag},
                    seq(('stand', 0.5), ('lifted', 0.55, 0.85), ('fwd', 0.8, 1.1), ('lifted', 0.4, 0.95),
                        ('side', 0.8, 1.1), ('lifted', 0.4, 0.95), ('diag', 0.8, 1.1),
                        ('lifted', 0.55, 0.95), ('stand', 0.4, 0.85)),
                    camera=(-50, 5), contacts=FEET, pins=['lBall'], flat_feet='l', far='l',
                    figure_style='fitness',
                    cues={'stand': 'Stand tall', 'stand>lifted': 'Lift your right foot', 'lifted': 'Balance on your left leg',
                          'fwd': 'Reach forward', 'side': 'Reach to the side', 'diag': 'Reach diagonally up',
                          'fwd>lifted': 'Return slowly', 'side>lifted': 'Return slowly', 'diag>lifted': 'Return slowly',
                          'lifted>stand': 'Lower your foot'})

# ------------------------------------------------------------------ range of motion

def knee_flexion_extension():
    sit = merge(SEATED, HANDS_ON_THIGHS)
    def knee(flex, dorsi=0):
        p = merge(sit, {'lKnee': {'flex': flex}, 'lAnkle': {'dorsi': dorsi}})
        p['ik'] = dict(HANDS_ON_THIGHS['ik'])
        return p
    return Exercise('Knee Flexion/Extension', {'sit': sit, 'ext': knee(0, 5), 'flex': knee(122, -25)},
                    seq(('sit', 0.3), ('ext', 0.4, 1.2), ('sit', 0, 0.9), ('flex', 0.4, 1.0), ('sit', 0.1, 1.0)),
                    camera=SIDE, props=chair(), flat_feet='r')

def lumbar_flexion_extension():
    feet = {'lAnkle': ('world', (0.13, 0.12, 0.02)), 'rAnkle': ('world', (-0.13, 0.12, 0.02))}
    stand = merge({'root': {'y': 0.94}}, LEG_HINT, ARMS_DOWN, {'ik': dict(feet)})
    fwd = merge({'root': {'y': 0.92, 'z': -0.12, 'pitch': 42}}, LEG_HINT, {'spine': {'flex': 38}},
                both(Shoulder={'flex': 72, 'abd': 6}), {'ik': dict(feet)})
    back = merge({'root': {'y': 0.94, 'z': 0.06, 'pitch': -8}}, LEG_HINT, {'spine': {'flex': -20}},
                 both(Shoulder={'flex': -20, 'abd': 8}), {'ik': dict(feet)})
    return Exercise('Lumbar Flexion/Extension', {'stand': stand, 'fwd': fwd, 'back': back},
                    seq(('stand', 0.3), ('fwd', 0.5, 1.6), ('stand', 0.2, 1.4), ('back', 0.5, 1.2), ('stand', 0.2, 1.2)),
                    camera=SIDE, flat_feet='lr')

ALL = [quad_sets, straight_leg_raises, short_arc_quads, terminal_knee_extension, wall_sit, step_ups,
       clamshells, glute_bridges, side_lying_hip_abduction, donkey_kicks,
       external_rotation_with_band, internal_rotation_with_band, shoulder_rows, scapular_retraction,
       heel_raises, ankle_eversion_with_band, towel_scrunches,
       dead_bug, bird_dog, pelvic_tilts, plank, supine_marching,
       hamstring_stretch, quad_stretch, hip_flexor_stretch, piriformis_stretch, calf_stretch, it_band_stretch,
       thoracic_rotation, shoulder_cross_body_stretch, neck_stretch,
       single_leg_stance, tandem_stance, single_leg_balance_with_arm_reach,
       ankle_alphabet, knee_flexion_extension, cervical_range_of_motion, shoulder_pendulum, shoulder_circles,
       hip_circles, lumbar_flexion_extension]
