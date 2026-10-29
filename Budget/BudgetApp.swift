import SwiftUI
import SwiftData

@main
struct BudgetApp: App {
    @StateObject private var store = ThemeStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .preferredColorScheme(store.scheme)
                .tint(store.theme.accent.color)
        }
        .modelContainer(for: Entry.self) // helyi tárolás az eszközön
    }
}
