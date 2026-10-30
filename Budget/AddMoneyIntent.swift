import AppIntents

/// A widget + és − gombja ezt futtatja: megnyitja az appot a bevétel / kiadás felvitelével.
struct AddMoneyIntent: AppIntent {
    static var title: LocalizedStringResource = "Add money entry"
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Kind")
    var kind: String

    init() {
        kind = "expense"
    }

    init(kind: String) {
        self.kind = kind
    }

    func perform() async throws -> some IntentResult {
        WidgetShared.defaults.set(kind, forKey: "pendingAdd")
        UserDefaults.standard.set(kind, forKey: "pendingAdd")
        return .result()
    }
}
