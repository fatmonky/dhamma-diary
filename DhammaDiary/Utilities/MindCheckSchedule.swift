import Foundation

/// When the mind check-in notifications fire (spec 9.2): three a day, one at
/// a random moment in each of 9–13, 13–17 and 17–21, at least an hour apart.
enum MindCheckSchedule {
    /// Start and end hours of each window.
    static let windows: [(start: Int, end: Int)] = [(9, 13), (13, 17), (17, 21)]
    static let minimumGapMinutes = 60
    /// How many days ahead are kept scheduled.
    static let daysAhead = 7

    /// The three times for the calendar date `day`, earliest first.
    static func times<R: RandomNumberGenerator>(
        forDay day: Date,
        calendar: Calendar = .current,
        using generator: inout R
    ) -> [Date] {
        let start = calendar.startOfDay(for: day)
        var times: [Date] = []
        var earliestMinute = 0
        for window in windows {
            // Minutes after midnight; the gap can push the start later, but
            // a four-hour window always leaves room.
            let lower = max(window.start * 60, earliestMinute)
            let upper = window.end * 60
            let minute = Int.random(in: lower..<upper, using: &generator)
            earliestMinute = minute + minimumGapMinutes
            let hour = minute / 60
            times.append(calendar.date(bySettingHour: hour, minute: minute % 60, second: 0, of: start)!)
        }
        return times
    }

    struct Plan: Equatable {
        /// New notification times, earliest first, all after `now`.
        let times: [Date]
        /// The last calendar date now scheduled.
        let plannedThrough: Date
    }

    /// The days not yet scheduled, from today up to `daysAhead` days ahead.
    /// `plannedThrough` is the last day already scheduled, or nil when
    /// nothing is; today's times that have passed are left out.
    static func plan<R: RandomNumberGenerator>(
        now: Date,
        plannedThrough: Date?,
        calendar: Calendar = .current,
        using generator: inout R
    ) -> Plan {
        let today = calendar.startOfDay(for: now)
        let last = calendar.date(byAdding: .day, value: daysAhead - 1, to: today)!
        var day = today
        if let plannedThrough {
            let next = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: plannedThrough))!
            day = max(day, next)
        }
        var times: [Date] = []
        while day <= last {
            times += Self.times(forDay: day, calendar: calendar, using: &generator).filter { $0 > now }
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        let through = max(last, plannedThrough.map { calendar.startOfDay(for: $0) } ?? last)
        return Plan(times: times, plannedThrough: through)
    }
}
