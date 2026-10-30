import SwiftUI
import SwiftData
import UserNotifications

/// Vásárlási várólista: 24 órát várni kell, mielőtt döntesz.
@Model
final class WishItem {
    var uid: String = UUID().uuidString
    var name: String = ""
    var price: Double = 0
    var createdAt: Date = Date.now
    var statusRaw: String = "waiting"   // waiting, bought, skipped

    init(name: String, price: Double) {
        self.name = name
        self.price = price
    }

    var unlockDate: Date { createdAt.addingTimeInterval(24 * 3600) }
}

enum WishNotifier {
    static func schedule(uid: String, name: String, english: Bool) {
        let title = english ? "Still want it?" : "Még mindig kell?"
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = name
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 24 * 3600, repeats: false)
            center.add(UNNotificationRequest(identifier: "wish-" + uid, content: content, trigger: trigger))
        }
    }

    static func cancel(uid: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["wish-" + uid])
    }
}

func parseNumber(_ s: String) -> Double {
    let cleaned = s.replacingOccurrences(of: ",", with: ".").replacingOccurrences(of: " ", with: "")
    return Double(cleaned) ?? 0
}

struct WishlistView: View {
    @EnvironmentObject private var store: ThemeStore
    @Environment(\.modelContext) private var context
    @Query(sort: \WishItem.createdAt, order: .reverse) private var items: [WishItem]
    @State private var showAdd = false

    private var waiting: [WishItem] { items.filter { $0.statusRaw == "waiting" } }
    private var done: [WishItem] { items.filter { $0.statusRaw != "waiting" } }
    private var saved: Double {
        items.filter { $0.statusRaw == "skipped" }.reduce(0) { $0 + $1.price }
    }

    var body: some View {
        let tr = store.tr
        List {
            Section {
                HStack {
                    Label(tr("Megspóroltad", "Saved"), systemImage: "leaf.fill")
                        .foregroundStyle(.green)
                    Spacer()
                    Text(saved.ft).font(.title3.bold())
                }
                .padding(.vertical, 6)
                .listRowBackground(rowBackground)
            }

            if !waiting.isEmpty {
                Section(tr("Vár", "Waiting")) {
                    ForEach(waiting) { item in waitingRow(item, tr) }
                        .onDelete { delete(waiting, $0) }
                }
            }
            if !done.isEmpty {
                Section(tr("Döntöttél", "Decided")) {
                    ForEach(done) { item in doneRow(item) }
                        .onDelete { delete(done, $0) }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppBackground())
        .navigationTitle(tr("Várólista", "Wishlist"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Haptics.tap()
                    showAdd = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAdd) { WishAddView() }
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(.clear)
            .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }

    private func countdown(_ left: TimeInterval, _ tr: Tr) -> String {
        let h = Int(left / 3600)
        let m = Int(left / 60) % 60
        return tr("\(h) ó \(m) p", "\(h)h \(m)m")
    }

    private func waitingRow(_ item: WishItem, _ tr: Tr) -> some View {
        TimelineView(.periodic(from: .now, by: 30)) { ctx in
            let left = item.unlockDate.timeIntervalSince(ctx.date)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(item.name).lineLimit(2)
                    Spacer()
                    Text(item.price.ft).fontWeight(.semibold)
                }
                if left > 0 {
                    Label(countdown(left, tr), systemImage: "hourglass")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 10) {
                        Button {
                            decide(item, "skipped")
                        } label: {
                            Label(tr("Kihagyom", "Skip"), systemImage: "xmark")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        Button {
                            decide(item, "bought")
                        } label: {
                            Label(tr("Megveszem", "Buy"), systemImage: "bag.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(rowBackground)
    }

    private func doneRow(_ item: WishItem) -> some View {
        let skipped = item.statusRaw == "skipped"
        return HStack {
            Image(systemName: skipped ? "leaf.fill" : "bag.fill")
                .foregroundStyle(skipped ? Color.green : Color.secondary)
            Text(item.name).lineLimit(1)
            Spacer()
            Text(item.price.ft).foregroundStyle(.secondary)
        }
        .listRowBackground(rowBackground)
    }

    private func decide(_ item: WishItem, _ status: String) {
        Haptics.success()
        withAnimation(.snappy) { item.statusRaw = status }
    }

    private func delete(_ list: [WishItem], _ offsets: IndexSet) {
        Haptics.tap(.medium)
        withAnimation(.snappy) {
            for i in offsets {
                WishNotifier.cancel(uid: list[i].uid)
                context.delete(list[i])
            }
        }
    }
}

struct WishAddView: View {
    @EnvironmentObject private var store: ThemeStore
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var priceText = ""

    var body: some View {
        let tr = store.tr
        NavigationStack {
            Form {
                TextField(tr("Mit akarsz venni?", "What do you want?"), text: $name)
                TextField(tr("Ár", "Price"), text: $priceText)
                    .keyboardType(.decimalPad)
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle(tr("Új kívánság", "New wish"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Mégse", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("Mentés", "Save")) { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        let item = WishItem(name: name.trimmingCharacters(in: .whitespaces),
                            price: parseNumber(priceText))
        context.insert(item)
        WishNotifier.schedule(uid: item.uid, name: item.name, english: store.isEnglish)
        Haptics.success()
        dismiss()
    }
}
