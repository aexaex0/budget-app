import SwiftUI
import SwiftData

/// Napi challenge: ha nem sikerül, 1000 Ft megy a Piggy Bankba.
enum ChallengeList {
    static let penalty = 1000.0

    static let items: [(String, String)] = [
        ("Egy napig csak vizet igyál", "Go one day drinking only water"),
        ("Egy napig ne káromkodj", "Go one day without swearing"),
        ("Ma ne rendelj kaját", "Don't order food today"),
        ("Ma ne vegyél kávét kint", "Don't buy coffee out today"),
        ("Ma ne költs semmire", "Spend nothing today"),
        ("Ma ne igyál üdítőt", "No soft drinks today"),
        ("Ma ne edd meg a nasit", "No snacks today"),
        ("Egy napig ne nézz közösségi médiát", "Stay off social media for a day"),
        ("Ma ne vegyél semmit impulzusból", "No impulse buys today"),
        ("Ma menj gyalog, ne használj tömegközlekedést", "Walk everywhere today, no transit"),
        ("Ma főzz otthon mindent", "Cook everything at home today"),
        ("Egy napig ne panaszkodj", "Go one day without complaining"),
        ("Ma ne rendelj semmit online", "Order nothing online today"),
        ("Ma ne igyál alkoholt", "No alcohol today"),
        ("Ma vidd magaddal az ebédet", "Bring your own lunch today"),
        ("Ma ne nézz streaminget", "No streaming today"),
        ("Ma ne használd a telefonod 22 óra után", "No phone after 10 pm today"),
        ("Ma csak csapvizet igyál, még kávét sem", "Only tap water today, not even coffee"),
        ("Ma ne vegyél energiaitalt", "No energy drinks today"),
        ("Egy napig ne késs el sehonnan", "Don't be late to anything today"),
    ]

    static func index(for date: Date, shift: Int) -> Int {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        let year = Calendar.current.component(.year, from: date)
        return ((day * 7 + year + shift) % items.count + items.count) % items.count
    }
}

struct ChallengeCard: View {
    @EnvironmentObject private var store: ThemeStore
    @Environment(\.modelContext) private var context
    @Query private var entries: [Entry]
    @AppStorage("challengeLog") private var log = ""
    @AppStorage("challengeShift") private var shiftRaw = ""

    private var todayKey: String { StreakCalc.key(Date()) }

    private var result: Int? {
        for part in log.split(separator: ",") {
            let kv = part.split(separator: "=")
            if kv.count == 2, String(kv[0]) == todayKey { return Int(kv[1]) }
        }
        return nil
    }

    private var shift: Int {
        let kv = shiftRaw.split(separator: "=")
        if kv.count == 2, String(kv[0]) == todayKey { return Int(kv[1]) ?? 0 }
        return 0
    }

    private var wins: Int {
        log.split(separator: ",").filter { $0.hasSuffix("=1") }.count
    }

    private func record(_ ok: Bool) {
        log += (log.isEmpty ? "" : ",") + "\(todayKey)=\(ok ? 1 : 0)"
        if ok {
            Haptics.success()
        } else {
            deposit()
            Haptics.tap(.heavy)
        }
    }

    private func deposit() {
        let amt = ChallengeList.penalty
        let goals = entries.filter { $0.kind == .saving && $0.targetAmount > 0 && $0.categoryID != "piggy" }
        if let g = goals.first {
            g.savedSoFar += amt
        } else {
            context.insert(Entry(name: "Piggy Bank", amount: 0, kind: .saving,
                                 targetAmount: 0, savedSoFar: amt))
        }
        context.insert(Entry(name: "Challenge", amount: amt, kind: .saving,
                             isRecurring: false, date: .now, categoryID: "piggy"))
    }

    private func reroll() {
        Haptics.tap(.soft)
        shiftRaw = "\(todayKey)=\(shift + 1)"
    }

    var body: some View {
        let tr = store.tr
        let item = ChallengeList.items[ChallengeList.index(for: Date(), shift: shift)]
        let text = tr(item.0, item.1)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(tr("Napi challenge", "Daily challenge"), systemImage: "flag.checkered")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(tr("Sikerült: \(wins)", "Won: \(wins)"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(text)
                .font(.title3.weight(.bold))
                .frame(maxWidth: .infinity, alignment: .leading)
            footer(tr)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(24)
    }

    @ViewBuilder
    private func footer(_ tr: Tr) -> some View {
        if let r = result {
            if r == 1 {
                Label(tr("Teljesítve, szép munka!", "Done, nice work!"), systemImage: "checkmark.circle.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.green)
            } else {
                Label(tr("Nem ment, \(ChallengeList.penalty.ft) a Piggy Bankba került",
                         "Failed, \(ChallengeList.penalty.ft) went to the Piggy Bank"),
                      systemImage: "xmark.circle.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.orange)
            }
        } else {
            HStack(spacing: 10) {
                Button { record(true) } label: {
                    Text(tr("Sikerült", "Done"))
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                Button { record(false) } label: {
                    Text(tr("Nem ment (+\(ChallengeList.penalty.ft))", "Failed (+\(ChallengeList.penalty.ft))"))
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                Button { reroll() } label: {
                    Image(systemName: "shuffle")
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
            }
        }
    }
}
