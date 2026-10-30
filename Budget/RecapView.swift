import SwiftUI
import SwiftData

/// Hónap és év visszatekintés: mire költöttél.
struct RecapView: View {
    var embedded = false

    @EnvironmentObject private var store: ThemeStore
    @Environment(\.dismiss) private var dismiss
    @Query private var entries: [Entry]
    @Query(sort: \Category.createdAt) private var categories: [Category]
    @State private var yearly = false

    private let cal = Calendar.current

    private var thisMonth: Date {
        cal.date(from: cal.dateComponents([.year, .month], from: .now)) ?? .now
    }

    private var yearMonths: [Date] {
        let y = cal.component(.year, from: .now)
        let upTo = cal.component(.month, from: .now)
        return (1...upTo).compactMap { cal.date(from: DateComponents(year: y, month: $0, day: 1)) }
    }

    private var months: [Date] { yearly ? yearMonths : [thisMonth] }

    private func spendEntries(_ m: Date) -> [Entry] {
        entries.filter { ($0.kind == .expense || $0.kind == .subscription) && $0.counts(in: m) }
    }

    private func sum(_ kind: EntryKind, _ m: Date) -> Double {
        entries.filter { $0.kind == kind && $0.categoryID != "piggy" && $0.counts(in: m) }
            .reduce(0) { $0 + $1.amount }
    }

    private func piggyMoves(_ m: Date) -> Double {
        entries.filter { $0.kind == .saving && $0.categoryID == "piggy" && $0.counts(in: m) }
            .reduce(0) { $0 + $1.amount }
    }

    private func spent(_ m: Date) -> Double { spendEntries(m).reduce(0) { $0 + $1.amount } }
    private func saved(_ m: Date) -> Double { sum(.saving, m) + piggyMoves(m) }

    private func catRows(_ tr: Tr) -> [CatRow] {
        var totals: [String: Double] = [:]
        for m in months {
            for e in spendEntries(m) {
                let key = e.kind == .subscription ? "subs" : (e.categoryID.isEmpty ? "other" : e.categoryID)
                totals[key, default: 0] += e.amount
            }
        }
        var rows: [CatRow] = []
        for (key, value) in totals where value > 0 {
            if key == "subs" {
                rows.append(CatRow(id: key, name: tr("Előfizetések", "Subscriptions"),
                                   symbol: "arrow.triangle.2.circlepath",
                                   color: EntryKind.subscription.color, spent: value, limit: 0))
            } else if let c = categories.first(where: { $0.id == key }) {
                rows.append(CatRow(id: key, name: c.name, symbol: c.symbol, color: c.color,
                                   spent: value, limit: 0))
            } else {
                rows.append(CatRow(id: key, name: tr("Egyéb", "Other"),
                                   symbol: "questionmark.circle.fill", color: .gray,
                                   spent: value, limit: 0))
            }
        }
        return rows.sorted { $0.spent > $1.spent }
    }

    private func yearPoints(_ tr: Tr) -> [HistPoint] {
        let loc = Locale(identifier: tr.en ? "en_US" : "hu_HU")
        var pts: [HistPoint] = []
        for m in yearMonths {
            let label = m.formatted(Date.FormatStyle().month(.abbreviated).locale(loc))
            pts.append(HistPoint(label: label, series: tr("Bevétel", "Income"), value: sum(.income, m)))
            pts.append(HistPoint(label: label, series: tr("Kiadás", "Spent"), value: spent(m)))
            pts.append(HistPoint(label: label, series: tr("Félretett", "Saved"), value: saved(m)))
        }
        return pts
    }

    var body: some View {
        if embedded {
            NavigationStack {
                content
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(store.tr("Kész", "Done")) { dismiss() }
                        }
                    }
            }
        } else {
            content
        }
    }

    private var content: some View {
        let tr = store.tr
        let income = months.reduce(0) { $0 + sum(.income, $1) }
        let spentTotal = months.reduce(0) { $0 + spent($1) }
        let savedTotal = months.reduce(0) { $0 + saved($1) }
        let rows = catRows(tr)
        let allSpend = months.flatMap { spendEntries($0) }
        let biggest = allSpend.max(by: { $0.amount < $1.amount })
        return ScrollView {
            VStack(spacing: 16) {
                Picker("", selection: $yearly.animation(.snappy)) {
                    Text(tr("Hónap", "Month")).tag(false)
                    Text(tr("Év", "Year")).tag(true)
                }
                .pickerStyle(.segmented)

                VStack(spacing: 10) {
                    summaryRow(tr("Bevétel", "Income"), income, .green)
                    summaryRow(tr("Kiadás", "Spent"), spentTotal, .orange)
                    summaryRow(tr("Félretett", "Saved"), savedTotal, .blue)
                    Divider()
                    summaryRow(tr("Maradt", "Left"), income - spentTotal - savedTotal, .primary)
                }
                .padding(18)
                .glassEffect(.regular, in: .rect(cornerRadius: 24))

                if yearly {
                    HistoryChartCard(points: yearPoints(tr), title: tr("Idén", "This year"))
                }

                if !rows.isEmpty {
                    CategoryBreakdownCard(rows: rows)
                }

                if let top = rows.first {
                    insight(icon: "flame.fill", color: .orange,
                            title: tr("Legtöbbet erre", "Most spent on"),
                            name: top.name, amount: top.spent)
                }
                if let b = biggest {
                    insight(icon: "bolt.fill", color: .pink,
                            title: tr("Legnagyobb tétel", "Biggest item"),
                            name: b.name, amount: b.amount)
                }
            }
            .padding(16)
        }
        .background(AppBackground())
        .navigationTitle(tr("Visszatekintés", "Recap"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func summaryRow(_ title: String, _ value: Double, _ color: Color) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value.ft)
                .font(.headline)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }

    private func insight(icon: String, color: Color, title: String, name: String, amount: Double) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.title2).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(name).font(.headline).lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(amount.ft).fontWeight(.bold).lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(18)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }
}
