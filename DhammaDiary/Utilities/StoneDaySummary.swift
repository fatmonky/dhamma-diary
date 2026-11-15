import Foundation

/// The quiet, read-only stone summary at the top of the Diary's Tonight
/// screen (spec 4.2): one row per stone colour, with that colour's roots.
struct StoneDaySummary: Equatable {
    struct Row: Equatable {
        let type: StoneType
        let count: Int
        /// Root names (fixed and custom) in the order they first appear.
        let roots: [String]

        var countText: String { "\(count) \(type.rawValue)" }
    }

    let rows: [Row]

    /// e.g. "3 white · 1 black".
    var countsText: String {
        rows.map(\.countText).joined(separator: " · ")
    }

    /// Nil for a day with no stones; nothing is shown then.
    init?(stones: [Stone]) {
        let rows: [Row] = StoneType.allCases.compactMap { type in
            let ofType = stones.filter { $0.type == type }
            guard !ofType.isEmpty else { return nil }
            var roots: [String] = []
            for name in ofType.flatMap(\.rootDisplayNames) where !roots.contains(name) {
                roots.append(name)
            }
            return Row(type: type, count: ofType.count, roots: roots)
        }
        guard !rows.isEmpty else { return nil }
        self.rows = rows
    }
}
