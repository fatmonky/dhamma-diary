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
        XCTAssertEqual(set.passages.count, 86)
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

    func testEveryExcerptIsShortAndFromItsPassage() {
        for passage in set.passages {
            XCTAssertFalse(passage.excerpt.isEmpty, passage.id)
            XCTAssertLessThanOrEqual(passage.excerpt.joined(separator: " ").count, 340, passage.id)
            let segments = passage.blocks.flatMap { $0 }
            for part in passage.excerpt {
                // The generator drops an unpaired quote mark at the edge of a passage (one that starts
                // mid-dialogue), while the excerpt keeps its own paired marks; compare the words.
                let words = part.trimmingCharacters(in: CharacterSet(charactersIn: "“”‘’"))
                XCTAssertTrue(segments.contains { $0.contains(words) }, "\(passage.id): \(part)")
            }
        }
    }

    func testEveryHighlightIsOneShortLineFromItsPassage() {
        for passage in set.passages {
            XCTAssertFalse(passage.highlight.isEmpty, passage.id)
            XCTAssertLessThanOrEqual(passage.highlight.count, 110, passage.id)
            XCTAssertTrue(passage.blocks.joined().contains { $0.contains(passage.highlight) }, passage.id)
        }
    }

    func testHighlightMarksACutSentence() throws {
        let restraint = try XCTUnwrap(set.passage(withID: "an4.14-restraint"))
        XCTAssertEqual(restraint.highlightText, "…they don’t get caught up in the features and details.")
        let afterActing = try XCTUnwrap(set.passage(withID: "mn61-after-acting"))
        XCTAssertEqual(afterActing.highlightText, "After you have acted with the body, you should check on that same act…")
        let speech = try XCTUnwrap(set.passage(withID: "an10.44-speech"))
        XCTAssertEqual(speech.highlightText, "I will speak lovingly, not from secret hate.")
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

final class SharedFirstDayTests: XCTestCase {
    private let oldName = "SharedFirstDayTests.old"
    private let sharedName = "SharedFirstDayTests.shared"

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: oldName)
        UserDefaults().removePersistentDomain(forName: sharedName)
        super.tearDown()
    }

    func testExistingFirstDayIsCopiedOnce() {
        let old = UserDefaults(suiteName: oldName)!
        let shared = UserDefaults(suiteName: sharedName)!
        old.set("2026-11-01", forKey: PassageSequence.firstDayStorageKey)

        PassageSequence.moveFirstDayToSharedStore(from: old, to: shared)
        XCTAssertEqual(shared.string(forKey: PassageSequence.firstDayStorageKey), "2026-11-01")

        // A later run doesn't overwrite the shared value.
        old.set("2026-12-25", forKey: PassageSequence.firstDayStorageKey)
        PassageSequence.moveFirstDayToSharedStore(from: old, to: shared)
        XCTAssertEqual(shared.string(forKey: PassageSequence.firstDayStorageKey), "2026-11-01")
    }

    func testNothingToCopyLeavesSharedEmpty() {
        let shared = UserDefaults(suiteName: sharedName)!
        PassageSequence.moveFirstDayToSharedStore(from: UserDefaults(suiteName: oldName)!, to: shared)
        XCTAssertNil(shared.string(forKey: PassageSequence.firstDayStorageKey))
    }
}

final class QuestionLinesTests: XCTestCase {
    func testEachFurtherQuestionStartsANewLine() {
        XCTAssertEqual(
            "Who were your good friends today? How did their company shape your practice?".questionLines,
            "Who were your good friends today?\nHow did their company shape your practice?"
        )
    }

    func testLeadingStatementStaysWithTheFirstQuestion() {
        XCTAssertEqual(
            "Think of a small wrong you did today. Was your heart like the cup or the Ganges? What would make it wider?".questionLines,
            "Think of a small wrong you did today. Was your heart like the cup or the Ganges?\nWhat would make it wider?"
        )
    }

    func testSingleQuestionAndLowercaseContinuationAreUnchanged() {
        XCTAssertEqual("Where did you wander today?".questionLines, "Where did you wander today?")
        XCTAssertEqual("Was it ‘mine’? or not?".questionLines, "Was it ‘mine’? or not?")
    }
}
