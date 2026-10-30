import SwiftUI
import UserNotifications
import UIKit

/// Munkaidő / kereset követő: valós idejű, az óraidőből számolt keresett összeg.
enum Earnings {
    static let neon = Color(red: 0, green: 1, blue: 102.0 / 255.0)

    struct Shift {
        let start: Date
        let end: Date
        var seconds: Double { end.timeIntervalSince(start) }
    }

    /// Az aktuális (vagy következő) műszak. Ha a vége <= kezdés, átnyúlik másnapra.
    static func shift(startMin: Int, endMin: Int, now: Date) -> Shift {
        let cal = Calendar.current
        let day = cal.startOfDay(for: now)
        func make(_ base: Date) -> Shift {
            let s = cal.date(byAdding: .minute, value: startMin, to: base) ?? base
            var e = cal.date(byAdding: .minute, value: endMin, to: base) ?? base
            if e <= s { e = cal.date(byAdding: .day, value: 1, to: e) ?? e }
            return Shift(start: s, end: e)
        }
        let yesterday = make(cal.date(byAdding: .day, value: -1, to: day) ?? day)
        if now >= yesterday.start && now < yesterday.end { return yesterday }
        return make(day)
    }

    static func progress(_ s: Shift, now: Date) -> Double {
        guard s.seconds > 0 else { return 0 }
        return min(max(now.timeIntervalSince(s.start) / s.seconds, 0), 1)
    }

    static func money(_ v: Double) -> String {
        v.formatted(.number.precision(.fractionLength(2)).locale(Locale(identifier: "hu_HU"))) + " Ft"
    }

    static func percent(_ p: Double) -> String {
        (p * 100).formatted(.number.precision(.fractionLength(2)).locale(Locale(identifier: "hu_HU"))) + "%"
    }

    static func remaining(_ sec: Double) -> String {
        let t = max(Int(sec.rounded(.up)), 0)
        return "\(t / 3600) ó \((t % 3600) / 60) p \(t % 60) mp"
    }

    /// Háttérben: előre kiszámolt helyi értesítések az aktuális összeggel.
    static func scheduleNotifications(shift s: Shift, wage: Double, english: Bool) async {
        let center = UNUserNotificationCenter.current()
        let ids = (0..<24).map { "shift-\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional else { return }

        let now = Date()
        guard now < s.end else { return }
        let total = s.seconds / 3600 * wage
        let from = max(now, s.start)
        let remain = s.end.timeIntervalSince(from)
        let step = max(600, (remain / 23 / 60).rounded(.up) * 60)
        var times: [Date] = []
        var t = from.addingTimeInterval(step)
        while t < s.end && times.count < 23 {
            times.append(t)
            t = t.addingTimeInterval(step)
        }
        times.append(s.end)

        for (i, when) in times.enumerated() {
            let p = progress(s, now: when)
            let content = UNMutableNotificationContent()
            if i == times.count - 1 {
                content.title = english ? "Done! 🎉" : "Vége! 🎉"
                content.body = money(total)
            } else {
                content.title = money(p * total)
                content.body = percent(p) + (english ? " of the shift" : " a műszakból")
            }
            content.sound = i == times.count - 1 ? .default : nil
            let interval = max(when.timeIntervalSince(now), 1)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: "shift-\(i)", content: content, trigger: trigger))
        }
    }

    static func cancelNotifications() {
        let ids = (0..<24).map { "shift-\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }
}

struct EarningsView: View {
    @EnvironmentObject private var store: ThemeStore
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("earnWage") private var wage: Double = 0
    @AppStorage("earnStart") private var startMin: Int = 600
    @AppStorage("earnEnd") private var endMin: Int = 1080
    @AppStorage("earnRunning") private var running = false
    @State private var wageText = ""

    var body: some View {
        let tr = store.tr
        Group {
            if running {
                liveView(tr)
            } else {
                setupView(tr)
            }
        }
        .background(NeonBackdrop())
        .navigationTitle(tr("Kereset követő", "Earnings tracker"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .preferredColorScheme(.dark)
        .onAppear {
            if wage > 0 && wageText.isEmpty { wageText = String(Int(wage)) }
            applyKeepAwake()
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .onChange(of: running) { _, _ in applyKeepAwake() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { applyKeepAwake() }
        }
    }

    private func applyKeepAwake() {
        UIApplication.shared.isIdleTimerDisabled = running
    }

    // MARK: Beállítás

    private func timeBinding(_ get: @escaping () -> Int, _ set: @escaping (Int) -> Void) -> Binding<Date> {
        Binding<Date>(
            get: {
                let day = Calendar.current.startOfDay(for: .now)
                return Calendar.current.date(byAdding: .minute, value: get(), to: day) ?? day
            },
            set: { d in
                let c = Calendar.current.dateComponents([.hour, .minute], from: d)
                set((c.hour ?? 0) * 60 + (c.minute ?? 0))
            })
    }

    private func setupView(_ tr: Tr) -> some View {
        let startB = timeBinding({ startMin }, { startMin = $0 })
        let endB = timeBinding({ endMin }, { endMin = $0 })
        let overnight = endMin <= startMin
        return ScrollView {
            VStack(spacing: 16) {
                field(tr("Órabér (Ft/óra)", "Hourly wage (Ft/h)"), "banknote.fill") {
                    TextField("0", text: $wageText)
                        .keyboardType(.decimalPad)
                        .font(.title2.bold())
                        .foregroundStyle(Earnings.neon)
                        .onChange(of: wageText) { _, v in wage = parseNumber(v) }
                }
                field(tr("Munkakezdés", "Start"), "sunrise.fill") {
                    DatePicker("", selection: startB, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .tint(Earnings.neon)
                }
                field(tr("Munkavége", "End"), "sunset.fill") {
                    DatePicker("", selection: endB, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .tint(Earnings.neon)
                }
                if overnight {
                    Text(tr("A vége korábbi a kezdésnél, ezért másnapra átnyúló műszak.",
                            "End is before start, so this counts as an overnight shift."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Button {
                    Haptics.success()
                    let s = Earnings.shift(startMin: startMin, endMin: endMin, now: .now)
                    running = true
                    Task { await Earnings.scheduleNotifications(shift: s, wage: wage, english: tr.en) }
                } label: {
                    Text(tr("Indítás", "Start"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(Earnings.neon)
                .foregroundStyle(.black)
                .disabled(wage <= 0)
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func field<Content: View>(_ title: String, _ icon: String,
                                      @ViewBuilder content: () -> Content) -> some View {
        let neon = Earnings.neon
        return HStack {
            VStack(alignment: .leading, spacing: 8) {
                Label(title.uppercased(), systemImage: icon)
                    .font(.caption.weight(.heavy))
                    .tracking(1.2)
                    .foregroundStyle(neon.opacity(0.8))
                content()
            }
            Spacer()
        }
        .padding(18)
        .background(neon.opacity(0.06), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(neon.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: neon.opacity(0.18), radius: 14)
    }

    // MARK: Élő nézet

    private func liveView(_ tr: Tr) -> some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { ctx in
            let s = Earnings.shift(startMin: startMin, endMin: endMin, now: ctx.date)
            let p = Earnings.progress(s, now: ctx.date)
            let total = s.seconds / 3600 * wage
            let left = s.end.timeIntervalSince(ctx.date)
            let notStarted = ctx.date < s.start
            VStack(spacing: 30) {
                Spacer()
                ring(p: p, text: Earnings.money(p * total), done: p >= 1, tr)
                VStack(spacing: 10) {
                    bar(p)
                    HStack {
                        Text(Earnings.percent(p))
                            .foregroundStyle(Earnings.neon)
                        Spacer()
                        Text(footerText(notStarted: notStarted, s: s, left: left, tr))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .font(.system(.subheadline, design: .rounded).monospacedDigit().weight(.semibold))
                }
                .padding(.horizontal, 28)
                Spacer()
                Button {
                    Haptics.tap()
                    running = false
                    Earnings.cancelNotifications()
                } label: {
                    Label(tr("Szerkesztés", "Edit"), systemImage: "slider.horizontal.3")
                }
                .buttonStyle(.bordered)
                .tint(Earnings.neon)
                .padding(.bottom, 24)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { resync(tr) }
        }
    }

    private func resync(_ tr: Tr) {
        let s = Earnings.shift(startMin: startMin, endMin: endMin, now: .now)
        Task { await Earnings.scheduleNotifications(shift: s, wage: wage, english: tr.en) }
    }

    private func footerText(notStarted: Bool, s: Earnings.Shift, left: Double, _ tr: Tr) -> String {
        if left <= 0 { return tr("Vége", "Finished") }
        if notStarted {
            let t = s.start.formatted(date: .omitted, time: .shortened)
            return tr("Kezdés: \(t)", "Starts: \(t)")
        }
        return Earnings.remaining(left)
    }

    private func ring(p: Double, text: String, done: Bool, _ tr: Tr) -> some View {
        let neon = Earnings.neon
        let sweep = AngularGradient(
            colors: [neon.opacity(0.25), Color(red: 0, green: 0.85, blue: 0.9), neon],
            center: .center, startAngle: .degrees(0), endAngle: .degrees(360 * max(p, 0.001)))
        return GeometryReader { geo in
            let d = min(geo.size.width, 330)
            ZStack {
                Circle()
                    .stroke(neon.opacity(0.10), lineWidth: 18)
                TickMarks(count: 60)
                    .stroke(neon.opacity(0.28), lineWidth: 1.5)
                    .padding(-14)
                Circle()
                    .trim(from: 0, to: p)
                    .stroke(sweep, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: neon.opacity(0.85), radius: 12)
                    .shadow(color: neon.opacity(0.5), radius: 28)
                if p > 0 && p < 1 {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 10, height: 10)
                        .shadow(color: neon, radius: 8)
                        .offset(y: -d / 2 + 9)
                        .rotationEffect(.degrees(360 * p))
                }
                VStack(spacing: 8) {
                    Text(done ? "Vége! 🎉" : tr("KERESETT", "EARNED"))
                        .font(.system(size: done ? 30 : 12, weight: .heavy, design: .rounded))
                        .tracking(done ? 0 : 3)
                        .foregroundStyle(done ? Color.white : neon.opacity(0.7))
                    Text(text)
                        .font(.system(size: 36, weight: .heavy, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                        .shadow(color: neon, radius: 14)
                        .shadow(color: neon.opacity(0.6), radius: 4)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }
                .padding(.horizontal, 34)
            }
            .frame(width: d, height: d)
            .frame(maxWidth: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(.horizontal, 34)
    }

    private func bar(_ p: Double) -> some View {
        let neon = Earnings.neon
        let fill = LinearGradient(colors: [Color(red: 0, green: 0.85, blue: 0.9), neon],
                                  startPoint: .leading, endPoint: .trailing)
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(neon.opacity(0.12))
                Capsule()
                    .fill(fill)
                    .frame(width: max(geo.size.width * p, 0))
                    .shadow(color: neon.opacity(0.9), radius: 9)
            }
        }
        .frame(height: 14)
        .overlay(Capsule().stroke(neon.opacity(0.3), lineWidth: 1))
    }
}

/// Fekete háttér halvány neon fénnyel és ráccsal.
struct NeonBackdrop: View {
    var body: some View {
        ZStack {
            Color.black
            RadialGradient(colors: [Earnings.neon.opacity(0.16), .clear],
                           center: .center, startRadius: 0, endRadius: 420)
            Canvas { ctx, size in
                var path = Path()
                var x = 0.0
                while x < size.width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    x += 34
                }
                var y = 0.0
                while y < size.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    y += 34
                }
                ctx.stroke(path, with: .color(Earnings.neon.opacity(0.045)), lineWidth: 1)
            }
        }
        .ignoresSafeArea()
    }
}

struct TickMarks: Shape {
    let count: Int
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        for i in 0..<count {
            let a = Double(i) / Double(count) * 2 * Double.pi
            let len: Double = i % 5 == 0 ? 9 : 4
            p.move(to: CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r))
            p.addLine(to: CGPoint(x: c.x + cos(a) * (r - len), y: c.y + sin(a) * (r - len)))
        }
        return p
    }
}
