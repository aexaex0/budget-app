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

/// Demó blackjack: nem érinti a valódi adatokat.
@MainActor
final class BlackjackEngine: ObservableObject {
    enum Phase { case betting, player, dealer, done }

    static let bets: [Int] = [20, 100, 500, 1000, 2500, 5000]

    @Published var balance: Double = 0
    @Published var bet: Int = 100
    @Published var phase: Phase = .betting
    @Published var player: [PlayingCard] = []
    @Published var dealer: [PlayingCard] = []
    @Published var holeHidden = true
    @Published var message: String?
    @Published var wager: Double = 0
    @Published var celebration: Celebration?

    private var shoe: [PlayingCard] = []
    private var task: Task<Void, Never>?

    func reset(balance: Double) {
        self.balance = balance
        if Double(bet) > balance, let b = Self.bets.last(where: { Double($0) <= balance }) {
            bet = b
        }
    }

    func stop() {
        task?.cancel()
    }

    private func draw() -> PlayingCard {
        if shoe.count < 30 {
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

    func deal() {
        guard phase == .betting || phase == .done, balance >= Double(bet) else { return }
        task?.cancel()
        task = Task { await dealRound() }
    }

    private func dealRound() async {
        wager = Double(bet)
        balance -= wager
        Stats.add("bj")
        message = nil
        celebration = nil
        player = []
        dealer = []
        holeHidden = true
        phase = .player
        withAnimation(.spring(duration: 0.35)) { player.append(draw()) }
        SlotSound.shared.play(.tick)
        await pause(0.3)
        withAnimation(.spring(duration: 0.35)) { dealer.append(draw()) }
        SlotSound.shared.play(.tick)
        await pause(0.3)
        withAnimation(.spring(duration: 0.35)) { player.append(draw()) }
        SlotSound.shared.play(.tick)
        await pause(0.3)
        withAnimation(.spring(duration: 0.35)) { dealer.append(draw()) }
        SlotSound.shared.play(.tick)
        await pause(0.4)
        if handTotal(player) == 21 {
            await dealerPlay()
        }
    }

    func hit() {
        guard phase == .player else { return }
        withAnimation(.spring(duration: 0.35)) { player.append(draw()) }
        SlotSound.shared.play(.tick)
        Haptics.tap(.light)
        let t = handTotal(player)
        if t > 21 {
            task = Task { await dealerPlay() }
        } else if t == 21 {
            stand()
        }
    }

    func stand() {
        guard phase == .player else { return }
        task = Task { await dealerPlay() }
    }

    func double() {
        guard phase == .player, player.count == 2, balance >= wager else { return }
        balance -= wager
        wager *= 2
        withAnimation(.spring(duration: 0.35)) { player.append(draw()) }
        SlotSound.shared.play(.tick)
        task = Task { await dealerPlay() }
    }

    private func dealerPlay() async {
        phase = .dealer
        await pause(0.4)
        withAnimation(.spring(duration: 0.35)) { holeHidden = false }
        await pause(0.6)
        if handTotal(player) <= 21 {
            while handTotal(dealer) < 17 && !Task.isCancelled {
                withAnimation(.spring(duration: 0.35)) { dealer.append(draw()) }
                SlotSound.shared.play(.tick)
                await pause(0.7)
            }
        }
        settle()
    }

    private func settle() {
        let p = handTotal(player)
        let d = handTotal(dealer)
        let playerBJ = player.count == 2 && p == 21
        let dealerBJ = dealer.count == 2 && d == 21
        var payout = 0.0
        var text = "Vesztettél"
        if p > 21 {
            text = "Bust"
        } else if playerBJ && !dealerBJ {
            payout = wager * 2.5
            text = "Blackjack!"
        } else if dealerBJ && !playerBJ {
            text = "Osztó blackjack"
        } else if d > 21 || p > d {
            payout = wager * 2
            text = "Nyertél"
        } else if p == d {
            payout = wager
            text = "Döntetlen"
        }
        balance += payout
        message = text
        phase = .done
        if payout > wager {
            SlotSound.shared.play(playerBJ ? .big : .win)
            Haptics.success()
            let c = Celebration(ratio: playerBJ ? 14 : 6, jackpot: false)
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
        VStack(spacing: 8) {
            hand(engine.player, hideSecond: false)
            HStack(spacing: 10) {
                Text(engine.player.isEmpty ? " " : "\(handTotal(engine.player))")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                if engine.wager > 0 && engine.phase != .betting {
                    Text(engine.wager.ft)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.yellow.opacity(0.25), in: .capsule)
                }
            }
            .frame(height: 28)
        }
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
                    .opacity(engine.player.count == 2 && engine.balance >= engine.wager ? 1 : 0.4)
                    .disabled(!(engine.player.count == 2 && engine.balance >= engine.wager))
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
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 62)
                .glassEffect(.regular.tint(color.opacity(0.5)).interactive(), in: .rect(cornerRadius: 22))
        }
        .buttonStyle(.plain)
    }
}
