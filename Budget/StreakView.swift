import SwiftUI
import SwiftData

/// Streak: egymást követő napok, amikor naplóztál (bármilyen tétel), vagy jelölted, hogy nem költöttél.
enum StreakCalc {
    static func key(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: d)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }

    static func days(entries: [Entry], noSpend: String) -> Set<String> {
        var set = Set<String>()
        for e in entries where e.categoryID != "piggy" {
            set.insert(key(e.createdAt))
            if !e.isRecurring { set.insert(key(e.date)) }
        }
        for k in noSpend.split(separator: ",") { set.insert(String(k)) }
        return set
    }

    /// A mai nap még nem szakítja meg a sorozatot, csak ha a nap végéig nincs naplózás.
    static func current(_ days: Set<String>) -> Int {
        let cal = Calendar.current
        var d = Date()
        if !days.contains(key(d)) {
            d = cal.date(byAdding: .day, value: -1, to: d) ?? d
        }
        var n = 0
        while days.contains(key(d)) {
            n += 1
            d = cal.date(byAdding: .day, value: -1, to: d) ?? d
            if n > 3650 { break }
        }
        return n
    }
}

struct StreakBadge: View {
    let count: Int

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "flame.fill")
                .foregroundStyle(count > 0 ? Color.orange : Color.secondary)
            Text("\(count)")
                .font(.subheadline.weight(.bold))
                .contentTransition(.numericText(value: Double(count)))
        }
    }
}

struct StreakSheet: View {
    @EnvironmentObject private var store: ThemeStore
    @Environment(\.dismiss) private var dismiss
    @Query private var entries: [Entry]
    @AppStorage("streakNoSpend") private var noSpend = ""

    var body: some View {
        let tr = store.tr
        let days = StreakCalc.days(entries: entries, noSpend: noSpend)
        let count = StreakCalc.current(days)
        let todayDone = days.contains(StreakCalc.key(Date()))
        let cal = Calendar.current
        let last: [Date] = (0..<14).reversed().compactMap { cal.date(byAdding: .day, value: -$0, to: Date()) }
        NavigationStack {
            VStack(spacing: 22) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 76))
                    .foregroundStyle(count > 0 ? Color.orange : Color.secondary)
                    .symbolEffect(.pulse, isActive: count > 0)
                Text("\(count)")
                    .font(.system(size: 64, weight: .heavy, design: .rounded))
                    .contentTransition(.numericText(value: Double(count)))
                Text(tr("napos sorozat", "day streak"))
                    .font(.headline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    ForEach(last, id: \.self) { d in
                        let done = days.contains(StreakCalc.key(d))
                        Circle()
                            .fill(done ? Color.orange : Color.white.opacity(0.15))
                            .frame(width: 18, height: 18)
                    }
                }

                Button {
                    Haptics.success()
                    noSpend += (noSpend.isEmpty ? "" : ",") + StreakCalc.key(Date())
                } label: {
                    Label(tr("Ma nem költöttem", "No spending today"), systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(todayDone)

                Text(todayDone ? tr("Mára kész ✅", "Done for today ✅")
                               : tr("Írj be egy tételt, vagy nyomd meg a gombot", "Log an item, or tap the button"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(AppBackground())
            .navigationTitle("Streak")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("Kész", "Done")) { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}
