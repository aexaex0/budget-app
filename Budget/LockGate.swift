import SwiftUI
import LocalAuthentication

/// Face ID / készülékkód zár. Háttérbe váltáskor újra zár.
struct LockGate<Content: View>: View {
    @EnvironmentObject private var store: ThemeStore
    @Environment(\.scenePhase) private var phase
    @State private var locked = true
    @State private var trying = false
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        let tr = store.tr
        ZStack {
            content
            if store.lockEnabled && (locked || phase != .active) {
                lockScreen(tr)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: locked)
        .onChange(of: phase) { _, new in
            guard store.lockEnabled else { return }
            if new == .background { locked = true }
            if new == .active && locked { authenticate(tr) }
        }
        .onChange(of: store.lockEnabled) { _, on in
            if !on { locked = false }
        }
        .task {
            if store.lockEnabled { authenticate(tr) } else { locked = false }
        }
    }

    private func lockScreen(_ tr: Tr) -> some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            VStack(spacing: 16) {
                Image(systemName: "lock.fill").font(.system(size: 44))
                Text("Pocket").font(.title2.bold())
                Button(tr("Feloldás", "Unlock")) { authenticate(tr) }
                    .buttonStyle(.glass)
            }
        }
        .ignoresSafeArea()
    }

    private func authenticate(_ tr: Tr) {
        if trying { return }
        let ctx = LAContext()
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else {
            locked = false   // nincs beállított készülékkód: nem tud zárolni
            return
        }
        trying = true
        ctx.evaluatePolicy(.deviceOwnerAuthentication,
                           localizedReason: tr("Pocket feloldása", "Unlock Pocket")) { ok, _ in
            DispatchQueue.main.async {
                trying = false
                if ok { locked = false }
            }
        }
    }
}
