import SwiftUI

/// The whole-screen particle noise behind Today while the stone is pressed
/// and slid (spec 9.6). `level` runs from 0 (still: nothing shown) to 1
/// (noisy: dense, restless particles). Never more than 50% opaque.
struct NoiseBackdrop: View {
    let level: Double

    private static let maxParticles = 520
    private static let maxOpacity = 0.5

    var body: some View {
        TimelineView(.animation(paused: level <= 0.001)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                // Restlessness and density both grow with the level.
                let count = Int(Double(Self.maxParticles) * level)
                let jitter = 2 + 16 * level
                let frame = Int(t * 24)
                for i in 0..<count {
                    let base = CGPoint(
                        x: Self.unit(i, 1) * size.width,
                        y: Self.unit(i, 2) * size.height
                    )
                    let drift = CGPoint(
                        x: sin(t * (0.6 + Self.unit(i, 3)) + Self.unit(i, 4) * 6.28) * 14 * level,
                        y: cos(t * (0.5 + Self.unit(i, 5)) + Self.unit(i, 6) * 6.28) * 14 * level
                    )
                    let shake = CGPoint(
                        x: (Self.unit(i &* 31 &+ frame, 7) - 0.5) * jitter,
                        y: (Self.unit(i &* 17 &+ frame, 8) - 0.5) * jitter
                    )
                    let radius = 0.8 + (1.4 + 1.2 * level) * Self.unit(i, 9)
                    let rect = CGRect(
                        x: base.x + drift.x + shake.x - radius,
                        y: base.y + drift.y + shake.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                    context.fill(Path(ellipseIn: rect), with: .color(.primary.opacity(0.4 + 0.6 * Self.unit(i, 10))))
                }
            }
        }
        .opacity(Self.maxOpacity * min(max(level, 0), 1))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// A stable pseudo-random number in 0..<1 for particle `i` and `salt`.
    private static func unit(_ i: Int, _ salt: Int) -> Double {
        var x = UInt64(truncatingIfNeeded: i) &* 0x9E3779B97F4A7C15 &+ UInt64(salt) &* 0xBF58476D1CE4E5B9
        x ^= x >> 31
        x = x &* 0x94D049BB133111EB
        x ^= x >> 29
        return Double(x % 10_000) / 10_000
    }
}
