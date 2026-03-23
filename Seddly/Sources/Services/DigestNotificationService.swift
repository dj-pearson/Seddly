import UserNotifications

struct DigestNotificationService {
    static func scheduleDailyDigest(
        hour: Int = 20,
        minute: Int = 0,
        screenshotsProcessed: Int,
        commitmentsDetected: Int,
        upcomingDeadlines: Int
    ) {
        let content = UNMutableNotificationContent()
        content.title = "Your Daily Accountability Check-in"

        var bodyParts: [String] = []
        if screenshotsProcessed > 0 {
            bodyParts.append("\(screenshotsProcessed) new screenshots processed")
        }
        if commitmentsDetected > 0 {
            bodyParts.append("\(commitmentsDetected) new commitments detected")
        }
        if upcomingDeadlines > 0 {
            bodyParts.append("\(upcomingDeadlines) deadlines this week")
        }

        if bodyParts.isEmpty {
            content.body = "Open Seddly to check for new commitments."
        } else {
            content.body = bodyParts.joined(separator: ". ") + "."
        }

        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(
            identifier: "daily-digest",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    static func cancelDailyDigest() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["daily-digest"])
    }
}
