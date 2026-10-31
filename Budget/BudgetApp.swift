import SwiftUI
import SwiftData

@main
struct BudgetApp: App {
    @StateObject private var store = ThemeStore()
    @StateObject private var router = Router()

    var body: some Scene {
        WindowGroup {
            LockGate {
                ContentView()
            }
            .environmentObject(store)
            .environmentObject(router)
            .preferredColorScheme(store.scheme)
            .tint(store.theme.accent.color)
        }
        .modelContainer(for: [Entry.self, Category.self, WishItem.self, Debt.self]) // helyi tárolás az eszközön
    }
}
