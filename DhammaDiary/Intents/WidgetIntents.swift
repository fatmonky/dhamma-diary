import AppIntents
import Foundation

/// The check-in widget's buttons (spec 9.8). Compiled
/// into both the app and the widget; no SwiftData here, the app imports the
/// queue later.

struct LogMindCheckIntent: AppIntent {
    static let title: LocalizedStringResource = "Note how noisy your mind is"
    static let isDiscoverable = false

    @Parameter(title: "Noise", default: 50)
    var noise: Double

    init() {}

    init(noise: Double) {
        self.noise = noise
    }

    func perform() async throws -> some IntentResult {
        WidgetLogQueue.append(WidgetLog(kind: .mind, timestamp: .now, noise: min(max(noise, 0), 100)))
        return .result()
    }
}

struct LogStoneIntent: AppIntent {
    static let title: LocalizedStringResource = "Log a stone"
    static let isDiscoverable = false

    @Parameter(title: "White", default: true)
    var white: Bool

    init() {}

    init(white: Bool) {
        self.white = white
    }

    func perform() async throws -> some IntentResult {
        WidgetLogQueue.append(WidgetLog(kind: white ? .whiteStone : .blackStone, timestamp: .now))
        return .result()
    }
}

extension Notification.Name {
    /// Posted after widget taps were imported, so Today reloads its stones.
    static let widgetLogsImported = Notification.Name("DhammaDiary.widgetLogsImported")
}
