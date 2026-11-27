import Foundation
import SwiftData

/// What Daily Review shows for one reflection day (spec 10): the stones in
/// the order they were logged, the mind check-ins, and the diary entry.
struct DailyReview {
    let day: Date
    /// Stone colours in logging order, earliest first: the order they fall.
    let stoneTypes: [StoneType]
    let checks: [MindCheck]
    let entry: JournalEntry?

    var whiteCount: Int { stoneTypes.filter { $0 == .white }.count }
    var blackCount: Int { stoneTypes.filter { $0 == .black }.count }

    /// "3 white · 1 black", as elsewhere in the app, or a quiet line for none.
    var tallyText: String {
        stoneTypes.isEmpty ? "No stones yet today." : "\(whiteCount) white · \(blackCount) black"
    }

    /// The reflection day `day` (03:00 to 03:00), read from the store.
    static func load(day: Date, in context: ModelContext) -> DailyReview {
        let interval = DateHelpers.reflectionDayInterval(forDay: day)
        let start = interval.start
        let end = interval.end
        let stones = context.fetchOrEmpty(FetchDescriptor<Stone>(
            predicate: #Predicate { $0.timestamp >= start && $0.timestamp < end },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        ))
        return DailyReview(
            day: day,
            stoneTypes: stones.map(\.type),
            checks: MindCheckStore.checks(onDay: day, in: context),
            entry: JournalStore.entry(forDay: day, in: context)
        )
    }

    /// Seconds between drops (spec 10.2): unhurried for a few stones, quicker
    /// for many, so the whole fall stays within about four seconds.
    static func dropInterval(forCount count: Int) -> TimeInterval {
        guard count > 1 else { return 0.55 }
        return min(0.55, max(0.05, 4.0 / Double(count)))
    }
}
