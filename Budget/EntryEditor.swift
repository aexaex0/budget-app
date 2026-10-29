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
    @State private var recurring: Bool
    @State private var date: Date

    init(kind: EntryKind, entry: Entry?, recurring: Bool = true) {
        self.kind = kind
        self.entry = entry
        _recurring = State(initialValue: entry?.isRecurring ?? recurring)
        _date = State(initialValue: entry?.date ?? Date.now)
    }

    private var supportsOneTime: Bool { kind == .income || kind == .expense }

    var body: some View {
        let tr = store.tr
        NavigationStack {
            Form {
                if supportsOneTime {
                    Section {
                        Picker(tr("Ismétlődés", "Repeat"), selection: $recurring) {
                            Text(tr("Minden hónapban", "Every month")).tag(true)
                            Text(tr("Egyszeri", "One-time")).tag(false)
                        }
                        .pickerStyle(.segmented)
                        if !recurring {
                            DatePicker(tr("Mikor", "When"), selection: $date, displayedComponents: .date)
                        }
                    } footer: {
                        Text(recurring
                             ? tr("Minden hónapban automatikusan beleszámít.",
                                  "Counted automatically every month.")
                             : tr("Csak a kiválasztott hónapban számít bele.",
                                  "Only counted in the selected month."))
                    }
                }
                Section {
                    TextField(tr("Név", "Name"), text: $name)
                    TextField(amountLabel(tr), value: $amount, format: .number)
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

    private func amountLabel(_ tr: Tr) -> String {
        if supportsOneTime && !recurring {
            return tr("Összeg (Ft)", "Amount (Ft)")
        }
        return tr("Havi összeg (Ft)", "Monthly amount (Ft)")
    }

    private func save() {
        let clean = name.trimmingCharacters(in: .whitespaces)
        let isRecurring = supportsOneTime ? recurring : true
        if let entry {
            entry.name = clean
            entry.amount = amount ?? 0
            entry.targetAmount = target ?? 0
            entry.savedSoFar = saved ?? 0
            entry.isRecurring = isRecurring
            entry.date = date
        } else {
            context.insert(Entry(name: clean, amount: amount ?? 0, kind: kind,
                                 targetAmount: target ?? 0, savedSoFar: saved ?? 0,
                                 isRecurring: isRecurring, date: date))
        }
        Haptics.success()
        dismiss()
    }
}
