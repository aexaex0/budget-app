import SwiftUI
import SwiftData

struct CategoriesView: View {
    @EnvironmentObject private var store: ThemeStore
    @Environment(\.modelContext) private var context
    @Query(sort: \Category.createdAt) private var categories: [Category]
    @Query private var entries: [Entry]
    @State private var editing: Category?
    @State private var adding = false

    private func spent(_ c: Category) -> Double {
        entries
            .filter { $0.kind == .expense && $0.categoryID == c.id && $0.counts(in: .now) }
            .reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        let tr = store.tr
        List {
            Section {
                ForEach(categories) { c in
                    Button {
                        Haptics.tap()
                        editing = c
                    } label: {
                        row(c, tr)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.clear)
                            .glassEffect(.regular, in: .rect(cornerRadius: 20))
                            .padding(.vertical, 3)
                            .padding(.horizontal, 16)
                    )
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 10, leading: 18, bottom: 10, trailing: 18))
                }
                .onDelete { offsets in
                    Haptics.tap(.medium)
                    for i in offsets { context.delete(categories[i]) }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AppBackground())
        .navigationTitle(tr("Kategóriák", "Categories"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(tr("Új", "New"), systemImage: "plus") {
                    Haptics.tap()
                    adding = true
                }
            }
        }
        .overlay {
            if categories.isEmpty {
                ContentUnavailableView(tr("Nincs kategória", "No categories"),
                                       systemImage: "tag.fill")
            }
        }
        .sheet(isPresented: $adding) { CategoryEditor(category: nil) }
        .sheet(item: $editing) { CategoryEditor(category: $0) }
    }

    private func row(_ c: Category, _ tr: Tr) -> some View {
        let used = spent(c)
        return HStack(spacing: 12) {
            Image(systemName: c.symbol)
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(c.color, in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(c.name).lineLimit(1)
                if c.monthlyLimit > 0 {
                    Text(c.monthlyLimit.ft)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            Text(used.ft)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(c.monthlyLimit > 0 && used > c.monthlyLimit ? Color.red : Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

struct CategoryEditor: View {
    let category: Category?

    @EnvironmentObject private var store: ThemeStore
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var symbol = "tag.fill"
    @State private var color = Color(red: 0.35, green: 0.55, blue: 0.95)
    @State private var limit: Double?

    private let columns = [GridItem(.adaptive(minimum: 48), spacing: 10)]

    var body: some View {
        let tr = store.tr
        NavigationStack {
            Form {
                Section {
                    TextField(tr("Név", "Name"), text: $name)
                    ColorPicker(tr("Szín", "Color"), selection: $color, supportsOpacity: false)
                }
                Section {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(CategorySeed.symbols, id: \.self) { s in
                            Button {
                                symbol = s
                                Haptics.tap(.soft)
                            } label: {
                                Image(systemName: s)
                                    .font(.title3)
                                    .frame(width: 44, height: 44)
                                    .foregroundStyle(symbol == s ? Color.white : Color.primary)
                                    .background(symbol == s ? color : Color.clear, in: .circle)
                                    .overlay(Circle().strokeBorder(Color.secondary.opacity(0.3)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section {
                    TextField(tr("Havi limit (Ft)", "Monthly limit (Ft)"),
                              value: $limit, format: .number)
                        .keyboardType(.decimalPad)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle(category == nil ? tr("Új kategória", "New category") : tr("Szerkesztés", "Edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Mégse", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("Mentés", "Save"), action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                guard let c = category else { return }
                name = c.name
                symbol = c.symbol
                color = c.color
                limit = c.monthlyLimit > 0 ? c.monthlyLimit : nil
            }
        }
        .presentationDetents([.large])
    }

    private func save() {
        let clean = name.trimmingCharacters(in: .whitespaces)
        let rgba = RGBA(color: color)
        if let c = category {
            c.name = clean
            c.symbol = symbol
            c.r = rgba.r
            c.g = rgba.g
            c.b = rgba.b
            c.monthlyLimit = limit ?? 0
        } else {
            context.insert(Category(name: clean, symbol: symbol, color: rgba, monthlyLimit: limit ?? 0))
        }
        Haptics.success()
        dismiss()
    }
}
