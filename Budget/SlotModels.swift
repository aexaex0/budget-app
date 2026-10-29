import Foundation

/// Szimbólumok. A súlyok és a kifizetések úgy vannak beállítva, hogy a gép
/// hosszú távon kb. 93%-ot fizessen vissza (mint egy valódi gép), tettől függetlenül.
enum SlotSymbol: Int, CaseIterable {
    case cherry, lemon, bell, star, diamond, seven, crown

    var glyph: String {
        switch self {
        case .cherry: "🍒"
        case .lemon: "🍋"
        case .bell: "🔔"
        case .star: "⭐️"
        case .diamond: "💎"
        case .seven: "7️⃣"
        case .crown: "👑"
        }
    }

    /// Előfordulási súly (összesen 100)
    var weight: Int {
        switch self {
        case .cherry: 28
        case .lemon: 24
        case .bell: 18
        case .star: 14
        case .diamond: 9
        case .seven: 5
        case .crown: 2
        }
    }

    /// Vonalkifizetés a vonaltét többszöröseként (3 egyforma a vonalon)
    var pay: Double {
        switch self {
        case .cherry: 2
        case .lemon: 4
        case .bell: 10
        case .star: 17
        case .diamond: 45
        case .seven: 140
        case .crown: 450
        }
    }

    static func random() -> SlotSymbol {
        var r = Int.random(in: 0..<100)
        for s in SlotSymbol.allCases {
            if r < s.weight { return s }
            r -= s.weight
        }
        return .cherry
    }
}

enum JackpotTier: Int, CaseIterable {
    case minor, major, grand, joker

    var title: String {
        switch self {
        case .minor: "MINOR"
        case .major: "MAJOR"
        case .grand: "GRAND"
        case .joker: "JOKER"
        }
    }

    /// Nyeremény a tét szorzójaként: pl. 60 Ft-nál minor 300–600 (5x–10x)
    var factors: (lo: Double, hi: Double) {
        switch self {
        case .minor: (5, 10)
        case .major: (15, 30)
        case .grand: (50, 200)
        case .joker: (1000, 1000)
        }
    }

    var weight: Int {
        switch self {
        case .minor: 70
        case .major: 22
        case .grand: 7
        case .joker: 1
        }
    }

    static func roll() -> JackpotTier {
        var r = Int.random(in: 0..<100)
        for t in JackpotTier.allCases {
            if r < t.weight { return t }
            r -= t.weight
        }
        return .minor
    }
}

enum Multiplier {
    static let values: [Int] = [2, 3, 6, 10, 15]
    static let weights: [Int] = [50, 28, 14, 6, 2]

    static func rollIndex() -> Int {
        var r = Int.random(in: 0..<100)
        for (i, w) in weights.enumerated() {
            if r < w { return i }
            r -= w
        }
        return 0
    }
}

struct SlotOutcome {
    var grid: [[SlotSymbol]]      // [oszlop][sor]
    var winLines: [Int]
    var baseUnits: Double         // nyertes vonalak összege a teljes tét többszöröseként
    var jackpot: JackpotTier?
    var jackpotFactor: Double
    var multIndex: Int

    var isWin: Bool { jackpot != nil || !winLines.isEmpty }

    func total(bet: Double) -> Double {
        if jackpot != nil { return (bet * jackpotFactor).rounded() }
        if winLines.isEmpty { return 0 }
        return (bet * baseUnits * Double(Multiplier.values[multIndex])).rounded()
    }

    /// 5 nyerővonal: 3 vízszintes + 2 átlós. (col, row)
    static let lines: [[(col: Int, row: Int)]] = [
        [(0, 0), (1, 0), (2, 0)],
        [(0, 1), (1, 1), (2, 1)],
        [(0, 2), (1, 2), (2, 2)],
        [(0, 0), (1, 1), (2, 2)],
        [(0, 2), (1, 1), (2, 0)],
    ]

    /// Egy valódi véletlen pörgetés. Semmi nincs befolyásolva: sem az egyenleg, sem a tét.
    static func roll() -> SlotOutcome {
        // Jackpot: kb. 5000 pörgetésből 1
        if Double.random(in: 0..<1) < 1.0 / 5000.0 {
            let tier = JackpotTier.roll()
            let f = Double.random(in: tier.factors.lo...tier.factors.hi)
            let crowns = Array(repeating: Array(repeating: SlotSymbol.crown, count: 3), count: 3)
            return SlotOutcome(grid: crowns, winLines: [], baseUnits: 0,
                               jackpot: tier, jackpotFactor: f, multIndex: tier.rawValue)
        }

        var grid: [[SlotSymbol]] = []
        repeat {
            grid = (0..<3).map { _ in (0..<3).map { _ in SlotSymbol.random() } }
        } while grid.allSatisfy { col in col.allSatisfy { $0 == .crown } }

        var winning: [Int] = []
        var units = 0.0
        for (i, line) in lines.enumerated() {
            let a = grid[line[0].col][line[0].row]
            let b = grid[line[1].col][line[1].row]
            let c = grid[line[2].col][line[2].row]
            if a == b && b == c {
                winning.append(i)
                units += a.pay / 5.0
            }
        }
        return SlotOutcome(grid: grid, winLines: winning, baseUnits: units,
                           jackpot: nil, jackpotFactor: 0, multIndex: Multiplier.rollIndex())
    }
}
