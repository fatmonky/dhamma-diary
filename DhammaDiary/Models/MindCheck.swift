import Foundation
import SwiftData

/// One answer to "How noisy is your mind now?" (spec 9.1).
@Model
final class MindCheck {
    var timestamp: Date
    /// "yyyy-MM-dd" of the reflection day (3am rule) of `timestamp`.
    var dayKey: String
    /// 0 = still, 100 = noisy.
    var noise: Double
    /// True when the check-in was opened from a notification.
    var prompted: Bool

    init(timestamp: Date = .now, noise: Double, prompted: Bool = false) {
        self.timestamp = timestamp
        self.dayKey = DateHelpers.reflectionDayKey(for: timestamp)
        self.noise = min(max(noise, 0), 100)
        self.prompted = prompted
    }
}
