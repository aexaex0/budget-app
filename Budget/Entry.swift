import SwiftUI
import SwiftData

enum EntryKind: String, CaseIterable, Identifiable {
    case income, expense, subscription, saving

    var id: String { rawValue }

    var title: String {
        switch self {
        case .income: "Bevétel"
        case .expense: "Kiadás"
        case .subscription: "Előfizetés"
        case .saving: "Megtakarítás"
        }
    }

    var plural: String {
        switch self {
        case .income: "Bevételek"
        case .expense: "Kiadások"
        case .subscription: "Előfizetések"
        case .saving: "Megtakarítások"
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

extension Double {
    /// Forintként formázva, tizedes nélkül (pl. 250 000 Ft)
    var ft: String {
        formatted(.currency(code: "HUF")
            .precision(.fractionLength(0))
            .locale(Locale(identifier: "hu_HU")))
    }
}

/// Háttér, amin a Liquid Glass elemek szépen látszanak.
struct AppBackground: View {
    var body: some View {
        LinearGradient(
            colors: [.indigo.opacity(0.45), .teal.opacity(0.30), .mint.opacity(0.25)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
