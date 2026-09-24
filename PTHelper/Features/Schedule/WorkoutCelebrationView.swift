import SwiftUI

/// Celebration shown when every exercise in a routine is done: a little figure hops with a squash-and-stretch
/// bounce, sparkles and hearts pop out around it, and the title bounces in letter by letter.
/// Changing `trigger` replays the sparkle burst. Falls back to a static badge when Reduce Motion is on.
struct WorkoutCelebrationView: View {
    let trigger: Int
    let exerciseCount: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: PTSpacing.lg) {
            ZStack {
                if !reduceMotion {
                    ForEach(Sparkle.all) { sparkle in
                        SparkleView(sparkle: sparkle, trigger: trigger)
                    }
                }
                HoppingFigure(animated: !reduceMotion)
            }
            .frame(width: 260, height: 220)

            VStack(spacing: PTSpacing.sm) {
                BouncyTitle(text: "You did it!", animated: !reduceMotion)
                Text("\(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s") done — your body thanks you.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .ptEntrance(index: 6)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Hopping figure

private struct HoppingFigure: View {
    let animated: Bool

    private struct Pose {
        var squashX = 1.0
        var squashY = 1.0
        var lift = 0.0
        var tilt = Angle.zero
    }

    var body: some View {
        badge
            .keyframeAnimator(initialValue: Pose(), repeating: animated) { content, pose in
                content
                    .scaleEffect(x: pose.squashX, y: pose.squashY, anchor: .bottom)
                    .rotationEffect(pose.tilt)
                    .offset(y: pose.lift)
            } keyframes: { _ in
                // Two quick hops, a little spin on the third, then a rest before looping.
                KeyframeTrack(\.lift) {
                    CubicKeyframe(0, duration: 0.12)
                    SpringKeyframe(-46, duration: 0.28, spring: .snappy)
                    CubicKeyframe(0, duration: 0.22)
                    CubicKeyframe(0, duration: 0.12)
                    SpringKeyframe(-46, duration: 0.28, spring: .snappy)
                    CubicKeyframe(0, duration: 0.22)
                    CubicKeyframe(0, duration: 0.12)
                    SpringKeyframe(-70, duration: 0.36, spring: .snappy)
                    CubicKeyframe(0, duration: 0.3)
                    LinearKeyframe(0, duration: 1.4)
                }
                KeyframeTrack(\.squashY) {
                    CubicKeyframe(0.82, duration: 0.12)   // crouch
                    CubicKeyframe(1.12, duration: 0.28)   // stretch in the air
                    CubicKeyframe(0.88, duration: 0.14)   // land
                    SpringKeyframe(1.0, duration: 0.08)
                    CubicKeyframe(0.82, duration: 0.12)   // crouch
                    CubicKeyframe(1.12, duration: 0.28)   // stretch in the air
                    CubicKeyframe(0.88, duration: 0.14)   // land
                    SpringKeyframe(1.0, duration: 0.08)
                    CubicKeyframe(0.8, duration: 0.12)
                    CubicKeyframe(1.15, duration: 0.36)
                    CubicKeyframe(0.86, duration: 0.16)
                    SpringKeyframe(1.0, duration: 0.14, spring: .bouncy)
                    LinearKeyframe(1.0, duration: 1.4)
                }
                KeyframeTrack(\.squashX) {
                    CubicKeyframe(1.14, duration: 0.12)
                    CubicKeyframe(0.92, duration: 0.28)
                    CubicKeyframe(1.1, duration: 0.14)
                    SpringKeyframe(1.0, duration: 0.08)
                    CubicKeyframe(1.14, duration: 0.12)
                    CubicKeyframe(0.92, duration: 0.28)
                    CubicKeyframe(1.1, duration: 0.14)
                    SpringKeyframe(1.0, duration: 0.08)
                    CubicKeyframe(1.16, duration: 0.12)
                    CubicKeyframe(0.9, duration: 0.36)
                    CubicKeyframe(1.12, duration: 0.16)
                    SpringKeyframe(1.0, duration: 0.14, spring: .bouncy)
                    LinearKeyframe(1.0, duration: 1.4)
                }
                KeyframeTrack(\.tilt) {
                    LinearKeyframe(.degrees(-6), duration: 0.4)
                    LinearKeyframe(.degrees(6), duration: 0.44)
                    LinearKeyframe(.zero, duration: 0.12)
                    CubicKeyframe(.degrees(360), duration: 0.36)   // twirl on the big hop
                    LinearKeyframe(.degrees(360), duration: 1.7)
                }
            }
    }

    private var badge: some View {
        Image(systemName: "figure.arms.open")
            .font(.system(size: 56, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 120, height: 120)
            .glassEffect(.regular.tint(.ptSecondary), in: .circle)
    }
}

// MARK: - Sparkles

private struct Sparkle: Identifiable {
    let id: Int
    let symbol: String
    let color: Color
    let angle: Angle
    let distance: CGFloat
    let size: CGFloat
    let delay: Double

    static let all: [Sparkle] = {
        let symbols = ["sparkle", "heart.fill", "star.fill", "sparkle", "heart.fill"]
        let colors: [Color] = [.ptBrandSky, .ptAccent, .ptBrandMint, .yellow, .pink]
        // Evenly spaced around the circle, with small deterministic offsets so the burst looks hand-placed.
        return (0..<12).map { (i: Int) -> Sparkle in
            let degrees: Double = Double(i) * 30 + Double((i * 37) % 17)
            let distance: CGFloat = 92 + CGFloat((i * 29) % 30)
            let size: CGFloat = 14 + CGFloat((i * 13) % 10)
            let delay: Double = Double(i % 4) * 0.05
            return Sparkle(id: i, symbol: symbols[i % symbols.count], color: colors[i % colors.count],
                           angle: .degrees(degrees), distance: distance, size: size, delay: delay)
        }
    }()
}

private struct SparkleView: View {
    let sparkle: Sparkle
    let trigger: Int

    private struct Burst {
        var distance: CGFloat = 0
        var scale = 0.0
        var opacity = 0.0
        var spin = Angle.zero
    }

    var body: some View {
        Image(systemName: sparkle.symbol)
            .font(.system(size: sparkle.size, weight: .bold))
            .foregroundStyle(sparkle.color.gradient)
            .keyframeAnimator(initialValue: Burst(), trigger: trigger) { content, burst in
                content
                    .scaleEffect(burst.scale)
                    .rotationEffect(burst.spin)
                    .offset(x: cos(sparkle.angle.radians) * burst.distance,
                            y: sin(sparkle.angle.radians) * burst.distance)
                    .opacity(burst.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.distance) {
                    LinearKeyframe(0, duration: sparkle.delay)
                    SpringKeyframe(sparkle.distance, duration: 0.7, spring: .bouncy)
                    LinearKeyframe(sparkle.distance + 12, duration: 0.9)
                }
                KeyframeTrack(\.scale) {
                    LinearKeyframe(0, duration: sparkle.delay)
                    SpringKeyframe(1.25, duration: 0.35, spring: .bouncy)
                    CubicKeyframe(0.9, duration: 0.5)
                    CubicKeyframe(0.4, duration: 0.75)
                }
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(0, duration: sparkle.delay)
                    LinearKeyframe(1, duration: 0.12)
                    LinearKeyframe(1, duration: 0.9)
                    CubicKeyframe(0, duration: 0.58)
                }
                KeyframeTrack(\.spin) {
                    LinearKeyframe(.zero, duration: sparkle.delay)
                    CubicKeyframe(.degrees(sparkle.id.isMultiple(of: 2) ? 90 : -90), duration: 1.6)
                }
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Bouncy title

private struct BouncyTitle: View {
    let text: String
    let animated: Bool
    @State private var shown = false

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { index, character in
                Text(String(character))
                    .font(.ptSerif(.largeTitle, weight: .bold))
                    .foregroundStyle(index.isMultiple(of: 2) ? Color.ptAccent : Color.ptSecondary)
                    .offset(y: shown || !animated ? 0 : 36)
                    .scaleEffect(shown || !animated ? 1 : 0.4, anchor: .bottom)
                    .opacity(shown || !animated ? 1 : 0)
                    .animation(.spring(duration: 0.55, bounce: 0.6).delay(0.25 + Double(index) * 0.045),
                               value: shown)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
        .onAppear { shown = true }
    }
}

#Preview {
    WorkoutCelebrationView(trigger: 1, exerciseCount: 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { PTAmbientBackground().ignoresSafeArea() }
}
