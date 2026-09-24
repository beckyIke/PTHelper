import SwiftUI

/// Looping, thick-limbed stick figure demonstrating an exercise, drawn live from joint data.
/// Crops to the scene's own bounds, follows the app palette in light and dark mode,
/// and shows a single still pose when Reduce Motion is on.
struct ExerciseFigureView: View {
    let animation: ExerciseAnimation
    var isPlaying = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startDate = Date()

    var body: some View {
        let renderer = ExerciseFigureRenderer(animation: animation)
        TimelineView(.animation(paused: !isPlaying || reduceMotion)) { context in
            let position = reduceMotion
                ? Double(animation.stillFrame)
                : animation.framePosition(at: context.date.timeIntervalSince(startDate))
            Canvas { canvas, size in
                renderer.draw(atFrame: position, in: &canvas, size: size)
            }
        }
        .aspectRatio(renderer.frame.width / max(renderer.frame.height, 0.01), contentMode: .fit)
        .clipped()
        .accessibilityElement()
        .accessibilityLabel("Animation showing how to do \(animation.name)")
        .accessibilityAddTraits(.isImage)
    }
}

#Preview {
    if let animation = ExerciseAnimation.named("Bird Dog") {
        ExerciseFigureView(animation: animation)
            .padding()
            .ptGlass()
            .padding()
            .background { PTAmbientBackground().ignoresSafeArea() }
    }
}
