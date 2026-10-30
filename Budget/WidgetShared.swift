import Foundation

/// Az app és a widgetek közös adattára. Ha az App Group nem elérhető (ingyenes aláírásnál gyakori),
/// akkor a sima UserDefaults-ra esik vissza, és a widgetek csak az adat nélküli részeket mutatják.
enum WidgetShared {
    static let group = "group.hu.sajat.budget"

    static var defaults: UserDefaults {
        if FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) != nil,
           let d = UserDefaults(suiteName: group) {
            return d
        }
        return .standard
    }

    static func set(_ key: String, _ value: Double) {
        defaults.set(value, forKey: "w." + key)
    }

    static func get(_ key: String) -> Double? {
        defaults.object(forKey: "w." + key) as? Double
    }
}
