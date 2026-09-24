import CoreGraphics
import Foundation

/// A looping stick-figure animation for an exercise, loaded from a bundled JSON file of joint positions.
///
/// Files live in `Resources/ExerciseAnimations/` and are named after the exercise ("Bird Dog" → `bird-dog.json`).
/// They're produced by the tools in `tools/stick-figure/`. Coordinates are normalized so that 1 unit is a fixed
/// real-world span, with y pointing up.
struct ExerciseAnimation: Decodable {
    typealias Pose = [String: CGPoint]

    enum Side: String, Decodable {
        case left = "l", right = "r"
        var opposite: Side { self == .left ? .right : .left }
    }

    /// A point that is either fixed or follows a joint.
    enum Anchor: Decodable {
        case point(CGPoint)
        case joint(String)

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let name = try? container.decode(String.self) {
                self = .joint(name)
            } else {
                let xy = try container.decode([Double].self)
                self = .point(CGPoint(x: xy[0], y: xy[1]))
            }
        }

        func resolve(in pose: Pose) -> CGPoint? {
            switch self {
            case .point(let p): return p
            case .joint(let name): return pose[name]
            }
        }
    }

    /// Scenery drawn behind the figure: walls, chairs, steps, bands, straps, towels.
    struct Prop: Decodable {
        enum Kind: String, Decodable { case line, circle, rect }
        enum Style: String, Decodable { case prop, band, strap, towel }
        let type: Kind
        let style: Style?
        let points: [Anchor]?
        let center: Anchor?
        let radius: Double?
        let rect: [Double]?      // x, y (bottom-left), width, height
        let width: Double?
        let corner: Double?
    }

    /// A soft glow on the working muscle, with a per-frame intensity (0…1).
    struct Glow: Decodable {
        let joints: [String]
        let intensity: [Double]
    }

    /// The recent path of a joint, drawn as a fading line (e.g. the toe in Ankle Alphabet).
    struct Trail: Decodable {
        let joint: String
        let frames: Int
    }

    let name: String
    let fps: Double
    /// Limbs on this side are farther from the camera and drawn lighter, behind the body.
    let farSide: Side
    let frames: [Pose]
    let props: [Prop]
    let glows: [Glow]
    let trails: [Trail]
    /// Draws a small nose so head turns read (neck exercises).
    let showsFace: Bool
    /// When set, the view frames just these joints (a close-up), e.g. the foot for ankle exercises.
    let focus: [String]

    var duration: TimeInterval { Double(frames.count) / fps }

    /// Joints every animation has. Authored animations also include feet (`lBall`, `lToe`, …) and `nose`.
    static let joints = ["root", "neck", "head", "lShoulder", "rShoulder", "lElbow", "rElbow", "lHand", "rHand",
                         "lHip", "rHip", "lKnee", "rKnee", "lAnkle", "rAnkle"]

    private enum CodingKeys: String, CodingKey { case name, fps, farSide, frames, props, glows, trails, face, focus }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        fps = try container.decode(Double.self, forKey: .fps)
        farSide = try container.decodeIfPresent(Side.self, forKey: .farSide) ?? .left
        let raw = try container.decode([[String: [Double]]].self, forKey: .frames)
        frames = raw.map { frame in frame.mapValues { CGPoint(x: $0[0], y: $0[1]) } }
        props = try container.decodeIfPresent([Prop].self, forKey: .props) ?? []
        glows = try container.decodeIfPresent([Glow].self, forKey: .glows) ?? []
        trails = try container.decodeIfPresent([Trail].self, forKey: .trails) ?? []
        showsFace = try container.decodeIfPresent(Bool.self, forKey: .face) ?? false
        focus = try container.decodeIfPresent([String].self, forKey: .focus) ?? []
    }

    // MARK: Playback

    /// Fractional frame position for a time, looping.
    func framePosition(at time: TimeInterval) -> Double {
        guard !frames.isEmpty else { return 0 }
        var position = (time * fps).truncatingRemainder(dividingBy: Double(frames.count))
        if position < 0 { position += Double(frames.count) }
        return position
    }

    /// The pose at `time` seconds, looping, blended between the two nearest frames.
    func pose(at time: TimeInterval) -> Pose {
        pose(atFrame: framePosition(at: time))
    }

    func pose(atFrame position: Double) -> Pose {
        guard frames.count > 1 else { return frames.first ?? [:] }
        let index = Int(position) % frames.count
        let next = (index + 1) % frames.count
        let w = position - Double(Int(position))
        return frames[index].merging(frames[next]) { a, b in
            CGPoint(x: a.x + (b.x - a.x) * w, y: a.y + (b.y - a.y) * w)
        }
    }

    /// Glow intensity for a glow at a (fractional) frame position.
    func intensity(of glow: Glow, atFrame position: Double) -> Double {
        guard !glow.intensity.isEmpty else { return 0 }
        let index = Int(position) % glow.intensity.count
        let next = (index + 1) % glow.intensity.count
        let w = position - Double(Int(position))
        return glow.intensity[index] + (glow.intensity[next] - glow.intensity[index]) * w
    }

    /// The frame shown when Reduce Motion is on: the one farthest from the starting pose (the "working" position).
    var stillFrame: Int {
        guard let first = frames.first else { return 0 }
        func spread(_ pose: Pose) -> Double {
            pose.reduce(0) { total, joint in
                guard let start = first[joint.key] else { return total }
                return total + hypot(joint.value.x - start.x, joint.value.y - start.y)
            }
        }
        return frames.indices.max { spread(frames[$0]) < spread(frames[$1]) } ?? 0
    }

    var stillPose: Pose { frames.isEmpty ? [:] : frames[stillFrame] }

    /// Bounding box of every joint and prop across all frames (or just the focus joints), so the view can crop.
    var bounds: CGRect {
        if !focus.isEmpty {
            let points = frames.flatMap { frame in focus.compactMap { frame[$0] } }
            let xs = points.map(\.x), ys = points.map(\.y)
            guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else { return .zero }
            return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        }
        var points = frames.flatMap(\.values)
        for prop in props {
            for anchor in prop.points ?? [] {
                if case .point(let p) = anchor { points.append(p) }
            }
            if case .point(let c)? = prop.center, let r = prop.radius {
                points += [CGPoint(x: c.x - r, y: c.y - r), CGPoint(x: c.x + r, y: c.y + r)]
            }
            if let r = prop.rect, r.count == 4 {
                points += [CGPoint(x: r[0], y: r[1]), CGPoint(x: r[0] + r[2], y: r[1] + r[3])]
            }
        }
        let xs = points.map(\.x), ys = points.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else { return .zero }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    // MARK: Loading

    private static var cache: [String: ExerciseAnimation?] = [:]

    /// The animation for an exercise, or nil if none is bundled. Results are cached.
    static func named(_ exerciseName: String, in bundle: Bundle = .main) -> ExerciseAnimation? {
        let resource = resourceName(for: exerciseName)
        if let cached = cache[resource] { return cached }
        let url = bundle.url(forResource: resource, withExtension: "json")
            ?? bundle.url(forResource: resource, withExtension: "json", subdirectory: "ExerciseAnimations")
        let animation = url.flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? JSONDecoder().decode(ExerciseAnimation.self, from: $0) }
        cache[resource] = animation
        return animation
    }

    /// "Bird Dog" → "bird-dog", "Calf Stretch (Gastrocnemius)" → "calf-stretch-gastrocnemius"
    static func resourceName(for exerciseName: String) -> String {
        exerciseName.lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .joined(separator: "-")
    }
}
