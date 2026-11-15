import SwiftUI
import SwiftData

@main
struct DhammaDiaryApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try DhammaDiaryStore.makeContainer()
        } catch {
            fatalError("Could not open the Dhamma Diary store: \(error)")
        }
        PassageSequence.moveFirstDayToSharedStore()
        PassageSequence.recordFirstDayIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            SplashView()
        }
        .modelContainer(container)
    }
}
