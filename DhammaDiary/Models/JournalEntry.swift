import Foundation
import SwiftData

/// One journal entry per reflection day. It keeps a copy of the passage
/// reference, title and question as shown that day, so later edits to the
/// passage set never change what a past entry displays.
@Model
final class JournalEntry {
    var day: Date
    var dayKey: String
    var passageID: String
    var passageRef: String
    var passageTitle: String
    var question: String
    var responseText: String
    var createdAt: Date
    var updatedAt: Date

    init(
        day: Date,
        passageID: String,
        passageRef: String,
        passageTitle: String,
        question: String,
        responseText: String,
        createdAt: Date = .now
    ) {
        let start = Calendar.current.startOfDay(for: day)
        self.day = start
        self.dayKey = DateHelpers.dayKey(for: start)
        self.passageID = passageID
        self.passageRef = passageRef
        self.passageTitle = passageTitle
        self.question = question
        self.responseText = responseText
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}
