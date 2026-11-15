import SwiftUI

/// Where to take the user in the Diary tab from elsewhere in the app.
enum DiaryDestination: Equatable {
    /// Tonight (from Today's morning question and the widget, spec 8.1, 8.4).
    case tonight
    /// Passages, expanded at one passage (from an entry opened in Review, spec 4.3).
    case passage(String)
}

/// Switches to the Diary tab at a destination. Set by ContentView; nil
/// where no such route exists.
private struct OpenDiaryKey: EnvironmentKey {
    static let defaultValue: ((DiaryDestination) -> Void)? = nil
}

extension EnvironmentValues {
    var openDiary: ((DiaryDestination) -> Void)? {
        get { self[OpenDiaryKey.self] }
        set { self[OpenDiaryKey.self] = newValue }
    }
}
