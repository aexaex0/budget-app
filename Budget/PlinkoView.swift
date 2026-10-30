import SwiftUI
import SwiftData

/// Demó Plinko: nem érinti a valódi adatokat. Valódi véletlen, kb. 96% visszafizetés.
@MainActor
final class PlinkoEngine: ObservableObject {
    static let rows = 8
    static let mults: [Double] = [18, 3.4, 1.3, 0.55, 0.3, 0.55, 1.3, 3.4, 18]
    static let bets: [Int] = [20, 40, 60, 100, 200, 400, 800, 1000, 1200, 1500, 2000, 2500, 3000, 4000]

    struct Ball: Identifiable {
        let id = UUID()
        var level = 0
        var k = 0
    }

    struct Hit: Identifiable {
        let id = UUID()
        let mult: Double
    }

    @Published var balance: Double = 0
    @Published var bet: Int = 60
    @Published var balls: [Ball] = []
    @Published var hits: [Hit] = []
    @Published var hot: Int?
    @Published var lastWin: Double = 0
    @Published var celebration: Celebration?

    private var tasks: [Task<Void, Never>] = []

    func reset(balance: Double) {
        self.balance = balance
        if Double(bet) > balance, let b = Self.bets.last(where: { Double($0) <= balance }) {
            bet = b
        }
    }

    func stop() {
        tasks.forEach { $0.cancel() }
    }

    func drop() {
        let b = Double(bet)
        guard balance >= b else { return }
        balance -= b
        Stats.add("plinko")
        let ball = Ball()
        withAnimation(.easeOut(duration: 0.2)) { balls.append(ball) }
        tasks.append(Task { await run(ball.id, bet: b) })
    }

    private func update(_ id: UUID, level: Int, k: Int) {
        if let i = balls.firstIndex(where: { $0.id == id }) {
            balls[i].level = level
            balls[i].k = k
        }
    }

    private func run(_ id: UUID, bet: Double) async {
        var k = 0
        for l in 1...Self.rows {
            try? await Task.sleep(for: .seconds(0.05))
            if Task.isCancelled { return }
            if Bool.random() { k += 1 }
            withAnimation(.easeIn(duration: 0.19)) { update(id, level: l, k: k) }
            try? await Task.sleep(for: .seconds(0.19))
            SlotSound.shared.play(.tick)
        }
        let mult = Self.mults[k]
        let payout = (bet * mult).rounded()
        balance += payout
        lastWin = payout
        hot = k
        hits.insert(Hit(mult: mult), at: 0)
        if hits.count > 8 { hits.removeLast() }
        if mult >= 3 {
            SlotSound.shared.play(mult >= 10 ? .big : .win)
            Haptics.success()
            let c = Celebration(ratio: mult >= 10 ? 20 : 6, jackpot: false)
            celebration = c
            Task {
                try? await Task.sleep(for: .seconds(c.lifetime))
                if celebration?.id == c.id { celebration = nil }
            }
        } else if mult >= 1 {
            SlotSound.shared.play(.coin)
        }
        Haptics.tap(.light)
        try? await Task.sleep(for: .seconds(0.25))
        withAnimation(.easeOut(duration: 0.2)) { balls.removeAll { $0.id == id } }
        try? await Task.sleep(for: .seconds(0.4))
        if hot == k { hot = nil }
    }
}

struct PlinkoView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var entries: [Entry]
    @StateObject private var engine = PlinkoEngine()
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
                lastHits
                board
                Spacer(minLength: 0)
                Text(engine.lastWin.ft)
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(engine.lastWin > 0 ? Color.yellow : Color.white.opacity(0.5))
                    .contentTransition(.numericText(value: engine.lastWin))
                    .animation(.snappy, value: engine.lastWin)
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

    private func fmt(_ m: Double) -> String {
        m == m.rounded() ? "\(Int(m))x" : String(format: "%.2gx", m)
    }

    private var lastHits: some View {
        HStack(spacing: 6) {
            ForEach(engine.hits) { h in
                Text(fmt(h.mult))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color(for: h.mult).opacity(0.35), in: .capsule)
                    .transition(.scale.combined(with: .opacity))
            }
            Spacer(minLength: 0)
        }
        .frame(height: 26)
        .animation(.spring(duration: 0.3), value: engine.hits.count)
    }

    private func color(for m: Double) -> Color {
        if m >= 10 { return .yellow }
        if m >= 3 { return .green }
        if m >= 1 { return .mint }
        return .red
    }

    private var board: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let dx = w / 9
            let dy: CGFloat = 32
            let rows = PlinkoEngine.rows
            ZStack(alignment: .topLeading) {
                // csapok
                ForEach(0..<rows, id: \.self) { l in
                    ForEach(0...l, id: \.self) { j in
                        Circle()
                            .fill(Color.white.opacity(0.75))
                            .frame(width: 7, height: 7)
                            .position(x: w / 2 + CGFloat(2 * j - l) * dx / 2,
                                      y: CGFloat(l) * dy + dy)
                    }
                }
                // vödrök
                ForEach(0..<9, id: \.self) { k in
                    let m = PlinkoEngine.mults[k]
                    let hot = engine.hot == k
                    Text(fmt(m))
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .frame(width: dx - 4, height: 32)
                        .foregroundStyle(hot ? Color.black : Color.white)
                        .background(hot ? color(for: m) : color(for: m).opacity(0.35),
                                    in: .rect(cornerRadius: 8))
                        .scaleEffect(hot ? 1.15 : 1)
                        .animation(.spring(duration: 0.25, bounce: 0.5), value: hot)
                        .position(x: w / 2 + CGFloat(2 * k - rows) * dx / 2,
                                  y: CGFloat(rows + 1) * dy + 14)
                }
                // golyók
                ForEach(engine.balls) { b in
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 14, height: 14)
                        .shadow(color: Color.yellow.opacity(0.8), radius: 6)
                        .position(ballPoint(b, w: w, dx: dx, dy: dy))
                        .transition(.opacity)
                }
            }
        }
        .frame(height: 8 * 32 + 32 + 60)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.06), in: .rect(cornerRadius: 24))
    }

    private func ballPoint(_ b: PlinkoEngine.Ball, w: CGFloat, dx: CGFloat, dy: CGFloat) -> CGPoint {
        let rows = PlinkoEngine.rows
        let x = w / 2 + CGFloat(2 * b.k - b.level) * dx / 2
        let y: CGFloat = b.level >= rows
            ? CGFloat(rows + 1) * dy + 14
            : CGFloat(b.level) * dy + dy * 0.45
        return CGPoint(x: x, y: y)
    }

    private var controls: some View {
        HStack(spacing: 16) {
            Menu {
                ForEach(PlinkoEngine.bets, id: \.self) { b in
                    Button {
                        engine.bet = b
                    } label: {
                        if b == engine.bet {
                            Label(Double(b).ft, systemImage: "checkmark")
                        } else {
                            Text(Double(b).ft)
                        }
                    }
                }
            } label: {
                VStack(spacing: 2) {
                    Text("BET").font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text(Double(engine.bet).ft)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .foregroundStyle(Color.white)
                .frame(width: 96, height: 60)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
            }

            Button {
                Haptics.tap(.medium)
                engine.drop()
            } label: {
                Text("DROP")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 70)
                    .glassEffect(.regular.tint(Color.green.opacity(0.55)).interactive(),
                                 in: .rect(cornerRadius: 28))
                    .opacity(engine.balance >= Double(engine.bet) ? 1 : 0.45)
            }
            .buttonStyle(.plain)
            .disabled(engine.balance < Double(engine.bet))
        }
    }
}
