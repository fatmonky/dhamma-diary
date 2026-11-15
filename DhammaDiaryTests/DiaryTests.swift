import XCTest
import SwiftData
@testable import DhammaDiary

final class StoneDaySummaryTests: XCTestCase {
    func testNoStonesGivesNoSummary() {
        XCTAssertNil(StoneDaySummary(stones: []))
    }

    func testCountsWhiteThenBlack() throws {
        let stones = [
            Stone(type: .black, roots: [.illWill]),
            Stone(type: .white, roots: [.kindness]),
            Stone(type: .white),
            Stone(type: .white, roots: [.renunciation, .kindness]),
        ]

        let summary = try XCTUnwrap(StoneDaySummary(stones: stones))

        XCTAssertEqual(summary.countsText, "3 white · 1 black")
        XCTAssertEqual(summary.rows.map(\.type), [.white, .black])
        XCTAssertEqual(summary.rows[0].roots, ["kindness", "renunciation"])
        XCTAssertEqual(summary.rows[1].roots, ["ill will"])
    }

    func testOnlyOneColourShowsOneRow() throws {
        let summary = try XCTUnwrap(StoneDaySummary(stones: [Stone(type: .black)]))
        XCTAssertEqual(summary.countsText, "1 black")
        XCTAssertEqual(summary.rows[0].roots, [])
    }

    func testCustomRootsAreIncluded() throws {
        let stone = Stone(type: .white, roots: [.kindness], rootDescriptor: "patience")
        let summary = try XCTUnwrap(StoneDaySummary(stones: [stone]))
        XCTAssertEqual(summary.rows[0].roots, ["kindness", "patience"])
    }
}

@MainActor
final class PassageGroupTests: XCTestCase {
    private func entry(_ passageID: String, title: String, daysAgo: Int) -> JournalEntry {
        let day = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Calendar.current.startOfDay(for: .now))!
        return JournalEntry(day: day, passageID: passageID, passageRef: passageID.uppercased(), passageTitle: title, question: "Q", responseText: "T")
    }

    func testGroupsByPassageNewestFirstWithNewestHeading() {
        // Already sorted newest first, as PassagesView fetches them.
        let entries = [
            entry("mn19", title: "Two Kinds of Thought", daysAgo: 1),
            entry("an10.51", title: "Your Own Mind (renamed)", daysAgo: 2),
            entry("mn19", title: "Two Kinds of Thought", daysAgo: 14),
            entry("an10.51", title: "Your Own Mind", daysAgo: 15),
        ]

        let groups = PassageGroup.groups(from: entries)

        XCTAssertEqual(groups.map(\.id), ["mn19", "an10.51"])
        XCTAssertEqual(groups.map(\.entries.count), [2, 2])
        XCTAssertEqual(groups[1].title, "Your Own Mind (renamed)")
    }
}

final class StonePromptTests: XCTestCase {
    func testBothColours() throws {
        let stones = [Stone(type: .white), Stone(type: .white), Stone(type: .black)]
        XCTAssertEqual(try XCTUnwrap(StoneDaySummary(stones: stones)).promptText,
                       "You had 2 white stones and 1 black stone today. What was happening?")
    }

    func testOneColourLeavesTheOtherOut() throws {
        XCTAssertEqual(try XCTUnwrap(StoneDaySummary(stones: [Stone(type: .white), Stone(type: .white)])).promptText,
                       "You had 2 white stones today. What was happening?")
        XCTAssertEqual(try XCTUnwrap(StoneDaySummary(stones: [Stone(type: .black)])).promptText,
                       "You had 1 black stone today. What was happening?")
    }
}

@MainActor
final class WeekLookBackTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
    }

    private func date(_ day: Int, _ hour: Int = 0, month: Int = 11) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    func testMondayOfTheWeek() {
        // 15 November 2026 is a Sunday; 9 November the Monday before.
        XCTAssertEqual(WeekLookBack.monday(of: date(15), calendar: calendar), date(9))
        XCTAssertEqual(WeekLookBack.monday(of: date(9), calendar: calendar), date(9))
        XCTAssertEqual(WeekLookBack.monday(of: date(12), calendar: calendar), date(9))
        XCTAssertTrue(WeekLookBack.isSunday(date(15), calendar: calendar))
        XCTAssertFalse(WeekLookBack.isSunday(date(14), calendar: calendar))
    }

    func testDaysRunFromMondayToTheCurrentDay() {
        let week = WeekLookBack(currentDay: date(11), stones: [], entries: [], calendar: calendar)
        XCTAssertEqual(week.days.map(\.date), [date(9), date(10), date(11)])
    }

    func testStonesGroupByReflectionDayAndRootsByFrequency() {
        let stones = [
            Stone(type: .white, timestamp: date(10, 21), roots: [.kindness]),
            Stone(type: .black, timestamp: date(11, 1), roots: [.illWill]), // 01:00 on the 11th is the 10th
            Stone(type: .black, timestamp: date(12, 20), roots: [.illWill]),
            Stone(type: .white, timestamp: date(8, 20), roots: [.renunciation]), // the week before
        ]
        let week = WeekLookBack(currentDay: date(15), stones: stones, entries: [], calendar: calendar)

        XCTAssertEqual(week.white, 1)
        XCTAssertEqual(week.black, 2)
        XCTAssertEqual(week.roots, [.init(name: "ill will", count: 2), .init(name: "kindness", count: 1)])
        let tuesday = week.days[1]
        XCTAssertEqual(tuesday.white, 1)
        XCTAssertEqual(tuesday.black, 1)
    }

    func testRangeText() {
        XCTAssertEqual(WeekLookBack.rangeText(monday: date(9), calendar: calendar), "9–15 November")
        XCTAssertEqual(WeekLookBack.rangeText(monday: date(26, month: 10), calendar: calendar), "26 October – 1 November")
    }
}
