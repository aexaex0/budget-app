import SwiftUI

struct Celebration: Identifiable {
    let id = UUID()
    let ratio: Double
    let jackpot: Bool
    let start = Date()

    var lifetime: Double {
        if jackpot || ratio >= 100 { return 6.5 }
        if ratio >= 40 { return 5.0 }
        return 3.8
    }
}

/// Demó slot: semmit nem ír a valódi adatokba. Az egyenleg csak a játékon belül él.
@MainActor
final class SlotEngine: ObservableObject {
    static let bets: [Int] = [20, 40, 60, 100, 200, 400, 800, 1000, 1200, 1500, 2000, 2500, 3000, 4000]

    @Published var balance: Double = 0
    @Published var bet: Int = 60
    @Published var grid: [[SlotSymbol]] = (0..<3).map { _ in (0..<3).map { _ in SlotSymbol.random() } }
    @Published var strips: [[SlotSymbol]] = (0..<3).map { _ in (0..<3).map { _ in SlotSymbol.random() } }
    @Published var spinIDs: [Int] = [0, 0, 0]
    @Published var reelDur: [Double] = [1, 1, 1]
    @Published var sound = true {
        didSet { SlotSound.shared.enabled = sound }
    }
    @Published var spinningCols: [Bool] = [false, false, false]
    @Published var bounce: [Bool] = [false, false, false]
    @Published var jackpotMode = false
    @Published var multIndex = 0
    @Published var multSpinning = false
    @Published var landedMult = false
    @Published var winLines: [Int] = []
    @Published var shownWin: Double = 0
    @Published var winBanner: String?
    @Published var busy = false
    @Published var fast = false
    @Published var celebration: Celebration?
    @Published var autoSpin = false {
        didSet {
            if autoSpin { startAuto() } else { autoTask?.cancel() }
        }
    }

    private var spinTask: Task<Void, Never>?
    private var autoTask: Task<Void, Never>?
    private var tickTask: Task<Void, Never>?
    private var lastRatio: Double = 0

    // MARK: Vezérlés

    func reset(balance: Double) {
        self.balance = balance
        if Double(bet) > balance, let affordable = Self.bets.last(where: { Double($0) <= balance }) {
            bet = affordable
        }
    }

    func stopAll() {
        autoTask?.cancel()
        spinTask?.cancel()
        tickTask?.cancel()
        SlotSound.shared.stopAll()
        autoSpin = false
    }

    func spinTapped() {
        guard !busy else { return }
        spinTask = Task { await spin() }
    }

    private var speed: Double { fast ? 0.4 : 1.0 }

    // MARK: Pörgetés

    func spin() async {
        let b = Double(bet)
        guard !busy, balance >= b else {
            autoSpin = false
            return
        }
        busy = true
        balance -= b
        Stats.add("spins")
        winLines = []
        withAnimation(.easeOut(duration: 0.15)) { winBanner = nil }
        celebration = nil
        jackpotMode = false
        landedMult = false
        lastRatio = 0

        let outcome = SlotOutcome.roll()

        spinningCols = [true, true, true]
        multSpinning = true
        tickTask?.cancel()
        tickTask = Task { await self.runTicker() }

        // valódi görgetés: minden oszlop egy hosszú tekercs, ami legördül a végeredményig
        let stops: [Double] = [0.9, 1.4, 1.9].map { $0 * speed }
        for c in 0..<3 {
            let rows = max(6, Int(stops[c] * 8))
            let filler = (0..<rows).map { _ in SlotSymbol.random() }
            let old = Array(strips[c].prefix(3))
            strips[c] = outcome.grid[c] + filler + old
            reelDur[c] = stops[c]
            spinIDs[c] += 1
        }
        // az oszlopok balról jobbra állnak meg
        var elapsed = 0.0
        for c in 0..<3 {
            try? await Task.sleep(for: .seconds(max(stops[c] - elapsed, 0)))
            elapsed = stops[c]
            grid[c] = outcome.grid[c]
            spinningCols[c] = false
            bump(c)
            SlotSound.shared.play(.stop)
            Haptics.tap(.light)
        }

        if outcome.isWin {
            if outcome.jackpot != nil {
                // minden ikon jackpot: a szorzó helyén a jackpot feliratok pörögnek
                jackpotMode = true
                multIndex = 0
                Haptics.tap(.heavy)
            }
            // a szorzó még pörög egy darabig, aztán megáll
            try? await Task.sleep(for: .seconds(1.0 * speed))
            await landMultiplier(target: outcome.multIndex)
            let total = outcome.total(bet: b)
            await celebrate(total: total, bet: b, outcome: outcome)
        } else {
            // vesztes pörgetés: a szorzó az utolsó oszloppal együtt áll meg
            multSpinning = false
            multIndex = outcome.multIndex
        }

        busy = false
    }

    private func runTicker() async {
        while !Task.isCancelled && (spinningCols.contains(true) || multSpinning) {
            let n = jackpotMode ? 4 : 5
            if multSpinning { multIndex = (multIndex + 1) % n }
            SlotSound.shared.play(.tick)
            try? await Task.sleep(for: .seconds(fast ? 0.06 : 0.09))
        }
    }

    private func landMultiplier(target: Int) async {
        let n = jackpotMode ? 4 : 5
        multSpinning = false
        let delays: [Double] = [0.09, 0.12, 0.17, 0.24, 0.34]
        for d in delays {
            multIndex = (multIndex + 1) % n
            SlotSound.shared.play(.tick)
            try? await Task.sleep(for: .seconds(d * speed))
        }
        var guardCount = 0
        while multIndex != target && guardCount < 12 {
            multIndex = (multIndex + 1) % n
            SlotSound.shared.play(.tick)
            Haptics.tap(.soft)
            try? await Task.sleep(for: .seconds(0.38 * speed))
            guardCount += 1
        }
        multIndex = target
        landedMult = true
        Haptics.tap(.rigid)
    }

    private func bump(_ c: Int) {
        bounce[c] = true
        Task {
            try? await Task.sleep(for: .seconds(0.16))
            bounce[c] = false
        }
    }

    // MARK: Nyeremény

    private func celebrate(total: Double, bet: Double, outcome: SlotOutcome) async {
        let ratio = total / bet
        lastRatio = ratio
        winLines = outcome.winLines

        var banner: String?
        if let t = outcome.jackpot {
            banner = "\(t.title) JACKPOT"
        } else if ratio >= 100 {
            banner = "EPIC WIN"
        } else if ratio >= 40 {
            banner = "MEGA WIN"
        } else if ratio >= 15 {
            banner = "BIG WIN"
        } else if ratio >= 5 {
            banner = "NICE WIN"
        }
        if let banner {
            withAnimation(.spring(duration: 0.45, bounce: 0.4)) { winBanner = banner }
        }
        if outcome.jackpot != nil { Stats.add("jackpots") }
        if outcome.jackpot != nil { SlotSound.shared.play(.jackpot) }
        else if ratio >= 100 { SlotSound.shared.play(.mega) }
        else if ratio >= 40 { SlotSound.shared.play(.mega) }
        else if ratio >= 15 { SlotSound.shared.play(.big) }
        else { SlotSound.shared.play(.win) }
        if ratio >= 5 || outcome.jackpot != nil {
            let c = Celebration(ratio: ratio, jackpot: outcome.jackpot != nil)
            celebration = c
            Task {
                try? await Task.sleep(for: .seconds(c.lifetime))
                if celebration?.id == c.id { celebration = nil }
            }
            Haptics.success()
        }

        // összeg gyors feltöltődése
        let steps = 24
        let dur: Double
        if outcome.jackpot != nil { dur = 2.4 }
        else if ratio >= 15 { dur = 1.6 }
        else if ratio >= 5 { dur = 1.0 }
        else { dur = 0.6 }
        for i in 1...steps {
            shownWin = total * Double(i) / Double(steps)
            if i % 4 == 0 { SlotSound.shared.play(.coin) }
            try? await Task.sleep(for: .seconds(dur / Double(steps) * (fast ? 0.5 : 1.0)))
        }
        shownWin = total
        balance += total
    }

    // MARK: Autospin

    private func pauseAfterSpin() -> Double {
        var extra = 0.0
        if lastRatio >= 100 { extra = 3.5 }
        else if lastRatio >= 40 { extra = 2.5 }
        else if lastRatio >= 15 { extra = 1.8 }
        else if lastRatio >= 5 { extra = 1.0 }
        else if lastRatio > 0 { extra = 0.5 }
        return (0.9 + extra) * (fast ? 0.5 : 1.0)
    }

    private func startAuto() {
        autoTask?.cancel()
        autoTask = Task {
            while !Task.isCancelled && autoSpin {
                if balance < Double(bet) {
                    autoSpin = false
                    break
                }
                if !busy { await spin() }
                try? await Task.sleep(for: .seconds(pauseAfterSpin()))
            }
        }
    }
}
