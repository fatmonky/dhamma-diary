import AVFoundation
import CoreHaptics
import OSLog

/// The three kinds of contact in Daily Review's pile (spec 10.2).
enum StoneContact: String, CaseIterable {
    /// The first stone onto the empty palm: soft and fleshy.
    case palm
    /// A stone landing on the pile: heavier and duller.
    case pile
    /// Stones touching afterwards: a light clack.
    case clack

    var fileName: String { "stone-\(rawValue)" }

    /// Core Haptics sharpness: dull for the palm and pile, crisp for a clack.
    var sharpness: Float {
        switch self {
        case .palm: 0.25
        case .pile: 0.12
        case .clack: 0.75
        }
    }

    /// The loudest each contact gets, before scaling by impact.
    var maxLevel: Float {
        switch self {
        case .palm: 0.8
        case .pile: 1.0
        case .clack: 0.45
        }
    }
}

/// Sound and a haptic tap for each contact, scaled by how hard it was.
/// Sounds use the `.ambient` session: the silent switch mutes them and
/// other audio keeps playing.
@MainActor
final class StoneDropFeedback {
    private var players: [StoneContact: [AVAudioPlayer]] = [:]
    private var engine: CHHapticEngine?
    private let logger = Logger(subsystem: "com.whitestone.DhammaDiary", category: "dailyReview")

    /// Off while skipping or with Reduce Motion: the pile settles silently.
    var isMuted = false

    func prepare() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            logger.error("Audio session failed: \(error.localizedDescription)")
        }
        for contact in StoneContact.allCases where players[contact] == nil {
            guard let url = Bundle.main.url(forResource: contact.fileName, withExtension: "wav") else {
                logger.error("Missing sound \(contact.fileName)")
                continue
            }
            // A few of each, so close contacts can overlap.
            players[contact] = (0..<4).compactMap { _ in
                let player = try? AVAudioPlayer(contentsOf: url)
                player?.enableRate = true
                player?.prepareToPlay()
                return player
            }
        }
        if CHHapticEngine.capabilitiesForHardware().supportsHaptics, engine == nil {
            do {
                let engine = try CHHapticEngine()
                engine.isAutoShutdownEnabled = true
                engine.playsHapticsOnly = true
                try engine.start()
                self.engine = engine
            } catch {
                logger.error("Haptics failed to start: \(error.localizedDescription)")
            }
        }
    }

    /// `strength` is 0…1, from the impact speed.
    func play(_ contact: StoneContact, strength: Double) {
        guard !isMuted else { return }
        let level = contact.maxLevel * Float(0.35 + 0.65 * min(max(strength, 0), 1))

        if let player = players[contact]?.first(where: { !$0.isPlaying }) {
            player.volume = level
            // A little variation, so a run of landings doesn't sound copied.
            player.rate = Float.random(in: 0.92...1.08)
            player.currentTime = 0
            player.play()
        }

        guard let engine else { return }
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: contact == .clack ? level * 0.6 : level),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: contact.sharpness),
            ],
            relativeTime: 0
        )
        do {
            try engine.start()
            let player = try engine.makePlayer(with: CHHapticPattern(events: [event], parameters: []))
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            logger.error("Haptic tap failed: \(error.localizedDescription)")
        }
    }

    func stop() {
        engine?.stop()
        engine = nil
    }
}
