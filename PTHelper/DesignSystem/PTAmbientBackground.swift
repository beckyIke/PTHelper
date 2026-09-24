import SwiftUI

/// Slowly drifting sky-and-mint mesh gradient that sits behind every screen.
/// Glass needs color behind it to read as glass — a flat fill makes it look like plain white.
/// Static when Reduce Motion is on, and paused while off screen.
struct PTAmbientBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || !isVisible)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            MeshGradient(width: 3, height: 3, points: points(at: t), colors: colors)
        }
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
        .accessibilityHidden(true)
    }

    /// Interior and edge-midpoint control points drift on slow, out-of-phase loops; corners stay pinned.
    private func points(at t: Double) -> [SIMD2<Float>] {
        func drift(_ speed: Double, _ phase: Double, _ amount: Float) -> Float {
            Float(sin(t * speed + phase)) * amount
        }
        return [
            [0, 0], [0.5 + drift(0.21, 0, 0.12), 0], [1, 0],
            [0, 0.5 + drift(0.17, 1, 0.1)],
            [0.5 + drift(0.23, 2, 0.15), 0.5 + drift(0.19, 3, 0.15)],
            [1, 0.5 + drift(0.15, 4, 0.1)],
            [0, 1], [0.5 + drift(0.2, 5, 0.12), 1], [1, 1],
        ]
    }

    /// Sky blue drifts along the top and mint along the bottom, echoing the app icon's gradient.
    private var colors: [Color] {
        let base = Color.ptBackground
        if colorScheme == .dark {
            return [
                base, Color.ptBrandSky.mix(with: base, by: 0.7), base,
                Color.ptAccent.mix(with: base, by: 0.65), base, Color.ptBrandSky.mix(with: base, by: 0.8),
                base, Color.ptBrandMint.mix(with: base, by: 0.72), Color.ptSecondary.mix(with: base, by: 0.65),
            ]
        }
        return [
            base, Color.ptBrandSky.mix(with: base, by: 0.55), base,
            Color.ptBrandSky.mix(with: base, by: 0.7), base, Color.ptBrandMint.mix(with: base, by: 0.65),
            Color.ptBrandMint.mix(with: base, by: 0.55), base, Color.ptBrandMint.mix(with: base, by: 0.6),
        ]
    }
}
