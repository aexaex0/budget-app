import SwiftUI
import SwiftData

struct PlayingCard: Identifiable, Equatable {
    let id = UUID()
    let rank: Int   // 1...13
    let suit: Int   // 0...3

    var value: Int { rank == 1 ? 11 : min(rank, 10) }
    var label: String {
        switch rank {
        case 1: return "A"
        case 11: return "J"
        case 12: return "Q"
        case 13: return "K"
        default: return "\(rank)"
        }
    }
    var suitGlyph: String { ["♠", "♥", "♦", "♣"][suit] }
    var isRed: Bool { suit == 1 || suit == 2 }
}

func handTotal(_ cards: [PlayingCard]) -> Int {
    var total = cards.reduce(0) { $0 + $1.value }
    var aces = cards.filter { $0.rank == 1 }.count
    while total > 21 && aces > 0 {
        total -= 10
        aces -= 1
    }
    return total
}

struct BJHand: Identifiable {
    let id = UUID()
    var cards: [PlayingCard]
    var wager: Double
    var fromSplitAces = false
}

/// Demó blackjack: nem érinti a valódi adatokat. Van double és split (max 4 kéz).
@MainActor
final class BlackjackEngine: ObservableObject {
    enum Phase { case betting, player, dealer, done }

    static let bets: [Int] = [20, 100, 500, 1000, 2500, 5000]

    @Published var balance: Double = 0
    @Published var bet: Int = 100
    @Published var phase: Phase = .betting
    @Published var hands: [BJHand] = []
    @Published var active = 0
    @Published var dealer: [PlayingCard] = []
    @Published var holeHidden = true
    @Published var message: String?
    @Published var celebration: Celebration?

    private var shoe: [PlayingCard] = []
    private var task: Task<Void, Never>?

    var totalWager: Double { hands.reduce(0) { $0 + $1.wager } }

    var canDouble: Bool {
        guard phase == .player, hands.indices.contains(active) else { return false }
        return hands[active].cards.count == 2 && balance >= hands[active].wager
    }

    var canSplit: Bool {
        guard phase == .player, hands.count < 4, hands.indices.contains(active) else { return false }
        let h = hands[active]
        return h.cards.count == 2 && h.cards[0].value == h.cards[1].value && balance >= h.wager
    }

    func reset(balance: Double) {
        self.balance = balance
        if Double(bet) > balance, let b = Self.bets.last(where: { Double($0) <= balance }) {
            bet = b
        }
    }

    func stop() { task?.cancel() }

    private func draw() -> PlayingCard {
        if shoe.count < 40 {
            var cards: [PlayingCard] = []
            for _ in 0..<6 {
                for s in 0..<4 {
                    for r in 1...13 { cards.append(PlayingCard(rank: r, suit: s)) }
                }
            }
            shoe = cards.shuffled()
        }
        return shoe.removeLast()
    }

    private func pause(_ s: Double) async {
        try? await Task.sleep(for: .seconds(s))
    }

    private func give(_ hand: Int) {
        guard hands.indices.contains(hand) else { return }
        withAnimation(.spring(duration: 0.35)) { hands[hand].cards.append(draw()) }
        SlotSound.shared.play(.tick)
    }

    func deal() {
        guard phase == .betting || phase == .done, balance >= Double(bet) else { return }
        task?.cancel()
        task = Task { await dealRound() }
    }

    private func dealRound() async {
        balance -= Double(bet)
        Stats.add("bj")
        message = nil
        celebration = nil
        dealer = []
        holeHidden = true
        active = 0
        hands = [BJHand(cards: [], wager: Double(bet))]
        phase = .player
        give(0)
        await pause(0.3)
        withAnimation(.spring(duration: 0.35)) { dealer.append(draw()) }
        SlotSound.shared.play(.tick)
        await pause(0.3)
        give(0)
        await pause(0.3)
        withAnimation(.spring(duration: 0.35)) { dealer.append(draw()) }
        SlotSound.shared.play(.tick)
        await pause(0.4)
        if handTotal(hands[0].cards) == 21 {
            await dealerPlay()
        }
    }

    func hit() {
        guard phase == .player, hands.indices.contains(active) else { return }
        give(active)
        Haptics.tap(.light)
        let t = handTotal(hands[active].cards)
        if t >= 21 { finishCurrent() }
    }

    func stand() {
        guard phase == .player else { return }
        finishCurrent()
    }

    func double() {
        guard canDouble else { return }
        balance -= hands[active].wager
        hands[active].wager *= 2
        give(active)
        finishCurrent()
    }

    func split() {
        guard canSplit else { return }
        let h = hands[active]
        balance -= h.wager
        let aces = h.cards[0].rank == 1
        let moved = h.cards[1]
        hands[active].cards.removeLast()
        hands[active].fromSplitAces = aces
        withAnimation(.spring(duration: 0.35)) {
            hands.insert(BJHand(cards: [moved], wager: h.wager, fromSplitAces: aces), at: active + 1)
        }
        give(active)
        Haptics.tap(.medium)
        if aces || handTotal(hands[active].cards) >= 21 { finishCurrent() }
    }

    private func finishCurrent() {
        task = Task { await advance() }
    }

    private func advance() async {
        if active + 1 < hands.count {
            await pause(0.35)
            active += 1
            if hands[active].cards.count == 1 {
                give(active)
                await pause(0.35)
            }
            if hands[active].fromSplitAces || handTotal(hands[active].cards) >= 21 {
                await advance()
            }
        } else {
            await dealerPlay()
        }
    }

    private func dealerPlay() async {
        phase = .dealer
        await pause(0.4)
        withAnimation(.spring(duration: 0.35)) { holeHidden = false }
        await pause(0.6)
        let live = hands.contains { handTotal($0.cards) <= 21 }
        if live {
            while handTotal(dealer) < 17 && !Task.isCancelled {
                withAnimation(.spring(duration: 0.35)) { dealer.append(draw()) }
                SlotSound.shared.play(.tick)
                await pause(0.7)
            }
        }
        settle()
    }

    private func settle() {
        let d = handTotal(dealer)
        let dealerBJ = dealer.count == 2 && d == 21
        var payout = 0.0
        var anyBJ = false
        for h in hands {
            let p = handTotal(h.cards)
            let natural = hands.count == 1 && h.cards.count == 2 && p == 21
            if p > 21 { continue }
            if natural && !dealerBJ {
                payout += h.wager * 2.5
                anyBJ = true
            } else if dealerBJ && !natural {
                continue
            } else if d > 21 || p > d {
                payout += h.wager * 2
            } else if p == d {
                payout += h.wager
            }
        }
        let net = payout - totalWager
        balance += payout
        if hands.count == 1 {
            let p = handTotal(hands[0].cards)
            if p > 21 { message = "Bust" }
            else if anyBJ { message = "Blackjack!" }
            else if dealerBJ && payout == 0 { message = "Osztó blackjack" }
            else if net > 0 { message = "Nyertél" }
            else if net == 0 { message = "Döntetlen" }
            else { message = "Vesztettél" }
        } else {
            let sign = net > 0 ? "+" : ""
            message = net == 0 ? "Döntetlen" : sign + net.ft
        }
        phase = .done
        if net > 0 {
            SlotSound.shared.play(anyBJ ? .big : .win)
            Haptics.success()
            let c = Celebration(ratio: anyBJ ? 14 : 6, jackpot: false)
            celebration = c
            Task {
                try? await Task.sleep(for: .seconds(c.lifetime))
                if celebration?.id == c.id { celebration = nil }
            }
        }
    }
}

struct CardFace: View {
    let card: PlayingCard?   // nil = lefordított

    var body: some View {
        ZStack {
            if let card {
                RoundedRectangle(cornerRadius: 10).fill(Color.white)
                VStack(spacing: 0) {
                    HStack {
                        Text(card.label).font(.system(size: 18, weight: .bold, design: .rounded))
                        Spacer()
                    }
                    Spacer()
                    Text(card.suitGlyph).font(.system(size: 30))
                    Spacer()
                }
                .padding(7)
                .foregroundStyle(card.isRed ? Color.red : Color.black)
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading,
                                         endPoint: .bottomTrailing))
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(Color.white.opacity(0.5), lineWidth: 2)
                    .padding(6)
            }
        }
        .frame(width: 64, height: 92)
        .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
    }
}

struct BlackjackView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var entries: [Entry]
    @StateObject private var engine = BlackjackEngine()
    @State private var started = false

    private var startBalance: Double {
        func sum(_ k: EntryKind) -> Double {
            entries.filter { $0.kind == k && $0.counts(in: .now) }.reduce(0) { $0 + $1.amount }
        }
        let left = sum(.income) - sum(.expense) - sum(.subscription) - sum(.saving)
        return left > 0 ? left.rounded() : 100_000
    }

    var body: some View {
        ZStack {
            AppBackground()
            Color.black.opacity(0.5).ignoresSafeArea()

            VStack(spacing: 14) {
                topBar
                Spacer(minLength: 0)
                dealerArea
                messageView
                playerArea
                Spacer(minLength: 0)
                controls
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)

            if let c = engine.celebration {
                CelebrationView(celebration: c).id(c.id)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if !started {
                started = true
                engine.reset(balance: startBalance)
            }
        }
        .onDisappear { engine.stop() }
    }

    private var topBar: some View {
        HStack {
            Button {
                Haptics.tap()
                engine.stop()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .frame(width: 44, height: 44)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
            Spacer()
            Text(engine.balance.ft)
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText(value: engine.balance))
                .animation(.snappy, value: engine.balance)
                .padding(.horizontal, 22)
                .padding(.vertical, 8)
                .glassEffect(.regular, in: .capsule)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
    }

    private func hand(_ cards: [PlayingCard], hideSecond: Bool) -> some View {
        HStack(spacing: -26) {
            ForEach(Array(cards.enumerated()), id: \.element.id) { idx, c in
                CardFace(card: (hideSecond && idx == 1) ? nil : c)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(height: 96)
    }

    private var dealerArea: some View {
        VStack(spacing: 8) {
            Text(dealerTotalText)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .frame(height: 28)
            hand(engine.dealer, hideSecond: engine.holeHidden)
        }
    }

    private var dealerTotalText: String {
        if engine.dealer.isEmpty { return " " }
        if engine.holeHidden { return "\(engine.dealer[0].value)" }
        return "\(handTotal(engine.dealer))"
    }

    private var messageView: some View {
        Text(engine.message ?? " ")
            .font(.system(size: 28, weight: .black, design: .rounded))
            .foregroundStyle(
                LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom)
            )
            .frame(height: 44)
            .animation(.spring(duration: 0.3), value: engine.message)
    }

    private var playerArea: some View {
        let n = engine.hands.count
        let scale: CGFloat = n <= 1 ? 1 : (n == 2 ? 0.85 : 0.66)
        return HStack(alignment: .top, spacing: n <= 1 ? 0 : 6) {
            ForEach(Array(engine.hands.enumerated()), id: \.element.id) { idx, h in
                let isActive = engine.phase == .player && idx == engine.active && n > 1
                VStack(spacing: 8) {
                    hand(h.cards, hideSecond: false)
                    VStack(spacing: 4) {
                        Text(h.cards.isEmpty ? " " : "\(handTotal(h.cards))")
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                        Text(h.wager.ft)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(Color.yellow.opacity(0.25), in: .capsule)
                    }
                }
                .padding(6)
                .background(isActive ? Color.white.opacity(0.14) : Color.clear,
                            in: .rect(cornerRadius: 16))
                .scaleEffect(scale)
                .frame(width: n <= 1 ? nil : (n == 2 ? 130 : 96))
            }
        }
        .animation(.spring(duration: 0.35), value: engine.hands.count)
    }

    @ViewBuilder
    private var controls: some View {
        switch engine.phase {
        case .betting, .done:
            VStack(spacing: 12) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(BlackjackEngine.bets, id: \.self) { b in
                            Button {
                                Haptics.tap(.soft)
                                engine.bet = b
                            } label: {
                                Text(Double(b).ft)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .foregroundStyle(engine.bet == b ? Color.black : Color.white)
                                    .background(engine.bet == b ? Color.yellow : Color.white.opacity(0.12),
                                                in: .capsule)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                Button {
                    Haptics.tap(.medium)
                    engine.deal()
                } label: {
                    Text("DEAL")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 62)
                        .glassEffect(.regular.tint(Color.green.opacity(0.55)).interactive(),
                                     in: .rect(cornerRadius: 24))
                        .opacity(engine.balance >= Double(engine.bet) ? 1 : 0.45)
                }
                .buttonStyle(.plain)
                .disabled(engine.balance < Double(engine.bet))
            }
        case .player:
            HStack(spacing: 12) {
                actionButton("HIT", .green) { engine.hit() }
                actionButton("STAND", .red) { engine.stand() }
                actionButton("DOUBLE", .orange) { engine.double() }
                    .opacity(engine.canDouble ? 1 : 0.4)
                    .disabled(!engine.canDouble)
                if engine.canSplit {
                    actionButton("SPLIT", .purple) { engine.split() }
                }
            }
        case .dealer:
            Color.clear.frame(height: 62)
        }
    }

    private func actionButton(_ title: String, _ color: Color, _ action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap(.medium)
            action()
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .minimumScaleFactor(0.7)
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 62)
                .glassEffect(.regular.tint(color.opacity(0.5)).interactive(), in: .rect(cornerRadius: 22))
        }
        .buttonStyle(.plain)
    }
}
