import SwiftUI
import SwiftData

/// Tartozás: valaki nekem tartozik (owedToMe) vagy én tartozom valakinek.
@Model
final class Debt {
    var person: String = ""
    var amount: Double = 0
    var paid: Double = 0
    var owedToMe: Bool = true
    var note: String = ""
    var hasDue: Bool = false
    var due: Date = Date.now
    var createdAt: Date = Date.now

    var remaining: Double { max(amount - paid, 0) }
    var settled: Bool { remaining <= 0.5 }

    init(person: String, amount: Double, owedToMe: Bool, note: String = "",
         hasDue: Bool = false, due: Date = .now) {
        self.person = person
        self.amount = amount
        self.owedToMe = owedToMe
        self.note = note
        self.hasDue = hasDue
        self.due = due
        self.createdAt = .now
    }
}

struct DebtsView: View {
    @EnvironmentObject private var store: ThemeStore
    @Environment(\.modelContext) private var context
    @Query(sort: \Debt.createdAt, order: .reverse) private var debts: [Debt]
    @State private var showAdd = false
    @State private var tab = 0   // 0: nekem tartoznak, 1: én tartozom
    @State private var payTarget: Debt?
    @State private var payText = ""

    private var open: [Debt] { debts.filter { !$0.settled } }
    private var owedToMeTotal: Double { open.filter { $0.owedToMe }.reduce(0) { $0 + $1.remaining } }
    private var iOweTotal: Double { open.filter { !$0.owedToMe }.reduce(0) { $0 + $1.remaining } }

    private func list(open isOpen: Bool) -> [Debt] {
        debts.filter { $0.owedToMe == (tab == 0) && $0.settled != isOpen }
    }

    var body: some View {
        let tr = store.tr
        let openList = list(open: true)
        let doneList = list(open: false)
        ScrollView {
            VStack(spacing: 16) {
                summary(tr)
                Picker("", selection: $tab) {
                    Text(tr("Nekem tartoznak", "Owed to me")).tag(0)
                    Text(tr("Én tartozom", "I owe")).tag(1)
                }
                .pickerStyle(.segmented)

                if openList.isEmpty {
                    Text(tab == 0 ? tr("Senki sem tartozik neked.", "Nobody owes you.")
                                  : tr("Nem tartozol senkinek.", "You owe nobody."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 30)
                }
                ForEach(openList) { d in row(d, tr) }

                if !doneList.isEmpty {
                    Text(tr("Rendezve", "Settled"))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                    ForEach(doneList) { d in row(d, tr).opacity(0.55) }
                }
            }
            .padding(16)
        }
        .background(AppBackground())
        .navigationTitle(tr("Tartozások", "Debts"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) { AddDebtSheet(owedToMe: tab == 0) }
        .alert(tr("Részletfizetés", "Payment"), isPresented: Binding(
            get: { payTarget != nil },
            set: { if !$0 { payTarget = nil } })) {
            TextField(tr("Összeg", "Amount"), text: $payText)
                .keyboardType(.decimalPad)
            Button(tr("Mégse", "Cancel"), role: .cancel) { payText = "" }
            Button(tr("Rögzít", "Save")) {
                if let d = payTarget { d.paid = min(d.paid + parseNumber(payText), d.amount) }
                payText = ""
                Haptics.success()
            }
        }
    }

    private func summary(_ tr: Tr) -> some View {
        let net = owedToMeTotal - iOweTotal
        return VStack(spacing: 12) {
            Text(tr("Egyenleg", "Balance"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text((net >= 0 ? "+" : "−") + abs(net).ft)
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(net >= 0 ? Color.green : Color.red)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            HStack {
                VStack {
                    Text(owedToMeTotal.ft).font(.headline).foregroundStyle(.green)
                    Text(tr("nekem tartoznak", "owed to me")).font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                VStack {
                    Text(iOweTotal.ft).font(.headline).foregroundStyle(.red)
                    Text(tr("én tartozom", "I owe")).font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
    }

    private func row(_ d: Debt, _ tr: Tr) -> some View {
        let overdue = d.hasDue && !d.settled && d.due < Calendar.current.startOfDay(for: .now)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(d.person).font(.headline)
                Spacer()
                Text(d.remaining.ft)
                    .font(.headline)
                    .foregroundStyle(d.owedToMe ? Color.green : Color.red)
            }
            if !d.note.isEmpty {
                Text(d.note).font(.subheadline).foregroundStyle(.secondary)
            }
            if d.paid > 0 {
                ProgressView(value: min(d.paid, d.amount), total: max(d.amount, 1))
                Text(tr("Törlesztve: \(d.paid.ft) / \(d.amount.ft)", "Paid: \(d.paid.ft) / \(d.amount.ft)"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if d.hasDue {
                Label(d.due.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(overdue ? Color.red : Color.secondary)
            }
            if !d.settled {
                HStack(spacing: 8) {
                    Button(tr("Részlet", "Part")) { payTarget = d }
                        .buttonStyle(.bordered)
                    Button(tr("Rendezve", "Settle")) {
                        Haptics.success()
                        d.paid = d.amount
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
                .font(.footnote.weight(.semibold))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
        .contextMenu {
            Button(tr("Törlés", "Delete"), systemImage: "trash", role: .destructive) {
                context.delete(d)
            }
        }
    }
}

struct AddDebtSheet: View {
    @EnvironmentObject private var store: ThemeStore
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State var owedToMe: Bool
    @State private var person = ""
    @State private var amountText = ""
    @State private var note = ""
    @State private var hasDue = false
    @State private var due = Date.now

    var body: some View {
        let tr = store.tr
        NavigationStack {
            Form {
                Picker("", selection: $owedToMe) {
                    Text(tr("Nekem tartozik", "Owes me")).tag(true)
                    Text(tr("Én tartozom", "I owe")).tag(false)
                }
                .pickerStyle(.segmented)
                TextField(tr("Kinek / ki", "Person"), text: $person)
                TextField(tr("Összeg (Ft)", "Amount"), text: $amountText)
                    .keyboardType(.decimalPad)
                TextField(tr("Megjegyzés", "Note"), text: $note)
                Toggle(tr("Határidő", "Due date"), isOn: $hasDue)
                if hasDue {
                    DatePicker(tr("Mikorra", "By"), selection: $due, displayedComponents: .date)
                }
            }
            .navigationTitle(tr("Új tartozás", "New debt"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Mégse", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("Mentés", "Save")) {
                        context.insert(Debt(person: person.trimmingCharacters(in: .whitespaces),
                                            amount: parseNumber(amountText), owedToMe: owedToMe,
                                            note: note, hasDue: hasDue, due: due))
                        Haptics.success()
                        dismiss()
                    }
                    .disabled(person.trimmingCharacters(in: .whitespaces).isEmpty || parseNumber(amountText) <= 0)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
