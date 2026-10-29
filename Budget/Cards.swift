import SwiftUI
import SwiftData
import Charts

// MARK: - Költőpénz

struct SpendingMoneyCard: View {
    @EnvironmentObject private var store: ThemeStore
    let allowance: Double   // amennyi a fix tételek után elkölthető
    let spent: Double       // egyszeri kiadások ebben a hónapban

    var body: some View {
        let tr = store.tr
        let remaining = allowance - spent
        let progress = allowance > 0 ? min(max(spent / allowance, 0), 1) : 0
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(tr("Költőpénz", "Spending money"), systemImage: "creditcard.fill")
                    .font(.headline)
                Spacer(minLength: 8)
                Text(remaining.ft)
                    .font(.title3.bold())
                    .foregroundStyle(remaining >= 0 ? Color.primary : Color.red)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText(value: remaining))
                    .animation(.snappy, value: remaining)
            }
            ProgressView(value: progress)
                .tint(progress > 0.9 ? Color.red : Color.orange)
            Text(tr("Elköltve: \(spent.ft) / \(allowance.ft). A fix tételek (lakás, előfizetések, megtakarítás) után ennyit költhetsz; az egyszeri kiadásaid ebből fogynak.",
                    "Spent: \(spent.ft) / \(allowance.ft). This is what you can spend after fixed items (housing, subscriptions, savings); one-time expenses come out of it."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(24)
    }
}

// MARK: - Piggy Bank

struct PiggyBankCard: View {
    @EnvironmentObject private var store: ThemeStore
    let saved: Double
    let target: Double
    let onDeposit: () -> Void

    var body: some View {
        let tr = store.tr
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label("Piggy Bank", systemImage: "banknote.fill").font(.headline)
                Spacer(minLength: 8)
                Button(tr("Befizetés / kivétel", "Deposit / withdraw"), systemImage: "plus.forwardslash.minus") {
                    Haptics.tap()
                    onDeposit()
                }
                .buttonStyle(.glass)
                .font(.footnote)
            }
            Text(saved.ft)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText(value: saved))
                .animation(.snappy, value: saved)
            if target > 0 {
                ProgressView(value: min(saved, target), total: target).tint(.blue)
                Text(tr("Összes cél: \(target.ft)", "All goals: \(target.ft)"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(tr("Eddig félretett összeg az összes megtakarításból.",
                        "Total saved so far across all your savings."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(24)
    }
}

struct DepositView: View {
    @EnvironmentObject private var store: ThemeStore
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Entry.createdAt) private var all: [Entry]

    @State private var withdraw = false
    @State private var amount: Double?
    @State private var selectedID: PersistentIdentifier?

    private var goals: [Entry] { all.filter { $0.kind == .saving } }

    var body: some View {
        let tr = store.tr
        NavigationStack {
            Form {
                Section {
                    Picker("", selection: $withdraw) {
                        Text(tr("Befizetés", "Deposit")).tag(false)
                        Text(tr("Kivétel", "Withdraw")).tag(true)
                    }
                    .pickerStyle(.segmented)
                    TextField(tr("Összeg (Ft)", "Amount (Ft)"), value: $amount, format: .number)
                        .keyboardType(.decimalPad)
                        .font(.title2.bold())
                }
                if !goals.isEmpty {
                    Section(tr("Melyik célhoz", "Which goal")) {
                        Picker(tr("Cél", "Goal"), selection: $selectedID) {
                            ForEach(goals) { g in
                                Text(g.name).tag(Optional(g.persistentModelID))
                            }
                        }
                    }
                } else {
                    Section {
                        Text(tr("Még nincs megtakarítási cél, ezért létrehozok egy \"Piggy Bank\" tételt.",
                                "No savings goal yet, so a \"Piggy Bank\" item will be created."))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle("Piggy Bank")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Mégse", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("Mentés", "Save"), action: save)
                        .disabled((amount ?? 0) <= 0)
                }
            }
            .onAppear {
                if selectedID == nil { selectedID = goals.first?.persistentModelID }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        let value = amount ?? 0
        let delta = withdraw ? -value : value
        if let id = selectedID, let goal = goals.first(where: { $0.persistentModelID == id }) {
            goal.savedSoFar = max(goal.savedSoFar + delta, 0)
        } else {
            context.insert(Entry(name: "Piggy Bank", amount: 0, kind: .saving,
                                 targetAmount: 0, savedSoFar: max(delta, 0)))
        }
        Haptics.success()
        dismiss()
    }
}

// MARK: - Kategóriák

struct CatRow: Identifiable {
    let id: String
    let name: String
    let symbol: String
    let color: Color
    let spent: Double
    let limit: Double
}

struct CategoryBreakdownCard: View {
    @EnvironmentObject private var store: ThemeStore
    let rows: [CatRow]

    var body: some View {
        let tr = store.tr
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(tr("Kiadás kategóriánként", "Spending by category"), systemImage: "tag.fill")
                    .font(.headline)
                Spacer(minLength: 8)
                NavigationLink {
                    CategoriesView()
                } label: {
                    Text(tr("Kezelés", "Manage")).font(.footnote)
                }
            }
            if rows.isEmpty {
                Text(tr("Még nincs kategorizált kiadás. A Kiadások fülön adj meg kategóriát a tételeknél.",
                        "No categorized spending yet. Pick a category when adding an expense."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ForEach(rows) { r in rowView(r, tr) }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(24)
    }

    private func rowView(_ r: CatRow, _ tr: Tr) -> some View {
        let over = r.limit > 0 && r.spent > r.limit
        let ratio = r.limit > 0 ? r.spent / r.limit : 0
        let tint: Color = over ? .red : (ratio >= 0.8 ? .orange : r.color)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: r.symbol).foregroundStyle(r.color).frame(width: 24)
                Text(r.name).lineLimit(1)
                Spacer(minLength: 8)
                Text(r.limit > 0 ? "\(r.spent.ft) / \(r.limit.ft)" : r.spent.ft)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            if r.limit > 0 {
                ProgressView(value: min(r.spent, r.limit), total: r.limit).tint(tint)
                if over {
                    Label(tr("Túllépve: +\((r.spent - r.limit).ft)", "Over by \((r.spent - r.limit).ft)"),
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }
}

// MARK: - Havi grafikon

struct HistPoint: Identifiable {
    let label: String
    let series: String
    let value: Double
    var id: String { label + "|" + series }
}

struct HistoryChartCard: View {
    @EnvironmentObject private var store: ThemeStore
    let points: [HistPoint]

    private func compact(_ v: Double) -> String {
        v.formatted(.number.notation(.compactName).locale(Locale(identifier: Fmt.en ? "en_US" : "hu_HU")))
    }

    var body: some View {
        let tr = store.tr
        let names: [String] = [tr("Bevétel", "Income"), tr("Kiadás", "Spent"), tr("Félretett", "Saved")]
        let colors: [Color] = [.green, .orange, .blue]
        VStack(alignment: .leading, spacing: 12) {
            Label(tr("Utolsó 6 hónap", "Last 6 months"), systemImage: "chart.bar.fill")
                .font(.headline)
            Chart(points) { p in
                BarMark(x: .value("Hónap", p.label), y: .value("Ft", p.value))
                    .foregroundStyle(by: .value("Típus", p.series))
                    .position(by: .value("Típus", p.series))
                    .cornerRadius(4)
            }
            .chartForegroundStyleScale(domain: names, range: colors)
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let d = value.as(Double.self) { Text(compact(d)) }
                    }
                }
            }
            .frame(height: 190)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(24)
    }
}
