import SwiftUI
import SwiftData
import Charts

// MARK: - Költőpénz

struct MoneySplitCard: View {
    @EnvironmentObject private var store: ThemeStore
    let spending: Double   // havi bevétel − kiadás − előfizetés − célok − Piggybe tett összeg
    let piggy: Double

    private func row(_ title: String, _ value: Double, bold: Bool) -> some View {
        HStack {
            Text(title)
                .font(bold ? .headline : .subheadline)
                .foregroundStyle(bold ? Color.primary : Color.secondary)
            Spacer(minLength: 8)
            Text(value.ft)
                .font(bold ? .title3.bold() : .body.weight(.semibold))
                .foregroundStyle(value < 0 ? Color.red : Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText(value: value))
                .animation(.snappy, value: value)
        }
    }

    var body: some View {
        let tr = store.tr
        VStack(spacing: 10) {
            row(tr("Költőpénz", "Spending money"), spending, bold: false)
            row("Piggy Bank", piggy, bold: false)
            Divider()
            row(tr("Együtt", "Total"), spending + piggy, bold: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(24)
    }
}

// MARK: - Piggy Bank

struct PiggyBankCard: View {
    let saved: Double
    let target: Double
    let onDeposit: () -> Void
    var onPlay: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    PocketBadge()
                    Text("Piggy Bank").font(.headline)
                }
                Spacer(minLength: 8)
                Button {
                    Haptics.tap()
                    onPlay()
                } label: {
                    Image(systemName: "gamecontroller.fill")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Mini game")
                Button {
                    Haptics.tap()
                    onDeposit()
                } label: {
                    Image(systemName: "plus.forwardslash.minus")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Deposit / withdraw")
            }
            Text(saved.ft)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText(value: saved))
                .animation(.snappy, value: saved)
            if target > 0 {
                ProgressView(value: min(saved, target), total: target).tint(.blue)
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

    private var goals: [Entry] { all.filter { $0.kind == .saving && $0.categoryID != "piggy" } }

    var body: some View {
        let tr = store.tr
        NavigationStack {
            Form {
                Section {
                    Picker("", selection: $withdraw) {
                        Image(systemName: "plus").tag(false)
                        Image(systemName: "minus").tag(true)
                    }
                    .pickerStyle(.segmented)
                    TextField(tr("Összeg (Ft)", "Amount (Ft)"), value: $amount, format: .number)
                        .keyboardType(.decimalPad)
                        .font(.title2.bold())
                }
                if goals.count > 1 {
                    Section {
                        Picker(tr("Cél", "Goal"), selection: $selectedID) {
                            ForEach(goals) { g in
                                Text(g.name).tag(Optional(g.persistentModelID))
                            }
                        }
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
        var applied = 0.0
        if let id = selectedID, let goal = goals.first(where: { $0.persistentModelID == id }) {
            let old = goal.savedSoFar
            goal.savedSoFar = max(old + delta, 0)
            applied = goal.savedSoFar - old
        } else {
            applied = max(delta, 0)
            context.insert(Entry(name: "Piggy Bank", amount: 0, kind: .saving,
                                 targetAmount: 0, savedSoFar: applied))
        }
        // A betett (vagy kivett) összeg a havi költőpénzből megy ki / jön vissza.
        if applied != 0 {
            context.insert(Entry(name: "Piggy Bank", amount: applied, kind: .saving,
                                 isRecurring: false, date: .now, categoryID: "piggy"))
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
                Label(tr("Kategóriák", "Categories"), systemImage: "tag.fill")
                    .font(.headline)
                Spacer(minLength: 8)
                NavigationLink {
                    CategoriesView()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .frame(width: 36, height: 36)
                }
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
                    Label("+\((r.spent - r.limit).ft)", systemImage: "exclamationmark.triangle.fill")
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
    var title: String? = nil

    private func compact(_ v: Double) -> String {
        v.formatted(.number.notation(.compactName).locale(Locale(identifier: Fmt.en ? "en_US" : "hu_HU")))
    }

    var body: some View {
        let tr = store.tr
        let names: [String] = [tr("Bevétel", "Income"), tr("Kiadás", "Spent"), tr("Félretett", "Saved")]
        let colors: [Color] = [.green, .orange, .blue]
        VStack(alignment: .leading, spacing: 12) {
            Label(title ?? tr("6 hónap", "6 months"), systemImage: "chart.bar.fill")
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
