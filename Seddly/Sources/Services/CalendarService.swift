import EventKit
import SwiftData

@Observable
final class CalendarService {
    private let eventStore = EKEventStore()
    private(set) var authorizationStatus: EKAuthorizationStatus = .notDetermined
    private(set) var isAuthorized = false

    init() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        isAuthorized = authorizationStatus == .fullAccess || authorizationStatus == .authorized
    }

    func requestAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
            isAuthorized = granted
            return granted
        } catch {
            return false
        }
    }

    /// Creates a calendar event for a commitment deadline and returns the event identifier.
    func createEvent(for commitment: LocalCommitment) -> String? {
        guard isAuthorized, let deadline = commitment.deadline else { return nil }

        let event = EKEvent(eventStore: eventStore)
        event.title = "\(commitment.entityName): \(commitment.summary)"
        event.startDate = deadline
        event.endDate = deadline.addingTimeInterval(3600) // 1 hour
        event.notes = buildEventNotes(for: commitment)
        event.calendar = eventStore.defaultCalendarForNewEvents

        // Add an alert 24 hours before
        event.addAlarm(EKAlarm(relativeOffset: -86400))

        do {
            try eventStore.save(event, span: .thisEvent)
            return event.eventIdentifier
        } catch {
            return nil
        }
    }

    /// Removes a calendar event by identifier.
    func removeEvent(identifier: String) {
        guard isAuthorized,
              let event = eventStore.event(withIdentifier: identifier) else { return }
        try? eventStore.remove(event, span: .thisEvent)
    }

    /// Checks if a calendar event has been completed/deleted and returns true if so.
    func isEventCompleted(identifier: String) -> Bool {
        guard isAuthorized else { return false }
        return eventStore.event(withIdentifier: identifier) == nil
    }

    /// Syncs commitment status changes to the calendar event.
    func updateEvent(identifier: String, commitment: LocalCommitment) {
        guard isAuthorized,
              let event = eventStore.event(withIdentifier: identifier) else { return }

        event.title = "\(commitment.entityName): \(commitment.summary)"
        if let deadline = commitment.deadline {
            event.startDate = deadline
            event.endDate = deadline.addingTimeInterval(3600)
        }
        event.notes = buildEventNotes(for: commitment)

        try? eventStore.save(event, span: .thisEvent)
    }

    private func buildEventNotes(for commitment: LocalCommitment) -> String {
        var notes = "Tracked by Seddly\n"
        notes += "Status: \(commitment.status.label)\n"
        if let amount = commitment.dollarAmount {
            notes += "Amount: $\(amount)\n"
        }
        if let userNotes = commitment.notes, !userNotes.isEmpty {
            notes += "\n\(userNotes)"
        }
        return notes
    }
}
