import SwiftUI
import SwiftData

struct DonutView: View {
    struct Seg: Identifiable {
        let id: String
        let value: Double
        let color: Color
    }

    let segs: [Seg]
    let progress: CGFloat
    let centerText: String
    let caption: String

    var body: some View {
        let total = max(segs.reduce(0) { $0 + $1.value }, 0.0001)
        ZStack {
            ForEach(Array(segs.enumerated()), id: \.offset) { idx, s in
                let before = segs[..<idx].reduce(0) { $0 + $1.value }
                let start = CGFloat(before / total)
                let end = start + CGFloat(s.value / total)
                Circle()
                    .inset(by: 13)
                    .trim(from: start * progress, to: max(start, end - 0.008) * progress)
                    .stroke(s.color, style: StrokeStyle(lineWidth: 26, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }
            VStack(spacing: 2) {
                Text(centerText)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text(caption).font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(width: 200, height: 200)
    }
}

struct OverviewView: View {
    @EnvironmentObject private var store: ThemeStore
    @Query private var entries: [Entry]
    @State private var showTheme = false
    @State private var showQuick = false
    @State private var sweep: CGFloat = 0
    @State private var month: Date = OverviewView.monthStart(Date.now)

    static func monthStart(_ d: Date) -> Date {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.year, .month], from: d)) ?? d
    }

    /// Az adott hónapba beleszámító tételek összege (ismétlődő + egyszeri).
    private func total(_ kind: EntryKind) -> Double {
        entries.filter { $0.kind == kind && $0.counts(in: month) }.reduce(0) { $0 + $1.amount }
    }

    /// Csak az egyszeri tételek összege az adott hónapban.
    private func oneTimeTotal(_ kind: EntryKind) -> Double {
        entries.filter { $0.kind == kind && !$0.isRecurring && $0.counts(in: month) }
            .reduce(0) { $0 + $1.amount }
    }

    private func shiftMonth(_ delta: Int) {
        let next = Calendar.current.date(byAdding: .month, value: delta, to: month) ?? month
        Haptics.tap(.soft)
        withAnimation(.snappy) { month = next }
        sweep = 0
        withAnimation(.easeOut(duration: 0.8)) { sweep = 1 }
    }

    private func monthTitle(_ tr: Tr) -> String {
        month.formatted(Date.FormatStyle().year().month(.wide)
            .locale(Locale(identifier: tr.en ? "en_US" : "hu_HU")))
    }

    var body: some View {
        let tr = store.tr
        let income = total(.income)
        let expenses = total(.expense)
        let subs = total(.subscription)
        let savings = total(.saving)
        let left = income - expenses - subs - savings
        let savingsRate = income > 0 ? savings / income : 0
        let daysInMonth = Calendar.current.range(of: .day, in: .month, for: month)?.count ?? 30
        let perDay = left / Double(daysInMonth)

        var segs: [DonutView.Seg] = [
            .init(id: tr("Kiadások", "Expenses"), value: expenses, color: EntryKind.expense.color),
            .init(id: tr("Előfizetések", "Subscriptions"), value: subs, color: EntryKind.subscription.color),
            .init(id: tr("Megtakarítás", "Savings"), value: savings, color: EntryKind.saving.color),
        ]
        if left > 0 { segs.append(.init(id: tr("Marad", "Left"), value: left, color: .green)) }
        segs = segs.filter { $0.value > 0 }

        let spendable = entries.filter { $0.kind == .expense || $0.kind == .subscription }
        let biggest = spendable.max(by: { $0.amount < $1.amount })
        let goals = entries.filter { $0.kind == .saving && $0.targetAmount > 0 }

        return NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Hónap választó
                    HStack {
                        Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
                            .accessibilityLabel(tr("Előző hónap", "Previous month"))
                        Spacer()
                        Text(monthTitle(tr))
                            .font(.headline)
                            .contentTransition(.numericText())
                        Spacer()
                        Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
                            .accessibilityLabel(tr("Következő hónap", "Next month"))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .glassEffect(.regular, in: .capsule)

                    // Fő kártya
                    VStack(spacing: 6) {
                        Text(tr("Havonta megmarad", "Left each month"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(left.ft)
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(left >= 0 ? Color.primary : Color.red)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                            .contentTransition(.numericText(value: left))
                            .animation(.snappy, value: left)
                        if left < 0 {
                            Label(tr("Többet költesz, mint amennyit keresel",
                                     "You spend more than you earn"),
                                  systemImage: "exclamationmark.triangle.fill")
                                .font(.footnote)
                                .foregroundStyle(.red)
                        } else if income > 0 {
                            Text(tr("Napi keret: \(perDay.ft)", "Daily allowance: \(perDay.ft)"))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(24)
                    .glassCard(28)

                    // Fánk diagram
                    if !segs.isEmpty {
                        VStack(spacing: 14) {
                            DonutView(
                                segs: segs, progress: sweep,
                                centerText: savingsRate.formatted(.percent.precision(.fractionLength(0))),
                                caption: tr("megtakarítás", "saved")
                            )
                            FlowLegend(items: segs.map { ($0.id, $0.color) })
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity)
                        .glassCard(28)
                    }

                    // Kategóriák, bevételhez viszonyítva
                    VStack(spacing: 14) {
                        ForEach(EntryKind.allCases) { k in
                            categoryRow(k, value: total(k), oneTime: oneTimeTotal(k), income: income, tr: tr)
                        }
                    }
                    .padding(18)
                    .glassCard(24)

                    // Statisztikák
                    GlassEffectContainer(spacing: 12) {
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                statCard(tr("Megtakarítási ráta", "Savings rate"),
                                         savingsRate.formatted(.percent.precision(.fractionLength(0))))
                                statCard(tr("Éves félretett", "Saved per year"), (savings * 12).ft)
                            }
                            HStack(spacing: 12) {
                                statCard(tr("Éves előfizetés", "Subscriptions / year"), (subs * 12).ft)
                                statCard(tr("Éves megmarad", "Left per year"), (left * 12).ft)
                            }
                            HStack(spacing: 12) {
                                statCard(tr("Napi keret", "Per day"), perDay.ft)
                                statCard(tr("Kiadás a bevételből", "Spent of income"),
                                         income > 0
                                         ? ((expenses + subs) / income).formatted(.percent.precision(.fractionLength(0)))
                                         : "–")
                            }
                        }
                    }

                    // Legnagyobb tétel
                    if let biggest {
                        HStack(spacing: 12) {
                            Image(systemName: "flame.fill").foregroundStyle(.orange).font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tr("Legnagyobb havi tétel", "Biggest monthly cost"))
                                    .font(.caption).foregroundStyle(.secondary)
                                Text(biggest.name).font(.headline).lineLimit(1)
                            }
                            Spacer(minLength: 8)
                            Text(biggest.amount.ft).fontWeight(.bold).lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .padding(18)
                        .glassCard(24)
                    }

                    // Megtakarítási célok
                    if !goals.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(tr("Célok", "Goals")).font(.headline)
                            ForEach(goals) { g in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(g.name).lineLimit(1)
                                        Spacer(minLength: 8)
                                        Text((g.savedSoFar / g.targetAmount).formatted(.percent.precision(.fractionLength(0))))
                                            .font(.footnote).foregroundStyle(.secondary)
                                    }
                                    ProgressView(value: min(g.savedSoFar, g.targetAmount), total: g.targetAmount)
                                        .tint(EntryKind.saving.color)
                                }
                            }
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard(24)
                    }
                }
                .padding()
            }
            .background(AppBackground())
            .navigationTitle(tr("Áttekintés", "Overview"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(tr("Gyors hozzáadás", "Quick add"), systemImage: "plus.circle.fill") {
                        Haptics.tap()
                        showQuick = true
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(tr("Téma", "Theme"), systemImage: "paintpalette.fill") {
                        Haptics.tap()
                        showTheme = true
                    }
                }
            }
            .sheet(isPresented: $showTheme) { ThemeSettingsView() }
            .sheet(isPresented: $showQuick) { QuickAddView() }
            .onAppear {
                sweep = 0
                withAnimation(.easeOut(duration: 1.0)) { sweep = 1 }
            }
        }
    }

    private func categoryRow(_ k: EntryKind, value: Double, oneTime: Double,
                             income: Double, tr: Tr) -> some View {
        let share = income > 0 ? min(value / income, 1) : 0
        let monthly = value - oneTime
        return VStack(spacing: 7) {
            HStack(spacing: 10) {
                Image(systemName: k.icon).foregroundStyle(k.color).frame(width: 26)
                Text(k.plural(tr)).lineLimit(1)
                Spacer(minLength: 8)
                Text(value.ft).fontWeight(.semibold).lineLimit(1).minimumScaleFactor(0.7)
            }
            if oneTime > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath").font(.caption2)
                    Text(monthly.ft).lineLimit(1)
                    Text("•")
                    Image(systemName: "1.circle").font(.caption2)
                    Text(oneTime.ft).lineLimit(1)
                    Spacer(minLength: 0)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 36)
            }
            if k != .income {
                ProgressView(value: share).tint(k.color)
            }
        }
    }

    private func statCard(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Text(value)
                .font(.headline)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }
}

struct FlowLegend: View {
    let items: [(String, Color)]

    var body: some View {
        HStack(spacing: 14) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 5) {
                    Circle().fill(item.1).frame(width: 9, height: 9)
                    Text(item.0).font(.caption).lineLimit(1)
                }
            }
        }
        .minimumScaleFactor(0.8)
    }
}
