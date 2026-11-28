import CoreHaptics
import OSLog

/// A steady light buzz while sliding the stone (spec 9.6): strongest at
/// "Noisy Mind", tapering off to nothing at "Still".
@MainActor
final class NoiseHaptics {
    private var engine: CHHapticEngine?
    private var player: CHHapticAdvancedPatternPlayer?
    private let logger = Logger(subsystem: "com.whitestone.DhammaDiary", category: "haptics")

    /// Starts the buzz at the level for `noise` (0 still … 100 noisy).
    func start(noise: Double) {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            // Its own audio session, so Daily Review's `.ambient` sounds (and
            // the silent switch) never reach the slide's buzz.
            let engine = try self.engine ?? CHHapticEngine(audioSession: nil)
            engine.isAutoShutdownEnabled = true
            try engine.start()
            self.engine = engine
            // One long continuous event; its intensity follows the slide.
            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.35),
                ],
                relativeTime: 0,
                duration: 30
            )
            let player = try engine.makeAdvancedPlayer(with: CHHapticPattern(events: [event], parameters: []))
            self.player = player
            update(noise: noise)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            logger.error("Haptics failed to start: \(error.localizedDescription)")
        }
    }

    func update(noise: Double) {
        guard let player else { return }
        let control = CHHapticDynamicParameter(
            parameterID: .hapticIntensityControl,
            value: Float(Self.intensity(for: noise)),
            relativeTime: 0
        )
        try? player.sendParameters([control], atTime: CHHapticTimeImmediate)
    }

    func stop() {
        try? player?.stop(atTime: CHHapticTimeImmediate)
        player = nil
    }

    /// Light: at most 0.45 at fully noisy, easing to 0 at still.
    nonisolated static func intensity(for noise: Double) -> Double {
        let level = min(max(noise / 100, 0), 1)
        return 0.45 * level * level
    }
}
