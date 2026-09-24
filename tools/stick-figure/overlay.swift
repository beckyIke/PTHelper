import AVFoundation
import AppKit

// Usage: overlay <video> <raw.json> <outDir> <cropY> <cropH> <frameIndex...>
let a = CommandLine.arguments
let url = URL(fileURLWithPath: a[1])
struct Frame: Codable { let t: Double; let joints: [String: [Double]] }
let frames = try! JSONDecoder().decode([Frame].self, from: Data(contentsOf: URL(fileURLWithPath: a[2])))
let outDir = a[3]; let cropY = Double(a[4])!, cropH = Double(a[5])!
let indices = a[6...].map { Int($0)! }
let bones = [("neck_1_joint","head_joint"),("neck_1_joint","left_shoulder_1_joint"),("neck_1_joint","right_shoulder_1_joint"),
 ("left_shoulder_1_joint","left_forearm_joint"),("left_forearm_joint","left_hand_joint"),
 ("right_shoulder_1_joint","right_forearm_joint"),("right_forearm_joint","right_hand_joint"),
 ("neck_1_joint","root"),("root","left_upLeg_joint"),("root","right_upLeg_joint"),
 ("left_upLeg_joint","left_leg_joint"),("left_leg_joint","left_foot_joint"),
 ("right_upLeg_joint","right_leg_joint"),("right_leg_joint","right_foot_joint")]
let asset = AVURLAsset(url: url)
let gen = AVAssetImageGenerator(asset: asset)
gen.requestedTimeToleranceBefore = .zero; gen.requestedTimeToleranceAfter = .zero
let sem = DispatchSemaphore(value: 0)
Task {
    for i in indices {
        let f = frames[i]
        let (cg, _) = try await gen.image(at: CMTime(seconds: f.t, preferredTimescale: 6000))
        let crop = cg.cropping(to: CGRect(x: 0, y: cropY, width: Double(cg.width), height: cropH))!
        let img = NSImage(cgImage: crop, size: NSSize(width: crop.width, height: crop.height))
        img.lockFocus()
        NSColor.systemRed.setStroke(); NSColor.systemBlue.setFill()
        for (p, q) in bones {
            guard let A = f.joints[p], let B = f.joints[q], A[2] > 0.3, B[2] > 0.3 else { continue }
            let path = NSBezierPath(); path.lineWidth = 6
            path.move(to: NSPoint(x: A[0], y: A[1])); path.line(to: NSPoint(x: B[0], y: B[1])); path.stroke()
        }
        for (_, v) in f.joints where v[2] > 0.3 { NSBezierPath(ovalIn: NSRect(x: v[0]-8, y: v[1]-8, width: 16, height: 16)).fill() }
        let label = String(format: "#%d t=%.2f", i, f.t) as NSString
        label.draw(at: NSPoint(x: 20, y: 20), withAttributes: [.font: NSFont.boldSystemFont(ofSize: 40)])
        img.unlockFocus()
        let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
        try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(outDir)/o\(i).png"))
    }
    sem.signal()
}
sem.wait()
