import SpriteKit
import SwiftUI

/// The falling stones shared by Daily Review and This week (spec 10.2,
/// 10.4): `types` drop into a white and a black heap, which gather into
/// composite stones; `settled` turns true when they come to rest, so the
/// screen can fade in what comes after. No stones: settled at once.
struct StoneDropPile: View {
    let types: [StoneType]
    /// Read by VoiceOver, e.g. "Today's stones" or "This week's stones".
    let label: String
    let value: String
    @Binding var settled: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scene: StoneDropScene?
    @State private var feedback = StoneDropFeedback()

    static let height: CGFloat = 330

    var body: some View {
        Group {
            if types.isEmpty {
                Color.clear.frame(height: 0)
                    .onAppear { settled = true }
            } else {
                GeometryReader { proxy in
                    ZStack {
                        if let scene {
                            SpriteView(scene: scene, options: [.allowsTransparency])
                                // With Reduce Motion the heaps gather out of sight first.
                                .opacity(reduceMotion && !settled ? 0 : 1)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { scene?.skipToEnd() }
                    .onAppear { makeScene(size: proxy.size) }
                }
                .frame(height: Self.height)
                .accessibilityElement()
                .accessibilityLabel(label)
                .accessibilityValue(value)
                .accessibilityHint(settled ? "" : "Double-tap to skip.")
            }
        }
        .onAppear { scene?.isPaused = false }
        .onDisappear {
            // Leaving mid-fall: no more sound or taps from a screen that's gone.
            feedback.isMuted = true
            feedback.stop()
            scene?.isPaused = true
        }
    }

    private func makeScene(size: CGSize) {
        // Once per visit: coming back from an entry keeps the settled heaps.
        guard scene == nil, size.width > 0 else { return }
        feedback.prepare()
        let scene = StoneDropScene(types: types, size: size, feedback: feedback)
        scene.onSettled = {
            withAnimation(.easeIn(duration: reduceMotion ? 0.6 : 0.8)) {
                settled = true
            }
        }
        if reduceMotion {
            scene.dropAllQuietly()
        }
        self.scene = scene
    }
}

#if DEBUG
enum StoneDropDebug {
    /// For simulator checks: `-debug.dropCount 40` drops that many stones instead.
    static func override(_ types: [StoneType]) -> [StoneType] {
        let count = UserDefaults.standard.integer(forKey: "debug.dropCount")
        guard count > 0 else { return types }
        return (0..<count).map { $0 % 3 == 2 ? .black : .white }
    }
}
#endif
