import Observation

/// Carries "a check-in notification was tapped" from the app delegate to
/// ContentView, which opens Today.
@Observable
@MainActor
final class MindCheckRouter {
    static let shared = MindCheckRouter()

    /// Set when a notification is tapped; ContentView clears it.
    var openRequested = false
}
