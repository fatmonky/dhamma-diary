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
