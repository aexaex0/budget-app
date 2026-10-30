import SwiftUI
import SwiftData

/// Heti (vagy napi) költési keret az egyszeri kiadásokra.
struct BudgetLimitCard: View {
    @EnvironmentObject private var store: ThemeStore
    @Query private var entries: [Entry]
    @AppStorage("budgetMode") private var mode = "week"
    @AppStorage("budgetLimit") private var limit: Double = 0
    @State private var showEdit = false

    private var spent: Double {
        var cal = Calendar.current
        cal.firstWeekday = 2
        let items = entries.filter { !$0.isRecurring && $0.kind == .expense }
        if mode == "day" {
            return items.filter { cal.isDateInToday($0.date) }.reduce(0) { $0 + $1.amount }
        }
        guard let interval = cal.dateInterval(of: .weekOfYear, for: .now) else { return 0 }
        return items.filter { interval.contains($0.date) }.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        let tr = store.tr
        let title = mode == "day" ? tr("Napi keret", "Daily budget") : tr("Heti keret", "Weekly budget")
        let remaining = limit - spent
        let progress = limit > 0 ? min(max(spent / limit, 0), 1) : 0
        Button {
            Haptics.tap()
            showEdit = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(title, systemImage: "gauge.with.dots.needle.67percent")
                        .font(.headline)
                    Spacer(minLength: 8)
                    if limit > 0 {
                        Text(remaining.ft)
                            .font(.title3.bold())
                            .foregroundStyle(remaining >= 0 ? Color.primary : Color.red)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    } else {
                        Image(systemName: "plus.circle.fill").font(.title3)
                    }
                }
                if limit > 0 {
                    ProgressView(value: progress)
                        .tint(progress > 0.9 ? Color.red : Color.green)
                    Text("\(spent.ft) / \(limit.ft)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(24)
        }
        .buttonStyle(.plain)
        .task(id: "\(limit)|\(spent)|\(mode)") {
            WidgetSync.push(budgetRemaining: limit - spent, budgetLimit: limit)
        }
        .sheet(isPresented: $showEdit) { BudgetLimitEditor() }
    }
}

struct BudgetLimitEditor: View {
    @EnvironmentObject private var store: ThemeStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("budgetMode") private var mode = "week"
    @AppStorage("budgetLimit") private var limit: Double = 0
    @State private var amount: Double?

    var body: some View {
        let tr = store.tr
        NavigationStack {
            Form {
                Picker("", selection: $mode) {
                    Text(tr("Napi", "Daily")).tag("day")
                    Text(tr("Heti", "Weekly")).tag("week")
                }
                .pickerStyle(.segmented)
                TextField(tr("Keret (Ft)", "Budget (Ft)"), value: $amount, format: .number)
                    .keyboardType(.decimalPad)
                    .font(.title2.bold())
                if limit > 0 {
                    Button(role: .destructive) {
                        limit = 0
                        dismiss()
                    } label: {
                        Label(tr("Kikapcsol", "Turn off"), systemImage: "trash")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle(tr("Költési keret", "Spending budget"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Mégse", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("Mentés", "Save")) {
                        limit = amount ?? 0
                        Haptics.success()
                        dismiss()
                    }
                    .disabled((amount ?? 0) <= 0)
                }
            }
            .onAppear { amount = limit > 0 ? limit : nil }
        }
        .presentationDetents([.medium])
    }
}
