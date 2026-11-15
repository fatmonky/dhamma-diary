import XCTest
@testable import DhammaDiary

final class ReflectionDayTests: XCTestCase {
    private var newYork: Calendar!

    override func setUp() {
        super.setUp()
        newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = TimeZone(identifier: "America/New_York")!
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0, in calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func key(_ date: Date) -> String {
        DateHelpers.reflectionDayKey(for: date, calendar: newYork)
    }

    // MARK: - The 03:00 boundary

    func testTwoFiftyNineBelongsToThePreviousDay() {
        XCTAssertEqual(key(date(2026, 11, 15, 2, 59, in: newYork)), "2026-11-14")
    }

    func testThreeOClockBelongsToTheSameDay() {
        XCTAssertEqual(key(date(2026, 11, 15, 3, 0, in: newYork)), "2026-11-15")
    }

    func testMidnightBelongsToThePreviousDay() {
        XCTAssertEqual(key(date(2026, 11, 15, 0, 0, in: newYork)), "2026-11-14")
    }

    func testReflectionDayIsStartOfThatCalendarDate() {
        let day = DateHelpers.reflectionDay(for: date(2026, 11, 15, 1, 30, in: newYork), calendar: newYork)
        XCTAssertEqual(day, date(2026, 11, 14, in: newYork))
    }

    // MARK: - Intervals

    func testOneAMStoneOnThe15thIsInThe14thsInterval() {
        let oneAM = date(2026, 11, 15, 1, 0, in: newYork)
        let fourteenth = date(2026, 11, 14, in: newYork)

        let interval = DateHelpers.reflectionDayInterval(forDay: fourteenth, calendar: newYork)

        XCTAssertTrue(interval.contains(oneAM))
        XCTAssertEqual(interval.start, date(2026, 11, 14, 3, 0, in: newYork))
        XCTAssertEqual(interval.end, date(2026, 11, 15, 3, 0, in: newYork))
        XCTAssertEqual(DateHelpers.reflectionDayInterval(for: oneAM, calendar: newYork), interval)
    }

    func testIntervalEndIsExclusive() {
        let interval = DateHelpers.reflectionDayInterval(forDay: date(2026, 11, 14, in: newYork), calendar: newYork)
        let nextStart = date(2026, 11, 15, 3, 0, in: newYork)
        XCTAssertFalse(interval.start..<interval.end ~= nextStart)
    }

    func testStoneDayKeyUsesReflectionDay() {
        let calendar = Calendar.current
        let oneAM = date(2026, 11, 15, 1, 0, in: calendar)

        let stone = Stone(type: .white, timestamp: oneAM)

        XCTAssertEqual(stone.dayKey, "2026-11-14")
        stone.setTimestamp(date(2026, 11, 15, 3, 0, in: calendar))
        XCTAssertEqual(stone.dayKey, "2026-11-15")
    }

    // MARK: - Daylight saving (America/New_York, 2026)

    func testSpringForwardDayIntervalIsTwentyThreeHours() {
        // Clocks jump 02:00 → 03:00 on 8 March 2026; that night belongs to 7 March.
        let interval = DateHelpers.reflectionDayInterval(forDay: date(2026, 3, 7, in: newYork), calendar: newYork)

        XCTAssertEqual(interval.start, date(2026, 3, 7, 3, 0, in: newYork))
        XCTAssertEqual(interval.end, date(2026, 3, 8, 3, 0, in: newYork))
        XCTAssertEqual(interval.duration, 23 * 3600)
    }

    func testFallBackDayIntervalIsTwentyFiveHours() {
        // Clocks fall back 02:00 → 01:00 on 1 November 2026; that night belongs to 31 October.
        let interval = DateHelpers.reflectionDayInterval(forDay: date(2026, 10, 31, in: newYork), calendar: newYork)

        XCTAssertEqual(interval.start, date(2026, 10, 31, 3, 0, in: newYork))
        XCTAssertEqual(interval.end, date(2026, 11, 1, 3, 0, in: newYork))
        XCTAssertEqual(interval.duration, 25 * 3600)
    }

    func testJustAfterThreeOnSpringForwardMorningIsTheNewDay() {
        // Subtracting three elapsed hours would wrongly give 7 March here.
        XCTAssertEqual(key(date(2026, 3, 8, 3, 30, in: newYork)), "2026-03-08")
        XCTAssertEqual(key(date(2026, 3, 8, 1, 59, in: newYork)), "2026-03-07")
    }

    func testBothOneThirtiesOnFallBackMorningBelongToThePreviousDay() {
        let firstOneThirty = date(2026, 11, 1, 1, 30, in: newYork)  // EDT
        let secondOneThirty = firstOneThirty.addingTimeInterval(3600) // EST, same wall clock
        XCTAssertEqual(key(firstOneThirty), "2026-10-31")
        XCTAssertEqual(key(secondOneThirty), "2026-10-31")
        XCTAssertEqual(key(date(2026, 11, 1, 3, 0, in: newYork)), "2026-11-01")
    }

    func testMonthIntervalRunsFromThreeAMOnTheFirstToThreeAMOnTheNextFirst() {
        let interval = DateHelpers.reflectionMonthInterval(for: date(2026, 11, 20, in: newYork), calendar: newYork)
        XCTAssertEqual(interval.start, date(2026, 11, 1, 3, 0, in: newYork))
        XCTAssertEqual(interval.end, date(2026, 12, 1, 3, 0, in: newYork))
    }

    // MARK: - Pattern notes

    func testPatternCadenceGroupsLateNightStonesWithThePreviousDay() {
        // Five evenings, each with a stone at 23:00 and another at 01:00 the
        // next morning: ten calendar dates, but only five reflection days.
        // "Logging on most days" needs ten days, so it must not appear.
        let stones = [4, 6, 8, 10, 12].flatMap { day in
            [
                Stone(type: .white, timestamp: date(2026, 11, day, 23, 0, in: newYork)),
                Stone(type: .white, timestamp: date(2026, 11, day + 1, 1, 0, in: newYork)),
            ]
        }
        let now = date(2026, 11, 14, 12, 0, in: newYork)

        let observations = PatternEngine.observations(from: stones, now: now, calendar: newYork)

        XCTAssertFalse(observations.contains { $0.id == "cadence-most-days" })
    }

    func testPatternWindowIncludesTonightBeforeThreeAM() {
        // Ten nights with one stone each at 01:00 on the 6th…15th = reflection
        // days 5th…14th. At 02:00 on the 15th it is still the 14th, so all ten
        // count.
        let stones = (6...15).map { Stone(type: .white, timestamp: date(2026, 11, $0, 1, 0, in: newYork)) }
        let now = date(2026, 11, 15, 2, 0, in: newYork)

        let observations = PatternEngine.observations(from: stones, now: now, calendar: newYork)

        XCTAssertTrue(observations.contains { $0.id == "cadence-most-days" })
    }
}
