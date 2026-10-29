import SwiftUI
import SwiftData

enum EntryKind: String, CaseIterable, Identifiable {
    case income, expense, subscription, saving

    var id: String { rawValue }

    func title(_ tr: Tr) -> String {
        switch self {
        case .income: tr("Bevétel", "Income")
        case .expense: tr("Kiadás", "Expense")
        case .subscription: tr("Előfizetés", "Subscription")
        case .saving: tr("Megtakarítás", "Saving")
        }
    }

    func plural(_ tr: Tr) -> String {
        switch self {
        case .income: tr("Bevételek", "Income")
        case .expense: tr("Kiadások", "Expenses")
        case .subscription: tr("Előfizetések", "Subscriptions")
        case .saving: tr("Megtakarítások", "Savings")
        }
    }

    var icon: String {
        switch self {
        case .income: "arrow.down.circle.fill"
        case .expense: "cart.fill"
        case .subscription: "arrow.triangle.2.circlepath.circle.fill"
        case .saving: "banknote.fill"
        }
    }

    var color: Color {
        switch self {
        case .income: .green
        case .expense: .orange
        case .subscription: .purple
        case .saving: .blue
        }
    }
}

/// Egy havi tétel (mindig havi összeg). Helyben tárolódik az eszközön (SwiftData).
@Model
final class Entry {
    var name: String
    var amount: Double          // havi összeg
    var kindRaw: String
    var targetAmount: Double    // csak megtakarításnál: cél (0 = nincs)
    var savedSoFar: Double      // csak megtakarításnál: eddig félretéve
    var createdAt: Date

    var kind: EntryKind {
        get { EntryKind(rawValue: kindRaw) ?? .expense }
        set { kindRaw = newValue.rawValue }
    }

    init(name: String, amount: Double, kind: EntryKind,
         targetAmount: Double = 0, savedSoFar: Double = 0) {
        self.name = name
        self.amount = amount
        self.kindRaw = kind.rawValue
        self.targetAmount = targetAmount
        self.savedSoFar = savedSoFar
        self.createdAt = .now
    }
}
