"""Description-level checks in 3D, before camera projection can hide a movement error.

Run: python3 -B -m unittest discover -s tools/stick-figure/author -p 'test_*.py'
"""
import math
from pathlib import Path
import re
import unittest

from alphabet import LETTERS
from library import ALL
from rig import sub, norm, dot


class DescriptionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.exercises = {ex.name: ex.build() for ex in (make() for make in ALL)}

    def pose(self, name, key):
        ex = self.exercises[name]
        return ex._solve_frame(ex.poses[key], ex.base)

    def assertNear(self, a, b, tolerance=0.001):
        self.assertLess(math.dist(a, b), tolerance)

    def angle(self, a, b, c):
        u, v = sub(a, b), sub(c, b)
        return math.degrees(math.acos(max(-1, min(1, dot(u, v) / (norm(u) * norm(v))))))

    def test_every_seed_description_has_an_authored_animation(self):
        seed = Path(__file__).resolve().parents[3] / 'PTHelper/Services/SeedData.swift'
        names = re.findall(r'Exercise\(name: "([^"]+)"', seed.read_text())
        self.assertEqual(len(names), 41)
        self.assertEqual(set(names), set(self.exercises))

    def test_all_loops_and_limb_lengths(self):
        for name, ex in self.exercises.items():
            with self.subTest(name=name):
                for j in ex.frames3d[0]:
                    self.assertNear(ex.frames3d[0][j], ex.frames3d[-1][j], 0.035)
                for f in ex.frames3d:
                    for side in 'lr':
                        for a, b, length in [('Hip', 'Knee', .44), ('Knee', 'Ankle', .43),
                                             ('Shoulder', 'Elbow', .29), ('Elbow', 'Hand', .29)]:
                            self.assertAlmostEqual(math.dist(f[side+a], f[side+b]), length, places=5)

    def test_straight_leg_raise_stops_at_bent_knee_height(self):
        f = self.pose('Straight Leg Raises', 'up')
        self.assertLess(abs(f['rAnkle'][1] - f['lKnee'][1]), .035)
        self.assertGreater(self.angle(f['rHip'], f['rKnee'], f['rAnkle']), 179)

    def test_clamshell_keeps_hips_and_feet_together(self):
        rest = self.pose('Clamshells', 'closed')
        up = self.pose('Clamshells', 'open')
        self.assertGreater(up['lKnee'][1], rest['lKnee'][1] + .06)
        for f in self.exercises['Clamshells'].frames3d:
            for side in 'lr':
                self.assertNear(f[side+'Hip'], rest[side+'Hip'])
            for j in ['Ankle', 'Ball', 'Toe', 'Heel']:
                self.assertAlmostEqual(math.dist(f['l'+j], f['r'+j]), .065, places=5)

    def test_bridge_is_a_straight_shoulder_hip_knee_line(self):
        f = self.pose('Glute Bridges', 'up')
        # Compare midline shoulder/root with the leg in the sagittal plane.
        shoulder = (0, f['lShoulder'][1], f['lShoulder'][2])
        hip = (0, f['lHip'][1], f['lHip'][2])
        knee = (0, f['lKnee'][1], f['lKnee'][2])
        self.assertGreater(self.angle(shoulder, hip, knee), 175)

    def test_bird_dog_and_dead_bug_use_opposite_limbs(self):
        for name, neutral in [('Bird Dog', 'rest'), ('Dead Bug', 'start')]:
            rest = self.pose(name, neutral)
            for key, arm, leg, still_arm, still_leg in [('a', 'r', 'l', 'l', 'r'), ('b', 'l', 'r', 'r', 'l')]:
                f = self.pose(name, key)
                self.assertGreater(math.dist(f[arm+'Hand'], rest[arm+'Hand']), .3)
                self.assertGreater(math.dist(f[leg+'Ankle'], rest[leg+'Ankle']), .3)
                self.assertNear(f[still_arm+'Hand'], rest[still_arm+'Hand'])
                self.assertNear(f[still_leg+'Knee'], rest[still_leg+'Knee'])
                self.assertNear(f['root'], rest['root'])

    def test_balance_reaches_with_arm_opposite_standing_leg(self):
        rest = self.pose('Single Leg Balance with Arm Reach', 'stand')
        for key in ['fwd', 'side', 'diag']:
            f = self.pose('Single Leg Balance with Arm Reach', key)
            self.assertNear(f['lBall'], rest['lBall'])
            self.assertGreater(f['rBall'][1], rest['rBall'][1] + .08)
            self.assertGreater(math.dist(f['rHand'], rest['rHand']), .3)

    def test_fixed_feet_and_rear_calf_knee(self):
        for name in ['Terminal Knee Extension', 'Calf Stretch (Gastrocnemius)', 'Wall Sit', 'Hip Circles']:
            frames = self.exercises[name].frames3d
            for f in frames:
                for j in ['lHeel', 'rHeel', 'lBall', 'rBall']:
                    self.assertNear(f[j], frames[0][j], .005)
        f = self.pose('Calf Stretch (Gastrocnemius)', 'lean')
        self.assertGreater(self.angle(f['lHip'], f['lKnee'], f['lAnkle']), 175)

    def test_explicit_short_holds_match_the_text(self):
        for name, pose, duration in [('Quad Sets', 'press', 5), ('Scapular Retraction', 'squeeze', 5),
                                     ('Short Arc Quads', 'straight', 2), ('Bird Dog', 'a', 2), ('Bird Dog', 'b', 2)]:
            self.assertIn((pose, duration), self.exercises[name].timeline)

    def test_full_alphabet_moves_only_the_ankle(self):
        self.assertEqual(''.join(LETTERS), 'ABCDEFGHIJKLMNOPQRSTUVWXYZ')
        ex = self.exercises['Ankle Alphabet']
        for f in ex.frames3d:
            for j in ['root', 'lHip', 'lKnee', 'lAnkle', 'rToe']:
                self.assertNear(f[j], ex.frames3d[0][j])

    def test_plank_support_and_alignment(self):
        f = self.pose('Plank', 'full')
        for side in 'lr':
            self.assertAlmostEqual(f[side+'Elbow'][2], f[side+'Shoulder'][2], places=5)
            self.assertLess(abs(f[side+'Ball'][1] - f[side+'Elbow'][1]), .02)
            self.assertGreater(self.angle(f[side+'Hip'], f[side+'Knee'], f[side+'Ankle']), 179)

    def test_seated_rotation_and_marching_keep_the_base_stable(self):
        for name, joints in [('Thoracic Rotation', ['root', 'lAnkle', 'rAnkle']),
                              ('Supine Marching', ['root', 'chest']),
                              ('Cervical Range of Motion', ['root', 'lShoulder', 'rShoulder'])]:
            frames = self.exercises[name].frames3d
            for f in frames:
                for j in joints:
                    self.assertNear(f[j], frames[0][j])


if __name__ == '__main__':
    unittest.main()
