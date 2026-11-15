import SwiftUI

/// Switches to the Diary tab's Passages mode at one passage (spec 4.3:
/// an entry opened from Review has a way through to its passage).
/// Set by ContentView; nil where no such route exists.
private struct OpenPassageInDiaryKey: EnvironmentKey {
    static let defaultValue: ((String) -> Void)? = nil
}

extension EnvironmentValues {
    var openPassageInDiary: ((String) -> Void)? {
        get { self[OpenPassageInDiaryKey.self] }
        set { self[OpenPassageInDiaryKey.self] = newValue }
    }
}
