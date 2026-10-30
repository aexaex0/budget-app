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
    @State private var showSlot = false
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
    private var total: Double { supportsOneTime ? recurringTotal + oneTimeThisMonth : recurringTotal }

    var body: some View {
        let tr = store.tr
        List {
            if !recurring.isEmpty || !supportsOneTime {
                Section {
                    ForEach(recurring) { entry in entryButton(entry, tr) }
                        .onDelete { delete(recurring, $0) }
                } header: {
                    if supportsOneTime {
                        sectionHeader(icon: "arrow.triangle.2.circlepath",
                                      title: tr("Havonta", "Monthly"))
                    }
                }
            }

            if supportsOneTime && !oneTime.isEmpty {
                Section {
                    ForEach(oneTime) { entry in entryButton(entry, tr) }
                        .onDelete { delete(oneTime, $0) }
                } header: {
                    sectionHeader(icon: "1.circle", title: tr("Egyszeri", "One-time"))
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AppBackground())
        .navigationTitle(kind.plural(tr))
        .animation(.snappy, value: entries.count)
        .safeAreaInset(edge: .top, spacing: 0) { summaryCard(tr) }
        .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: 76) }
        .overlay(alignment: .bottom) {
            addButton(tr).padding(.bottom, 12)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if kind == .income {
                    Button {
                        Haptics.tap()
                        showSlot = true
                    } label: {
                        Image(systemName: "die.face.5.fill")
                    }
                    .accessibilityLabel("Slot")
                }
            }
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
        }
        .sheet(item: $newEntry) { EntryEditor(kind: kind, entry: nil, recurring: $0.recurring) }
        .sheet(item: $editing) { EntryEditor(kind: kind, entry: $0) }
        .sheet(isPresented: $showCalc) { GoalCalculatorView() }
        .fullScreenCover(isPresented: $showSlot) { SlotGameView() }
    }

    // MARK: Részek

    /// Lebegő + gomb lent, középen.
    @ViewBuilder
    private func addButton(_ tr: Tr) -> some View {
        if supportsOneTime {
            Menu {
                Button {
                    newEntry = NewEntry(recurring: true)
                } label: {
                    Label(tr("Havi ismétlődő", "Monthly"), systemImage: "arrow.triangle.2.circlepath")
                }
                Button {
                    newEntry = NewEntry(recurring: false)
                } label: {
                    Label(tr("Egyszeri", "One-time"), systemImage: "1.circle")
                }
            } label: {
                plusIcon
            }
        } else {
            Button {
                Haptics.tap()
                newEntry = NewEntry(recurring: true)
            } label: {
                plusIcon
            }
            .buttonStyle(.plain)
        }
    }

    private var plusIcon: some View {
        Image(systemName: "plus")
            .font(.title2.weight(.semibold))
            .frame(width: 58, height: 58)
            .glassEffect(.regular.interactive(), in: .circle)
    }

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
                    chip(icon: "arrow.triangle.2.circlepath", value: recurringTotal)
                    chip(icon: "1.circle", value: oneTimeThisMonth)
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

    private func chip(icon: String, value: Double) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.caption).foregroundStyle(kind.color)
            Text(value.ft)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 14))
    }

    private func sectionHeader(icon: String, title: String) -> some View {
        Label(title, systemImage: icon)
            .font(.subheadline.bold())
            .foregroundStyle(.secondary)
            .textCase(nil)
            .padding(.top, 8)
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
                        Label("\(entry.renewalDay).", systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if !entry.isRecurring {
                        Label(shortDate(entry.date, english: store.isEnglish), systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if kind == .expense, let cat = categories.first(where: { $0.id == entry.categoryID }) {
                        Label(cat.name, systemImage: cat.symbol)
                            .font(.caption)
                            .foregroundStyle(cat.color)
                    }
                }
                Spacer(minLength: 8)
                Text(entry.amount.ft)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            if kind == .saving, entry.targetAmount > 0 {
                ProgressView(value: min(entry.savedSoFar, entry.targetAmount),
                             total: entry.targetAmount)
                    .tint(kind.color)
                let remaining = max(entry.targetAmount - entry.savedSoFar, 0)
                if remaining == 0 {
                    Text("🎉").font(.caption)
                } else if entry.amount > 0 {
                    let months = Int((remaining / entry.amount).rounded(.up))
                    Text(tr("\(remaining.ft) · \(months) hó", "\(remaining.ft) · \(months) mo"))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}
