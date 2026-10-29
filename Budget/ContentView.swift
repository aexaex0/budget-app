import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: ThemeStore
    @State private var selected = 0

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
    }
}
