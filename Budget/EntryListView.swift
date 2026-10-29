import SwiftUI
import SwiftData

struct NewEntry: Identifiable {
    let id = UUID()
    let recurring: Bool
}

struct EntryListView: View {
    let kind: EntryKind

    @EnvironmentObject private var store: ThemeStore
    @Environment(\.modelContext) private var context
    @Query private var entries: [Entry]
    @State private var editing: Entry?
    @State private var newEntry: NewEntry?
    @State private var showCalc = false
    @Query(sort: \Category.createdAt) private var categories: [Category]

    init(kind: EntryKind) {
        self.kind = kind
        let raw = kind.rawValue
        _entries = Query(filter: #Predicate<Entry> { $0.kindRaw == raw },
                         sort: \.createdAt)
    }

    /// Bevételnél és kiadásnál lehet egyszeri összeg is.
    private var supportsOneTime: Bool { kind == .income || kind == .expense }

    private var recurring: [Entry] { entries.filter { $0.isRecurring } }
    private var oneTime: [Entry] { entries.filter { !$0.isRecurring }.sorted { $0.date > $1.date } }
    private var recurringTotal: Double { recurring.reduce(0) { $0 + $1.amount } }
    private var oneTimeThisMonth: Double {
        oneTime.filter { $0.counts(in: .now) }.reduce(0) { $0 + $1.amount }
    }
    private var total: Double { recurringTotal + oneTimeThisMonth }

    var body: some View {
        let tr = store.tr
        List {
            Section {
                ForEach(recurring) { entry in entryButton(entry, tr) }
                    .onDelete { delete(recurring, $0) }
                if recurring.isEmpty {
                    hint(tr("Még nincs havi tétel. Koppints a + gombra.",
                            "No monthly items yet. Tap +."))
                }
            } header: {
                sectionHeader(
                    icon: "arrow.triangle.2.circlepath",
                    title: tr("Havonta megújul", "Renews every month"),
                    subtitle: tr("Minden hónapban automatikusan beleszámít.",
                                 "Counted automatically every month.")
                )
            }

            if supportsOneTime {
                Section {
                    ForEach(oneTime) { entry in entryButton(entry, tr) }
                        .onDelete { delete(oneTime, $0) }
                    if oneTime.isEmpty {
                        hint(tr("Nincs egyszeri összeg. A + gombbal tudsz hozzáadni.",
                                "No one-time amounts. Add one with +."))
                    }
                } header: {
                    sectionHeader(
                        icon: "1.circle",
                        title: tr("Egyszeri összegek", "One-time amounts"),
                        subtitle: tr("Csak abban a hónapban számítanak, amelyiknél megadtad.",
                                     "Only counted in the month you set.")
                    )
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AppBackground())
        .navigationTitle(kind.plural(tr))
        .animation(.snappy, value: entries.count)
        .safeAreaInset(edge: .top, spacing: 0) { summaryCard(tr) }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if kind == .expense {
                    NavigationLink {
                        CategoriesView()
                    } label: {
                        Label(tr("Kategóriák", "Categories"), systemImage: "tag.fill")
                    }
                } else if kind == .saving {
                    Button(tr("Célkalkulátor", "Goal calculator"), systemImage: "function") {
                        Haptics.tap()
                        showCalc = true
                    }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                if supportsOneTime {
                    Menu {
                        Button {
                            newEntry = NewEntry(recurring: true)
                        } label: {
                            Label(tr("Havi ismétlődő", "Monthly (repeats)"),
                                  systemImage: "arrow.triangle.2.circlepath")
                        }
                        Button {
                            newEntry = NewEntry(recurring: false)
                        } label: {
                            Label(tr("Egyszeri összeg", "One-time amount"), systemImage: "1.circle")
                        }
                    } label: {
                        Label(tr("Új", "New"), systemImage: "plus")
                    }
                } else {
                    Button(tr("Új", "New"), systemImage: "plus") {
                        Haptics.tap()
                        newEntry = NewEntry(recurring: true)
                    }
                }
            }
        }
        .sheet(item: $newEntry) { EntryEditor(kind: kind, entry: nil, recurring: $0.recurring) }
        .sheet(item: $editing) { EntryEditor(kind: kind, entry: $0) }
        .sheet(isPresented: $showCalc) { GoalCalculatorView() }
    }

    // MARK: Részek

    private func summaryCard(_ tr: Tr) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Text(supportsOneTime ? tr("Ebben a hónapban", "This month")
                                     : tr("Havi összesen", "Monthly total"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(total.ft)
                    .font(.title3.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText(value: total))
                    .animation(.snappy, value: total)
            }
            if supportsOneTime {
                HStack(spacing: 10) {
                    chip(icon: "arrow.triangle.2.circlepath",
                         title: tr("Havonta", "Monthly"), value: recurringTotal)
                    chip(icon: "1.circle",
                         title: tr("Egyszeri", "One-time"), value: oneTimeThisMonth)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }

    private func chip(icon: String, title: String, value: Double) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.caption).foregroundStyle(kind.color)
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.caption2).foregroundStyle(.secondary)
                Text(value.ft)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 14))
    }

    private func sectionHeader(icon: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(title, systemImage: icon)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .textCase(nil)
        .padding(.top, 8)
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }

    private func entryButton(_ entry: Entry, _ tr: Tr) -> some View {
        Button {
            Haptics.tap()
            editing = entry
        } label: {
            row(entry, tr)
        }
        .buttonStyle(.plain)
        .listRowBackground(
            RoundedRectangle(cornerRadius: 20)
                .fill(.clear)
                .glassEffect(.regular, in: .rect(cornerRadius: 20))
                .padding(.vertical, 3)
        )
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 10, leading: 18, bottom: 10, trailing: 18))
    }

    private func delete(_ list: [Entry], _ offsets: IndexSet) {
        Haptics.tap(.medium)
        withAnimation(.snappy) {
            for i in offsets { context.delete(list[i]) }
        }
    }

    private func row(_ entry: Entry, _ tr: Tr) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: kind.icon)
                    .foregroundStyle(kind.color)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name).lineLimit(2)
                    if kind == .subscription {
                        Label(tr("Megújul: \(entry.renewalDay). nap", "Renews: day \(entry.renewalDay)"),
                              systemImage: "arrow.triangle.2.circlepath")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if entry.isRecurring {
                        Label(tr("Minden hónapban", "Every month"),
                              systemImage: "arrow.triangle.2.circlepath")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        let day = shortDate(entry.date, english: store.isEnglish)
                        Label(tr("Egyszeri • \(day)", "One-time • \(day)"), systemImage: "1.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                Text(entry.amount.ft)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            if kind == .expense, let cat = categories.first(where: { $0.id == entry.categoryID }) {
                Label(cat.name, systemImage: cat.symbol)
                    .font(.caption)
                    .foregroundStyle(cat.color)
            }
            if kind == .saving, entry.targetAmount > 0 {
                ProgressView(value: min(entry.savedSoFar, entry.targetAmount),
                             total: entry.targetAmount)
                    .tint(kind.color)
                let remaining = max(entry.targetAmount - entry.savedSoFar, 0)
                if remaining == 0 {
                    Text(tr("Cél elérve 🎉", "Goal reached 🎉")).font(.caption).foregroundStyle(.secondary)
                } else if entry.amount > 0 {
                    let months = Int((remaining / entry.amount).rounded(.up))
                    Text(tr("Még \(remaining.ft) • kb. \(months) hónap",
                            "\(remaining.ft) to go • ~\(months) months"))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}
