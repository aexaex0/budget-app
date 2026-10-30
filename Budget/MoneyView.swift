import SwiftUI
import SwiftData

struct MoneyNew: Identifiable {
    let id = UUID()
    let kind: EntryKind
    let recurring: Bool
}

/// Pénz fül: bevételek és kiadások egy listában. Lent: − (kiadás) és + (bevétel).
struct MoneyView: View {
    @EnvironmentObject private var store: ThemeStore
    @Environment(\.modelContext) private var context
    @Query(sort: \Entry.createdAt) private var all: [Entry]
    @Query(sort: \Category.createdAt) private var categories: [Category]
    @State private var editing: Entry?
    @State private var newItem: MoneyNew?

    private func ordered(_ list: [Entry]) -> [Entry] {
        list.sorted { a, b in
            if a.isRecurring != b.isRecurring { return a.isRecurring }
            return a.date > b.date
        }
    }

    private var incomes: [Entry] { ordered(all.filter { $0.kind == .income }) }
    private var expenses: [Entry] { ordered(all.filter { $0.kind == .expense }) }

    private func total(_ list: [Entry]) -> Double {
        list.filter { $0.counts(in: .now) }.reduce(0) { $0 + $1.amount }
    }

    private var subsTotal: Double {
        all.filter { $0.kind == .subscription }.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        let tr = store.tr
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        EntryListView(kind: .subscription)
                    } label: {
                        HStack {
                            Label(tr("Előfizetések", "Subscriptions"),
                                  systemImage: EntryKind.subscription.icon)
                            Spacer()
                            Text(subsTotal.ft).foregroundStyle(.secondary)
                        }
                    }
                    .listRowBackground(rowBackground)
                }

                if !incomes.isEmpty {
                    Section(tr("Bevétel", "Income")) {
                        ForEach(incomes) { e in rowButton(e, tr) }
                            .onDelete { delete(incomes, $0) }
                    }
                }
                if !expenses.isEmpty {
                    Section(tr("Kiadás", "Expenses")) {
                        ForEach(expenses) { e in rowButton(e, tr) }
                            .onDelete { delete(expenses, $0) }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle(tr("Pénz", "Money"))
            .safeAreaInset(edge: .top, spacing: 0) { summary(tr) }
            .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: 76) }
            .overlay(alignment: .bottom) {
                HStack(spacing: 28) {
                    addMenu(.expense, "minus", tr)
                    addMenu(.income, "plus", tr)
                }
                .padding(.bottom, 12)
            }
            .sheet(item: $newItem) { EntryEditor(kind: $0.kind, entry: nil, recurring: $0.recurring) }
            .sheet(item: $editing) { EntryEditor(kind: $0.kind, entry: $0) }
        }
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(.clear)
            .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }

    private func summary(_ tr: Tr) -> some View {
        let inc = total(incomes)
        let exp = total(expenses)
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(tr("Bevétel", "Income")).font(.caption).foregroundStyle(.secondary)
                Text(inc.ft).font(.subheadline.bold()).foregroundStyle(.green)
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
            Spacer(minLength: 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(tr("Kiadás", "Expenses")).font(.caption).foregroundStyle(.secondary)
                Text(exp.ft).font(.subheadline.bold()).foregroundStyle(.red)
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 2) {
                Text(tr("Különbség", "Net")).font(.caption).foregroundStyle(.secondary)
                Text((inc - exp).ft).font(.subheadline.bold())
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 6)
    }

    private func addMenu(_ kind: EntryKind, _ icon: String, _ tr: Tr) -> some View {
        Menu {
            Button {
                newItem = MoneyNew(kind: kind, recurring: true)
            } label: {
                Label(tr("Havi ismétlődő", "Monthly"), systemImage: "arrow.triangle.2.circlepath")
            }
            Button {
                newItem = MoneyNew(kind: kind, recurring: false)
            } label: {
                Label(tr("Egyszeri", "One-time"), systemImage: "1.circle")
            }
        } label: {
            Image(systemName: icon)
                .font(.title2.weight(.semibold))
                .foregroundStyle(kind.color)
                .frame(width: 58, height: 58)
                .glassEffect(.regular.interactive(), in: .circle)
        }
    }

    private func rowButton(_ e: Entry, _ tr: Tr) -> some View {
        Button {
            Haptics.tap()
            editing = e
        } label: {
            row(e, tr)
        }
        .buttonStyle(.plain)
        .listRowBackground(rowBackground)
    }

    private func row(_ e: Entry, _ tr: Tr) -> some View {
        HStack(spacing: 12) {
            Image(systemName: e.isRecurring ? "arrow.triangle.2.circlepath" : "1.circle")
                .foregroundStyle(e.kind.color)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(e.name).lineLimit(2)
                if !e.isRecurring {
                    Text(shortDate(e.date, english: store.isEnglish))
                        .font(.caption).foregroundStyle(.secondary)
                }
                if e.kind == .expense, let cat = categories.first(where: { $0.id == e.categoryID }) {
                    Label(cat.name, systemImage: cat.symbol)
                        .font(.caption).foregroundStyle(cat.color)
                }
            }
            Spacer(minLength: 8)
            Text(e.amount.ft)
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private func delete(_ list: [Entry], _ offsets: IndexSet) {
        Haptics.tap(.medium)
        withAnimation(.snappy) {
            for i in offsets { context.delete(list[i]) }
        }
    }
}
