import SwiftUI
import SwiftData

@main
struct BudgetApp: App {
    @StateObject private var store = ThemeStore()

    var body: some Scene {
        WindowGroup {
            LockGate {
                ContentView()
            }
            .environmentObject(store)
            .preferredColorScheme(store.scheme)
            .tint(store.theme.accent.color)
        }
        .modelContainer(for: [Entry.self, Category.self]) // helyi tárolás az eszközön
    }
}
