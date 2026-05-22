import Foundation
import UserNotifications

enum HONMessageScheduler {

    static func schedule(message: HONPendingMessage) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }

            let content       = UNMutableNotificationContent()
            content.title     = "H.O.N"
            content.body      = message.message
            content.sound     = .default
            content.userInfo  = [
                "honMessageId": message.id.uuidString,
                "kind": message.kind.rawValue
            ]

            // Deliver at 08:00 tomorrow local time
            var comps        = DateComponents()
            comps.hour       = 8
            comps.minute     = 0
            let trigger      = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

            let request = UNNotificationRequest(
                identifier: "hon-pending",   // fixed — replaces any existing pending HON notification
                content: content,
                trigger: trigger
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
