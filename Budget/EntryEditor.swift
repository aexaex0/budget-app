import SwiftUI
import SwiftData

struct EntryEditor: View {
    let kind: EntryKind
    let entry: Entry?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var amount: Double?
    @State private var target: Double?
    @State private var saved: Double?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Név", text: $name)
                    TextField("Havi összeg (Ft)", value: $amount, format: .number)
                        .keyboardType(.decimalPad)
                }
                if kind == .saving {
                    Section("Cél (nem kötelező)") {
                        TextField("Célösszeg (Ft)", value: $target, format: .number)
                            .keyboardType(.decimalPad)
                        TextField("Eddig félretéve (Ft)", value: $saved, format: .number)
                            .keyboardType(.decimalPad)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle(entry == nil ? "Új \(kind.title.lowercased())" : "Szerkesztés")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Mégse") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Mentés", action: save)
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
        dismiss()
    }
}
