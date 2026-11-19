import Observation
import SwiftUI

/// Carries "a check-in notification was tapped" from the app delegate to
/// ContentView, which opens the Mind tab.
@Observable
@MainActor
final class MindCheckRouter {
    static let shared = MindCheckRouter()

    /// Set when a notification is tapped; ContentView clears it.
    var openRequested = false
}

/// Switches to the Mind tab. Set by ContentView; nil where no such route exists.
private struct OpenMindKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    var openMind: (() -> Void)? {
        get { self[OpenMindKey.self] }
        set { self[OpenMindKey.self] = newValue }
    }
}
