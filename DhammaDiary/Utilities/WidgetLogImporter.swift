import Foundation
import SwiftData

/// Turns queued widget taps into MindChecks and Stones (spec 9.8).
enum WidgetLogImporter {
    /// Ids already imported, kept in the app's own defaults so a record
    /// is never imported twice, even if removing it from the queue failed.
    static let importedIDsKey = "widget.importedLogIDs"
    private static let rememberedIDs = 500

    /// Returns how many records were imported.
    @discardableResult
    static func run(
        into context: ModelContext,
        shared: UserDefaults = PassageSequence.sharedDefaults,
        local: UserDefaults = .standard
    ) -> Int {
        let logs = WidgetLogQueue.pending(defaults: shared)
        guard !logs.isEmpty else { return 0 }

        var imported = local.stringArray(forKey: importedIDsKey) ?? []
        let alreadyImported = Set(imported)
        var count = 0
        for log in logs where !alreadyImported.contains(log.id.uuidString) {
            switch log.kind {
            case .mind:
                context.insert(MindCheck(timestamp: log.timestamp, noise: log.noise ?? 50))
            case .whiteStone:
                context.insert(Stone(type: .white, timestamp: log.timestamp))
            case .blackStone:
                context.insert(Stone(type: .black, timestamp: log.timestamp))
            }
            imported.append(log.id.uuidString)
            count += 1
        }
        do {
            try context.save()
        } catch {
            return 0
        }
        local.set(Array(imported.suffix(rememberedIDs)), forKey: importedIDsKey)
        WidgetLogQueue.remove(ids: Set(logs.map(\.id)), defaults: shared)
        return count
    }
}
