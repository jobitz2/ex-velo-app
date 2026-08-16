import SwiftUI

@main
struct ExVeloApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Swing.self)
    }
}
