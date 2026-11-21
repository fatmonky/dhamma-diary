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

extension WidgetLog.Kind {
    /// Which half of the medium widget shows this tap's "Noted at …" line.
    var notedGroup: WidgetLogQueue.NotedGroup {
        self == .mind ? .mind : .stone
    }
}

enum WidgetLogQueue {
    static let queueKey = "widget.pendingLogs"
    /// The time of the last widget tap of any kind.
    static let lastNotedKey = "widget.lastNoted"
    /// The last check-in tap and the last stone tap, each for its own half
    /// of the medium widget.
    enum NotedGroup: String {
        case mind
        case stone

        var key: String { "widget.lastNoted.\(rawValue)" }
    }

    static func append(_ log: WidgetLog, defaults: UserDefaults = PassageSequence.sharedDefaults) {
        var logs = pending(defaults: defaults)
        logs.append(log)
        save(logs, defaults: defaults)
        defaults.set(log.timestamp.timeIntervalSinceReferenceDate, forKey: lastNotedKey)
        defaults.set(log.timestamp.timeIntervalSinceReferenceDate, forKey: log.kind.notedGroup.key)
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
        date(forKey: lastNotedKey, defaults: defaults)
    }

    static func lastNoted(_ group: NotedGroup, defaults: UserDefaults = PassageSequence.sharedDefaults) -> Date? {
        date(forKey: group.key, defaults: defaults)
    }

    private static func date(forKey key: String, defaults: UserDefaults) -> Date? {
        let value = defaults.double(forKey: key)
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
