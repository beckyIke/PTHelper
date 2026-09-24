import AppKit
import SwiftUI
import ImageIO
import UniformTypeIdentifiers

// preview <animation.json | animation-directory> <output-directory> [--gifs]
// Uses the production renderer, including captions, props, close-ups and face-direction cues.
@MainActor
func snapshot(_ content: some View) throws -> CGImage {
    let renderer = ImageRenderer(content: content.environment(\.colorScheme, .light))
    renderer.scale = 1
    guard let image = renderer.cgImage else { throw CocoaError(.fileWriteUnknown) }
    return image
}

@MainActor
func stage(_ renderer: ExerciseFigureRenderer, frame: Int, width: CGFloat) -> some View {
    Canvas { context, size in
        renderer.draw(atFrame: Double(frame), in: &context, size: size)
    }.frame(width: width, height: width * renderer.frame.height / renderer.frame.width)
}

@MainActor
func run() throws {
    let args = CommandLine.arguments
    guard args.count >= 3 else {
        print("Usage: preview <json | directory> <output-directory> [--gifs]")
        return
    }
    let input = URL(fileURLWithPath: args[1]), output = URL(fileURLWithPath: args[2], isDirectory: true)
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    let files = input.pathExtension == "json" ? [input] : try FileManager.default.contentsOfDirectory(
        at: input, includingPropertiesForKeys: nil).filter { $0.pathExtension == "json" }.sorted { $0.path < $1.path }
    var rows: [AnyView] = []
    for file in files {
        let animation = try JSONDecoder().decode(ExerciseAnimation.self, from: Data(contentsOf: file))
        let renderer = ExerciseFigureRenderer(animation: animation)
        let slug = file.deletingPathExtension().lastPathComponent
        var samples = [0, animation.stillFrame]
        let starts = animation.cues.map(\.startFrame) + [animation.frames.count]
        let phases = animation.cues.indices.map { Int(Double(starts[$0]) + Double(starts[$0 + 1] - starts[$0]) * 0.65) }
        for i in 0..<4 {
            samples.append(phases.isEmpty ? animation.frames.count * (i + 1) / 5 : phases[(phases.count - 1) * i / 3])
        }
        samples = Array(Set(samples)).sorted()
        let content = VStack(alignment: .leading, spacing: 10) {
            Text(animation.name).font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
            HStack(alignment: .center, spacing: 10) {
                ForEach(samples, id: \.self) { frame in
                    let width = min(230, 240 * renderer.frame.width / renderer.frame.height)
                    stage(renderer, frame: frame, width: width).frame(width: 230, height: 240)
                }
            }
        }.padding(16).background(ExerciseFigureRenderer.fitnessBackground)
        let image = try snapshot(content)
        try NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
            .write(to: output.appendingPathComponent(slug + ".png"))
        rows.append(AnyView(content))
        if args.contains("--gifs") {
            // Ten frames per second retains the authored timing while keeping review files compact.
            let strideSize = max(1, Int(animation.fps / 10))
            let indices = Array(stride(from: 0, to: animation.frames.count, by: strideSize))
            let destination = CGImageDestinationCreateWithURL(output.appendingPathComponent(slug + ".gif") as CFURL,
                                                              UTType.gif.identifier as CFString, indices.count, nil)!
            CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
            for frame in indices {
                let image = try snapshot(stage(renderer, frame: frame, width: 320))
                CGImageDestinationAddImage(destination, image, [kCGImagePropertyGIFDictionary:
                    [kCGImagePropertyGIFDelayTime: Double(min(strideSize, animation.frames.count - frame)) / animation.fps]] as CFDictionary)
            }
            guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
        }
        print("Reviewed preview: \(animation.name)")
    }
    for start in stride(from: 0, to: rows.count, by: 6) {
        let group = Array(rows[start..<min(start + 6, rows.count)])
        let image = try snapshot(VStack(alignment: .leading, spacing: 8) {
            ForEach(group.indices, id: \.self) { group[$0] }
        }.background(ExerciseFigureRenderer.fitnessBackground))
        try NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
            .write(to: output.appendingPathComponent("review-\(start / 6 + 1).png"))
    }
}

try MainActor.assumeIsolated { try run() }
