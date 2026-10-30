import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Adatok

struct SnapEntry: TimelineEntry {
    let date: Date
    let spending: Double?
    let piggy: Double?
    let streak: Int?
    let budgetRemaining: Double?
    let budgetLimit: Double?
    let payday: Int
}

struct SnapProvider: TimelineProvider {
    static func read(_ date: Date) -> SnapEntry {
        SnapEntry(date: date,
                  spending: WidgetShared.get("spending"),
                  piggy: WidgetShared.get("piggy"),
                  streak: WidgetShared.get("streak").map { Int($0) },
                  budgetRemaining: WidgetShared.get("budgetRemaining"),
                  budgetLimit: WidgetShared.get("budgetLimit"),
                  payday: Int(WidgetShared.get("payday") ?? 28))
    }

    func placeholder(in context: Context) -> SnapEntry {
        SnapEntry(date: Date(), spending: 42_000, piggy: 120_000, streak: 7,
                  budgetRemaining: 8_000, budgetLimit: 20_000, payday: 28)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapEntry) -> Void) {
        completion(Self.read(Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapEntry>) -> Void) {
        let now = Date()
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now.addingTimeInterval(3600)
        completion(Timeline(entries: [Self.read(now)], policy: .after(next)))
    }
}

// MARK: - Segédek

func L(_ hu: String, _ en: String) -> String {
    Locale.current.language.languageCode?.identifier == "hu" ? hu : en
}

func compact(_ v: Double?) -> String {
    guard let v else { return "–" }
    return v.formatted(.number.notation(.compactName).precision(.significantDigits(1...3))
        .locale(Locale(identifier: "en_US")))
}

func money(_ v: Double?) -> String {
    guard let v else { return "–" }
    return v.formatted(.number.precision(.fractionLength(0))
        .locale(Locale(identifier: L("hu_HU", "en_US")))) + " Ft"
}

func daysUntilPayday(_ payday: Int) -> Int {
    let cal = Calendar.current
    let today = cal.startOfDay(for: Date())
    func target(_ offset: Int) -> Date? {
        guard let base = cal.date(byAdding: .month, value: offset, to: today),
              let range = cal.range(of: .day, in: .month, for: base) else { return nil }
        var c = cal.dateComponents([.year, .month], from: base)
        c.day = min(payday, range.count)
        return cal.date(from: c)
    }
    if let t = target(0), t >= today {
        return cal.dateComponents([.day], from: today, to: t).day ?? 0
    }
    if let t = target(1) {
        return cal.dateComponents([.day], from: today, to: t).day ?? 0
    }
    return 0
}

// MARK: - Gyors hozzáadás (+ / −)

struct QuickAddView: View {
    @Environment(\.widgetFamily) private var family

    private var accessory: Bool { family == .accessoryRectangular }

    private func quick(_ icon: String, _ kind: String, _ tint: Color) -> some View {
        Button(intent: AddMoneyIntent(kind: kind)) {
            ZStack {
                RoundedRectangle(cornerRadius: accessory ? 10 : 22, style: .continuous)
                    .fill(accessory ? Color.white.opacity(0.25) : tint.opacity(0.9))
                Image(systemName: icon)
                    .font(.system(size: accessory ? 22 : 34, weight: .bold))
                    .foregroundStyle(accessory ? Color.white : Color.white)
            }
        }
        .buttonStyle(.plain)
    }

    var body: some View {
        HStack(spacing: accessory ? 6 : 12) {
            quick("minus", "expense", .red)
            quick("plus", "income", .green)
        }
    }
}

struct QuickAddWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PocketQuickAdd", provider: SnapProvider()) { _ in
            QuickAddView().containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(L("Gyors hozzáadás", "Quick add"))
        .description(L("+ és − gomb egymás mellett.", "Plus and minus side by side."))
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

// MARK: - Fizetésnap

struct PaydayView: View {
    @Environment(\.widgetFamily) private var family
    let e: SnapEntry

    var body: some View {
        let d = daysUntilPayday(e.payday)
        switch family {
        case .accessoryCircular:
            Gauge(value: Double(min(d, 31)), in: 0...31) {
                Text(L("nap", "day"))
            } currentValueLabel: {
                Text("\(d)")
            }
            .gaugeStyle(.accessoryCircularCapacity)
        case .accessoryInline:
            Label(d == 0 ? L("Ma fizetésnap!", "Payday today!")
                         : L("\(d) nap a fizetésig", "\(d) days to payday"),
                  systemImage: "calendar")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(L("Fizetésig", "To payday")).font(.caption2).foregroundStyle(.secondary)
                Text(d == 0 ? "🎉" : L("\(d) nap", "\(d) days")).font(.title2.bold())
                if let s = e.spending, d > 0 {
                    Text(L("Naponta: \(compact(max(s, 0) / Double(d)))", "Per day: \(compact(max(s, 0) / Double(d)))"))
                        .font(.caption2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            VStack(spacing: 4) {
                Image(systemName: "calendar.badge.clock").font(.title).foregroundStyle(.green)
                Text(d == 0 ? "🎉" : "\(d)").font(.system(size: 44, weight: .heavy, design: .rounded))
                Text(L("nap a fizetésig", "days to payday")).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct PaydayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PocketPayday", provider: SnapProvider()) { e in
            PaydayView(e: e).containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(L("Fizetésnap", "Payday"))
        .description(L("Hány nap van a fizetésig.", "Days until payday."))
        .supportedFamilies([.accessoryCircular, .accessoryInline, .accessoryRectangular, .systemSmall])
    }
}

// MARK: - Költőpénz

struct SpendingView: View {
    @Environment(\.widgetFamily) private var family
    let e: SnapEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: "creditcard.fill").font(.caption)
                    Text(compact(e.spending)).font(.system(size: 15, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.6)
                }
            }
        case .accessoryInline:
            Label(L("Költő: \(compact(e.spending))", "Spend: \(compact(e.spending))"),
                  systemImage: "creditcard.fill")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(L("Költőpénz", "Spending money")).font(.caption2).foregroundStyle(.secondary)
                Text(money(e.spending)).font(.title3.bold()).minimumScaleFactor(0.6).lineLimit(1)
                Text("Piggy: \(money(e.piggy))").font(.caption2).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            VStack(alignment: .leading, spacing: 6) {
                Label(L("Költőpénz", "Spending"), systemImage: "creditcard.fill")
                    .font(.caption).foregroundStyle(.secondary)
                Text(money(e.spending)).font(.title2.bold()).minimumScaleFactor(0.5).lineLimit(1)
                Text("Piggy: \(money(e.piggy))").font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct SpendingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PocketSpending", provider: SnapProvider()) { e in
            SpendingView(e: e).containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(L("Költőpénz", "Spending money"))
        .description(L("Mennyi a költőpénzed.", "Your spending money."))
        .supportedFamilies([.accessoryCircular, .accessoryInline, .accessoryRectangular, .systemSmall])
    }
}

// MARK: - Streak

struct StreakWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let e: SnapEntry

    var body: some View {
        let n = e.streak ?? 0
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: "flame.fill").font(.caption)
                    Text("\(n)").font(.system(size: 20, weight: .heavy, design: .rounded))
                }
            }
        case .accessoryInline:
            Label(L("\(n) napos sorozat", "\(n) day streak"), systemImage: "flame.fill")
        case .accessoryRectangular:
            HStack(spacing: 8) {
                Image(systemName: "flame.fill").font(.title)
                VStack(alignment: .leading) {
                    Text("\(n)").font(.title.bold())
                    Text(L("napos sorozat", "day streak")).font(.caption2)
                }
                Spacer(minLength: 0)
            }
        default:
            VStack(spacing: 4) {
                Image(systemName: "flame.fill").font(.largeTitle).foregroundStyle(.orange)
                Text("\(n)").font(.system(size: 46, weight: .heavy, design: .rounded))
                Text(L("napos sorozat", "day streak")).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct StreakWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PocketStreak", provider: SnapProvider()) { e in
            StreakWidgetView(e: e).containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Streak")
        .description(L("A napi sorozatod.", "Your daily streak."))
        .supportedFamilies([.accessoryCircular, .accessoryInline, .accessoryRectangular, .systemSmall])
    }
}

// MARK: - Piggy Bank

struct PiggyView: View {
    @Environment(\.widgetFamily) private var family
    let e: SnapEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: "banknote.fill").font(.caption)
                    Text(compact(e.piggy)).font(.system(size: 15, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.6)
                }
            }
        case .accessoryInline:
            Label("Piggy: \(compact(e.piggy))", systemImage: "banknote.fill")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("Piggy Bank").font(.caption2).foregroundStyle(.secondary)
                Text(money(e.piggy)).font(.title3.bold()).minimumScaleFactor(0.6).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            VStack(alignment: .leading, spacing: 6) {
                Label("Piggy Bank", systemImage: "banknote.fill").font(.caption).foregroundStyle(.secondary)
                Text(money(e.piggy)).font(.title2.bold()).minimumScaleFactor(0.5).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct PiggyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PocketPiggy", provider: SnapProvider()) { e in
            PiggyView(e: e).containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Piggy Bank")
        .description(L("A Piggy Bank egyenleged.", "Your Piggy Bank balance."))
        .supportedFamilies([.accessoryCircular, .accessoryInline, .accessoryRectangular, .systemSmall])
    }
}

// MARK: - Költési keret

struct LimitView: View {
    @Environment(\.widgetFamily) private var family
    let e: SnapEntry

    var body: some View {
        let limit = max(e.budgetLimit ?? 0, 1)
        let rem = e.budgetRemaining ?? 0
        let frac = min(max(rem / limit, 0), 1)
        switch family {
        case .accessoryCircular:
            Gauge(value: frac) {
                Text("")
            } currentValueLabel: {
                Text(compact(e.budgetRemaining)).font(.system(size: 12, weight: .bold))
            }
            .gaugeStyle(.accessoryCircularCapacity)
        case .accessoryInline:
            Label(L("Keret: \(compact(e.budgetRemaining))", "Budget: \(compact(e.budgetRemaining))"),
                  systemImage: "gauge.with.dots.needle.67percent")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 3) {
                Text(L("Költési keret", "Spending budget")).font(.caption2).foregroundStyle(.secondary)
                Text(money(e.budgetRemaining)).font(.title3.bold()).minimumScaleFactor(0.6).lineLimit(1)
                ProgressView(value: frac)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            VStack(alignment: .leading, spacing: 6) {
                Label(L("Költési keret", "Budget"), systemImage: "gauge.with.dots.needle.67percent")
                    .font(.caption).foregroundStyle(.secondary)
                Text(money(e.budgetRemaining)).font(.title2.bold()).minimumScaleFactor(0.5).lineLimit(1)
                ProgressView(value: frac).tint(.green)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct LimitWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PocketLimit", provider: SnapProvider()) { e in
            LimitView(e: e).containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(L("Költési keret", "Spending budget"))
        .description(L("Mennyi maradt a napi/heti keretből.", "What is left of your budget."))
        .supportedFamilies([.accessoryCircular, .accessoryInline, .accessoryRectangular, .systemSmall])
    }
}

// MARK: - Áttekintés (nagy)

struct OverviewWidgetView: View {
    let e: SnapEntry

    private func block(_ icon: String, _ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon).foregroundStyle(color)
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline).minimumScaleFactor(0.5).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var body: some View {
        let d = daysUntilPayday(e.payday)
        HStack(spacing: 12) {
            block("creditcard.fill", L("Költő", "Spending"), money(e.spending), .orange)
            block("banknote.fill", "Piggy", money(e.piggy), .blue)
            block("calendar", L("Fizetésig", "Payday"), L("\(d) nap", "\(d) d"), .green)
            block("flame.fill", "Streak", "\(e.streak ?? 0)", .red)
        }
    }
}

struct OverviewWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PocketOverview", provider: SnapProvider()) { e in
            OverviewWidgetView(e: e).containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(L("Áttekintés", "Overview"))
        .description(L("Minden fontos szám egy helyen.", "Key numbers at a glance."))
        .supportedFamilies([.systemMedium])
    }
}

@main
struct PocketWidgets: WidgetBundle {
    var body: some Widget {
        QuickAddWidget()
        PaydayWidget()
        SpendingWidget()
        StreakWidget()
        PiggyWidget()
        LimitWidget()
        OverviewWidget()
    }
}
