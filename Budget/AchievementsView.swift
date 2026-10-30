import SwiftUI
import SwiftData

struct Achievement: Identifiable {
    let id: String
    let icon: String
    let title: String
    let detail: String
    let value: Double
    let target: Double
    var done: Bool { value >= target }
}

struct AchievementsView: View {
    @EnvironmentObject private var store: ThemeStore
    @Query private var entries: [Entry]
    @Query private var wishes: [WishItem]
    @Query private var categories: [Category]
    @AppStorage("budgetLimit") private var budgetLimit: Double = 0

    private var list: [Achievement] {
        let tr = store.tr
        let incomeCount = Double(entries.filter { $0.kind == .income }.count)
        let oneTimeExpenses = Double(entries.filter { $0.kind == .expense && !$0.isRecurring }.count)
        let piggy = entries.filter { $0.kind == .saving && $0.categoryID != "piggy" }
            .reduce(0) { $0 + $1.savedSoFar }
        let skipped = wishes.filter { $0.statusRaw == "skipped" }
        let skippedSum = skipped.reduce(0) { $0 + $1.price }
        let limits = Double(categories.filter { $0.monthlyLimit > 0 }.count)
        return [
            Achievement(id: "inc", icon: "arrow.down.circle.fill",
                        title: tr("Első bevétel", "First income"),
                        detail: tr("Írj be egy bevételt", "Add an income"),
                        value: incomeCount, target: 1),
            Achievement(id: "log", icon: "pencil.and.list.clipboard",
                        title: tr("Naplózó", "Logger"),
                        detail: tr("10 egyszeri kiadás", "10 one-time expenses"),
                        value: oneTimeExpenses, target: 10),
            Achievement(id: "pig1", icon: "banknote.fill",
                        title: tr("Zsebben a pénz", "Money in pocket"),
                        detail: tr("10 000 Ft a Piggy Bankben", "10,000 Ft in Piggy Bank"),
                        value: piggy, target: 10_000),
            Achievement(id: "pig2", icon: "banknote.fill",
                        title: tr("Nagy tartalék", "Big reserve"),
                        detail: tr("100 000 Ft a Piggy Bankben", "100,000 Ft in Piggy Bank"),
                        value: piggy, target: 100_000),
            Achievement(id: "wish1", icon: "hourglass",
                        title: tr("Türelmes", "Patient"),
                        detail: tr("3 kihagyott vásárlás", "Skip 3 purchases"),
                        value: Double(skipped.count), target: 3),
            Achievement(id: "wish2", icon: "leaf.fill",
                        title: tr("Spórolós", "Saver"),
                        detail: tr("20 000 Ft megspórolva", "Save 20,000 Ft by skipping"),
                        value: skippedSum, target: 20_000),
            Achievement(id: "cat", icon: "tag.fill",
                        title: tr("Limitmester", "Limit master"),
                        detail: tr("3 kategória limittel", "3 categories with limits"),
                        value: limits, target: 3),
            Achievement(id: "plan", icon: "gauge.with.dots.needle.67percent",
                        title: tr("Tervező", "Planner"),
                        detail: tr("Állíts be költési keretet", "Set a spending budget"),
                        value: budgetLimit > 0 ? 1 : 0, target: 1),
            Achievement(id: "spin", icon: "die.face.5.fill",
                        title: tr("Pörgő", "Spinner"),
                        detail: tr("100 pörgetés a slotban", "100 slot spins"),
                        value: Double(Stats.get("spins")), target: 100),
            Achievement(id: "jp", icon: "crown.fill",
                        title: "Jackpot!",
                        detail: tr("Nyerj egy jackpotot", "Hit a jackpot"),
                        value: Double(Stats.get("jackpots")), target: 1),
            Achievement(id: "bj", icon: "suit.spade.fill",
                        title: tr("Kártyaasztal", "Card table"),
                        detail: tr("20 blackjack kör", "20 blackjack hands"),
                        value: Double(Stats.get("bj")), target: 20),
        ]
    }

    var body: some View {
        let tr = store.tr
        let items = list
        let doneCount = items.filter { $0.done }.count
        ScrollView {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "trophy.fill").foregroundStyle(.yellow).font(.title2)
                    Text("\(doneCount) / \(items.count)")
                        .font(.title2.bold())
                    Spacer()
                }
                .padding(18)
                .glassEffect(.regular, in: .rect(cornerRadius: 24))

                ForEach(items) { a in row(a) }
            }
            .padding(16)
        }
        .background(AppBackground())
        .navigationTitle(tr("Teljesítmények", "Achievements"))
    }

    private func row(_ a: Achievement) -> some View {
        HStack(spacing: 14) {
            Image(systemName: a.icon)
                .font(.title3)
                .foregroundStyle(a.done ? Color.black : Color.secondary)
                .frame(width: 46, height: 46)
                .background(a.done ? Color.yellow : Color.white.opacity(0.1), in: .circle)
            VStack(alignment: .leading, spacing: 4) {
                Text(a.title).font(.headline)
                Text(a.detail).font(.caption).foregroundStyle(.secondary)
                if !a.done {
                    ProgressView(value: min(a.value, a.target), total: a.target)
                        .tint(.yellow)
                }
            }
            Spacer(minLength: 0)
            if a.done {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.title3)
            }
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }
}
