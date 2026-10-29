import Foundation
import UserNotifications

struct SubInfo: Hashable {
    let name: String
    let day: Int
    let amount: Double
}

/// Helyi értesítések (nem kell hozzá szerver, az iPhone ütemezi őket).
enum Notifier {
    static func sync(subs: [SubInfo], reminders: Bool, daysBefore: Int,
                     monthlyReport: Bool, english: Bool) async {
        let center = UNUserNotificationCenter.current()
        let ids: [String] = (0..<64).map { "sub-\($0)" } + ["monthly-report"]
        center.removePendingNotificationRequests(withIdentifiers: ids)
        guard reminders || monthlyReport else { return }

        _ = try? await center.requestAuthorization(options: [.alert, .sound])
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional else { return }

        let tr = Tr(en: english)

        if reminders {
            for (i, s) in subs.prefix(64).enumerated() {
                // a megújulás előtti nap (28 napos hónapokhoz igazítva)
                let day = ((s.day - daysBefore - 1 + 28) % 28) + 1
                var dc = DateComponents()
                dc.day = day
                dc.hour = 9
                dc.minute = 0

                let content = UNMutableNotificationContent()
                content.title = tr("Előfizetés megújul", "Subscription renewing")
                let when = daysBefore == 0
                    ? tr("ma", "today")
                    : tr("\(daysBefore) nap múlva", "in \(daysBefore) days")
                content.body = tr("\(s.name) \(when) megújul (\(s.amount.ft)).",
                                  "\(s.name) renews \(when) (\(s.amount.ft)).")
                content.sound = .default

                let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
                let req = UNNotificationRequest(identifier: "sub-\(i)", content: content, trigger: trigger)
                try? await center.add(req)
            }
        }

        if monthlyReport {
            var dc = DateComponents()
            dc.day = 1
            dc.hour = 9
            dc.minute = 0
            let content = UNMutableNotificationContent()
            content.title = tr("Elkészült a havi összegzésed", "Your monthly report is ready")
            content.body = tr("Nézd meg, hogyan alakult az elmúlt hónapod a Pocketben.",
                              "See how your last month went in Pocket.")
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
            let req = UNNotificationRequest(identifier: "monthly-report", content: content, trigger: trigger)
            try? await center.add(req)
        }
    }
}
