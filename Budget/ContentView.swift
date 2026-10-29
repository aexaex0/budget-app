import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Áttekintés", systemImage: "chart.pie.fill") {
                OverviewView()
            }
            Tab("Bevétel", systemImage: EntryKind.income.icon) {
                NavigationStack { EntryListView(kind: .income) }
            }
            Tab("Kiadások", systemImage: EntryKind.expense.icon) {
                NavigationStack { EntryListView(kind: .expense) }
            }
            Tab("Előfizetés", systemImage: EntryKind.subscription.icon) {
                NavigationStack { EntryListView(kind: .subscription) }
            }
            Tab("Félretesz", systemImage: EntryKind.saving.icon) {
                NavigationStack { EntryListView(kind: .saving) }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown) // Liquid Glass tabsáv összehúzódik görgetéskor
    }
}
