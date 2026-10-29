import SwiftUI
import UIKit

// MARK: - Nyelv

/// Kis segéd: tr("magyar", "english")
struct Tr {
    let en: Bool
    func callAsFunction(_ hu: String, _ eng: String) -> String { en ? eng : hu }
}

enum Fmt { static var en = false }

extension Double {
    /// Forint formázás (magyar vagy angol számformátum, mindig "Ft")
    var ft: String {
        let loc = Locale(identifier: Fmt.en ? "en_US" : "hu_HU")
        return self.formatted(.number.precision(.fractionLength(0)).locale(loc)) + " Ft"
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case system, hu, en
    var id: String { rawValue }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
}

// MARK: - Szín és átmenet

struct RGBA: Codable, Equatable {
    var r: Double
    var g: Double
    var b: Double

    init(_ r: Double, _ g: Double, _ b: Double) { self.r = r; self.g = g; self.b = b }

    init(color: Color) {
        let ui = UIColor(color)
        var rr: CGFloat = 0, gg: CGFloat = 0, bb: CGFloat = 0, aa: CGFloat = 0
        ui.getRed(&rr, green: &gg, blue: &bb, alpha: &aa)
        self.init(Double(rr), Double(gg), Double(bb))
    }

    var color: Color { Color(red: r, green: g, blue: b) }
}

enum GradientStyle: String, CaseIterable, Codable, Identifiable {
    case leftToRight, rightToLeft, topToBottom, bottomToTop
    case diagDown, diagUp, radialOut, radialIn, angular

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .leftToRight: "arrow.right"
        case .rightToLeft: "arrow.left"
        case .topToBottom: "arrow.down"
        case .bottomToTop: "arrow.up"
        case .diagDown: "arrow.down.right"
        case .diagUp: "arrow.up.right"
        case .radialOut: "arrow.up.left.and.arrow.down.right"
        case .radialIn: "arrow.down.right.and.arrow.up.left"
        case .angular: "arrow.triangle.2.circlepath"
        }
    }

    func title(_ tr: Tr) -> String {
        switch self {
        case .leftToRight: tr("Balról jobbra", "Left to right")
        case .rightToLeft: tr("Jobbról balra", "Right to left")
        case .topToBottom: tr("Fentről le", "Top to bottom")
        case .bottomToTop: tr("Lentről fel", "Bottom to top")
        case .diagDown: tr("Bal felsőből jobb alsóba", "Top-left to bottom-right")
        case .diagUp: tr("Bal alsóból jobb felsőbe", "Bottom-left to top-right")
        case .radialOut: tr("Középről kifelé", "Center outward")
        case .radialIn: tr("Kintről befelé", "Edges inward")
        case .angular: tr("Körkörös", "Circular")
        }
    }
}

struct AppTheme: Codable, Equatable, Identifiable {
    var id: String
    var nameHu: String
    var nameEn: String
    var colors: [RGBA]
    var accent: RGBA
    var style: GradientStyle
    var intensity: Double
    var animated: Bool
    var orbs: Bool

    func name(_ tr: Tr) -> String { tr(nameHu, nameEn) }

    static let presets: [AppTheme] = [
        AppTheme(id: "ocean", nameHu: "Óceán", nameEn: "Ocean",
                 colors: [RGBA(0.20, 0.55, 0.98), RGBA(0.18, 0.85, 0.82)],
                 accent: RGBA(0.10, 0.45, 0.95), style: .diagDown, intensity: 0.85, animated: true, orbs: true),
        AppTheme(id: "sunset", nameHu: "Naplemente", nameEn: "Sunset",
                 colors: [RGBA(1.00, 0.55, 0.30), RGBA(0.95, 0.30, 0.55), RGBA(0.45, 0.25, 0.80)],
                 accent: RGBA(0.95, 0.35, 0.40), style: .topToBottom, intensity: 0.85, animated: true, orbs: true),
        AppTheme(id: "forest", nameHu: "Erdő", nameEn: "Forest",
                 colors: [RGBA(0.10, 0.55, 0.40), RGBA(0.60, 0.85, 0.45)],
                 accent: RGBA(0.10, 0.60, 0.40), style: .bottomToTop, intensity: 0.80, animated: false, orbs: true),
        AppTheme(id: "lavender", nameHu: "Levendula", nameEn: "Lavender",
                 colors: [RGBA(0.70, 0.55, 0.98), RGBA(0.98, 0.70, 0.90)],
                 accent: RGBA(0.55, 0.35, 0.90), style: .radialOut, intensity: 0.85, animated: true, orbs: false),
        AppTheme(id: "midnight", nameHu: "Éjfél", nameEn: "Midnight",
                 colors: [RGBA(0.10, 0.12, 0.40), RGBA(0.35, 0.20, 0.65), RGBA(0.05, 0.05, 0.20)],
                 accent: RGBA(0.55, 0.60, 1.00), style: .diagUp, intensity: 0.95, animated: true, orbs: true),
        AppTheme(id: "rose", nameHu: "Rózsa", nameEn: "Rose",
                 colors: [RGBA(1.00, 0.70, 0.75), RGBA(1.00, 0.88, 0.70)],
                 accent: RGBA(0.90, 0.30, 0.50), style: .leftToRight, intensity: 0.80, animated: false, orbs: false),
        AppTheme(id: "aurora", nameHu: "Sarki fény", nameEn: "Aurora",
                 colors: [RGBA(0.20, 0.90, 0.60), RGBA(0.25, 0.50, 0.95), RGBA(0.70, 0.35, 0.95)],
                 accent: RGBA(0.20, 0.70, 0.85), style: .angular, intensity: 0.80, animated: true, orbs: true),
        AppTheme(id: "mono", nameHu: "Szürke", nameEn: "Graphite",
                 colors: [RGBA(0.70, 0.72, 0.78), RGBA(0.40, 0.42, 0.50)],
                 accent: RGBA(0.30, 0.34, 0.45), style: .topToBottom, intensity: 0.70, animated: false, orbs: false),
    ]

    static var `default`: AppTheme { presets[0] }
}

// MARK: - Tároló (helyben, UserDefaults)

final class ThemeStore: ObservableObject {
    @Published var theme: AppTheme { didSet { saveTheme() } }
    @Published var appearance: AppearanceMode {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: "appearance") }
    }
    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "language")
            Fmt.en = isEnglish
        }
    }
    @Published var haptics: Bool {
        didSet { UserDefaults.standard.set(haptics, forKey: "haptics") }
    }
    @Published var lockEnabled: Bool {
        didSet { UserDefaults.standard.set(lockEnabled, forKey: "lock") }
    }
    @Published var subReminders: Bool {
        didSet { UserDefaults.standard.set(subReminders, forKey: "subReminders") }
    }
    @Published var reminderDays: Int {
        didSet { UserDefaults.standard.set(reminderDays, forKey: "reminderDays") }
    }
    @Published var monthlyReport: Bool {
        didSet { UserDefaults.standard.set(monthlyReport, forKey: "monthlyReport") }
    }

    init() {
        let d = UserDefaults.standard
        if let data = d.data(forKey: "theme"),
           let t = try? JSONDecoder().decode(AppTheme.self, from: data), t.colors.count >= 2 {
            theme = t
        } else {
            theme = .default
        }
        appearance = AppearanceMode(rawValue: d.string(forKey: "appearance") ?? "") ?? .system
        language = AppLanguage(rawValue: d.string(forKey: "language") ?? "") ?? .system
        haptics = d.object(forKey: "haptics") as? Bool ?? true
        lockEnabled = d.bool(forKey: "lock")
        subReminders = d.bool(forKey: "subReminders")
        reminderDays = d.object(forKey: "reminderDays") as? Int ?? 2
        monthlyReport = d.bool(forKey: "monthlyReport")
        Fmt.en = isEnglish
    }

    private func saveTheme() {
        if let data = try? JSONEncoder().encode(theme) {
            UserDefaults.standard.set(data, forKey: "theme")
        }
    }

    var scheme: ColorScheme? {
        switch appearance {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var isEnglish: Bool {
        switch language {
        case .en: true
        case .hu: false
        case .system: Locale.current.language.languageCode?.identifier != "hu"
        }
    }

    var tr: Tr { Tr(en: isEnglish) }
}

enum Haptics {
    private static var enabled: Bool {
        UserDefaults.standard.object(forKey: "haptics") as? Bool ?? true
    }
    static func tap(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    static func success() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: - Háttér

struct GradientBackdrop: View {
    let colors: [Color]
    let style: GradientStyle
    var phase: Double = 0

    var body: some View {
        switch style {
        case .leftToRight:
            LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
        case .rightToLeft:
            LinearGradient(colors: colors, startPoint: .trailing, endPoint: .leading)
        case .topToBottom:
            LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
        case .bottomToTop:
            LinearGradient(colors: colors, startPoint: .bottom, endPoint: .top)
        case .diagDown:
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
        case .diagUp:
            LinearGradient(colors: colors, startPoint: .bottomLeading, endPoint: .topTrailing)
        case .radialOut:
            RadialGradient(colors: colors, center: .center, startRadius: 0, endRadius: 560)
        case .radialIn:
            RadialGradient(colors: Array(colors.reversed()), center: .center, startRadius: 0, endRadius: 560)
        case .angular:
            AngularGradient(colors: colors + [colors[0]], center: .center, angle: .degrees(phase))
        }
    }
}

struct OrbsLayer: View {
    let colors: [Color]
    let time: Double

    private func point(_ i: Int, in size: CGSize) -> CGPoint {
        let f: Double = Double(i)
        let ax: Double = time * 0.18 + f * 2.1
        let ay: Double = time * 0.13 + f * 1.7
        let nx: Double = 0.5 + 0.38 * sin(ax)
        let ny: Double = 0.5 + 0.40 * cos(ay)
        return CGPoint(x: Double(size.width) * nx, y: Double(size.height) * ny)
    }

    var body: some View {
        GeometryReader { geo in
            let d: CGFloat = geo.size.width * 0.75
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(colors[i % colors.count])
                    .frame(width: d, height: d)
                    .blur(radius: 70)
                    .opacity(0.6)
                    .position(point(i, in: geo.size))
            }
        }
    }
}

struct AppBackground: View {
    @EnvironmentObject private var store: ThemeStore
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let t = store.theme
        ZStack {
            Color(.systemBackground)
            if t.animated && !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
                    layer(t, time: ctx.date.timeIntervalSinceReferenceDate, moving: true)
                }
            } else {
                layer(t, time: 0, moving: false)
            }
            (scheme == .dark ? Color.black.opacity(0.42) : Color.white.opacity(0.28))
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func layer(_ t: AppTheme, time: Double, moving: Bool) -> some View {
        let cs = t.colors.map(\.color)
        ZStack {
            GradientBackdrop(colors: cs, style: t.style, phase: time * 12)
                .scaleEffect(moving ? 1.25 : 1)
                .offset(x: moving ? sin(time * 0.25) * 28 : 0,
                        y: moving ? cos(time * 0.2) * 28 : 0)
            if t.orbs {
                OrbsLayer(colors: cs, time: moving ? time : 0)
            }
        }
        .opacity(t.intensity)
    }
}

// MARK: - Közös kártya stílus

extension View {
    /// Liquid Glass kártya, görgetéskor finoman animál.
    func glassCard(_ radius: CGFloat = 26) -> some View {
        self
            .glassEffect(.regular, in: .rect(cornerRadius: radius))
            .scrollTransition { content, phase in
                content
                    .opacity(phase.isIdentity ? 1 : 0.5)
                    .scaleEffect(phase.isIdentity ? 1 : 0.95)
            }
    }
}
