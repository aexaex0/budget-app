import SwiftUI

struct ThemeSettingsView: View {
    @EnvironmentObject private var store: ThemeStore
    @Environment(\.dismiss) private var dismiss

    private let gridColumns = [GridItem(.adaptive(minimum: 100), spacing: 10)]

    var body: some View {
        let tr = store.tr
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    preview(tr)

                    section(tr("Megjelenés", "Appearance")) {
                        Picker("", selection: $store.appearance) {
                            Text(tr("Rendszer", "System")).tag(AppearanceMode.system)
                            Text(tr("Világos", "Light")).tag(AppearanceMode.light)
                            Text(tr("Sötét", "Dark")).tag(AppearanceMode.dark)
                        }
                        .pickerStyle(.segmented)
                    }

                    section(tr("Nyelv", "Language")) {
                        Picker("", selection: $store.language) {
                            Text(tr("Rendszer", "System")).tag(AppLanguage.system)
                            Text("Magyar").tag(AppLanguage.hu)
                            Text("English").tag(AppLanguage.en)
                        }
                        .pickerStyle(.segmented)
                    }

                    section(tr("Fülváltás animáció", "Tab animation")) {
                        TabAnimPicker()
                    }

                    section(tr("Ikon", "App icon")) {
                        AppIconPicker()
                    }

                    NavigationLink {
                        CategoriesView()
                    } label: {
                        HStack {
                            Label(tr("Kategóriák és limitek", "Categories & limits"), systemImage: "tag.fill")
                            Spacer()
                            Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.secondary)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .glassEffect(.regular, in: .rect(cornerRadius: 24))
                    }
                    .buttonStyle(.plain)

                    section(tr("Biztonság", "Security")) {
                        Toggle(tr("Zárolás Face ID-val", "Lock with Face ID"), isOn: $store.lockEnabled)
                    }

                    section(tr("Értesítések", "Notifications")) {
                        Toggle(tr("Előfizetés emlékeztető", "Subscription reminders"), isOn: $store.subReminders)
                        if store.subReminders {
                            Stepper(value: $store.reminderDays, in: 0...7) {
                                Text(tr("\(store.reminderDays) nappal előtte", "\(store.reminderDays) days before"))
                            }
                        }
                        Toggle(tr("Havi összegzés kész", "Monthly report ready"), isOn: $store.monthlyReport)
                    }

                    section(tr("Kész témák", "Preset themes")) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(AppTheme.presets) { p in presetButton(p, tr) }
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    section(tr("Színek keverése", "Mix colors")) {
                        ForEach(store.theme.colors.indices, id: \.self) { i in
                            ColorPicker(tr("Szín \(i + 1)", "Color \(i + 1)"),
                                        selection: colorBinding(i), supportsOpacity: false)
                        }
                        HStack(spacing: 10) {
                            Button {
                                edit { $0.colors.append($0.colors.last ?? RGBA(0.5, 0.5, 0.9)) }
                            } label: {
                                Label(tr("Szín hozzáadása", "Add color"), systemImage: "plus")
                            }
                            .disabled(store.theme.colors.count >= 4)

                            Button {
                                edit { if $0.colors.count > 2 { $0.colors.removeLast() } }
                            } label: {
                                Label(tr("Utolsó törlése", "Remove last"), systemImage: "minus")
                            }
                            .disabled(store.theme.colors.count <= 2)
                        }
                        .buttonStyle(.glass)
                        .font(.footnote)

                        ColorPicker(tr("Kiemelő szín", "Accent color"),
                                    selection: accentBinding, supportsOpacity: false)
                    }

                    section(tr("Átmenet iránya", "Gradient direction")) {
                        LazyVGrid(columns: gridColumns, spacing: 10) {
                            ForEach(GradientStyle.allCases) { s in styleButton(s, tr) }
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(tr("Erősség", "Intensity")).font(.footnote).foregroundStyle(.secondary)
                            Slider(value: Binding(
                                get: { store.theme.intensity },
                                set: { v in edit { $0.intensity = v } }
                            ), in: 0.3...1.0)
                        }
                    }

                    section(tr("Effektek", "Effects")) {
                        Toggle(tr("Animált háttér", "Animated background"), isOn: $store.theme.animated)
                        Toggle(tr("Lebegő fények", "Floating glow"), isOn: $store.theme.orbs)
                        Toggle(tr("Rezgés visszajelzés", "Haptic feedback"), isOn: $store.haptics)
                    }
                }
                .padding()
            }
            .background(AppBackground())
            .navigationTitle(tr("Beállítások", "Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("Kész", "Done")) { dismiss() }
                }
            }
        }
    }

    // MARK: Részek

    private func preview(_ tr: Tr) -> some View {
        let t = store.theme
        return ZStack(alignment: .bottomLeading) {
            GradientBackdrop(colors: t.colors.map(\.color), style: t.style)
            VStack(alignment: .leading, spacing: 2) {
                Text(t.name(tr)).font(.title3.bold())
                Text(t.style.title(tr)).font(.footnote)
            }
            .foregroundStyle(.white)
            .shadow(radius: 3)
            .padding(16)
        }
        .frame(height: 120)
        .clipShape(.rect(cornerRadius: 26))
        .animation(.smooth, value: store.theme)
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }

    private func presetButton(_ p: AppTheme, _ tr: Tr) -> some View {
        let selected = store.theme.id == p.id
        return Button {
            withAnimation(.smooth) { store.theme = p }
            Haptics.tap()
        } label: {
            VStack(spacing: 6) {
                GradientBackdrop(colors: p.colors.map(\.color), style: p.style)
                    .frame(width: 84, height: 104)
                    .clipShape(.rect(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(selected ? Color.primary : Color.clear, lineWidth: 3)
                    )
                Text(p.name(tr)).font(.caption).lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }

    private func styleButton(_ s: GradientStyle, _ tr: Tr) -> some View {
        let selected = store.theme.style == s
        return Button {
            withAnimation(.smooth) { edit { $0.style = s } }
            Haptics.tap()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: s.symbol).font(.title3)
                Text(s.title(tr))
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .lineLimit(2, reservesSpace: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
            .background(selected ? Color.accentColor.opacity(0.25) : Color.clear,
                        in: .rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(selected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Szerkesztés

    /// Egyedi témává alakítja a jelenlegit, és alkalmazza a módosítást.
    private func edit(_ change: (inout AppTheme) -> Void) {
        var t = store.theme
        change(&t)
        t.id = "custom"
        t.nameHu = "Egyedi"
        t.nameEn = "Custom"
        store.theme = t
    }

    private func colorBinding(_ i: Int) -> Binding<Color> {
        Binding(
            get: { i < store.theme.colors.count ? store.theme.colors[i].color : .clear },
            set: { c in edit { if i < $0.colors.count { $0.colors[i] = RGBA(color: c) } } }
        )
    }

    private var accentBinding: Binding<Color> {
        Binding(
            get: { store.theme.accent.color },
            set: { c in edit { $0.accent = RGBA(color: c) } }
        )
    }
}

struct TabAnimPicker: View {
    @EnvironmentObject private var store: ThemeStore
    @AppStorage("tabAnim") private var styleRaw = TabAnimStyle.fade.rawValue

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 8)]

    var body: some View {
        let tr = store.tr
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(TabAnimStyle.allCases) { s in
                let on = styleRaw == s.rawValue
                Button {
                    Haptics.tap(.soft)
                    styleRaw = s.rawValue
                } label: {
                    Text(s.title(tr))
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(on ? Color.white : Color.primary)
                        .background(on ? Color.accentColor : Color.secondary.opacity(0.15), in: .capsule)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
