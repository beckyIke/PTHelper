import AVFoundation
import AppKit
import CoreGraphics

// Usage: render <skeleton.json> <out.mp4> <stillsDir> [loops]
let args = CommandLine.arguments
struct Anim: Decodable { let name: String; let fps: Int; let farSide: String?; let frames: [[String: [Double]]] }
let anim = try! JSONDecoder().decode(Anim.self, from: Data(contentsOf: URL(fileURLWithPath: args[1])))
let outURL = URL(fileURLWithPath: args[2])
let stillsDir = args[3]
let loops = args.count > 4 ? Int(args[4])! : 3
let size = 1080

// Palette (PTHelper): accent for the body and near limbs, brand sky for far limbs.
func rgb(_ hex: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}
let background = rgb(0xEEF6F9)
let near = rgb(0x2870B2)
let far = rgb(0x75B7EF)

func draw(_ J: [String: [Double]], in ctx: CGContext) {
    let S = Double(size)
    func p(_ k: String) -> CGPoint { CGPoint(x: J[k]![0] * S, y: J[k]![1] * S) }
    let limb = S * 0.062, torsoWidth = S * 0.12, headRadius = S * 0.058

    ctx.setFillColor(background)
    ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)

    func stroke(_ keys: [String], _ color: CGColor, _ width: Double) {
        ctx.setStrokeColor(color)
        ctx.setLineWidth(width)
        ctx.beginPath()
        ctx.move(to: p(keys[0]))
        for k in keys.dropFirst() { ctx.addLine(to: p(k)) }
        ctx.strokePath()
    }

    // Ground shadow under whatever touches the floor (feet, or hands and knees).
    let points = J.keys.map(p)
    let groundY = points.map(\.y).min()!
    let grounded = points.filter { $0.y < groundY + limb * 1.5 }
    let minX = grounded.map(\.x).min()!, maxX = grounded.map(\.x).max()!
    let shadowWidth = max(maxX - minX + limb * 2, S * 0.28)
    ctx.setFillColor(CGColor(gray: 0, alpha: 0.08))
    ctx.fillEllipse(in: CGRect(x: (minX + maxX) / 2 - shadowWidth / 2, y: groundY - limb * 0.6 - S * 0.012,
                               width: shadowWidth, height: S * 0.024))

    // Far limbs first and lighter, then the torso, then near limbs on top.
    let f = anim.farSide ?? "l", n = f == "l" ? "r" : "l"
    stroke(["\(f)Hip", "\(f)Knee", "\(f)Ankle"], far, limb)
    stroke(["\(f)Shoulder", "\(f)Elbow", "\(f)Hand"], far, limb)

    // Torso: a thick capsule from the pelvis to the shoulders.
    let pelvis = CGPoint(x: (p("lHip").x + p("rHip").x) / 2, y: (p("lHip").y + p("rHip").y) / 2)
    let chest = CGPoint(x: (p("lShoulder").x + p("rShoulder").x) / 2, y: (p("lShoulder").y + p("rShoulder").y) / 2)
    ctx.setStrokeColor(near)
    ctx.setLineWidth(torsoWidth)
    ctx.beginPath(); ctx.move(to: pelvis); ctx.addLine(to: chest); ctx.strokePath()
    // Shoulder bar only when the shoulders are apart (front view); in side view they overlap.
    if hypot(p("lShoulder").x - p("rShoulder").x, p("lShoulder").y - p("rShoulder").y) > limb {
        stroke(["lShoulder", "rShoulder"], near, limb * 1.4)
    }

    stroke(["\(n)Hip", "\(n)Knee", "\(n)Ankle"], near, limb)
    stroke(["\(n)Shoulder", "\(n)Elbow", "\(n)Hand"], near, limb)

    // Head sits just beyond the neck, along the neck→head direction.
    let neck = p("neck"), headJ = p("head")
    let dx = headJ.x - neck.x, dy = headJ.y - neck.y, d = max(hypot(dx, dy), 1)
    let reach = max(headRadius * 1.45, d * 0.9)
    let center = CGPoint(x: neck.x + dx / d * reach, y: neck.y + dy / d * reach)
    ctx.setFillColor(near)
    ctx.fillEllipse(in: CGRect(x: center.x - headRadius, y: center.y - headRadius, width: headRadius * 2, height: headRadius * 2))
}

func makeContext() -> CGContext {
    CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
              space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)!
}

// Stills for review
for i in stride(from: 0, to: anim.frames.count, by: max(1, anim.frames.count / 12)) {
    let ctx = makeContext()
    draw(anim.frames[i], in: ctx)
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(stillsDir)/s\(String(format: "%03d", i)).png"))
}

// Video
try? FileManager.default.removeItem(at: outURL)
let writer = try! AVAssetWriter(outputURL: outURL, fileType: .mp4)
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: size, AVVideoHeightKey: size,
])
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB, kCVPixelBufferWidthKey as String: size,
    kCVPixelBufferHeightKey as String: size,
])
writer.add(input)
writer.startWriting()
writer.startSession(atSourceTime: .zero)
var frameIndex: Int64 = 0
for _ in 0..<loops {
    for J in anim.frames {
        while !input.isReadyForMoreMediaData { usleep(1000) }
        var buffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer)
        CVPixelBufferLockBaseAddress(buffer!, [])
        let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buffer!), width: size, height: size, bitsPerComponent: 8,
                            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer!), space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
        draw(J, in: ctx)
        CVPixelBufferUnlockBaseAddress(buffer!, [])
        adaptor.append(buffer!, withPresentationTime: CMTime(value: frameIndex, timescale: CMTimeScale(anim.fps)))
        frameIndex += 1
    }
}
input.markAsFinished()
let sem = DispatchSemaphore(value: 0)
writer.finishWriting { sem.signal() }
sem.wait()
print("wrote \(outURL.path): \(frameIndex) frames, status \(writer.status.rawValue)")
