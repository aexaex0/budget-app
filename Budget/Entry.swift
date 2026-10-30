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
    var isRecurring: Bool = true   // true: minden hónapban számít; false: csak a `date` hónapjában
    var date: Date = Date.now      // egyszeri tételnél az időpont
    var categoryID: String = ""    // kiadás kategóriája (Category.id), üres = nincs
    var renewalDay: Int = 1        // előfizetés megújulásának napja (1-28)

    var kind: EntryKind {
        get { EntryKind(rawValue: kindRaw) ?? .expense }
        set { kindRaw = newValue.rawValue }
    }

    init(name: String, amount: Double, kind: EntryKind,
         targetAmount: Double = 0, savedSoFar: Double = 0,
         isRecurring: Bool = true, date: Date = .now,
         categoryID: String = "", renewalDay: Int = 1) {
        self.name = name
        self.amount = amount
        self.kindRaw = kind.rawValue
        self.targetAmount = targetAmount
        self.savedSoFar = savedSoFar
        self.createdAt = .now
        self.isRecurring = isRecurring
        self.date = date
        self.categoryID = categoryID
        self.renewalDay = renewalDay
    }

    /// Beleszámít-e az adott hónapba? Ismétlődő: mindig. Egyszeri: csak a saját hónapjában.
    /// A havi ismétlődő kiadás, előfizetés és megtakarítás csak a létrehozás utáni hónaptól vonódik le.
    /// A havi bevétel azonnal számít.
    func counts(in month: Date) -> Bool {
        let cal = Calendar.current
        if !isRecurring {
            return cal.isDate(date, equalTo: month, toGranularity: .month)
        }
        if kind == .income { return true }
        guard let firstMonth = cal.date(byAdding: .month, value: 1, to: createdAt) else { return true }
        return cal.compare(month, to: firstMonth, toGranularity: .month) != .orderedAscending
    }
}

/// Rövid dátum a kiválasztott nyelven (pl. "okt. 12." / "Oct 12")
func shortDate(_ d: Date, english: Bool) -> String {
    d.formatted(Date.FormatStyle().day().month(.abbreviated)
        .locale(Locale(identifier: english ? "en_US" : "hu_HU")))
}
