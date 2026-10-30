import SwiftUI

/// Fülváltás animáció. A stílus a Beállításokban választható.
enum TabAnimStyle: String, CaseIterable, Identifiable {
    case none, fade, slide, rise, zoom, spring
    var id: String { rawValue }

    func title(_ tr: Tr) -> String {
        switch self {
        case .none: return tr("Nincs", "None")
        case .fade: return tr("Áttűnés", "Fade")
        case .slide: return tr("Csúszás", "Slide")
        case .rise: return tr("Emelkedés", "Rise")
        case .zoom: return tr("Nagyítás", "Zoom")
        case .spring: return tr("Rugó", "Spring")
        }
    }
}

struct TabEntrance: ViewModifier {
    @AppStorage("tabAnim") private var styleRaw = TabAnimStyle.fade.rawValue
    @State private var shown = false
    @State private var animating = false

    private var style: TabAnimStyle { TabAnimStyle(rawValue: styleRaw) ?? .fade }

    private var opacityValue: Double {
        if style == .none || shown { return 1 }
        return 0
    }

    private var offsetX: CGFloat {
        style == .slide && !shown ? 70 : 0
    }

    private var offsetY: CGFloat {
        if shown { return 0 }
        if style == .rise { return 30 }
        if style == .spring { return 70 }
        return 0
    }

    private var scaleValue: CGFloat {
        style == .zoom && !shown ? 0.92 : 1
    }

    private var animation: Animation {
        switch style {
        case .spring: return .spring(duration: 0.6, bounce: 0.4)
        case .slide: return .easeOut(duration: 0.35)
        case .fade: return .easeInOut(duration: 0.3)
        default: return .spring(duration: 0.45, bounce: 0.1)
        }
    }

    func body(content: Content) -> some View {
        content
            .opacity(opacityValue)
            .offset(x: offsetX, y: offsetY)
            .scaleEffect(scaleValue)
            .background {
                // animáció közben a téma háttere látszik, nem a fekete
                if animating { AppBackground().ignoresSafeArea() }
            }
            .onAppear {
                guard style != .none else {
                    shown = true
                    return
                }
                animating = true
                withAnimation(animation) { shown = true }
                Task {
                    try? await Task.sleep(for: .seconds(0.8))
                    animating = false
                }
            }
            .onDisappear {
                shown = false
            }
    }
}

extension View {
    func tabEntrance() -> some View { modifier(TabEntrance()) }
}

/// Egyszerű számlálók az achievementekhez (csak az eszközön).
enum Stats {
    static func add(_ key: String, _ n: Int = 1) {
        let k = "stat." + key
        UserDefaults.standard.set(UserDefaults.standard.integer(forKey: k) + n, forKey: k)
    }

    static func get(_ key: String) -> Int {
        UserDefaults.standard.integer(forKey: "stat." + key)
    }
}

/// Mini zseb animáció: egy érme folyamatosan beleesik a zsebbe.
struct PocketBadge: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            Circle()
                .fill(Color.yellow)
                .frame(width: 12, height: 12)
                .phaseAnimator([0.0, 1.0]) { content, phase in
                    content
                        .offset(y: phase == 0 ? -12 : 4)
                        .opacity(phase == 0 ? 0 : 1)
                } animation: { _ in
                    .easeIn(duration: 0.9)
                }
            UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 13,
                                   bottomTrailingRadius: 13, topTrailingRadius: 4)
                .fill(Color.accentColor.gradient)
                .frame(width: 28, height: 22)
        }
        .frame(width: 30, height: 32)
    }
}
