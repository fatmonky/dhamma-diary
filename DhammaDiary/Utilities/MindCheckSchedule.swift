import Foundation

/// When the mind check-in notifications fire (spec 9.2): `perDay` a day
/// (1–6, three by default), one at a random moment in each of `perDay`
/// equal windows between 9am and 9pm, at least an hour apart. Three gives
/// the windows 9–13, 13–17 and 17–21.
enum MindCheckSchedule {
    static let firstMinute = 9 * 60
    static let lastMinute = 21 * 60
    static let perDayRange = 1...6
    static let defaultPerDay = 3
    static let minimumGapMinutes = 60
    /// How many days ahead are kept scheduled.
    static let daysAhead = 7

    /// Start and end of each window, in minutes after midnight.
    static func windows(perDay: Int) -> [(start: Int, end: Int)] {
        let count = min(max(perDay, perDayRange.lowerBound), perDayRange.upperBound)
        let length = (lastMinute - firstMinute) / count
        return (0..<count).map { i in
            (firstMinute + i * length, firstMinute + (i + 1) * length)
        }
    }

    /// The times for the calendar date `day`, earliest first.
    static func times<R: RandomNumberGenerator>(
        forDay day: Date,
        perDay: Int = defaultPerDay,
        calendar: Calendar = .current,
        using generator: inout R
    ) -> [Date] {
        let start = calendar.startOfDay(for: day)
        var times: [Date] = []
        var earliestMinute = 0
        for window in windows(perDay: perDay) {
            // The gap can push the start later, but every window (two hours
            // at six a day) is longer than the gap, so there's always room.
            let lower = max(window.start, earliestMinute)
            let upper = window.end
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
        perDay: Int = defaultPerDay,
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
            times += Self.times(forDay: day, perDay: perDay, calendar: calendar, using: &generator).filter { $0 > now }
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        let through = max(last, plannedThrough.map { calendar.startOfDay(for: $0) } ?? last)
        return Plan(times: times, plannedThrough: through)
    }
}
