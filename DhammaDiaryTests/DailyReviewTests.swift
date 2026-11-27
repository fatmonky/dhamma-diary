import XCTest
import SwiftData
@testable import DhammaDiary

@MainActor
final class DailyReviewTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private let calendar = Calendar.current
    /// The calendar date of the reflection day under test.
    private let day = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 28))!

    override func setUp() async throws {
        container = try DhammaDiaryStore.makeContainer(inMemory: true)
        context = container.mainContext
    }

    override func tearDown() async throws {
        context = nil
        container = nil
    }

    private func at(_ hour: Int, _ minute: Int = 0, dayOffset: Int = 0) -> Date {
        let base = calendar.date(byAdding: .day, value: dayOffset, to: day)!
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: base)!
    }

    func testStonesInLoggingOrderWithinTheReflectionDay() throws {
        context.insert(Stone(type: .black, timestamp: at(14)))
        context.insert(Stone(type: .white, timestamp: at(9)))
        context.insert(Stone(type: .white, timestamp: at(2, 30, dayOffset: 1))) // 02:30 next morning: still this day
        context.insert(Stone(type: .black, timestamp: at(2, 59))) // before 03:00: the day before
        context.insert(Stone(type: .white, timestamp: at(3, 0, dayOffset: 1))) // 03:00 next morning: the next day
        try context.save()

        let review = DailyReview.load(day: day, in: context)
        XCTAssertEqual(review.stoneTypes, [.white, .black, .white])
        XCTAssertEqual(review.whiteCount, 2)
        XCTAssertEqual(review.blackCount, 1)
        XCTAssertEqual(review.tallyText, "2 white · 1 black")
    }

    func testNoStones() {
        let review = DailyReview.load(day: day, in: context)
        XCTAssertTrue(review.stoneTypes.isEmpty)
        XCTAssertEqual(review.tallyText, "No stones yet today.")
        XCTAssertNil(review.entry)
        XCTAssertTrue(review.checks.isEmpty)
    }

    func testMindChecksAndEntryForTheDay() throws {
        context.insert(MindCheck(timestamp: at(10), noise: 70, prompted: false))
        context.insert(MindCheck(timestamp: at(1, dayOffset: 1), noise: 20, prompted: false))
        context.insert(MindCheck(timestamp: at(23, dayOffset: -1), noise: 50, prompted: false))
        context.insert(JournalEntry(
            day: day, passageID: "an10.51-mirror", passageRef: "AN 10.51", passageTitle: "Your Own Mind",
            question: "What did you notice?", responseText: "A quiet day.", createdAt: at(21)
        ))
        context.insert(JournalEntry(
            day: calendar.date(byAdding: .day, value: -1, to: day)!, passageID: "mn19", passageRef: "MN 19",
            passageTitle: "Two Kinds of Thought", question: "?", responseText: "Yesterday.", createdAt: at(21, dayOffset: -1)
        ))
        try context.save()

        let review = DailyReview.load(day: day, in: context)
        XCTAssertEqual(review.checks.map(\.noise), [70, 20])
        XCTAssertEqual(review.entry?.responseText, "A quiet day.")
    }

    func testDropIntervalKeepsTheFallShort() {
        XCTAssertEqual(DailyReview.dropInterval(forCount: 1), 0.55)
        XCTAssertEqual(DailyReview.dropInterval(forCount: 5), 0.55)
        XCTAssertEqual(DailyReview.dropInterval(forCount: 20), 0.2, accuracy: 0.0001)
        XCTAssertEqual(DailyReview.dropInterval(forCount: 100), 0.05)
        XCTAssertEqual(DailyReview.dropInterval(forCount: 70) * 70, 4.0, accuracy: 0.001)
        for count in [8, 15, 33, 60] {
            XCTAssertLessThanOrEqual(DailyReview.dropInterval(forCount: count) * Double(count), 4.4)
        }
    }
}
