import Foundation
import SwiftData

/// Single-use data fixes PJ asked for. Each matches one record exactly and
/// does nothing once applied, so it's safe to run on every launch. Remove a
/// fix once it has run on PJ's phone.
enum OneOffFixes {
    static func run(in context: ModelContext) {
        rewordAN1061EntryOn20Nov(in: context)
    }

    static let oldAN1061Question = "Who and what did you spend your time with today? What did that fill up in you?"
    static let newAN1061Question = "What filled you up today? Was it faith, rational application of mind, mindfulness, sense restraint, good conduct, or something else?"

    /// PJ's 20 Nov 2026 entry was written just before AN 10.61's question
    /// was reworded; give it the new wording. Its text is untouched.
    @discardableResult
    static func rewordAN1061EntryOn20Nov(in context: ModelContext) -> Bool {
        let key = "2026-11-20"
        let id = "an10.61-true-persons"
        let old = oldAN1061Question
        let descriptor = FetchDescriptor<JournalEntry>(
            predicate: #Predicate { $0.dayKey == key && $0.passageID == id && $0.question == old }
        )
        let matches = context.fetchOrEmpty(descriptor)
        guard !matches.isEmpty else { return false }
        for entry in matches {
            entry.question = newAN1061Question
        }
        try? context.save()
        return true
    }
}
