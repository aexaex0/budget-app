import SwiftUI
import SwiftData

/// Saját kategória (pl. Étel, Lakás) opcionális havi limittel.
@Model
final class Category {
    var id: String = UUID().uuidString
    var name: String = ""
    var symbol: String = "tag.fill"
    var r: Double = 0.35
    var g: Double = 0.55
    var b: Double = 0.95
    var monthlyLimit: Double = 0     // 0 = nincs limit
    var createdAt: Date = Date.now

    init(name: String, symbol: String, color: RGBA, monthlyLimit: Double = 0) {
        self.name = name
        self.symbol = symbol
        self.r = color.r
        self.g = color.g
        self.b = color.b
        self.monthlyLimit = monthlyLimit
    }

    var color: Color { Color(red: r, green: g, blue: b) }
}

enum CategorySeed {
    static let symbols: [String] = [
        "house.fill", "fork.knife", "car.fill", "popcorn.fill",
        "cross.case.fill", "bag.fill", "tag.fill", "airplane",
        "graduationcap.fill", "pawprint.fill", "gift.fill", "figure.run",
        "wifi", "gamecontroller.fill", "tshirt.fill", "book.fill",
    ]

    /// Első indításkor alap kategóriák (később szabadon szerkeszthetők, törölhetők).
    static func seedIfNeeded(_ context: ModelContext, english: Bool) {
        let key = "categories-seeded"
        if UserDefaults.standard.bool(forKey: key) { return }
        let tr = Tr(en: english)
        let items: [(String, String, RGBA)] = [
            (tr("Lakás", "Housing"), "house.fill", RGBA(0.35, 0.55, 0.95)),
            (tr("Étel", "Food"), "fork.knife", RGBA(0.95, 0.60, 0.20)),
            (tr("Közlekedés", "Transport"), "car.fill", RGBA(0.30, 0.75, 0.70)),
            (tr("Szórakozás", "Fun"), "popcorn.fill", RGBA(0.75, 0.40, 0.90)),
            (tr("Egészség", "Health"), "cross.case.fill", RGBA(0.90, 0.35, 0.40)),
            (tr("Vásárlás", "Shopping"), "bag.fill", RGBA(0.90, 0.50, 0.70)),
        ]
        for item in items {
            context.insert(Category(name: item.0, symbol: item.1, color: item.2))
        }
        UserDefaults.standard.set(true, forKey: key)
    }
}
