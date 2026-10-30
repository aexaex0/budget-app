import SwiftUI

/// Fülváltáskor a tartalom finoman becsúszik és előúszik, nem snappel.
struct TabEntrance: ViewModifier {
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 28)
            .scaleEffect(shown ? 1 : 0.97)
            .onAppear {
                withAnimation(.spring(duration: 0.5, bounce: 0.15)) { shown = true }
            }
            .onDisappear { shown = false }
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
