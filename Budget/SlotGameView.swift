import SwiftUI
import SwiftData

/// Demó slot. Az egyenleg a havi megmaradásból indul, de csak a játékon belül létezik:
/// semmi nem vonódik le a valódi pénzedből, és kilépéskor minden visszaáll.
struct SlotGameView: View {
    @EnvironmentObject private var store: ThemeStore
    @Environment(\.dismiss) private var dismiss
    @Query private var entries: [Entry]
    @StateObject private var engine = SlotEngine()
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
            Color.black.opacity(0.45).ignoresSafeArea()

            VStack(spacing: 14) {
                topBar
                jackpotHeader
                multiplierStrip
                reels
                Spacer(minLength: 0)
                latestWin
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
        .onDisappear { engine.stopAll() }
    }

    // MARK: Felső sor: bezárás + egyenleg

    private var topBar: some View {
        HStack {
            Button {
                Haptics.tap()
                engine.stopAll()
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
            Button {
                Haptics.tap()
                engine.sound.toggle()
            } label: {
                Image(systemName: engine.sound ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.headline)
                    .frame(width: 44, height: 44)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Jackpot fejléc (a tét szerint skálázódik)

    private func compact(_ v: Double) -> String {
        v.formatted(.number.notation(.compactName).locale(Locale(identifier: "en_US")))
    }

    private func rangeText(_ tier: JackpotTier) -> String {
        let a = compact(Double(engine.bet) * tier.factors.lo)
        let b = compact(Double(engine.bet) * tier.factors.hi)
        return tier.factors.lo == tier.factors.hi ? a : "\(a)–\(b)"
    }

    private var jackpotHeader: some View {
        HStack(spacing: 6) {
            ForEach(JackpotTier.allCases, id: \.rawValue) { tier in
                let hit = engine.jackpotMode && engine.landedMult && engine.multIndex == tier.rawValue
                VStack(spacing: 2) {
                    Text(tier.title).font(.system(size: 11, weight: .heavy, design: .rounded))
                    Text(rangeText(tier))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .foregroundStyle(hit ? Color.black : Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(hit ? Color.yellow : Color.white.opacity(0.10), in: .rect(cornerRadius: 14))
                .shadow(color: hit ? Color.yellow.opacity(0.8) : Color.clear, radius: 12)
                .scaleEffect(hit ? 1.06 : 1)
                .animation(.spring(duration: 0.3, bounce: 0.4), value: hit)
            }
        }
    }

    // MARK: Szorzó sor

    private var multiplierStrip: some View {
        let labels: [String] = engine.jackpotMode
            ? JackpotTier.allCases.map { $0.title }
            : Multiplier.values.map { "\($0)x" }
        return HStack(spacing: 8) {
            ForEach(labels.indices, id: \.self) { i in
                let on = i == engine.multIndex
                Text(labels[i])
                    .font(.system(size: engine.jackpotMode ? 13 : 20, weight: .heavy, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .foregroundStyle(on ? Color.black : Color.white)
                    .background(on ? Color.yellow : Color.white.opacity(0.12), in: .rect(cornerRadius: 14))
                    .scaleEffect(on ? 1.1 : 1)
                    .shadow(color: on ? Color.yellow.opacity(0.7) : Color.clear, radius: 10)
            }
        }
        .animation(.easeOut(duration: 0.08), value: engine.multIndex)
        .padding(8)
        .background(Color.white.opacity(0.08), in: .rect(cornerRadius: 22))
    }

    // MARK: 3x3-as rács (valódi görgetés)

    private let gap: CGFloat = 10

    private func isWinning(col: Int, row: Int) -> Bool {
        engine.winLines.contains { i in
            SlotOutcome.lines[i].contains { $0.col == col && $0.row == row }
        }
    }

    private func winCells(_ col: Int) -> [Bool] {
        (0..<3).map { row in isWinning(col: col, row: row) }
    }

    private var reels: some View {
        HStack(spacing: gap) {
            ForEach(0..<3, id: \.self) { col in
                ReelColumn(strip: engine.strips[col],
                           start: engine.reelStart[col],
                           duration: engine.reelDur[col],
                           spinning: engine.spinningCols[col],
                           bounce: engine.bounce[col],
                           wins: winCells(col))
                    .equatable()
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.08), in: .rect(cornerRadius: 28))
        .overlay {
            if let b = engine.winBanner {
                Text(b)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: .black.opacity(0.7), radius: 6)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .transition(.scale.combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
    }

    private var latestWin: some View {
        VStack(spacing: 2) {
            Text("LATEST WIN")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(.secondary)
            Text(engine.shownWin.ft)
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(engine.shownWin > 0 ? Color.yellow : Color.white.opacity(0.5))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText(value: engine.shownWin))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Vezérlők: bet | pörgetés | autospin + fast

    private var canSpin: Bool {
        !engine.busy && engine.balance >= Double(engine.bet)
    }

    private var controls: some View {
        HStack(spacing: 16) {
            Menu {
                ForEach(SlotEngine.bets, id: \.self) { b in
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
            .disabled(engine.busy)

            Button {
                Haptics.tap(.medium)
                engine.spinTapped()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 92, height: 92)
                    .glassEffect(.regular.tint(Color.green.opacity(0.55)).interactive(), in: .circle)
                    .opacity(canSpin ? 1 : 0.45)
            }
            .buttonStyle(.plain)
            .disabled(!canSpin)

            VStack(spacing: 10) {
                toggleButton("repeat", on: engine.autoSpin) { engine.autoSpin.toggle() }
                toggleButton("bolt.fill", on: engine.fast) { engine.fast.toggle() }
            }
        }
    }

    private func toggleButton(_ icon: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap(.soft)
            action()
        } label: {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(on ? Color.yellow : Color.white)
                .frame(width: 46, height: 46)
                .glassEffect(on ? .regular.tint(Color.yellow.opacity(0.35)).interactive()
                                : .regular.interactive(), in: .circle)
        }
        .buttonStyle(.plain)
    }
}

/// A tekercs Canvas-on rajzolódik, az állapotot az idő adja, nem a SwiftUI nézetfa.
/// Így pörgetés közben nincs nézetfrissítés, csak egy sima rajzolás képkockánként.
struct ReelColumn: View, Equatable {
    let strip: [SlotSymbol]
    let start: Date
    let duration: Double
    let spinning: Bool
    let bounce: Bool
    let wins: [Bool]

    private let cellSize: CGFloat = 92
    private let gap: CGFloat = 10

    private func progress(at date: Date) -> Double {
        let x = date.timeIntervalSince(start) / max(duration, 0.01)
        if x <= 0 { return 0 }
        if x >= 1 { return 1 }
        return 1 - pow(1 - x, 2.4)
    }

    var body: some View {
        let step = cellSize + gap
        let height = cellSize * 3 + gap * 2
        TimelineView(.animation(minimumInterval: nil, paused: !spinning)) { ctx in
            Canvas { context, size in
                let p = progress(at: ctx.date)
                let travel = Double(max(strip.count - 3, 0)) * Double(step)
                let off = -(1 - p) * travel
                // háttér cellák
                for r in 0..<3 {
                    let rect = CGRect(x: 0, y: CGFloat(r) * step, width: cellSize, height: cellSize)
                    context.fill(Path(roundedRect: rect, cornerRadius: 18),
                                 with: .color(Color.white.opacity(0.10)))
                }
                // tekercs
                var clipped = context
                clipped.clip(to: Path(CGRect(origin: .zero, size: size)))
                for i in strip.indices {
                    let y = Double(i) * Double(step) + off
                    if y < -Double(step) || y > Double(height) { continue }
                    if let sym = context.resolveSymbol(id: strip[i].rawValue) {
                        clipped.draw(sym, at: CGPoint(x: cellSize / 2, y: y + Double(cellSize) / 2))
                    }
                }
                // nyerő keretek
                for r in 0..<3 where wins[r] {
                    let rect = CGRect(x: 1.5, y: CGFloat(r) * step + 1.5,
                                      width: cellSize - 3, height: cellSize - 3)
                    context.stroke(Path(roundedRect: rect, cornerRadius: 17),
                                   with: .color(.yellow), lineWidth: 3)
                }
            } symbols: {
                ForEach(SlotSymbol.allCases, id: \.rawValue) { s in
                    Text(s.glyph).font(.system(size: 46)).tag(s.rawValue)
                }
            }
        }
        .frame(width: cellSize, height: height)
        .offset(y: bounce ? 8 : 0)
        .animation(.spring(duration: 0.2, bounce: 0.5), value: bounce)
    }
}
