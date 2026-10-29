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
            Tab(EntryKind.income.plural(tr), systemImage: EntryKind.income.icon, value: 1) {
                NavigationStack { EntryListView(kind: .income) }
            }
            Tab(EntryKind.expense.plural(tr), systemImage: EntryKind.expense.icon, value: 2) {
                NavigationStack { EntryListView(kind: .expense) }
            }
            Tab(tr("Előfizetés", "Subs"), systemImage: EntryKind.subscription.icon, value: 3) {
                NavigationStack { EntryListView(kind: .subscription) }
            }
            Tab(tr("Félretesz", "Savings"), systemImage: EntryKind.saving.icon, value: 4) {
                NavigationStack { EntryListView(kind: .saving) }
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
