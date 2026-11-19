import Foundation
import OSLog
import UserNotifications

/// The mind check-in notifications (spec 9.2). Local only: they're
/// scheduled on the phone and nothing is sent anywhere.
enum MindCheckNotifications {
    static let identifierPrefix = "mindcheck."
    static let enabledKey = "mindCheck.enabled"
    static let plannedThroughKey = "mindCheck.plannedThrough"
    static let question = "How noisy is your mind now?"

    enum Status: Equatable {
        case off
        case on
        /// Turned on in the app, but notifications are off in iOS Settings.
        case blocked
    }

    private static let logger = Logger(subsystem: "com.whitestone.DhammaDiary", category: "mindcheck")
    private static var defaults: UserDefaults { .standard }
    private static var center: UNUserNotificationCenter { .current() }

    static var isEnabled: Bool { defaults.bool(forKey: enabledKey) }

    static func status() async -> Status {
        guard isEnabled else { return .off }
        return await isAuthorized() ? .on : .blocked
    }

    /// Asks for permission if needed, then schedules the next week.
    @discardableResult
    static func start() async -> Status {
        defaults.set(true, forKey: enabledKey)
        defaults.removeObject(forKey: plannedThroughKey)
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            logger.error("Notification permission request failed: \(error.localizedDescription)")
        }
        await topUp()
        return await status()
    }

    static func stop() async {
        defaults.set(false, forKey: enabledKey)
        defaults.removeObject(forKey: plannedThroughKey)
        let pending = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)
    }

    /// Keeps the next `MindCheckSchedule.daysAhead` days scheduled. Called
    /// when the app becomes active.
    static func topUp(now: Date = .now) async {
        guard isEnabled, await isAuthorized() else { return }
        let plannedThrough = defaults.string(forKey: plannedThroughKey).flatMap(DateHelpers.date(from:))
        // If the app was away longer than the week ahead, start again from today.
        let stillAhead = plannedThrough.flatMap { $0 >= Calendar.current.startOfDay(for: now) ? $0 : nil }
        var generator = SystemRandomNumberGenerator()
        let plan = MindCheckSchedule.plan(now: now, plannedThrough: stillAhead, using: &generator)

        for time in plan.times {
            let content = UNMutableNotificationContent()
            content.body = question
            content.sound = .default
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: time)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: identifier(for: time), content: content, trigger: trigger)
            do {
                try await center.add(request)
            } catch {
                logger.error("Scheduling a check-in failed: \(error.localizedDescription)")
            }
        }
        defaults.set(DateHelpers.dayKey(for: plan.plannedThrough), forKey: plannedThroughKey)
    }

    /// e.g. "mindcheck.2026-11-20-1410". The same time always gets the same
    /// identifier, so scheduling twice replaces rather than doubles.
    static func identifier(for time: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: time)
        return identifierPrefix + DateHelpers.dayKey(for: time) + String(format: "-%02d%02d", c.hour ?? 0, c.minute ?? 0)
    }

    private static func isAuthorized() async -> Bool {
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }
}
