import Foundation
import SwiftData

/// The passage details a new journal entry keeps a copy of.
struct JournalPassageCopy: Equatable {
    var passageID: String
    var passageRef: String
    var passageTitle: String
    var question: String
}

/// Saving rules for journal entries (spec 3.2):
/// - at most one entry per day; saving again replaces its text;
/// - the passage copies are set once and never overwritten;
/// - empty or whitespace-only text deletes the entry;
/// - a new entry can only be written for the current day.
enum JournalStore {
    enum SaveResult: Equatable {
        case saved
        case deleted
        case nothingToSave
        case notCurrentDay
    }

    static func entry(forDay day: Date, in context: ModelContext) -> JournalEntry? {
        let key = DateHelpers.dayKey(for: day)
        let predicate = #Predicate<JournalEntry> { $0.dayKey == key }
        var descriptor = FetchDescriptor<JournalEntry>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        descriptor.fetchLimit = 1
        return context.fetchOrEmpty(descriptor).first
    }

    static func entries(forPassage passageID: String, in context: ModelContext) -> [JournalEntry] {
        let predicate = #Predicate<JournalEntry> { $0.passageID == passageID }
        let descriptor = FetchDescriptor<JournalEntry>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.day, order: .forward)]
        )
        return context.fetchOrEmpty(descriptor)
    }

    static func entries(in interval: DateInterval, in context: ModelContext) -> [JournalEntry] {
        let start = interval.start
        let end = interval.end
        let predicate = #Predicate<JournalEntry> { $0.day >= start && $0.day < end }
        let descriptor = FetchDescriptor<JournalEntry>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.day, order: .forward)]
        )
        return context.fetchOrEmpty(descriptor)
    }

    /// Saves the entry for `day`. `currentDay` is the day the user is in now;
    /// a new entry is only created when `day` is that day.
    @discardableResult
    static func save(
        text: String,
        day: Date,
        currentDay: Date,
        passage: JournalPassageCopy,
        now: Date = .now,
        in context: ModelContext
    ) -> SaveResult {
        if let existing = entry(forDay: day, in: context) {
            return update(existing, text: text, now: now, in: context)
        }
        guard !isBlank(text) else { return .nothingToSave }
        guard DateHelpers.dayKey(for: day) == DateHelpers.dayKey(for: currentDay) else {
            return .notCurrentDay
        }
        let entry = JournalEntry(
            day: day,
            passageID: passage.passageID,
            passageRef: passage.passageRef,
            passageTitle: passage.passageTitle,
            question: passage.question,
            responseText: text,
            createdAt: now
        )
        context.insert(entry)
        try? context.save()
        return .saved
    }

    /// Edits an existing entry's text. Blank text deletes it.
    @discardableResult
    static func update(
        _ entry: JournalEntry,
        text: String,
        now: Date = .now,
        in context: ModelContext
    ) -> SaveResult {
        if isBlank(text) {
            context.delete(entry)
        } else {
            entry.responseText = text
            entry.updatedAt = now
        }
        try? context.save()
        return isBlank(text) ? .deleted : .saved
    }

    private static func isBlank(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
