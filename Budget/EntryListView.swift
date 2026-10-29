import SwiftUI
import SwiftData

struct EntryListView: View {
    let kind: EntryKind

    @EnvironmentObject private var store: ThemeStore
    @Environment(\.modelContext) private var context
    @Query private var entries: [Entry]
    @State private var editing: Entry?
    @State private var adding = false

    init(kind: EntryKind) {
        self.kind = kind
        let raw = kind.rawValue
        _entries = Query(filter: #Predicate<Entry> { $0.kindRaw == raw },
                         sort: \.createdAt)
    }

    private var total: Double { entries.reduce(0) { $0 + $1.amount } }

    var body: some View {
        let tr = store.tr
        List {
            ForEach(entries) { entry in
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
            .onDelete { offsets in
                Haptics.tap(.medium)
                withAnimation(.snappy) {
                    for i in offsets { context.delete(entries[i]) }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AppBackground())
        .navigationTitle(kind.plural(tr))
        .animation(.snappy, value: entries.count)
        .safeAreaInset(edge: .top, spacing: 0) {
            // Havi összesen kártya: rendes belső margóval, hogy a szöveg ne érjen a szélhez
            HStack(spacing: 12) {
                Text(tr("Havi összesen", "Monthly total"))
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
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .glassEffect(.regular, in: .rect(cornerRadius: 24))
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 10)
        }
        .overlay {
            if entries.isEmpty {
                ContentUnavailableView(tr("Még nincs tétel", "Nothing here yet"),
                                       systemImage: kind.icon,
                                       description: Text(tr("Koppints a + gombra a hozzáadáshoz.",
                                                            "Tap + to add one.")))
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(tr("Új", "New"), systemImage: "plus") {
                    Haptics.tap()
                    adding = true
                }
            }
        }
        .sheet(isPresented: $adding) { EntryEditor(kind: kind, entry: nil) }
        .sheet(item: $editing) { EntryEditor(kind: kind, entry: $0) }
    }

    private func row(_ entry: Entry, _ tr: Tr) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: kind.icon)
                    .foregroundStyle(kind.color)
                    .frame(width: 26)
                Text(entry.name)
                    .lineLimit(2)
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
