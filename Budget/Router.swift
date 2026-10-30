import SwiftUI
import WidgetKit

/// Widgetből érkező műveletek (pl. gyors hozzáadás).
final class Router: ObservableObject {
    @Published var pendingAdd: String?

    /// Kiolvassa és törli a widget által beállított kérést.
    static func takePending() -> String? {
        var found: String?
        for d in [WidgetShared.defaults, UserDefaults.standard] {
            if let k = d.string(forKey: "pendingAdd"), !k.isEmpty {
                found = k
                d.removeObject(forKey: "pendingAdd")
            }
        }
        return found
    }
}

enum WidgetSync {
    static func push(spending: Double, piggy: Double, streak: Int, payday: Int) {
        WidgetShared.set("spending", spending)
        WidgetShared.set("piggy", piggy)
        WidgetShared.set("streak", Double(streak))
        WidgetShared.set("payday", Double(payday))
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func push(budgetRemaining: Double, budgetLimit: Double) {
        WidgetShared.set("budgetRemaining", budgetRemaining)
        WidgetShared.set("budgetLimit", budgetLimit)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
