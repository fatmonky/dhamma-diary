import Foundation

/// The week's look-back (spec 8.3): Monday to Sunday in reflection days,
/// containing the current reflection day.
struct WeekLookBack {
    struct Day: Identifiable {
        /// Start of the calendar date (a reflection day).
        let date: Date
        let white: Int
        let black: Int
        let entry: JournalEntry?

        var id: Date { date }
    }

    struct RootCount: Equatable {
        let name: String
        let count: Int
    }

    /// Monday of the week.
    let monday: Date
    /// Monday up to the current day; later days aren't shown.
    let days: [Day]
    let white: Int
    let black: Int
    /// Most frequent first; ties keep the order they first appeared.
    let roots: [RootCount]

    /// Builds the week from stones and entries already fetched for it.
    init(currentDay: Date, stones: [Stone], entries: [JournalEntry], calendar: Calendar = .current) {
        let monday = Self.monday(of: currentDay, calendar: calendar)
        let today = calendar.startOfDay(for: currentDay)
        self.monday = monday

        var stonesByKey: [String: [Stone]] = [:]
        for stone in stones {
            stonesByKey[DateHelpers.reflectionDayKey(for: stone.timestamp, calendar: calendar), default: []].append(stone)
        }
        var entriesByKey: [String: JournalEntry] = [:]
        for entry in entries {
            entriesByKey[DateHelpers.dayKey(forDay: entry.day, calendar: calendar)] = entry
        }

        var days: [Day] = []
        var date = monday
        while date <= today, days.count < 7 {
            let key = DateHelpers.dayKey(forDay: date, calendar: calendar)
            let dayStones = stonesByKey[key] ?? []
            days.append(Day(
                date: date,
                white: dayStones.filter { $0.type == .white }.count,
                black: dayStones.filter { $0.type == .black }.count,
                entry: entriesByKey[key]
            ))
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        self.days = days

        let weekKeys = Set(days.map { DateHelpers.dayKey(forDay: $0.date, calendar: calendar) })
        let weekStones = stonesByKey.filter { weekKeys.contains($0.key) }.values.flatMap { $0 }
            .sorted { $0.timestamp < $1.timestamp }
        white = weekStones.filter { $0.type == .white }.count
        black = weekStones.filter { $0.type == .black }.count

        var order: [String] = []
        var counts: [String: Int] = [:]
        for name in weekStones.flatMap(\.rootDisplayNames) {
            if counts[name] == nil { order.append(name) }
            counts[name, default: 0] += 1
        }
        roots = order.enumerated()
            .sorted { a, b in
                let (ca, cb) = (counts[a.element]!, counts[b.element]!)
                return ca != cb ? ca > cb : a.offset < b.offset
            }
            .map { RootCount(name: $0.element, count: counts[$0.element]!) }
    }

    /// Monday of the week containing the calendar date `day`.
    static func monday(of day: Date, calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: day)
        let weekday = calendar.component(.weekday, from: start) // 1 = Sunday … 7 = Saturday
        let back = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -back, to: start)!
    }

    /// Whether the calendar date `day` is a Sunday.
    static func isSunday(_ day: Date, calendar: Calendar = .current) -> Bool {
        calendar.component(.weekday, from: day) == 1
    }

    /// Reflection-day interval for stones, Monday to the current day.
    static func stoneInterval(currentDay: Date, calendar: Calendar = .current) -> DateInterval {
        let monday = monday(of: currentDay, calendar: calendar)
        let count = (calendar.dateComponents([.day], from: monday, to: calendar.startOfDay(for: currentDay)).day ?? 0) + 1
        return DateHelpers.reflectionInterval(fromDay: monday, days: count, calendar: calendar)
    }

    /// Calendar-date interval for entries (whose `day` is a start of day).
    static func entryInterval(currentDay: Date, calendar: Calendar = .current) -> DateInterval {
        let monday = monday(of: currentDay, calendar: calendar)
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: currentDay))!
        return DateInterval(start: monday, end: end)
    }

    /// "9–15 November", or "27 October – 2 November" across months.
    var rangeText: String {
        Self.rangeText(monday: monday)
    }

    static func rangeText(monday: Date, calendar: Calendar = .current) -> String {
        let sunday = calendar.date(byAdding: .day, value: 6, to: monday)!
        let day = DateFormatter()
        day.calendar = calendar
        day.timeZone = calendar.timeZone
        day.dateFormat = "d"
        let dayMonth = DateFormatter()
        dayMonth.calendar = calendar
        dayMonth.timeZone = calendar.timeZone
        dayMonth.dateFormat = "d MMMM"
        if calendar.isDate(monday, equalTo: sunday, toGranularity: .month) {
            return "\(day.string(from: monday))–\(dayMonth.string(from: sunday))"
        }
        return "\(dayMonth.string(from: monday)) – \(dayMonth.string(from: sunday))"
    }
}
