import SwiftUI

/// Draws one frame of an `ExerciseAnimation`: props, muscle glows, trails, then the thick-limbed figure.
/// Shared by `ExerciseFigureView` and the Mac preview tool in `tools/stick-figure/`, so previews match the app.
struct ExerciseFigureRenderer {
    let animation: ExerciseAnimation
    var near: Color = .ptAccent
    var far: Color = .ptBrandSky
    var propColor: Color = .primary.opacity(0.14)
    var bandColor: Color = .ptBrandMint
    var glowColor: Color = .orange

    /// Stroke sizes in animation units.
    static let limbWidth = 0.062
    static let torsoWidth = 0.12
    static let headRadius = 0.058
    /// Room around the scene bounds for limb thickness and the head.
    static let margin = 0.09

    var frame: CGRect { animation.bounds.insetBy(dx: -Self.margin, dy: -Self.margin) }

    func draw(atFrame position: Double, in canvas: inout GraphicsContext, size: CGSize) {
        let pose = animation.pose(atFrame: position)
        let frame = self.frame
        let scale = size.width / frame.width   // points per animation unit
        func map(_ v: CGPoint) -> CGPoint { CGPoint(x: (v.x - frame.minX) * scale, y: (frame.maxY - v.y) * scale) }
        func p(_ key: String) -> CGPoint? { pose[key].map(map) }
        let limb = Self.limbWidth * scale

        func stroke(_ points: [CGPoint], _ color: Color, _ width: CGFloat) {
            guard let first = points.first else { return }
            var path = Path()
            path.move(to: first)
            points.dropFirst().forEach { path.addLine(to: $0) }
            canvas.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
        }
        func stroke(_ keys: [String], _ color: Color, _ width: CGFloat) {
            stroke(keys.compactMap(p), color, width)
        }

        // Props
        for prop in animation.props {
            let color: Color = switch prop.style ?? .prop {
            case .band: bandColor
            case .strap: .primary.opacity(0.45)
            case .towel: .primary.opacity(0.22)
            case .prop: propColor
            }
            switch prop.type {
            case .line:
                let points = (prop.points ?? []).compactMap { $0.resolve(in: pose) }.map(map)
                stroke(points, color, (prop.width ?? 0.02) * scale)
            case .circle:
                if let c = prop.center?.resolve(in: pose), let r = prop.radius {
                    let center = map(c), radius = r * scale
                    canvas.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                                with: .color(color))
                }
            case .rect:
                if let r = prop.rect, r.count == 4 {
                    let topLeft = map(CGPoint(x: r[0], y: r[1] + r[3]))
                    let rect = CGRect(x: topLeft.x, y: topLeft.y, width: r[2] * scale, height: r[3] * scale)
                    canvas.fill(Path(roundedRect: rect, cornerRadius: (prop.corner ?? 0.015) * scale), with: .color(color))
                }
            }
        }

        // Ground shadow under whatever touches the floor.
        let points = pose.values.map(map)
        if let groundY = points.map(\.y).max() {
            let grounded = points.filter { $0.y > groundY - limb * 1.5 }
            let minX = grounded.map(\.x).min() ?? 0, maxX = grounded.map(\.x).max() ?? 0
            let width = max(maxX - minX + limb * 2, 0.28 * scale)
            let shadow = CGRect(x: (minX + maxX) / 2 - width / 2, y: groundY + limb * 0.6 - 0.012 * scale,
                                width: width, height: 0.024 * scale)
            canvas.fill(Path(ellipseIn: shadow), with: .color(.primary.opacity(0.08)))
        }

        // Trails (fading path of a joint over recent frames)
        for trail in animation.trails {
            let count = min(trail.frames, animation.frames.count - 1)
            guard count > 1 else { continue }
            let path = (0...count).map { step -> CGPoint? in
                let back = position - Double(count - step)
                let wrapped = back < 0 ? back + Double(animation.frames.count) : back
                return animation.pose(atFrame: wrapped)[trail.joint].map(map)
            }.compactMap { $0 }
            for i in 1..<path.count {
                let alpha = Double(i) / Double(path.count)
                stroke([path[i - 1], path[i]], bandColor.opacity(alpha * 0.9), limb * 0.45)
            }
        }

        // Muscle glows, under the limbs
        for glow in animation.glows {
            let amount = animation.intensity(of: glow, atFrame: position)
            guard amount > 0.01 else { continue }
            var glowCanvas = canvas
            glowCanvas.addFilter(.blur(radius: limb * 0.5))
            let pts = glow.joints.compactMap(p)
            let color = glowColor.opacity(0.75 * amount)
            if pts.count == 1, let c = pts.first {
                let r = limb * 1.6
                glowCanvas.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(color))
            } else {
                var path = Path()
                path.move(to: pts[0])
                pts.dropFirst().forEach { path.addLine(to: $0) }
                glowCanvas.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: limb * 2.4, lineCap: .round, lineJoin: .round))
            }
        }

        // Figure: far limbs first and lighter, then the torso, then near limbs on top.
        let f = animation.farSide.rawValue, n = animation.farSide.opposite.rawValue
        let foot = { (s: String) in pose["\(s)Heel"] != nil ? ["\(s)Ankle", "\(s)Heel", "\(s)Ball", "\(s)Toe"] : ["\(s)Ankle", "\(s)Ball", "\(s)Toe"] }
        stroke(["\(f)Hip", "\(f)Knee", "\(f)Ankle"], far, limb)
        stroke(foot(f), far, limb * 0.8)
        stroke(["\(f)Shoulder", "\(f)Elbow", "\(f)Hand"], far, limb)

        if let lHip = p("lHip"), let rHip = p("rHip"), let lSh = p("lShoulder"), let rSh = p("rShoulder") {
            stroke([midpoint(lHip, rHip), midpoint(lSh, rSh)], near, Self.torsoWidth * scale)
            if distance(lSh, rSh) > limb {   // front view only; shoulders overlap side-on
                stroke([lSh, rSh], near, limb * 1.4)
            }
        }

        // Near limbs are a touch deeper than the torso so they still read where they cross it.
        let limbColor = near.mix(with: .black, by: 0.16)
        stroke(["\(n)Hip", "\(n)Knee", "\(n)Ankle"], limbColor, limb)
        stroke(foot(n), limbColor, limb * 0.8)
        stroke(["\(n)Shoulder", "\(n)Elbow", "\(n)Hand"], limbColor, limb)

        // Head just beyond the neck, along the neck → head direction.
        if let neck = p("neck"), let head = p("head") {
            let d = max(distance(neck, head), 1)
            let radius = Self.headRadius * scale
            let reach = max(radius * 1.45, d * 0.9)
            let center = CGPoint(x: neck.x + (head.x - neck.x) / d * reach, y: neck.y + (head.y - neck.y) / d * reach)
            canvas.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                        with: .color(near))
            // Nose: shows which way the head faces (neck exercises only).
            if animation.showsFace, let nose = p("nose") {
                // The nose bone is 0.05 units long; its projected length says how far the face is turned.
                let offset = CGPoint(x: nose.x - head.x, y: nose.y - head.y)
                let length = hypot(offset.x, offset.y)
                let spread = min(length / (0.05 * scale), 1)
                let dir = length > 0.5 ? CGPoint(x: offset.x / length, y: offset.y / length) : .zero
                let noseCenter = CGPoint(x: center.x + dir.x * radius * 0.95 * spread, y: center.y + dir.y * radius * 0.95 * spread)
                let r = radius * 0.32
                canvas.fill(Path(ellipseIn: CGRect(x: noseCenter.x - r, y: noseCenter.y - r, width: r * 2, height: r * 2)),
                            with: .color(far))
            }
        }
    }

    private func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) }
    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }
}
