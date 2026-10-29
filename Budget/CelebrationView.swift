import SwiftUI

struct Particle {
    let x: Double          // 0...1 a szélesség arányában
    let delay: Double
    let speed: Double
    let size: Double
    let swayAmp: Double
    let swayFreq: Double
    let rotSpeed: Double
    let color: Color
    let emoji: String?     // nil = konfetti szelet
    var burst = false      // alulról kilőtt konfetti
    var vx = 0.0
    var vy = 0.0
}

enum ParticleFactory {
    /// Minél nagyobb a nyeremény a tét többszöröseként, annál több konfetti és pénzeső.
    static func make(ratio: Double, jackpot: Bool) -> [Particle] {
        let confettiCount: Int = jackpot ? 520 : min(Int(24 + ratio * 5), 420)
        let coinCount: Int = jackpot ? 160 : (ratio >= 15 ? min(Int(ratio * 1.5), 120) : 0)
        let burstCount: Int = jackpot ? 260 : (ratio >= 15 ? min(Int(ratio * 3), 200) : 0)
        let colors: [Color] = [.red, .orange, .yellow, .green, .mint, .cyan, .blue, .purple, .pink]
        let coins: [String] = ["💰", "💵", "🪙", "💸"]
        var out: [Particle] = []

        for _ in 0..<confettiCount {
            out.append(Particle(
                x: Double.random(in: 0...1),
                delay: Double.random(in: 0...1.8),
                speed: Double.random(in: 170...420),
                size: Double.random(in: 7...14),
                swayAmp: Double.random(in: 8...40),
                swayFreq: Double.random(in: 1.5...5),
                rotSpeed: Double.random(in: -9...9),
                color: colors.randomElement() ?? .yellow,
                emoji: nil))
        }
        for _ in 0..<coinCount {
            out.append(Particle(
                x: Double.random(in: 0...1),
                delay: Double.random(in: 0...2.4),
                speed: Double.random(in: 220...480),
                size: Double.random(in: 22...34),
                swayAmp: Double.random(in: 6...26),
                swayFreq: Double.random(in: 1...3),
                rotSpeed: 0,
                color: .yellow,
                emoji: coins.randomElement() ?? "💰"))
        }
        for i in 0..<burstCount {
            let left = i % 2 == 0
            out.append(Particle(
                x: left ? 0 : 1,
                delay: Double.random(in: 0...0.5),
                speed: 0,
                size: Double.random(in: 8...15),
                swayAmp: 0,
                swayFreq: 1,
                rotSpeed: Double.random(in: -12...12),
                color: colors.randomElement() ?? .yellow,
                emoji: nil,
                burst: true,
                vx: (left ? 1 : -1) * Double.random(in: 80...380),
                vy: -Double.random(in: 650...1150)))
        }
        return out
    }
}

struct CelebrationView: View {
    let celebration: Celebration
    @State private var particles: [Particle]

    init(celebration: Celebration) {
        self.celebration = celebration
        _particles = State(initialValue: ParticleFactory.make(ratio: celebration.ratio,
                                                              jackpot: celebration.jackpot))
    }

    var body: some View {
        TimelineView(.animation) { ctx in
            Canvas { context, size in
                let t = ctx.date.timeIntervalSince(celebration.start)
                if celebration.ratio >= 15 || celebration.jackpot {
                    let a = max(0, 0.45 - t * 0.9)
                    if a > 0 {
                        context.fill(Path(CGRect(origin: .zero, size: size)),
                                     with: .color(Color.yellow.opacity(a)))
                    }
                }
                for p in particles {
                    let lt = t - p.delay
                    if lt < 0 { continue }
                    var x: Double
                    var y: Double
                    if p.burst {
                        x = p.x * size.width + p.vx * lt
                        y = size.height * 0.85 + p.vy * lt + 520 * lt * lt
                        if y > size.height + 40 && lt > 0.4 { continue }
                    } else {
                        y = -30 + lt * p.speed
                        if y > size.height + 40 { continue }
                        x = p.x * size.width + sin(lt * p.swayFreq) * p.swayAmp
                    }
                    if let e = p.emoji {
                        context.draw(Text(e).font(.system(size: p.size)), at: CGPoint(x: x, y: y))
                    } else {
                        var g = context
                        g.translateBy(x: x, y: y)
                        g.rotate(by: .radians(lt * p.rotSpeed))
                        let rect = CGRect(x: -p.size / 2, y: -p.size * 0.3,
                                          width: p.size, height: p.size * 0.6)
                        g.fill(Path(rect), with: .color(p.color))
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}
