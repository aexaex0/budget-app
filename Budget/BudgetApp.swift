import SwiftUI
import SwiftData

@main
struct BudgetApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Entry.self) // helyi tárolás az eszközön
    }
}
