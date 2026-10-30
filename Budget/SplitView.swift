import SwiftUI

struct SplitExpense: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var amount: Double
    var payer: String
}

struct SplitState: Codable, Equatable {
    var people: [String] = []
    var expenses: [SplitExpense] = []
}

struct Settlement: Identifiable {
    let id = UUID()
    let from: String
    let to: String
    let amount: Double
}

/// Ki mennyivel tartozik: egyenlő felosztás, minimális számú utalással.
struct SplitView: View {
    @EnvironmentObject private var store: ThemeStore
    @AppStorage("splitData") private var raw: String = ""
    @State private var state = SplitState()
    @State private var newPerson = ""
    @State private var title = ""
    @State private var amountText = ""
    @State private var payer = ""

    private func load() {
        if let d = raw.data(using: .utf8), let s = try? JSONDecoder().decode(SplitState.self, from: d) {
            state = s
            if payer.isEmpty { payer = s.people.first ?? "" }
        }
    }

    private func save() {
        if let d = try? JSONEncoder().encode(state), let s = String(data: d, encoding: .utf8) {
            raw = s
        }
    }

    private var settlements: [Settlement] {
        let n = Double(state.people.count)
        if n < 2 { return [] }
        let total = state.expenses.reduce(0) { $0 + $1.amount }
        let share = total / n
        var debtors: [(String, Double)] = []
        var creditors: [(String, Double)] = []
        for p in state.people {
            let paid = state.expenses.filter { $0.payer == p }.reduce(0) { $0 + $1.amount }
            let bal = paid - share
            if bal < -0.5 { debtors.append((p, -bal)) }
            if bal > 0.5 { creditors.append((p, bal)) }
        }
        var out: [Settlement] = []
        var i = 0
        var j = 0
        while i < debtors.count && j < creditors.count {
            let pay = min(debtors[i].1, creditors[j].1)
            out.append(Settlement(from: debtors[i].0, to: creditors[j].0, amount: pay.rounded()))
            debtors[i].1 -= pay
            creditors[j].1 -= pay
            if debtors[i].1 < 0.5 { i += 1 }
            if creditors[j].1 < 0.5 { j += 1 }
        }
        return out
    }

    var body: some View {
        let tr = store.tr
        List {
            Section(tr("Emberek", "People")) {
                ForEach(state.people, id: \.self) { p in
                    Label(p, systemImage: "person.fill")
                }
                .onDelete { offsets in
                    let names = offsets.map { state.people[$0] }
                    state.people.removeAll { names.contains($0) }
                    state.expenses.removeAll { names.contains($0.payer) }
                    save()
                }
                HStack {
                    TextField(tr("Név", "Name"), text: $newPerson)
                        .submitLabel(.done)
                        .onSubmit(addPerson)
                    Button(action: addPerson) {
                        Image(systemName: "plus.circle.fill")
                    }
                    .buttonStyle(.borderless)
                }
            }

            if state.people.count >= 2 {
                Section(tr("Új költés", "New expense")) {
                    TextField(tr("Mire?", "What for?"), text: $title)
                    TextField(tr("Összeg", "Amount"), text: $amountText)
                        .keyboardType(.decimalPad)
                    Picker(tr("Fizette", "Paid by"), selection: $payer) {
                        ForEach(state.people, id: \.self) { Text($0).tag($0) }
                    }
                    Button {
                        addExpense()
                    } label: {
                        Label(tr("Hozzáad", "Add"), systemImage: "plus")
                    }
                    .disabled(parseNumber(amountText) <= 0)
                }
            }

            if !state.expenses.isEmpty {
                Section(tr("Költések", "Expenses")) {
                    ForEach(state.expenses) { e in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(e.title.isEmpty ? "—" : e.title)
                                Text(e.payer).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(e.amount.ft).fontWeight(.semibold)
                        }
                    }
                    .onDelete { offsets in
                        state.expenses.remove(atOffsets: offsets)
                        save()
                    }
                }
            }

            if !settlements.isEmpty {
                Section(tr("Elszámolás", "Settle up")) {
                    ForEach(settlements) { s in
                        HStack {
                            Text(s.from).fontWeight(.semibold)
                            Image(systemName: "arrow.right").foregroundStyle(.secondary)
                            Text(s.to).fontWeight(.semibold)
                            Spacer()
                            Text(s.amount.ft).foregroundStyle(.green).fontWeight(.bold)
                        }
                    }
                }
            } else if state.expenses.count > 0 && state.people.count >= 2 {
                Section {
                    Label(tr("Mindenki kvitt", "All even"), systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            if !state.expenses.isEmpty || !state.people.isEmpty {
                Section {
                    Button(role: .destructive) {
                        state = SplitState()
                        payer = ""
                        save()
                    } label: {
                        Label(tr("Újrakezdés", "Reset"), systemImage: "arrow.counterclockwise")
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppBackground())
        .navigationTitle(tr("Ki mennyivel tartozik", "Split bill"))
        .onAppear(perform: load)
    }

    private func addPerson() {
        let n = newPerson.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty, !state.people.contains(n) else { return }
        Haptics.tap()
        state.people.append(n)
        if payer.isEmpty { payer = n }
        newPerson = ""
        save()
    }

    private func addExpense() {
        let amount = parseNumber(amountText)
        guard amount > 0 else { return }
        let who = state.people.contains(payer) ? payer : (state.people.first ?? "")
        Haptics.success()
        state.expenses.append(SplitExpense(title: title, amount: amount, payer: who))
        title = ""
        amountText = ""
        save()
    }
}
