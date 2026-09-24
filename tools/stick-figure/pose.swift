import AVFoundation
import Vision
import CoreImage
import Foundation

// Usage: pose <video> <out.json> <cropY> <cropHeight>
let args = CommandLine.arguments
let url = URL(fileURLWithPath: args[1])
let outURL = URL(fileURLWithPath: args[2])
let cropY = Double(args[3])!, cropH = Double(args[4])!

let joints: [VNHumanBodyPoseObservation.JointName] = [
    .nose, .neck, .leftShoulder, .rightShoulder, .leftElbow, .rightElbow, .leftWrist, .rightWrist,
    .root, .leftHip, .rightHip, .leftKnee, .rightKnee, .leftAnkle, .rightAnkle, .leftEar, .rightEar,
]

struct Frame: Codable { let t: Double; let joints: [String: [Double]] }  // name -> [x, y, confidence], y up, in crop pixels

let asset = AVURLAsset(url: url)
let sem = DispatchSemaphore(value: 0)
Task {
    let track = try await asset.loadTracks(withMediaType: .video).first!
    let size = try await track.load(.naturalSize)
    let reader = try AVAssetReader(asset: asset)
    let output = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
    reader.add(output)
    reader.startReading()
    let ci = CIContext()
    // CoreImage origin is bottom-left; crop is given from the top.
    let crop = CGRect(x: 0, y: Double(size.height) - cropY - cropH, width: Double(size.width), height: cropH)
    var frames: [Frame] = []
    var index = 0, detected = 0
    while let sample = output.copyNextSampleBuffer() {
        defer { index += 1 }
        guard index % 2 == 0, let buffer = CMSampleBufferGetImageBuffer(sample) else { continue }  // ~30 fps
        let t = CMSampleBufferGetPresentationTimeStamp(sample).seconds
        let image = CIImage(cvPixelBuffer: buffer).cropped(to: crop)
        let cg = ci.createCGImage(image, from: crop)!
        let request = VNDetectHumanBodyPoseRequest()
        try VNImageRequestHandler(cgImage: cg).perform([request])
        var map: [String: [Double]] = [:]
        if let obs = request.results?.max(by: { $0.confidence < $1.confidence }) {
            detected += 1
            for j in joints {
                if let p = try? obs.recognizedPoint(j), p.confidence > 0 {
                    map[j.rawValue.rawValue] = [p.location.x * crop.width, p.location.y * crop.height, Double(p.confidence)]
                }
            }
        }
        frames.append(Frame(t: t, joints: map))
    }
    let enc = JSONEncoder(); enc.outputFormatting = .sortedKeys
    try enc.encode(frames).write(to: outURL)
    print("frames \(frames.count), with a person \(detected), crop \(Int(crop.width))x\(Int(crop.height))")
    // Per-joint detection rate
    for j in joints {
        let name = j.rawValue.rawValue
        let hits = frames.filter { ($0.joints[name]?[2] ?? 0) > 0.3 }.count
        print(String(format: "%-22@ %3d%%", name as NSString, hits * 100 / max(frames.count, 1)))
    }
    sem.signal()
}
sem.wait()
