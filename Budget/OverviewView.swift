import SwiftUI
import SwiftData
import Charts

struct OverviewView: View {
    @Query private var entries: [Entry]

    private func total(_ kind: EntryKind) -> Double {
        entries.filter { $0.kind == kind }.reduce(0) { $0 + $1.amount }
    }

    private struct Slice: Identifiable {
        let id: String
        let value: Double
        let color: Color
    }

    var body: some View {
        let income = total(.income)
        let expenses = total(.expense)
        let subs = total(.subscription)
        let savings = total(.saving)
        let left = income - expenses - subs - savings
        let savingsRate = income > 0 ? savings / income : 0

        var slices: [Slice] = [
            Slice(id: "Kiadások", value: expenses, color: EntryKind.expense.color),
            Slice(id: "Előfizetések", value: subs, color: EntryKind.subscription.color),
            Slice(id: "Megtakarítás", value: savings, color: EntryKind.saving.color),
        ]
        if left > 0 { slices.append(Slice(id: "Marad", value: left, color: .green)) }
        slices = slices.filter { $0.value > 0 }

        return NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Fő kártya: mennyi marad
                    VStack(spacing: 6) {
                        Text("Havonta megmarad")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(left.ft)
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(left >= 0 ? Color.primary : Color.red)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                        if left < 0 {
                            Label("Többet költesz, mint amennyit keresel", systemImage: "exclamationmark.triangle.fill")
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(24)
                    .glassEffect(.regular, in: .rect(cornerRadius: 28))

                    // Fánk diagram
                    if !slices.isEmpty {
                        VStack(spacing: 12) {
                            Chart(slices) { s in
                                SectorMark(angle: .value("Összeg", s.value),
                                           innerRadius: .ratio(0.62),
                                           angularInset: 2)
                                .foregroundStyle(s.color)
                                .cornerRadius(6)
                            }
                            .frame(height: 200)

                            HStack(spacing: 14) {
                                ForEach(slices) { s in
                                    HStack(spacing: 5) {
                                        Circle().fill(s.color).frame(width: 9, height: 9)
                                        Text(s.id).font(.caption)
                                    }
                                }
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity)
                        .glassEffect(.regular, in: .rect(cornerRadius: 28))
                    }

                    // Részletek
                    VStack(spacing: 0) {
                        row(.income, income)
                        Divider()
                        row(.expense, expenses)
                        Divider()
                        row(.subscription, subs)
                        Divider()
                        row(.saving, savings)
                    }
                    .padding(.horizontal, 16)
                    .glassEffect(.regular, in: .rect(cornerRadius: 24))

                    // Kivetítés
                    GlassEffectContainer(spacing: 12) {
                        HStack(spacing: 12) {
                            statCard("Megtakarítási ráta",
                                     savingsRate.formatted(.percent.precision(.fractionLength(0))))
                            statCard("Éves félretett", (savings * 12).ft)
                        }
                        HStack(spacing: 12) {
                            statCard("Éves előfizetés", (subs * 12).ft)
                            statCard("Éves megmarad", (left * 12).ft)
                        }
                    }
                }
                .padding()
            }
            .background(AppBackground())
            .navigationTitle("Áttekintés")
        }
    }

    private func row(_ kind: EntryKind, _ value: Double) -> some View {
        HStack {
            Image(systemName: kind.icon)
                .foregroundStyle(kind.color)
                .frame(width: 28)
            Text(kind.plural)
            Spacer()
            Text(value.ft).fontWeight(.semibold)
        }
        .padding(.vertical, 12)
    }

    private func statCard(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }
}
