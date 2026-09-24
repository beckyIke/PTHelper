import SwiftUI

/// Draws one frame of an `ExerciseAnimation`: props, muscle glows, trails, then the activity figure.
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

    static let fitnessTint = Color(red: 0.68, green: 1, blue: 0)
    static let fitnessBackground = Color(red: 0.055, green: 0.075, blue: 0.025)

    var frame: CGRect {
        var bounds = animation.bounds.insetBy(dx: -Self.margin, dy: -Self.margin)
        if animation.figureStyle == .fitness {
            let width = max(bounds.width, 0.58)
            bounds.origin.x -= (width - bounds.width) / 2
            bounds.size.width = width
            if !animation.cues.isEmpty {
                bounds.origin.y -= 0.14
                bounds.size.height += 0.14
            }
        }
        return bounds
    }

    func draw(atFrame position: Double, in canvas: inout GraphicsContext, size: CGSize) {
        let pose = animation.pose(atFrame: position)
        let frame = self.frame
        let scale = size.width / frame.width   // points per animation unit
        func map(_ v: CGPoint) -> CGPoint { CGPoint(x: (v.x - frame.minX) * scale, y: (frame.maxY - v.y) * scale) }
        func p(_ key: String) -> CGPoint? { pose[key].map(map) }
        let fitness = animation.figureStyle == .fitness
        let limb = (fitness ? 0.039 : Self.limbWidth) * scale

        if fitness {
            canvas.clip(to: Path(CGRect(origin: .zero, size: size)))
            canvas.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Self.fitnessBackground))
        }

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
            case .strap: fitness ? .white.opacity(0.65) : .primary.opacity(0.45)
            case .towel: fitness ? .white.opacity(0.35) : .primary.opacity(0.22)
            case .prop: fitness ? .white.opacity(0.22) : propColor
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
            canvas.fill(Path(ellipseIn: shadow), with: .color(fitness ? Self.fitnessTint.opacity(0.07) : .primary.opacity(0.08)))
        }

        // Trails (fading path of a joint over recent frames)
        for trail in animation.trails {
            var count = min(trail.frames, animation.frames.count - 1)
            if trail.resetOnCue == true, let cue = animation.cues.last(where: { Double($0.startFrame) <= position }) {
                count = min(count, max(0, Int(position) - cue.startFrame))
            }
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
            let color = fitness ? Self.fitnessTint.opacity(0.4 * amount) : glowColor.opacity(0.75 * amount)
            if pts.count == 1, let c = pts.first {
                let r = limb * 1.6
                glowCanvas.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(color))
            } else if let first = pts.first {
                var path = Path()
                path.move(to: first)
                pts.dropFirst().forEach { path.addLine(to: $0) }
                glowCanvas.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: limb * 2.4, lineCap: .round, lineJoin: .round))
            }
        }

        if fitness {
            drawFitness(pose, atFrame: position, in: &canvas, size: size, scale: scale, map: map)
            return
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

    /// A compact activity glyph with a tapered torso, rounded limbs and quiet joint cues.
    private func drawFitness(_ pose: ExerciseAnimation.Pose, atFrame position: Double,
                             in canvas: inout GraphicsContext, size: CGSize, scale: CGFloat,
                             map: (CGPoint) -> CGPoint) {
        func p(_ key: String) -> CGPoint? { pose[key].map(map) }
        func path(_ keys: [String]) -> Path {
            let points = keys.compactMap(p)
            return Path { path in
                guard let first = points.first else { return }
                path.move(to: first)
                points.dropFirst().forEach { path.addLine(to: $0) }
            }
        }
        func stroke(_ keys: [String], color: Color, width: CGFloat) {
            canvas.stroke(path(keys), with: .color(color),
                          style: StrokeStyle(lineWidth: width * scale, lineCap: .round, lineJoin: .round))
        }
        func joint(_ key: String, color: Color, radius: CGFloat = 0.0065) {
            guard let center = p(key) else { return }
            let r = radius * scale
            let dot = Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
            canvas.fill(dot, with: .color(color.mix(with: Self.fitnessBackground, by: 0.18)))
        }
        func leg(_ side: String, color: Color) {
            stroke(["\(side)Hip", "\(side)Knee", "\(side)Ankle"], color: color, width: 0.043)
            // A simple rounded foot instead of the anatomical heel/ball outline.
            stroke(["\(side)Ankle", "\(side)Ball", "\(side)Toe"], color: color, width: 0.032)
            joint("\(side)Knee", color: color)
            joint("\(side)Ankle", color: color, radius: 0.005)
            if animation.focus.contains("\(side)Toe") {
                // Foot close-ups need the ball joint to make toe curls and ankle motion legible.
                joint("\(side)Ball", color: color, radius: 0.004)
            }
        }
        func arm(_ side: String, color: Color, foreground: Bool) {
            let keys = ["\(side)Shoulder", "\(side)Elbow", "\(side)Hand"]
            if foreground {
                // A fine gap keeps the moving arm readable when it passes across the torso.
                stroke(keys, color: Self.fitnessBackground, width: 0.048)
            }
            stroke(keys, color: color, width: 0.039)
            joint("\(side)Shoulder", color: color, radius: 0.008)
            joint("\(side)Elbow", color: color)
        }

        let foreground = Self.fitnessTint
        let background = foreground.mix(with: Self.fitnessBackground, by: 0.13)
        let f = animation.farSide.rawValue, n = animation.farSide.opposite.rawValue
        leg(f, color: background)
        arm(f, color: background, foreground: false)
        leg(n, color: foreground)

        if let lHip = p("lHip"), let rHip = p("rHip"), let lSh = p("lShoulder"), let rSh = p("rShoulder") {
            let top = midpoint(lSh, rSh), bottom = midpoint(lHip, rHip)
            let lumbar = p("lumbar"), chest = p("chest")
            let lumbarOffset = if let lumbar, let chest {
                CGPoint(x: lumbar.x - (bottom.x * 0.65 + chest.x * 0.35),
                        y: lumbar.y - (bottom.y * 0.65 + chest.y * 0.35))
            } else { CGPoint.zero }
            let length = max(distance(top, bottom), 1)
            let axis = CGPoint(x: (bottom.x - top.x) / length, y: (bottom.y - top.y) / length)
            let normal = CGPoint(x: -axis.y, y: axis.x)
            func offset(_ point: CGPoint, across: CGFloat, along: CGFloat = 0) -> CGPoint {
                CGPoint(x: point.x + normal.x * across + axis.x * along,
                        y: point.y + normal.y * across + axis.y * along)
            }
            func lowerCurve(_ point: CGPoint) -> CGPoint {
                let control = offset(point, across: 0, along: -length * 0.25)
                return CGPoint(x: control.x + lumbarOffset.x * 2, y: control.y + lumbarOffset.y * 2)
            }
            let shoulderWidth = max(distance(lSh, rSh) * 0.5, 0.036 * scale)
            let hipWidth = max(distance(lHip, rHip) * 0.5, 0.025 * scale)
            let topA = offset(top, across: shoulderWidth), topB = offset(top, across: -shoulderWidth)
            let bottomA = offset(bottom, across: hipWidth), bottomB = offset(bottom, across: -hipWidth)
            let torso = Path { path in
                path.move(to: topA)
                path.addQuadCurve(to: topB, control: offset(top, across: 0, along: -shoulderWidth * 0.85))
                path.addCurve(to: bottomB, control1: offset(topB, across: 0, along: length * 0.45),
                              control2: lowerCurve(bottomB))
                path.addQuadCurve(to: bottomA, control: offset(bottom, across: 0, along: 0.027 * scale))
                path.addCurve(to: topA, control1: lowerCurve(bottomA),
                              control2: offset(topA, across: 0, along: length * 0.45))
                path.closeSubpath()
            }
            canvas.fill(torso, with: .color(foreground))
            joint("\(n)Hip", color: foreground, radius: 0.006)
        }
        arm(n, color: foreground, foreground: true)

        if let head = p("head"), let neck = p("neck") {
            let radius = 0.047 * scale
            let d = max(distance(neck, head), 1)
            let center = CGPoint(x: head.x - (head.x - neck.x) / d * 0.008 * scale,
                                 y: head.y - (head.y - neck.y) / d * 0.008 * scale)
            canvas.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                              width: radius * 2, height: radius * 2)), with: .color(foreground))
            if animation.showsFace, let nose = p("nose") {
                // A quiet face-direction dot distinguishes turning from tilting the head.
                let offset = CGPoint(x: nose.x - head.x, y: nose.y - head.y)
                let dotRadius = radius * 0.22
                let dotCenter = CGPoint(x: center.x + offset.x * 0.72, y: center.y + offset.y * 0.72)
                canvas.fill(Path(ellipseIn: CGRect(x: dotCenter.x - dotRadius, y: dotCenter.y - dotRadius,
                                                  width: dotRadius * 2, height: dotRadius * 2)),
                            with: .color(foreground.mix(with: Self.fitnessBackground, by: 0.45)))
            }
        }

        if let cue = animation.cue(atFrame: position) {
            // Crop the figure above this band, including legs outside an upper-body close-up.
            canvas.fill(Path(CGRect(x: 0, y: size.height - 0.14 * scale,
                                    width: size.width, height: 0.14 * scale)), with: .color(Self.fitnessBackground))
            let text = Text(cue).font(.system(size: min(15, max(9, 0.031 * scale)), weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            // Constrain captions so narrow portrait and close-up stages don't clip longer cues.
            let rect = CGRect(x: 8, y: size.height - 0.13 * scale,
                              width: max(0, size.width - 16), height: 0.12 * scale)
            canvas.draw(text, in: rect)
        }
    }

    private func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) }
    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }
}
