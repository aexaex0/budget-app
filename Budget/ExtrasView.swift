import SwiftUI

struct ExtrasView: View {
    @EnvironmentObject private var store: ThemeStore
    @State private var showSlot = false

    var body: some View {
        let tr = store.tr
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Button {
                        Haptics.tap(.medium)
                        showSlot = true
                    } label: {
                        tile(icon: "die.face.5.fill", color: .pink, title: "Slot",
                             subtitle: tr("Demó", "Demo"))
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        WishlistView()
                    } label: {
                        tile(icon: "hourglass", color: .orange, title: tr("Várólista", "Wishlist"),
                             subtitle: "24h")
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        WorkHoursView()
                    } label: {
                        tile(icon: "clock.fill", color: .blue, title: tr("Hány munkaóra?", "Work hours"),
                             subtitle: tr("Ár → óra", "Price → hours"))
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        SplitView()
                    } label: {
                        tile(icon: "person.2.fill", color: .green,
                             title: tr("Ki mennyivel tartozik", "Split bill"),
                             subtitle: tr("Felosztás", "Split"))
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
            }
            .background(AppBackground())
            .navigationTitle(tr("Extrák", "Extras"))
        }
        .fullScreenCover(isPresented: $showSlot) { SlotGameView() }
    }

    private func tile(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 52, height: 52)
                .background(color.opacity(0.18), in: .rect(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
    }
}

/// Pénz fül: a négy lista egy helyen, felül váltóval.
struct MoneyView: View {
    @EnvironmentObject private var store: ThemeStore
    @State private var kind: EntryKind = .income

    private func label(_ k: EntryKind, _ tr: Tr) -> String {
        switch k {
        case .income: return tr("Bevétel", "Income")
        case .expense: return tr("Kiadás", "Expenses")
        case .subscription: return tr("Előfiz.", "Subs")
        case .saving: return tr("Mentés", "Savings")
        }
    }

    var body: some View {
        let tr = store.tr
        NavigationStack {
            EntryListView(kind: kind)
                .id(kind)
                .safeAreaInset(edge: .top, spacing: 0) {
                    Picker("", selection: $kind) {
                        ForEach(EntryKind.allCases) { k in
                            Text(label(k, tr)).tag(k)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .onChange(of: kind) { _, _ in Haptics.tap(.soft) }
                }
        }
    }
}
