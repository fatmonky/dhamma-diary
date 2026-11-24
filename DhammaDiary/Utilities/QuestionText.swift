import Foundation

extension String {
    /// A reflection question laid out for reading: each further question starts on its
    /// own line ("…today? What…" becomes "…today?\nWhat…"). A leading statement such as
    /// "Think of something you said today." stays with the first question. Used on the
    /// full-size screens; the Today card and widgets keep the question as one flow.
    var questionLines: String {
        replacingOccurrences(of: #"\?\s+(?=\p{Lu})"#, with: "?\n", options: .regularExpression)
    }
}
