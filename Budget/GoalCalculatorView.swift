import SwiftUI
import SwiftData

/// Célkalkulátor: határidőből havi összeg, vagy havi összegből határidő.
struct GoalCalculatorView: View {
    @EnvironmentObject private var store: ThemeStore
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var entries: [Entry]

    @State private var name = ""
    @State private var target: Double?
    @State private var saved: Double?
    @State private var byDeadline = true
    @State private var months = 12
    @State private var monthly: Double?

    /// Az idei hónapban még szabadon félretehető összeg.
    private var available: Double {
        func sum(_ k: EntryKind) -> Double {
            entries.filter { $0.kind == k && $0.counts(in: .now) }.reduce(0) { $0 + $1.amount }
        }
        return sum(.income) - sum(.expense) - sum(.subscription) - sum(.saving)
    }

    private var remaining: Double { max((target ?? 0) - (saved ?? 0), 0) }

    /// Havi összeg az eredményhez.
    private var monthlyResult: Double {
        if byDeadline {
            return months > 0 ? remaining / Double(months) : 0
        }
        return monthly ?? 0
    }

    private var monthsResult: Int {
        if byDeadline { return months }
        guard let m = monthly, m > 0 else { return 0 }
        return Int((remaining / m).rounded(.up))
    }

    var body: some View {
        let tr = store.tr
        NavigationStack {
            Form {
                Section {
                    TextField(tr("Cél neve", "Goal name"), text: $name)
                    TextField(tr("Célösszeg (Ft)", "Target amount (Ft)"), value: $target, format: .number)
                        .keyboardType(.decimalPad)
                    TextField(tr("Már megvan (Ft)", "Already saved (Ft)"), value: $saved, format: .number)
                        .keyboardType(.decimalPad)
                }
                Section {
                    Picker("", selection: $byDeadline) {
                        Text(tr("Határidő alapján", "By deadline")).tag(true)
                        Text(tr("Havi összeg alapján", "By monthly amount")).tag(false)
                    }
                    .pickerStyle(.segmented)
                    if byDeadline {
                        Stepper(value: $months, in: 1...240) {
                            Text(tr("\(months) hónap alatt", "Within \(months) months"))
                        }
                    } else {
                        TextField(tr("Havi összeg (Ft)", "Monthly amount (Ft)"), value: $monthly, format: .number)
                            .keyboardType(.decimalPad)
                    }
                }
                if (target ?? 0) > 0 {
                    Section {
                        result(tr)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle(tr("Célkalkulátor", "Goal calculator"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Bezár", "Close")) { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    @ViewBuilder
    private func result(_ tr: Tr) -> some View {
        let perMonth = monthlyResult
        let m = monthsResult
        VStack(alignment: .leading, spacing: 8) {
            if byDeadline {
                Label(tr("Havonta", "Per month"), systemImage: "calendar")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(perMonth.ft)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            } else if m > 0 {
                let end = Calendar.current.date(byAdding: .month, value: m, to: .now) ?? .now
                let when = end.formatted(Date.FormatStyle().year().month(.wide)
                    .locale(Locale(identifier: store.isEnglish ? "en_US" : "hu_HU")))
                Label(when, systemImage: "calendar")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(tr("\(m) hónap", "\(m) months"))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
            }

            if perMonth > 0 {
                if perMonth <= max(available, 0) {
                    Label(tr("Belefér", "Fits"), systemImage: "checkmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(.green)
                } else {
                    Label(tr("Nem fér bele", "Too much"), systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
                Button(tr("Mentés célként", "Save as goal")) {
                    saveGoal(perMonth, tr)
                }
                .buttonStyle(.glassProminent)
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }

    private func saveGoal(_ perMonth: Double, _ tr: Tr) {
        let clean = name.trimmingCharacters(in: .whitespaces)
        context.insert(Entry(name: clean.isEmpty ? tr("Új cél", "New goal") : clean,
                             amount: perMonth.rounded(.up), kind: .saving,
                             targetAmount: target ?? 0, savedSoFar: saved ?? 0))
        Haptics.success()
        dismiss()
    }
}
