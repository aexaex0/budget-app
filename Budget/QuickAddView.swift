import SwiftUI
import SwiftData

/// Gyors, egyszeri összeg hozzáadása (bevétel vagy kiadás) – pl. ajándék, extra kiadás.
struct QuickAddView: View {
    @EnvironmentObject private var store: ThemeStore
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var kind: EntryKind = .income
    @State private var amount: Double?
    @State private var note = ""
    @State private var date = Date.now
    @State private var categoryID = ""
    @Query(sort: \Category.createdAt) private var categories: [Category]

    var body: some View {
        let tr = store.tr
        NavigationStack {
            Form {
                Section {
                    Picker("", selection: $kind) {
                        Text(EntryKind.income.title(tr)).tag(EntryKind.income)
                        Text(EntryKind.expense.title(tr)).tag(EntryKind.expense)
                    }
                    .pickerStyle(.segmented)
                    TextField(tr("Összeg (Ft)", "Amount (Ft)"), value: $amount, format: .number)
                        .keyboardType(.decimalPad)
                        .font(.title2.bold())
                    TextField(tr("Megjegyzés (nem kötelező)", "Note (optional)"), text: $note)
                    if kind == .expense {
                        Picker(tr("Kategória", "Category"), selection: $categoryID) {
                            Text(tr("Nincs", "None")).tag("")
                            ForEach(categories) { c in
                                Label(c.name, systemImage: c.symbol).tag(c.id)
                            }
                        }
                    }
                }
                Section {
                    DatePicker(tr("Mikor", "When"), selection: $date, displayedComponents: .date)
                } footer: {
                    Text(tr("Egyszeri összeg: csak a kiválasztott hónapban számít bele.",
                            "One-time amount: only counted in the selected month."))
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle(tr("Gyors hozzáadás", "Quick add"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Mégse", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("Mentés", "Save")) { save(tr) }
                        .disabled((amount ?? 0) <= 0)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func save(_ tr: Tr) {
        let clean = note.trimmingCharacters(in: .whitespaces)
        let fallback = kind == .income
            ? tr("Egyszeri bevétel", "One-time income")
            : tr("Egyszeri kiadás", "One-time expense")
        context.insert(Entry(name: clean.isEmpty ? fallback : clean,
                             amount: amount ?? 0, kind: kind,
                             isRecurring: false, date: date,
                             categoryID: kind == .expense ? categoryID : ""))
        Haptics.success()
        dismiss()
    }
}
