import SwiftUI
import SwiftData

@main
struct DhammaDiaryApp: App {
    var body: some Scene {
        WindowGroup {
            SplashView()
        }
        .modelContainer(for: [Stone.self, Reflection.self])
    }
}
