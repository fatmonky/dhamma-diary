import AppIntents
import Foundation
import WidgetKit

/// The widget's buttons and the Control Center control (spec 9.8). Compiled
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
        // A Control Center tap doesn't refresh the widget by itself.
        WidgetCenter.shared.reloadTimelines(ofKind: "MindCheckIn")
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
        WidgetCenter.shared.reloadTimelines(ofKind: "MindCheckIn")
        return .result()
    }
}

/// Opens the app at Today, ready to slide the stone.
struct OpenTodayIntent: AppIntent {
    static let title: LocalizedStringResource = "Mind check-in"
    static let description = IntentDescription("Opens Today, ready to slide the stone.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        PassageSequence.sharedDefaults.set(true, forKey: WidgetLogQueue.openTodayKey)
        await MainActor.run {
            NotificationCenter.default.post(name: .openTodayRequested, object: nil)
        }
        return .result()
    }
}

extension Notification.Name {
    static let openTodayRequested = Notification.Name("DhammaDiary.openTodayRequested")
    /// Posted after widget taps were imported, so Today reloads its stones.
    static let widgetLogsImported = Notification.Name("DhammaDiary.widgetLogsImported")
}
