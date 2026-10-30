import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject private var store: ThemeStore
    @Environment(\.modelContext) private var context
    @Query private var all: [Entry]
    @State private var selected = 0
    @EnvironmentObject private var router: Router
    @Environment(\.scenePhase) private var scenePhase

    /// Ha ez változik, újraütemezzük az értesítéseket.
    private var syncKey: String {
        let subs = all.filter { $0.kind == .subscription }
        let parts: [String] = subs.map { "\($0.name)|\($0.renewalDay)|\($0.amount)" }
        let flags = "\(store.subReminders)|\(store.reminderDays)|\(store.monthlyReport)|\(store.isEnglish)"
        return parts.joined(separator: ";") + "#" + flags
    }

    private var subInfos: [SubInfo] {
        all.filter { $0.kind == .subscription }
            .map { SubInfo(name: $0.name, day: $0.renewalDay, amount: $0.amount) }
    }

    /// A widget gombja elindítja az appot, a kérés kicsit később érkezhet meg.
    private func consumeWidgetAction() async {
        for _ in 0..<8 {
            if let kind = Router.takePending() {
                selected = 1
                router.pendingAdd = kind
                return
            }
            try? await Task.sleep(for: .seconds(0.3))
        }
    }

    var body: some View {
        let tr = store.tr
        TabView(selection: $selected) {
            Tab(tr("Áttekintés", "Overview"), systemImage: "chart.pie.fill", value: 0) {
                OverviewView().tabEntrance()
            }
            Tab(tr("Pénz", "Money"), systemImage: "banknote.fill", value: 1) {
                MoneyView().tabEntrance()
            }
            Tab(tr("Extrák", "Extras"), systemImage: "square.grid.2x2.fill", value: 2) {
                ExtrasView().tabEntrance()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .onChange(of: selected) { _, _ in Haptics.tap(.soft) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await consumeWidgetAction() } }
        }
        .task { await consumeWidgetAction() }
        .task {
            CategorySeed.seedIfNeeded(context, english: store.isEnglish)
        }
        .task(id: syncKey) {
            await Notifier.sync(subs: subInfos, reminders: store.subReminders,
                                daysBefore: store.reminderDays,
                                monthlyReport: store.monthlyReport,
                                english: store.isEnglish)
        }
    }
}
