import XCTest
@testable import DhammaDiary

final class PassageSetTests: XCTestCase {
    private var set: PassageSet!

    override func setUpWithError() throws {
        set = try PassageSet.load(from: .main)
    }

    func testBundledFileDecodes() {
        XCTAssertEqual(set.formatVersion, 1)
        XCTAssertEqual(set.source.repo, "suttacentral/bilara-data")
        XCTAssertEqual(set.source.branch, "published")
        XCTAssertEqual(set.source.translator, "sujato")
        XCTAssertFalse(set.source.commit.isEmpty)
        XCTAssertEqual(set.passages.count, 13)
    }

    func testIDsAreUnique() {
        let ids = set.passages.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testEveryPassageHasTextAndAQuestion() {
        for passage in set.passages {
            XCTAssertFalse(passage.blocks.isEmpty, passage.id)
            XCTAssertEqual(passage.blocks.count, passage.ranges.count, passage.id)
            XCTAssertTrue(passage.blocks.allSatisfy { !$0.isEmpty && $0.allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty } }, passage.id)
            XCTAssertFalse(passage.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, passage.id)
            XCTAssertFalse(passage.title.isEmpty, passage.id)
            XCTAssertEqual(passage.url.host, "suttacentral.net", passage.id)
        }
    }

    func testFirstPassageIsAN1051() {
        let first = set.passages.first
        XCTAssertEqual(first?.id, "an10.51-mirror")
        XCTAssertEqual(first?.ref, "AN 10.51")
        XCTAssertEqual(first?.title, "Your Own Mind")
    }

    func testJournalCopyCarriesPassageDetails() {
        let passage = set.passages[0]
        XCTAssertEqual(
            passage.journalCopy,
            JournalPassageCopy(passageID: passage.id, passageRef: passage.ref, passageTitle: passage.title, question: passage.question)
        )
    }

    func testBundledSetMatchesLoadedFile() {
        XCTAssertEqual(PassageSet.bundled, set)
    }
}

final class PassageSequenceTests: XCTestCase {
    private var calendar: Calendar!
    private var defaults: UserDefaults!
    private let suiteName = "PassageSequenceTests"

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func day(_ month: Int, _ day: Int, _ hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    private func index(daysAfter offset: Int, count: Int = 13) -> Int {
        let first = day(11, 1)
        let current = calendar.date(byAdding: .day, value: offset, to: first)!
        return PassageSequence.index(firstDay: first, currentDay: current, passageCount: count, calendar: calendar)
    }

    func testDayZeroIsPassageOne() {
        XCTAssertEqual(index(daysAfter: 0), 0)
    }

    func testDayTwelveIsPassageThirteen() {
        XCTAssertEqual(index(daysAfter: 12), 12)
    }

    func testDayThirteenWrapsToPassageOne() {
        XCTAssertEqual(index(daysAfter: 13), 0)
    }

    func testNegativeDaysGivePassageOne() {
        XCTAssertEqual(index(daysAfter: -5), 0)
    }

    func testWorksWithAnyPassageCount() {
        XCTAssertEqual(index(daysAfter: 40, count: 30), 10)
        XCTAssertEqual(index(daysAfter: 3, count: 0), 0)
    }

    func testCountsWholeDaysAcrossDaylightSaving() {
        // 1 November 2026 is a 25-hour day in New York.
        let first = day(10, 31)
        XCTAssertEqual(PassageSequence.index(firstDay: first, currentDay: day(11, 1), passageCount: 13, calendar: calendar), 1)
        XCTAssertEqual(PassageSequence.index(firstDay: first, currentDay: day(11, 2), passageCount: 13, calendar: calendar), 2)
    }

    func testFirstDayIsStoredOnceAsReflectionDay() {
        // 01:00 on the 15th is still the 14th's reflection day.
        let stored = PassageSequence.recordFirstDayIfNeeded(now: day(11, 15, 1), defaults: defaults, calendar: calendar)
        XCTAssertEqual(stored, day(11, 14))
        XCTAssertEqual(defaults.string(forKey: PassageSequence.firstDayStorageKey), "2026-11-14")

        let later = PassageSequence.recordFirstDayIfNeeded(now: day(12, 20, 12), defaults: defaults, calendar: calendar)
        XCTAssertEqual(later, day(11, 14))
        XCTAssertEqual(defaults.string(forKey: PassageSequence.firstDayStorageKey), "2026-11-14")
    }

    func testFirstNightShowsTheFirstPassage() throws {
        let set = try PassageSet.load(from: .main)
        PassageSequence.recordFirstDayIfNeeded(now: day(11, 15, 21), defaults: defaults, calendar: calendar)

        let tonight = PassageSequence.passage(for: day(11, 15), in: set, defaults: defaults, calendar: calendar)
        let tomorrow = PassageSequence.passage(for: day(11, 16), in: set, defaults: defaults, calendar: calendar)

        XCTAssertEqual(tonight?.id, "an10.51-mirror")
        XCTAssertEqual(tomorrow?.id, "mn19-two-kinds")
    }
}
