import SwiftUI

struct ExtrasView: View {
    @EnvironmentObject private var store: ThemeStore
    @State private var showSlot = false
    @State private var showBJ = false
    @State private var showPlinko = false

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

                    Button {
                        Haptics.tap(.medium)
                        showBJ = true
                    } label: {
                        tile(icon: "suit.spade.fill", color: .indigo, title: "Blackjack",
                             subtitle: tr("Demó", "Demo"))
                    }
                    .buttonStyle(.plain)

                    Button {
                        Haptics.tap(.medium)
                        showPlinko = true
                    } label: {
                        tile(icon: "circle.grid.3x3.fill", color: .mint, title: "Plinko",
                             subtitle: tr("Demó", "Demo"))
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        RecapView()
                    } label: {
                        tile(icon: "chart.bar.doc.horizontal.fill", color: .teal,
                             title: tr("Visszatekintés", "Recap"),
                             subtitle: tr("Hónap és év", "Month & year"))
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        AchievementsView()
                    } label: {
                        tile(icon: "trophy.fill", color: .yellow, title: "Achievements",
                             subtitle: tr("Teljesítmények", "Trophies"))
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
        .fullScreenCover(isPresented: $showBJ) { BlackjackView() }
        .fullScreenCover(isPresented: $showPlinko) { PlinkoView() }
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
