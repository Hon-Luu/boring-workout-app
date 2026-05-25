import UserNotifications

enum NotificationScheduler {

    private static let reEngagementId = "re_engagement"

    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// Cancels any pending re-engagement notification and schedules a new one 3 days from now.
    /// Call this after every completed workout and every time the app becomes active.
    static func scheduleReEngagement() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reEngagementId])

        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }

            let content = UNMutableNotificationContent()
            content.title = "Time to train"
            content.body = "You haven't logged a session in 3 days. Keep the momentum going."
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3 * 24 * 3600, repeats: false)
            let request = UNNotificationRequest(identifier: reEngagementId, content: content, trigger: trigger)
            center.add(request, withCompletionHandler: nil)
        }
    }
}
