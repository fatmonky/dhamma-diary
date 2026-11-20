import Foundation

/// The plain line under the day's mind chart and on Tonight (spec 9.3),
/// e.g. "3 check-ins today. Stillest at 2:10 PM, noisiest at 9:40 AM."
struct MindDaySummary: Equatable {
    struct Sample: Equatable {
        let timestamp: Date
        let noise: Double
    }

    let samples: [Sample]

    /// Nil when there are no check-ins; nothing is shown then.
    init?(samples: [Sample]) {
        guard !samples.isEmpty else { return nil }
        self.samples = samples.sorted { $0.timestamp < $1.timestamp }
    }

    init?(checks: [MindCheck]) {
        self.init(samples: checks.map { Sample(timestamp: $0.timestamp, noise: $0.noise) })
    }

    func text(time: (Date) -> String = DateHelpers.timeString(for:)) -> String {
        let count = samples.count
        if count == 1 {
            return "1 check-in today, at \(time(samples[0].timestamp))."
        }
        // The first of equal values wins, so the line stays stable.
        let stillest = samples.min { $0.noise < $1.noise }!
        let noisiest = samples.max { $0.noise < $1.noise }!
        if stillest.noise == noisiest.noise {
            return "\(count) check-ins today, all about the same."
        }
        return "\(count) check-ins today. Stillest at \(time(stillest.timestamp)), noisiest at \(time(noisiest.timestamp))."
    }

    /// Press-and-slide on Today's stone (spec 9.6): the press starts in
    /// between (50); sliding up `range` points is fully noisy (100), down
    /// `range` points fully still (0). `dy` is negative upwards.
    static func noise(forSlide dy: Double, range: Double) -> Double {
        guard range > 0 else { return 50 }
        return min(max(50 - dy / range * 50, 0), 100)
    }

    /// Words for a slider position, used on screen and by VoiceOver.
    static func word(for noise: Double) -> String {
        switch noise {
        case ..<20: return "Very still"
        case ..<40: return "Fairly still"
        case ..<60: return "In between"
        case ..<80: return "Fairly noisy"
        default: return "Very noisy"
        }
    }
}
