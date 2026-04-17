import SwiftUI
import SwiftData
import UserNotifications

/// US-152: Scheduled-reminder management.
///
/// Lists every pending UNNotificationRequest Seddly has registered and lets the
/// user cancel individual reminders. Each reminder is correlated back to its
/// commitment by parsing the request identifier (`approaching-<uuid>` /
/// `overdue-<uuid>`), which is the naming scheme used in NotificationService.
struct ReminderListView: View {
    @Query private var commitments: [LocalCommitment]
    @State private var reminders: [Reminder] = []
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var isLoading = true

    var body: some View {
        List {
            if authorizationStatus == .denied {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Notifications are turned off", systemImage: "bell.slash")
                            .font(.subheadline.weight(.semibold))
                        Text("Enable notifications in iOS Settings to receive deadline reminders.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
            }

            if isLoading {
                Section {
                    HStack {
                        ProgressView()
                        Text("Loading reminders…")
                            .foregroundStyle(.secondary)
                    }
                }
            } else if reminders.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No Scheduled Reminders",
                        systemImage: "bell.slash.fill",
                        description: Text("Reminders appear here once you add a commitment with a deadline.")
                    )
                }
            } else {
                ForEach(groupedReminders, id: \.key) { group in
                    Section(group.key) {
                        ForEach(group.value) { reminder in
                            ReminderRow(
                                reminder: reminder,
                                onCancel: { cancel(reminder) }
                            )
                        }
                    }
                }
            }
        }
        .navigationTitle("Scheduled Reminders")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
    }

    private var groupedReminders: [(key: String, value: [Reminder])] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: today) ?? today

        let buckets = Dictionary(grouping: reminders) { reminder -> String in
            let day = calendar.startOfDay(for: reminder.fireDate)
            if day < today { return "Overdue" }
            if day == today { return "Today" }
            if day == tomorrow { return "Tomorrow" }
            if day <= weekEnd { return "This Week" }
            return "Later"
        }

        let order = ["Overdue", "Today", "Tomorrow", "This Week", "Later"]
        return order.compactMap { key in
            guard let list = buckets[key] else { return nil }
            return (key, list.sorted { $0.fireDate < $1.fireDate })
        }
    }

    private func load() async {
        isLoading = true
        let center = UNUserNotificationCenter.current()
        authorizationStatus = await center.notificationSettings().authorizationStatus
        let requests = await center.pendingNotificationRequests()
        reminders = requests.compactMap { Reminder(request: $0, commitments: commitments) }
            .sorted { $0.fireDate < $1.fireDate }
        isLoading = false
    }

    private func cancel(_ reminder: Reminder) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [reminder.id])
        reminders.removeAll { $0.id == reminder.id }
    }
}

// MARK: - Reminder row

private struct ReminderRow: View {
    let reminder: ReminderListView.Reminder
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: reminder.kind.iconName)
                    .foregroundStyle(reminder.kind.tint)
                Text(reminder.title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(reminder.fireDate, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let subtitle = reminder.subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Text(reminder.fireDate.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onCancel) {
                Label("Cancel", systemImage: "trash")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Swipe left to cancel this reminder")
    }
}

// MARK: - Reminder model

extension ReminderListView {
    struct Reminder: Identifiable {
        enum Kind {
            case approaching
            case overdue
            case other

            var iconName: String {
                switch self {
                case .approaching: return "clock.badge.exclamationmark"
                case .overdue:     return "exclamationmark.triangle.fill"
                case .other:       return "bell"
                }
            }

            var tint: Color {
                switch self {
                case .approaching: return .orange
                case .overdue:     return .red
                case .other:       return .accentColor
                }
            }
        }

        let id: String
        let title: String
        let subtitle: String?
        let fireDate: Date
        let kind: Kind

        init?(request: UNNotificationRequest, commitments: [LocalCommitment]) {
            guard let trigger = request.trigger as? UNCalendarNotificationTrigger,
                  let fire = trigger.nextTriggerDate() else {
                return nil
            }
            self.id = request.identifier
            self.fireDate = fire

            let (kind, uuidString) = Self.parse(identifier: request.identifier)
            self.kind = kind

            if let uuidString,
               let uuid = UUID(uuidString: uuidString),
               let commitment = commitments.first(where: { $0.id == uuid }) {
                self.title = commitment.entityName
                self.subtitle = commitment.summary
            } else {
                self.title = request.content.title
                self.subtitle = request.content.body.isEmpty ? nil : request.content.body
            }
        }

        private static func parse(identifier: String) -> (Kind, String?) {
            if identifier.hasPrefix("approaching-") {
                return (.approaching, String(identifier.dropFirst("approaching-".count)))
            }
            if identifier.hasPrefix("overdue-") {
                return (.overdue, String(identifier.dropFirst("overdue-".count)))
            }
            return (.other, nil)
        }
    }
}

#Preview {
    NavigationStack {
        ReminderListView()
            .modelContainer(for: LocalCommitment.self, inMemory: true)
    }
}
