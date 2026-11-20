import SwiftUI
import SwiftData

@main
struct DhammaDiaryApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let container: ModelContainer

    init() {
        do {
            try DhammaDiaryStore.settleStoreLocation()
        } catch {
            fatalError("Could not move the Dhamma Diary store: \(error)")
        }
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
