from rig import *

STAND_ARMS = both(Shoulder={'abd': 6})
FEET = [('lBall', 0.06), ('rBall', 0.06)]
SUPINE_HEAD_LEFT = {'root': {'yaw': 180, 'pitch': -90}}
TORSO_R = 0.145
CLAM_CAMERA = (0, 35)

def glute_bridges():
    down = merge(SUPINE_HEAD_LEFT, both(Hip={'flex': 55}, Knee={'flex': 110}), both(Shoulder={'abd': 10}))
    up = merge(down, {'root': {'yaw': 180, 'pitch': -127}, 'neck': {'flex': 30}},
               {'ik': {'lAnkle': ('base', 'lAnkle'), 'rAnkle': ('base', 'rAnkle'),
                       'lHand': ('base', 'lHand'), 'rHand': ('base', 'rHand')}})
    down['ik'] = dict(up['ik'])
    up['glow'] = {'glutes': 1.0}
    return Exercise('Glute Bridges', {'down': down, 'up': up},
                    [('down', 0.6), ('down>up', 1.4), ('up', 1.2), ('up>down', 1.4), ('down', 0.4)],
                    camera=(90, 0), contacts=[('chest', TORSO_R), ('root', TORSO_R)], pins=['chest'],
                    flat_feet='lr', glows=[{'name': 'glutes', 'joints': ['root']}])

def wall_sit():
    feet = {'lAnkle': ('world', (0.1, 0.12, 0.42)), 'rAnkle': ('world', (-0.1, 0.12, 0.42))}
    hands = {'lHand': ('joint', 'lKnee', (0, 0.09, -0.12)), 'rHand': ('joint', 'rKnee', (0, 0.09, -0.12))}
    top = merge({'root': {'y': 0.88, 'z': 0.0}}, both(Hip={'flex': 25}, Knee={'flex': 35}), STAND_ARMS, {'ik': {**feet, **hands}})
    bottom = merge({'root': {'y': 0.55, 'z': 0.0}}, both(Hip={'flex': 90}, Knee={'flex': 90}), STAND_ARMS, {'ik': {**feet, **hands}})
    bottom['glow'] = {'quads': 1.0}
    wall = {'type': 'rect', 'box': ((-0.3, 0, -0.30), (0.3, 1.95, -0.16)), 'style': 'prop'}
    return Exercise('Wall Sit', {'top': top, 'bottom': bottom},
                    [('top', 0.6), ('top>bottom', 1.6), ('bottom', 2.4), ('bottom>top', 1.6), ('top', 0.4)],
                    camera=(90, 0), props=[wall], flat_feet='lr',
                    glows=[{'name': 'quads', 'joints': ['lHip', 'lKnee']}])

def heel_raises():
    flat = merge(STAND_ARMS)
    up = merge(STAND_ARMS, both(Ankle={'dorsi': -32}, Toe={'flex': -32}))
    return Exercise('Heel Raises', {'flat': flat, 'up': up},
                    [('flat', 0.6), ('flat>up', 1.1), ('up', 0.8), ('up>flat', 1.4), ('flat', 0.3)],
                    camera=(90, 0), contacts=FEET, pins=['lBall', 'rBall'])

def clamshells():
    base = merge({'root': {'roll': 90}}, both(Hip={'flex': 45}, Knee={'flex': 90}),
                 {'rShoulder': {'flex': 170}, 'rElbow': {'flex': 20}, 'lShoulder': {'flex': 10}, 'neck': {'lat': -15}})
    base['ik'] = {'lAnkle': ('joint', 'rAnkle', (0, 0.17, 0))}
    open_ = merge(base, {'lHip': {'flex': 45, 'abd': 38}})
    open_['ik'] = dict(base['ik'])
    open_['glow'] = {'glute': 1.0}
    return Exercise('Clamshells', {'closed': base, 'open': open_},
                    [('closed', 0.6), ('closed>open', 1.2), ('open', 0.6), ('open>closed', 1.4), ('closed', 0.3)],
                    camera=CLAM_CAMERA, contacts=[('rHip', 0.075), ('rShoulder', 0.075), ('rKnee', 0.075)],
                    glows=[{'name': 'glute', 'joints': ['lHip']}])

if __name__ == '__main__':
    import sys
    for make in (glute_bridges, wall_sit, heel_raises, clamshells):
        ex = make().build()
        path = f"{sys.argv[1]}/{ex.name.lower().replace(' ', '-')}.json"
        ex.export(path)
    for i, cam in enumerate([(0, 20), (-35, 30), (35, 30), (0, 60)]):
        CLAM_CAMERA = cam
        globals()['CLAM_CAMERA'] = cam
        ex = clamshells().build()
        ex.name = f'Clamshells cam {cam}'
        ex.export(f"{sys.argv[1]}/clam{i}.json")
