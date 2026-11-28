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
        case .palm: 0.9
        case .pile: 1.0
        case .clack: 0.6
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
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "debug.logContacts") {
            print("played \(contact.rawValue) at \(Date.now.timeIntervalSince1970)")
        }
        #endif
        // Never faint: even a gentle landing is clearly heard and felt
        // (PJ, 28 Nov: too weak on the phone).
        let level = contact.maxLevel * Float(0.6 + 0.4 * min(max(strength, 0), 1))

        if let player = players[contact]?.first(where: { !$0.isPlaying }) {
            player.volume = level
            // A little variation, so a run of landings doesn't sound copied.
            player.rate = Float.random(in: 0.92...1.08)
            player.currentTime = 0
            player.play()
        }

        guard let engine else { return }
        let events: [CHHapticEvent]
        switch contact {
        case .clack:
            // A small, crisp tick.
            events = [CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: level * 0.7),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: contact.sharpness),
                ],
                relativeTime: 0
            )]
        case .palm, .pile:
            // A landing: a full-strength knock, then a brief, heavy settle,
            // so each stone is felt arriving in the hand.
            let weight: Float = contact == .pile ? 1.0 : 0.75
            events = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: min(1, level * 1.1)),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: contact.sharpness),
                    ],
                    relativeTime: 0
                ),
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: level * weight * 0.8),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.05),
                    ],
                    relativeTime: 0.01,
                    duration: contact == .pile ? 0.09 : 0.06
                ),
            ]
        }
        do {
            try engine.start()
            let player = try engine.makePlayer(with: CHHapticPattern(events: events, parameters: []))
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
