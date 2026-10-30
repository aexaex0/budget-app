import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject private var store: ThemeStore
    @Environment(\.modelContext) private var context
    @Query private var all: [Entry]
    @State private var selected = 0

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

    var body: some View {
        let tr = store.tr
        TabView(selection: $selected) {
            Tab(tr("Áttekintés", "Overview"), systemImage: "chart.pie.fill", value: 0) {
                OverviewView()
            }
            Tab(tr("Pénz", "Money"), systemImage: "banknote.fill", value: 1) {
                MoneyView()
            }
            Tab(tr("Extrák", "Extras"), systemImage: "square.grid.2x2.fill", value: 2) {
                ExtrasView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .onChange(of: selected) { _, _ in Haptics.tap(.soft) }
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
