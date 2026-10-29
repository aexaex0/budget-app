import SwiftUI
import SwiftData

struct EntryEditor: View {
    let kind: EntryKind
    let entry: Entry?

    @EnvironmentObject private var store: ThemeStore
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var amount: Double?
    @State private var target: Double?
    @State private var saved: Double?

    var body: some View {
        let tr = store.tr
        NavigationStack {
            Form {
                Section {
                    TextField(tr("Név", "Name"), text: $name)
                    TextField(tr("Havi összeg (Ft)", "Monthly amount (Ft)"), value: $amount, format: .number)
                        .keyboardType(.decimalPad)
                }
                if kind == .saving {
                    Section(tr("Cél (nem kötelező)", "Goal (optional)")) {
                        TextField(tr("Célösszeg (Ft)", "Target amount (Ft)"), value: $target, format: .number)
                            .keyboardType(.decimalPad)
                        TextField(tr("Eddig félretéve (Ft)", "Saved so far (Ft)"), value: $saved, format: .number)
                            .keyboardType(.decimalPad)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle(entry == nil
                             ? tr("Új \(kind.title(tr).lowercased())", "New \(kind.title(tr).lowercased())")
                             : tr("Szerkesztés", "Edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Mégse", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("Mentés", "Save"), action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || amount == nil)
                }
            }
            .onAppear {
                guard let entry else { return }
                name = entry.name
                amount = entry.amount
                target = entry.targetAmount > 0 ? entry.targetAmount : nil
                saved = entry.savedSoFar > 0 ? entry.savedSoFar : nil
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        let clean = name.trimmingCharacters(in: .whitespaces)
        if let entry {
            entry.name = clean
            entry.amount = amount ?? 0
            entry.targetAmount = target ?? 0
            entry.savedSoFar = saved ?? 0
        } else {
            context.insert(Entry(name: clean, amount: amount ?? 0, kind: kind,
                                 targetAmount: target ?? 0, savedSoFar: saved ?? 0))
        }
        Haptics.success()
        dismiss()
    }
}
