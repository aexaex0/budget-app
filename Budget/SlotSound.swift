import AVFoundation

/// Hangok: nincsenek külső fájlok, minden a kódban generálódik (szinusz hangok).
@MainActor
final class SlotSound {
    static let shared = SlotSound()

    enum Kind: CaseIterable { case tick, stop, coin, win, big, mega, jackpot }

    var enabled = true
    private var pools: [Kind: [AVAudioPlayer]] = [:]
    private var next: [Kind: Int] = [:]

    private struct Note {
        var f: Double
        var t: Double
        var d: Double
        var a: Double
        var decay: Double
        var noise = false
    }

    private init() {
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? s.setActive(true)
        for k in Kind.allCases {
            let (notes, len) = Self.recipe(k)
            let data = Self.wav(notes, length: len)
            let count = (k == .tick || k == .coin || k == .stop) ? 4 : 1
            var arr: [AVAudioPlayer] = []
            for _ in 0..<count {
                if let p = try? AVAudioPlayer(data: data) {
                    p.prepareToPlay()
                    p.volume = k == .tick ? 0.35 : 0.9
                    arr.append(p)
                }
            }
            pools[k] = arr
        }
    }

    func play(_ k: Kind) {
        guard enabled, let arr = pools[k], !arr.isEmpty else { return }
        let i = (next[k] ?? 0) % arr.count
        next[k] = i + 1
        let p = arr[i]
        p.currentTime = 0
        p.play()
    }

    func stopAll() {
        for (_, arr) in pools { arr.forEach { $0.stop() } }
    }

    // MARK: Hangrecept

    private static func arp(_ freqs: [Double], gap: Double, d: Double, a: Double, decay: Double,
                            start: Double = 0) -> [Note] {
        freqs.enumerated().map { i, f in
            Note(f: f, t: start + Double(i) * gap, d: d, a: a, decay: decay)
        }
    }

    private static func recipe(_ k: Kind) -> ([Note], Double) {
        let c5 = 523.25, e5 = 659.25, g5 = 783.99, c6 = 1046.5, e6 = 1318.5, g6 = 1568.0
        switch k {
        case .tick:
            return ([Note(f: 1500, t: 0, d: 0.03, a: 0.5, decay: 110)], 0.04)
        case .stop:
            return ([Note(f: 150, t: 0, d: 0.2, a: 0.9, decay: 20),
                     Note(f: 0, t: 0, d: 0.05, a: 0.35, decay: 80, noise: true)], 0.22)
        case .coin:
            return ([Note(f: 1568, t: 0, d: 0.25, a: 0.5, decay: 14),
                     Note(f: 2093, t: 0.07, d: 0.3, a: 0.5, decay: 12)], 0.4)
        case .win:
            return (arp([c5, e5, g5], gap: 0.09, d: 0.4, a: 0.5, decay: 7), 0.8)
        case .big:
            var n = arp([c5, e5, g5, c6, e6], gap: 0.08, d: 0.45, a: 0.4, decay: 6)
            n += [c6, e6, g6].map { Note(f: $0, t: 0.45, d: 0.7, a: 0.3, decay: 3.5) }
            return (n, 1.3)
        case .mega:
            var n = arp([c5, e5, g5, c6, e6, g6, c6 * 2], gap: 0.07, d: 0.5, a: 0.4, decay: 5)
            n += [c5, e5, g5, c6].map { Note(f: $0, t: 0.55, d: 1.1, a: 0.28, decay: 2.5) }
            n += arp([c6, e6, g6, c6 * 2], gap: 0.12, d: 0.4, a: 0.3, decay: 5, start: 0.9)
            return (n, 2.0)
        case .jackpot:
            var n: [Note] = []
            for r in 0..<4 {
                n += arp([c5, e5, g5, c6, e6, g6, c6 * 2], gap: 0.06, d: 0.45, a: 0.35, decay: 5,
                         start: Double(r) * 0.55)
                n += [c5, g5, e6].map { Note(f: $0, t: Double(r) * 0.55 + 0.4, d: 0.6, a: 0.25, decay: 4) }
            }
            n += [c5, e5, g5, c6, e6].map { Note(f: $0, t: 2.3, d: 1.6, a: 0.28, decay: 1.8) }
            return (n, 4.0)
        }
    }

    private static func wav(_ notes: [Note], length: Double) -> Data {
        let rate = 22050.0
        let total = Int(length * rate)
        var buf = [Double](repeating: 0, count: total)
        var noiseState: Double = 0
        for n in notes {
            let start = Int(n.t * rate)
            let cnt = Int(n.d * rate)
            if cnt <= 0 { continue }
            for i in 0..<cnt {
                let idx = start + i
                if idx >= total { break }
                let t = Double(i) / rate
                let attack = min(t / 0.004, 1.0)
                let env = attack * exp(-n.decay * t)
                var s: Double
                if n.noise {
                    noiseState = noiseState * 0.6 + Double.random(in: -1...1) * 0.4
                    s = noiseState
                } else {
                    let w = 2 * Double.pi * n.f * t
                    s = sin(w) + 0.3 * sin(2 * w) + 0.12 * sin(3 * w)
                }
                buf[idx] += s * env * n.a
            }
        }
        var pcm = Data(capacity: total * 2)
        for v in buf {
            let c = max(-1.0, min(1.0, v * 0.8))
            var s = Int16(c * 32000).littleEndian
            withUnsafeBytes(of: &s) { pcm.append(contentsOf: $0) }
        }
        var d = Data()
        func u32(_ v: UInt32) { var x = v.littleEndian; withUnsafeBytes(of: &x) { d.append(contentsOf: $0) } }
        func u16(_ v: UInt16) { var x = v.littleEndian; withUnsafeBytes(of: &x) { d.append(contentsOf: $0) } }
        d.append(contentsOf: Array("RIFF".utf8)); u32(UInt32(36 + pcm.count))
        d.append(contentsOf: Array("WAVE".utf8))
        d.append(contentsOf: Array("fmt ".utf8)); u32(16); u16(1); u16(1)
        u32(UInt32(rate)); u32(UInt32(rate) * 2); u16(2); u16(16)
        d.append(contentsOf: Array("data".utf8)); u32(UInt32(pcm.count))
        d.append(pcm)
        return d
    }
}
