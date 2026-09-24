import SwiftUI

// MARK: - Entrance

/// Fades, lifts and un-blurs content into place the first time it appears.
/// `index` staggers items in a group. Skipped when Reduce Motion is on.
private struct PTEntrance: ViewModifier {
    let index: Int
    @State private var isShown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(isShown || reduceMotion ? 1 : 0)
            .offset(y: isShown || reduceMotion ? 0 : 18)
            .blur(radius: isShown || reduceMotion ? 0 : 6)
            .onAppear {
                guard !isShown else { return }
                withAnimation(PTMotion.bouncy.delay(Double(index) * PTMotion.stagger)) { isShown = true }
            }
    }
}

extension View {
    func ptEntrance(index: Int = 0) -> some View {
        modifier(PTEntrance(index: index))
    }

    /// Cards shrink and fade slightly as they scroll toward the edges.
    func ptScrollTransition() -> some View {
        scrollTransition(.interactive, axis: .vertical) { content, phase in
            content
                .scaleEffect(phase.isIdentity ? 1 : 0.94)
                .opacity(phase.isIdentity ? 1 : 0.7)
        }
    }
}

// MARK: - Confetti

/// A one-shot burst of brand-colored confetti. Change `trigger` to fire it.
struct PTConfetti: View {
    let trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startDate: Date?

    private static let duration: Double = 2.6
    private static let pieces: [Piece] = (0..<70).map { _ in Piece() }

    var body: some View {
        TimelineView(.animation(paused: startDate == nil)) { context in
            Canvas { canvas, size in
                guard let startDate else { return }
                let elapsed = context.date.timeIntervalSince(startDate)
                guard elapsed < Self.duration else { return }
                for piece in Self.pieces {
                    draw(piece, elapsed: elapsed, in: &canvas, size: size)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: trigger) {
            guard !reduceMotion else { return }
            startDate = .now
            Task {
                try? await Task.sleep(for: .seconds(Self.duration))
                startDate = nil
            }
        }
    }

    private func draw(_ piece: Piece, elapsed t: Double, in canvas: inout GraphicsContext, size: CGSize) {
        // Launch upward from the bottom-center, then fall under gravity with a little flutter.
        let x = size.width / 2 + piece.velocity.dx * t + sin(t * piece.flutter) * 12
        let y = size.height * 0.9 + piece.velocity.dy * t + 900 * t * t
        let fade = max(0, 1 - t / Self.duration)
        var context = canvas
        context.opacity = fade
        context.translateBy(x: x, y: y)
        context.rotate(by: .radians(piece.spin * t))
        let rect = CGRect(x: -piece.size.width / 2, y: -piece.size.height / 2,
                          width: piece.size.width, height: piece.size.height)
        context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(piece.color))
    }

    private struct Piece {
        let velocity = CGVector(dx: .random(in: -260...260), dy: .random(in: -1150 ... -650))
        let spin = Double.random(in: -8...8)
        let flutter = Double.random(in: 4...9)
        let size = CGSize(width: .random(in: 6...11), height: .random(in: 10...16))
        let color = [Color.ptAccent, .ptSecondary, .ptBrandSky, .ptBrandMint, .ptAccentSoft, .yellow].randomElement()!
    }
}
