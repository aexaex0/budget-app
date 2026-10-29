import SwiftUI
import SwiftData

struct EntryListView: View {
    let kind: EntryKind

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
        List {
            Section {
                HStack {
                    Text("Havi összesen")
                    Spacer()
                    Text(total.ft).fontWeight(.bold)
                }
            }
            .listRowBackground(Color.clear)
            .glassEffect(.regular, in: .rect(cornerRadius: 20))

            Section {
                ForEach(entries) { entry in
                    Button { editing = entry } label: { row(entry) }
                        .buttonStyle(.plain)
                }
                .onDelete { offsets in
                    for i in offsets { context.delete(entries[i]) }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppBackground())
        .navigationTitle(kind.plural)
        .overlay {
            if entries.isEmpty {
                ContentUnavailableView("Még nincs tétel",
                                       systemImage: kind.icon,
                                       description: Text("Koppints a + gombra a hozzáadáshoz."))
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Új", systemImage: "plus") { adding = true }
            }
        }
        .sheet(isPresented: $adding) { EntryEditor(kind: kind, entry: nil) }
        .sheet(item: $editing) { EntryEditor(kind: kind, entry: $0) }
    }

    private func row(_ entry: Entry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: kind.icon).foregroundStyle(kind.color)
                Text(entry.name)
                Spacer()
                Text(entry.amount.ft).fontWeight(.semibold)
            }
            if kind == .saving, entry.targetAmount > 0 {
                ProgressView(value: min(entry.savedSoFar, entry.targetAmount),
                             total: entry.targetAmount)
                    .tint(kind.color)
                let remaining = max(entry.targetAmount - entry.savedSoFar, 0)
                if remaining == 0 {
                    Text("Cél elérve 🎉").font(.caption).foregroundStyle(.secondary)
                } else if entry.amount > 0 {
                    let months = Int((remaining / entry.amount).rounded(.up))
                    Text("Még \(remaining.ft) • kb. \(months) hónap")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}
