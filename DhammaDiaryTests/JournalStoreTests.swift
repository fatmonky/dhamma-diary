import XCTest
import SwiftData
@testable import DhammaDiary

@MainActor
final class JournalStoreTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    private let today = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 15, hour: 21))!
    private var yesterday: Date { Calendar.current.date(byAdding: .day, value: -1, to: today)! }

    private let passage = JournalPassageCopy(
        passageID: "an10.51-your-own-mind",
        passageRef: "AN 10.51",
        passageTitle: "Your Own Mind",
        question: "What did you notice in your mind today?"
    )

    override func setUp() async throws {
        container = try DhammaDiaryStore.makeContainer(inMemory: true)
        context = container.mainContext
    }

    override func tearDown() async throws {
        context = nil
        container = nil
    }

    private func allEntries() -> [JournalEntry] {
        (try? context.fetch(FetchDescriptor<JournalEntry>())) ?? []
    }

    func testContainerUsesVersionedSchemaWithMindChecks() {
        let names = Set(container.schema.entities.map(\.name))
        XCTAssertEqual(names, ["Stone", "JournalEntry", "MindCheck"])
        XCTAssertEqual(SchemaV2.versionIdentifier, Schema.Version(2, 0, 0))
        XCTAssertEqual(DhammaDiaryMigrationPlan.schemas.count, 2)
    }

    func testSavingCreatesOneEntryWithPassageCopies() throws {
        let result = JournalStore.save(text: "Calm at work.", day: today, currentDay: today, passage: passage, in: context)

        XCTAssertEqual(result, .saved)
        let entry = try XCTUnwrap(allEntries().first)
        XCTAssertEqual(allEntries().count, 1)
        XCTAssertEqual(entry.passageID, passage.passageID)
        XCTAssertEqual(entry.passageRef, "AN 10.51")
        XCTAssertEqual(entry.passageTitle, "Your Own Mind")
        XCTAssertEqual(entry.question, passage.question)
        XCTAssertEqual(entry.day, Calendar.current.startOfDay(for: today))
        XCTAssertEqual(entry.dayKey, DateHelpers.dayKey(for: today))
    }

    func testSavingAgainReplacesTextAndKeepsCopies() throws {
        let created = Date(timeIntervalSince1970: 1_000)
        let later = Date(timeIntervalSince1970: 2_000)
        JournalStore.save(text: "First.", day: today, currentDay: today, passage: passage, now: created, in: context)

        let reworded = JournalPassageCopy(
            passageID: "other",
            passageRef: "MN 19",
            passageTitle: "Two Kinds of Thought",
            question: "A reworded question?"
        )
        let result = JournalStore.save(text: "Second.", day: today, currentDay: today, passage: reworded, now: later, in: context)

        XCTAssertEqual(result, .saved)
        let entries = allEntries()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].responseText, "Second.")
        XCTAssertEqual(entries[0].question, passage.question)
        XCTAssertEqual(entries[0].passageID, passage.passageID)
        XCTAssertEqual(entries[0].createdAt, created)
        XCTAssertEqual(entries[0].updatedAt, later)
    }

    func testSavingBlankTextDeletesTheEntry() {
        JournalStore.save(text: "Something.", day: today, currentDay: today, passage: passage, in: context)

        let result = JournalStore.save(text: "  \n ", day: today, currentDay: today, passage: passage, in: context)

        XCTAssertEqual(result, .deleted)
        XCTAssertTrue(allEntries().isEmpty)
    }

    func testSavingBlankTextWithNoEntryDoesNothing() {
        let result = JournalStore.save(text: "", day: today, currentDay: today, passage: passage, in: context)

        XCTAssertEqual(result, .nothingToSave)
        XCTAssertTrue(allEntries().isEmpty)
    }

    func testMissedDayCannotBeFilledInAfterwards() {
        let result = JournalStore.save(text: "Late.", day: yesterday, currentDay: today, passage: passage, in: context)

        XCTAssertEqual(result, .notCurrentDay)
        XCTAssertTrue(allEntries().isEmpty)
    }

    func testPastEntryStaysEditable() throws {
        JournalStore.save(text: "Then.", day: yesterday, currentDay: yesterday, passage: passage, in: context)

        let result = JournalStore.save(text: "Edited later.", day: yesterday, currentDay: today, passage: passage, in: context)

        XCTAssertEqual(result, .saved)
        XCTAssertEqual(try XCTUnwrap(JournalStore.entry(forDay: yesterday, in: context)).responseText, "Edited later.")
    }

    func testEntriesForPassageAreOldestFirstAndMatchByID() {
        JournalStore.save(text: "B", day: today, currentDay: today, passage: passage, in: context)
        JournalStore.save(text: "A", day: yesterday, currentDay: yesterday, passage: passage, in: context)
        let other = JournalPassageCopy(passageID: "mn19", passageRef: "MN 19", passageTitle: "T", question: "Q")
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: today)!
        JournalStore.save(text: "C", day: twoDaysAgo, currentDay: twoDaysAgo, passage: other, in: context)

        let entries = JournalStore.entries(forPassage: passage.passageID, in: context)

        XCTAssertEqual(entries.map(\.responseText), ["A", "B"])
    }
}

@MainActor
final class OneOffFixesTests: XCTestCase {
    func testOnlyThe20NovAN1061EntryWithTheOldQuestionChanges() throws {
        let container = try DhammaDiaryStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let calendar = Calendar.current
        let nov20 = calendar.date(from: DateComponents(year: 2026, month: 11, day: 20))!
        let nov7 = calendar.date(from: DateComponents(year: 2026, month: 11, day: 7))!
        let old = OneOffFixes.oldAN1061Question
        let target = JournalEntry(day: nov20, passageID: "an10.61-true-persons", passageRef: "AN 10.61", passageTitle: "Ignorance", question: old, responseText: "today filled up about work.")
        let earlier = JournalEntry(day: nov7, passageID: "an10.61-true-persons", passageRef: "AN 10.61", passageTitle: "Ignorance", question: old, responseText: "Earlier.")
        context.insert(target)
        context.insert(earlier)
        try context.save()
        let updatedAt = target.updatedAt

        XCTAssertTrue(OneOffFixes.rewordAN1061EntryOn20Nov(in: context))
        XCTAssertEqual(target.question, OneOffFixes.newAN1061Question)
        XCTAssertEqual(target.responseText, "today filled up about work.")
        XCTAssertEqual(target.updatedAt, updatedAt)
        XCTAssertEqual(earlier.question, old)
        // Runs once: nothing left to change.
        XCTAssertFalse(OneOffFixes.rewordAN1061EntryOn20Nov(in: context))
    }

    func testNewWordingMatchesThePassageSet() throws {
        let set = try PassageSet.load(from: .main)
        XCTAssertEqual(set.passage(withID: "an10.61-true-persons")?.question, OneOffFixes.newAN1061Question)
    }
}
