import SwiftUI

/// Fizetésnap visszaszámláló. Alapból minden hónap 28-a.
struct PaydayCard: View {
    @EnvironmentObject private var store: ThemeStore
    @AppStorage("payday") private var payday = 28
    @State private var showEdit = false
    let spendingLeft: Double

    private var daysUntil: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        func target(in monthOffset: Int) -> Date? {
            guard let base = cal.date(byAdding: .month, value: monthOffset, to: today),
                  let range = cal.range(of: .day, in: .month, for: base) else { return nil }
            var comps = cal.dateComponents([.year, .month], from: base)
            comps.day = min(payday, range.count)
            return cal.date(from: comps)
        }
        if let t = target(in: 0), t >= today {
            return cal.dateComponents([.day], from: today, to: t).day ?? 0
        }
        if let t = target(in: 1) {
            return cal.dateComponents([.day], from: today, to: t).day ?? 0
        }
        return 0
    }

    var body: some View {
        let tr = store.tr
        let n = daysUntil
        let perDay = n > 0 ? max(spendingLeft, 0) / Double(n) : 0
        Button {
            Haptics.tap()
            showEdit = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "calendar.badge.clock")
                    .font(.title)
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 3) {
                    if n == 0 {
                        Text(tr("Ma fizetésnap! 🎉", "Payday today! 🎉")).font(.headline)
                    } else {
                        Text(tr("\(n) nap a fizetésig", "\(n) days to payday")).font(.headline)
                        Text(tr("Naponta jut: \(perDay.ft)", "Per day until then: \(perDay.ft)"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                Text("\(payday).")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(24)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showEdit) {
            NavigationStack {
                Form {
                    Stepper(value: $payday, in: 1...31) {
                        Text(tr("Fizetésnap: \(payday).", "Payday: day \(payday)"))
                    }
                }
                .scrollContentBackground(.hidden)
                .background(AppBackground())
                .navigationTitle(tr("Fizetésnap", "Payday"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(tr("Kész", "Done")) { showEdit = false }
                    }
                }
            }
            .presentationDetents([.height(220)])
        }
    }
}
