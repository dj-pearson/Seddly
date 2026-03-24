import UserNotifications

actor NotificationService {
    func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound])
    }

    func scheduleDeadlineApproaching(for commitment: LocalCommitment) async {
        guard UserDefaults.standard.bool(forKey: "notificationsEnabled") != false else { return }
        guard let deadline = commitment.deadline else { return }

        let triggerDate = Calendar.current.date(byAdding: .hour, value: -24, to: deadline) ?? deadline
        guard triggerDate > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = "Deadline Tomorrow"
        content.body = "\(commitment.entityName) promised \(commitment.summary) by tomorrow."
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: triggerDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: "approaching-\(commitment.id.uuidString)",
            content: content,
            trigger: trigger
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    func scheduleDeadlinePassed(for commitment: LocalCommitment) async {
        guard UserDefaults.standard.bool(forKey: "notificationsEnabled") != false else { return }
        guard let deadline = commitment.deadline else { return }

        let triggerDate = Calendar.current.date(byAdding: .day, value: 1, to: deadline) ?? deadline
        guard triggerDate > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = "Commitment Overdue"
        content.body = "\(commitment.entityName)'s commitment to \(commitment.summary) is now overdue."
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: triggerDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: "overdue-\(commitment.id.uuidString)",
            content: content,
            trigger: trigger
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    func removeNotifications(for commitmentID: UUID) {
        let identifiers = [
            "approaching-\(commitmentID.uuidString)",
            "overdue-\(commitmentID.uuidString)"
        ]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
