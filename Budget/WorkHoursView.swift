import SwiftUI
import SwiftData

/// Hány munkaórába kerül ez? Egy ár átváltása a saját órabéredre.
struct WorkHoursView: View {
    @EnvironmentObject private var store: ThemeStore
    @Query private var entries: [Entry]
    @AppStorage("hourlyWage") private var wage: Double = 0
    @State private var wageText = ""
    @State private var priceText = ""

    private var monthlyIncome: Double {
        entries.filter { $0.kind == .income && $0.counts(in: .now) }.reduce(0) { $0 + $1.amount }
    }

    private var price: Double { parseNumber(priceText) }
    private var hours: Double { wage > 0 ? price / wage : 0 }

    var body: some View {
        let tr = store.tr
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Label(tr("Órabér", "Hourly wage"), systemImage: "clock.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                    TextField("0", text: $wageText)
                        .keyboardType(.decimalPad)
                        .font(.title2.bold())
                        .onChange(of: wageText) { _, v in wage = parseNumber(v) }
                    if monthlyIncome > 0 {
                        Button {
                            Haptics.tap()
                            let w = (monthlyIncome / 160).rounded()
                            wageText = String(Int(w))
                            wage = w
                        } label: {
                            Label(tr("Bevételemből", "From my income"), systemImage: "wand.and.stars")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular, in: .rect(cornerRadius: 24))

                VStack(alignment: .leading, spacing: 10) {
                    Label(tr("Ár", "Price"), systemImage: "tag.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                    TextField("0", text: $priceText)
                        .keyboardType(.decimalPad)
                        .font(.title2.bold())
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular, in: .rect(cornerRadius: 24))

                if hours > 0 {
                    resultCard(tr)
                }
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppBackground())
        .navigationTitle(tr("Hány munkaóra?", "Work hours"))
        .onAppear {
            if wage > 0 && wageText.isEmpty { wageText = String(Int(wage)) }
        }
    }

    private func resultCard(_ tr: Tr) -> some View {
        let days = hours / 8
        let hText = hours.formatted(.number.precision(.fractionLength(1)))
        let dText = days.formatted(.number.precision(.fractionLength(1)))
        return VStack(spacing: 6) {
            Text(tr("\(hText) óra", "\(hText) hours"))
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .contentTransition(.numericText(value: hours))
            Text(tr("\(dText) munkanap", "\(dText) work days"))
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
        .animation(.snappy, value: hours)
    }
}
