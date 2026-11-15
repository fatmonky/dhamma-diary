import Foundation

/// Which passage belongs to which reflection day (spec 3.4).
///
/// The user's first reflection day is stored once, and tonight's passage is
/// the number of days since then, wrapping around the set. It advances
/// whether or not the app is opened.
enum PassageSequence {
    static let firstDayStorageKey = "sequence.firstDay"

    /// Shared with the widget (spec 8.4).
    static let appGroup = "group.com.whitestone.DhammaDiary"

    /// Where the first day is stored: the App Group, so the widget can read
    /// it. Falls back to the app's own defaults if the group is unavailable.
    static let sharedDefaults: UserDefaults = UserDefaults(suiteName: appGroup) ?? .standard

    /// Copies a first day stored before the App Group existed into the
    /// shared store, once, so an update doesn't restart the sequence.
    static func moveFirstDayToSharedStore(from old: UserDefaults = .standard, to shared: UserDefaults = sharedDefaults) {
        guard shared.string(forKey: firstDayStorageKey) == nil,
              let value = old.string(forKey: firstDayStorageKey) else { return }
        shared.set(value, forKey: firstDayStorageKey)
    }

    /// Index into the passage set for `currentDay`. Both are calendar dates
    /// (reflection days). A negative day count (clock set back) gives 0.
    static func index(
        firstDay: Date,
        currentDay: Date,
        passageCount: Int,
        calendar: Calendar = .current
    ) -> Int {
        guard passageCount > 0 else { return 0 }
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: firstDay),
            to: calendar.startOfDay(for: currentDay)
        ).day ?? 0
        guard days > 0 else { return 0 }
        return days % passageCount
    }

    /// Stores today's reflection day as the first day, unless one is already
    /// stored. Returns the stored first day.
    @discardableResult
    static func recordFirstDayIfNeeded(
        now: Date = .now,
        defaults: UserDefaults = sharedDefaults,
        calendar: Calendar = .current
    ) -> Date {
        if let stored = firstDay(defaults: defaults, calendar: calendar) {
            return stored
        }
        let day = DateHelpers.reflectionDay(for: now, calendar: calendar)
        defaults.set(DateHelpers.dayKey(forDay: day, calendar: calendar), forKey: firstDayStorageKey)
        return day
    }

    static func firstDay(defaults: UserDefaults = sharedDefaults, calendar: Calendar = .current) -> Date? {
        guard let key = defaults.string(forKey: firstDayStorageKey) else { return nil }
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// Tonight's passage: the one for the current reflection day.
    static func passage(
        for currentDay: Date = DateHelpers.currentReflectionDay,
        in set: PassageSet = .bundled,
        defaults: UserDefaults = sharedDefaults,
        calendar: Calendar = .current
    ) -> Passage? {
        guard !set.passages.isEmpty else { return nil }
        let first = recordFirstDayIfNeeded(defaults: defaults, calendar: calendar)
        let i = index(firstDay: first, currentDay: currentDay, passageCount: set.passages.count, calendar: calendar)
        return set.passages[i]
    }
}
