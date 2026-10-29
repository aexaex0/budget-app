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
}

enum ParticleFactory {
    /// Minél nagyobb a nyeremény a tét többszöröseként, annál több konfetti és pénzeső.
    static func make(ratio: Double, jackpot: Bool) -> [Particle] {
        let confettiCount: Int = jackpot ? 380 : min(Int(24 + ratio * 4), 320)
        let coinCount: Int = jackpot ? 120 : (ratio >= 15 ? min(Int(ratio), 90) : 0)
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
                for p in particles {
                    let lt = t - p.delay
                    if lt < 0 { continue }
                    let y = -30 + lt * p.speed
                    if y > size.height + 40 { continue }
                    let x = p.x * size.width + sin(lt * p.swayFreq) * p.swayAmp
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
