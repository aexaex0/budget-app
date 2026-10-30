import SwiftUI

/// Mini játék a Piggy Bankhez: húzd fel az érmét, és találd el a mozgó zsebet.
struct PocketGameView: View {
    @EnvironmentObject private var store: ThemeStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("pocketBest") private var best = 0
    @State private var streakHits = 0
    @State private var coin: CGPoint?
    @State private var flying = false
    @State private var coinVisible = true
    @State private var bounce = false
    @State private var celebration: Celebration?

    private let flight = 0.42

    private func pocketX(_ date: Date, mid: CGFloat, amp: CGFloat) -> CGFloat {
        mid + CGFloat(sin(date.timeIntervalSinceReferenceDate * 1.7)) * amp
    }

    private var pocketWidth: CGFloat { max(110 - CGFloat(streakHits) * 4, 62) }

    var body: some View {
        let tr = store.tr
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let mid = w / 2
            let amp = w / 2 - 80
            let pocketY: CGFloat = 190
            let rest = CGPoint(x: mid, y: h - 170)
            ZStack {
                AppBackground()
                Color.black.opacity(0.35).ignoresSafeArea()

                VStack(spacing: 4) {
                    Text("\(streakHits)")
                        .font(.system(size: 54, weight: .heavy, design: .rounded))
                        .contentTransition(.numericText(value: Double(streakHits)))
                    Text(tr("Legjobb: \(best)", "Best: \(best)"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .position(x: mid, y: 90)

                TimelineView(.animation) { ctx in
                    let px = pocketX(ctx.date, mid: mid, amp: amp)
                    UnevenRoundedRectangle(topLeadingRadius: 8, bottomLeadingRadius: pocketWidth / 2,
                                           bottomTrailingRadius: pocketWidth / 2, topTrailingRadius: 8)
                        .fill(Color.accentColor.gradient)
                        .frame(width: pocketWidth, height: 76)
                        .scaleEffect(bounce ? 1.12 : 1)
                        .position(x: px, y: pocketY)
                }

                if coinVisible {
                    Text("🪙")
                        .font(.system(size: 54))
                        .position(coin ?? rest)
                        .gesture(
                            DragGesture()
                                .onChanged { v in
                                    guard !flying else { return }
                                    coin = CGPoint(x: rest.x + v.translation.width,
                                                   y: rest.y + v.translation.height)
                                }
                                .onEnded { v in
                                    guard !flying else { return }
                                    throwCoin(v, rest: rest, pocketY: pocketY, mid: mid, amp: amp)
                                }
                        )
                }

                VStack {
                    HStack {
                        Button {
                            Haptics.tap()
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.headline)
                                .frame(width: 44, height: 44)
                                .glassEffect(.regular.interactive(), in: .circle)
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    Spacer()
                    Text(tr("Húzd fel az érmét a zsebbe", "Flick the coin into the pocket"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                if let c = celebration {
                    CelebrationView(celebration: c).id(c.id)
                }
            }
            .onAppear { coin = rest }
        }
        .preferredColorScheme(.dark)
    }

    private func throwCoin(_ v: DragGesture.Value, rest: CGPoint, pocketY: CGFloat,
                           mid: CGFloat, amp: CGFloat) {
        guard v.translation.height < -50 else {
            withAnimation(.spring(duration: 0.3)) { coin = rest }
            return
        }
        flying = true
        let extra = (v.predictedEndTranslation.width - v.translation.width) * 0.4
        let targetX = min(max(rest.x + v.translation.width + extra, 20), rest.x * 2 - 20)
        let arrival = Date().addingTimeInterval(flight)
        let px = pocketX(arrival, mid: mid, amp: amp)
        let hit = abs(targetX - px) < pocketWidth / 2 - 6
        withAnimation(.easeOut(duration: flight)) {
            coin = CGPoint(x: targetX, y: pocketY)
        }
        Task {
            try? await Task.sleep(for: .seconds(flight))
            if hit {
                streakHits += 1
                best = max(best, streakHits)
                Stats.add("pocket")
                SlotSound.shared.play(.coin)
                Haptics.success()
                withAnimation(.spring(duration: 0.25, bounce: 0.6)) { bounce = true }
                if streakHits % 5 == 0 {
                    let c = Celebration(ratio: 6, jackpot: false)
                    celebration = c
                    Task {
                        try? await Task.sleep(for: .seconds(c.lifetime))
                        if celebration?.id == c.id { celebration = nil }
                    }
                }
            } else {
                streakHits = 0
                Haptics.tap(.rigid)
                withAnimation(.easeIn(duration: 0.4)) {
                    coin = CGPoint(x: targetX, y: rest.y + 200)
                }
            }
            try? await Task.sleep(for: .seconds(hit ? 0.25 : 0.4))
            withAnimation(.spring(duration: 0.25)) { bounce = false }
            coinVisible = false
            coin = rest
            try? await Task.sleep(for: .seconds(0.12))
            withAnimation(.easeOut(duration: 0.2)) { coinVisible = true }
            flying = false
        }
    }
}
