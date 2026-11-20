import Foundation

/// Check-ins and stones tapped on the widget, waiting for the app to import
/// them (spec 9.8). Lives in the App Group, so both the widget and the app
/// can reach it. Foundation only: the widget compiles this file too.
struct WidgetLog: Codable, Equatable, Identifiable {
    enum Kind: String, Codable {
        case mind
        case whiteStone
        case blackStone
    }

    var id = UUID()
    var kind: Kind
    var timestamp: Date
    /// 0 still … 100 noisy, for `.mind`.
    var noise: Double?
}

enum WidgetLogQueue {
    static let queueKey = "widget.pendingLogs"
    /// The time of the last widget tap, for its "Noted at …" line.
    static let lastNotedKey = "widget.lastNoted"
    /// Set by the Control Center control; the app opens Today and clears it.
    static let openTodayKey = "widget.openToday"

    static func append(_ log: WidgetLog, defaults: UserDefaults = PassageSequence.sharedDefaults) {
        var logs = pending(defaults: defaults)
        logs.append(log)
        save(logs, defaults: defaults)
        defaults.set(log.timestamp.timeIntervalSinceReferenceDate, forKey: lastNotedKey)
    }

    static func pending(defaults: UserDefaults = PassageSequence.sharedDefaults) -> [WidgetLog] {
        guard let data = defaults.data(forKey: queueKey) else { return [] }
        return (try? JSONDecoder().decode([WidgetLog].self, from: data)) ?? []
    }

    /// Removes only these records, so a tap that arrives during an import stays queued.
    static func remove(ids: Set<UUID>, defaults: UserDefaults = PassageSequence.sharedDefaults) {
        save(pending(defaults: defaults).filter { !ids.contains($0.id) }, defaults: defaults)
    }

    static func lastNoted(defaults: UserDefaults = PassageSequence.sharedDefaults) -> Date? {
        let value = defaults.double(forKey: lastNotedKey)
        return value > 0 ? Date(timeIntervalSinceReferenceDate: value) : nil
    }

    private static func save(_ logs: [WidgetLog], defaults: UserDefaults) {
        if logs.isEmpty {
            defaults.removeObject(forKey: queueKey)
        } else if let data = try? JSONEncoder().encode(logs) {
            defaults.set(data, forKey: queueKey)
        }
    }
}
