import AVFoundation
import AppKit

let url = URL(fileURLWithPath: CommandLine.arguments[1])
let out = CommandLine.arguments[2]
let asset = AVURLAsset(url: url)
let sem = DispatchSemaphore(value: 0)
Task {
    let duration = try await asset.load(.duration)
    let track = try await asset.loadTracks(withMediaType: .video).first!
    let size = try await track.load(.naturalSize)
    let fps = try await track.load(.nominalFrameRate)
    let transform = try await track.load(.preferredTransform)
    print("duration \(duration.seconds)s size \(size) fps \(fps) transform \(transform)")
    let gen = AVAssetImageGenerator(asset: asset)
    gen.appliesPreferredTrackTransform = true
    gen.requestedTimeToleranceBefore = .zero; gen.requestedTimeToleranceAfter = .zero
    for i in 0..<8 {
        let t = CMTime(seconds: duration.seconds * Double(i) / 8, preferredTimescale: 600)
        let (cg, _) = try await gen.image(at: t)
        let rep = NSBitmapImageRep(cgImage: cg)
        try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(out)/f\(i).png"))
    }
    sem.signal()
}
sem.wait()
