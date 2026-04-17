import WidgetKit
import SwiftUI
import SwiftData
import AppIntents

// MARK: - Widget Entry

struct SeddlyWidgetEntry: TimelineEntry {
    let date: Date
    let overdueCount: Int
    let pendingCount: Int
    let nextDeadline: Date?
    let nextDeadlineEntity: String?
    let topCommitments: [WidgetCommitment]
}

struct WidgetCommitment: Identifiable {
    let id: String
    let entityName: String
    let summary: String
    let deadline: Date?
    let isOverdue: Bool
}

// MARK: - Interactive Widget Intents (iOS 17+)

struct FulfillCommitmentIntent: AppIntent {
    static var title: LocalizedStringResource = "Mark Fulfilled"
    static var description = IntentDescription("Mark a commitment as fulfilled")

    @Parameter(title: "Commitment ID")
    var commitmentID: String

    init() {}

    init(commitmentID: String) {
        self.commitmentID = commitmentID
    }

    func perform() async throws -> some IntentResult {
        guard let container = try? SharedModelContainer.create() else {
            return .result()
        }
        let context = ModelContext(container)
        guard let uuid = UUID(uuidString: commitmentID) else { return .result() }

        let descriptor = FetchDescriptor<LocalCommitment>(
            predicate: #Predicate { $0.id == uuid }
        )

        if let commitment = try? context.fetch(descriptor).first {
            commitment.statusRaw = "fulfilled"
            commitment.updatedAt = .now
            try? context.save()
        }

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct DismissCommitmentIntent: AppIntent {
    static var title: LocalizedStringResource = "Dismiss Commitment"
    static var description = IntentDescription("Dismiss a commitment")

    @Parameter(title: "Commitment ID")
    var commitmentID: String

    init() {}

    init(commitmentID: String) {
        self.commitmentID = commitmentID
    }

    func perform() async throws -> some IntentResult {
        guard let container = try? SharedModelContainer.create() else {
            return .result()
        }
        let context = ModelContext(container)
        guard let uuid = UUID(uuidString: commitmentID) else { return .result() }

        let descriptor = FetchDescriptor<LocalCommitment>(
            predicate: #Predicate { $0.id == uuid }
        )

        if let commitment = try? context.fetch(descriptor).first {
            commitment.statusRaw = "dismissed"
            commitment.updatedAt = .now
            try? context.save()
        }

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: - Timeline Provider

struct SeddlyWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> SeddlyWidgetEntry {
        SeddlyWidgetEntry(date: .now, overdueCount: 2, pendingCount: 5, nextDeadline: nil, nextDeadlineEntity: nil, topCommitments: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (SeddlyWidgetEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SeddlyWidgetEntry>) -> Void) {
        let entry = loadEntry()
        // Refresh every 30 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadEntry() -> SeddlyWidgetEntry {
        guard let container = try? SharedModelContainer.create() else {
            return SeddlyWidgetEntry(date: .now, overdueCount: 0, pendingCount: 0, nextDeadline: nil, nextDeadlineEntity: nil, topCommitments: [])
        }

        let context = ModelContext(container)

        let allDescriptor = FetchDescriptor<LocalCommitment>(
            predicate: #Predicate { $0.statusRaw == "pending" }
        )

        let commitments = (try? context.fetch(allDescriptor)) ?? []

        let overdueCount = commitments.filter { commitment in
            guard let deadline = commitment.deadline else { return false }
            return deadline < .now
        }.count

        let upcoming = commitments
            .filter { $0.deadline != nil && $0.deadline! > .now }
            .sorted { $0.deadline! < $1.deadline! }
            .first

        // Build top commitments for deep linking (overdue first, then by deadline)
        let sortedCommitments = commitments.sorted { a, b in
            let aOverdue = a.deadline.map { $0 < .now } ?? false
            let bOverdue = b.deadline.map { $0 < .now } ?? false
            if aOverdue != bOverdue { return aOverdue }
            guard let aDeadline = a.deadline, let bDeadline = b.deadline else {
                return a.deadline != nil
            }
            return aDeadline < bDeadline
        }

        let topCommitments = sortedCommitments.prefix(5).map { commitment in
            WidgetCommitment(
                id: commitment.id.uuidString,
                entityName: commitment.entityName,
                summary: commitment.summary,
                deadline: commitment.deadline,
                isOverdue: commitment.deadline.map { $0 < .now } ?? false
            )
        }

        return SeddlyWidgetEntry(
            date: .now,
            overdueCount: overdueCount,
            pendingCount: commitments.count,
            nextDeadline: upcoming?.deadline,
            nextDeadlineEntity: upcoming?.entityName,
            topCommitments: topCommitments
        )
    }
}

// MARK: - Widget Views

struct SeddlyWidgetEntryView: View {
    var entry: SeddlyWidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallWidget
        case .systemMedium:
            mediumWidget
        case .systemLarge:
            largeWidget
        default:
            smallWidget
        }
    }

    // MARK: Small Widget

    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(.accent)
                Text("Seddly")
                    .font(.caption)
                    .fontWeight(.bold)
            }

            Spacer()

            if entry.overdueCount > 0 {
                Text("\(entry.overdueCount)")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.red)
                Text("overdue")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(entry.pendingCount)")
                    .font(.system(size: 44, weight: .bold))
                Text("pending")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .widgetURL(smallWidgetURL)
    }

    /// Small widget links to the first overdue commitment, or first pending commitment
    private var smallWidgetURL: URL? {
        guard let first = entry.topCommitments.first else { return nil }
        return URL(string: "seddly://commitment/\(first.id)")
    }

    // MARK: Medium Widget

    private var mediumWidget: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(.accent)
                    Text("Seddly")
                        .font(.caption)
                        .fontWeight(.bold)
                }

                Spacer()

                HStack(spacing: 16) {
                    VStack {
                        Text("\(entry.overdueCount)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(entry.overdueCount > 0 ? .red : .primary)
                        Text("Overdue")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    VStack {
                        Text("\(entry.pendingCount)")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("Pending")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            if !entry.topCommitments.isEmpty {
                VStack(alignment: .trailing, spacing: 6) {
                    ForEach(entry.topCommitments.prefix(3)) { commitment in
                        Link(destination: URL(string: "seddly://commitment/\(commitment.id)")!) {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(commitment.isOverdue ? .red : .orange)
                                    .frame(width: 6, height: 6)
                                Text(commitment.entityName)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            } else if let deadline = entry.nextDeadline, let entity = entry.nextDeadlineEntity {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Next deadline")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text(entity)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    Text(deadline, style: .date)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding()
    }

    // MARK: Large Widget — Commitment Timeline with Interactive Buttons

    private var largeWidget: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(.accent)
                Text("Seddly")
                    .font(.headline)
                    .fontWeight(.bold)

                Spacer()

                HStack(spacing: 12) {
                    VStack(spacing: 0) {
                        Text("\(entry.overdueCount)")
                            .font(.title3.bold())
                            .foregroundStyle(entry.overdueCount > 0 ? .red : .primary)
                        Text("Overdue")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    VStack(spacing: 0) {
                        Text("\(entry.pendingCount)")
                            .font(.title3.bold())
                        Text("Pending")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.bottom, 4)

            Divider()

            if entry.topCommitments.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.title)
                            .foregroundStyle(.secondary)
                        Text("No pending commitments")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                // Commitment timeline list with interactive buttons
                ForEach(entry.topCommitments.prefix(5)) { commitment in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(commitment.isOverdue ? .red : .orange)
                                .frame(width: 8, height: 8)

                            Text(commitment.entityName)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .lineLimit(1)

                            Spacer()

                            if let deadline = commitment.deadline {
                                Text(deadline, style: .relative)
                                    .font(.caption2)
                                    .foregroundStyle(commitment.isOverdue ? .red : .secondary)
                            }
                        }

                        HStack {
                            Link(destination: URL(string: "seddly://commitment/\(commitment.id)")!) {
                                Text(commitment.summary)
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }

                            Spacer()

                            // Interactive buttons (iOS 17+)
                            HStack(spacing: 8) {
                                Button(intent: FulfillCommitmentIntent(commitmentID: commitment.id)) {
                                    Image(systemName: "checkmark.circle")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                }
                                .buttonStyle(.plain)

                                Button(intent: DismissCommitmentIntent(commitmentID: commitment.id)) {
                                    Image(systemName: "xmark.circle")
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 2)

                    if commitment.id != entry.topCommitments.prefix(5).last?.id {
                        Divider()
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding()
    }
}

// MARK: - Widget Configuration

struct SeddlyWidget: Widget {
    let kind = "SeddlyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SeddlyWidgetProvider()) { entry in
            SeddlyWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Commitments")
        .description("See overdue and pending commitments at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// US-151: Register both the classic timeline widget and the Live Activity
// presentation under a single bundle so the extension hosts both.
@main
struct SeddlyWidgetBundle: WidgetBundle {
    var body: some Widget {
        SeddlyWidget()
        CommitmentLiveActivityWidget()
    }
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    SeddlyWidget()
} timeline: {
    SeddlyWidgetEntry(date: .now, overdueCount: 3, pendingCount: 8, nextDeadline: nil, nextDeadlineEntity: nil, topCommitments: [
        WidgetCommitment(id: "abc-123", entityName: "Landlord", summary: "Fix plumbing", deadline: Calendar.current.date(byAdding: .day, value: -2, to: .now), isOverdue: true)
    ])
}

#Preview(as: .systemMedium) {
    SeddlyWidget()
} timeline: {
    SeddlyWidgetEntry(date: .now, overdueCount: 1, pendingCount: 5, nextDeadline: Calendar.current.date(byAdding: .day, value: 2, to: .now), nextDeadlineEntity: "Acme Property Mgmt", topCommitments: [
        WidgetCommitment(id: "abc-123", entityName: "Landlord", summary: "Fix plumbing", deadline: Calendar.current.date(byAdding: .day, value: -2, to: .now), isOverdue: true),
        WidgetCommitment(id: "def-456", entityName: "Acme Corp", summary: "Invoice payment", deadline: Calendar.current.date(byAdding: .day, value: 3, to: .now), isOverdue: false),
    ])
}

#Preview(as: .systemLarge) {
    SeddlyWidget()
} timeline: {
    SeddlyWidgetEntry(date: .now, overdueCount: 2, pendingCount: 7, nextDeadline: Calendar.current.date(byAdding: .day, value: 1, to: .now), nextDeadlineEntity: "Cable Co", topCommitments: [
        WidgetCommitment(id: "1", entityName: "Landlord", summary: "Fix plumbing by end of week", deadline: Calendar.current.date(byAdding: .day, value: -2, to: .now), isOverdue: true),
        WidgetCommitment(id: "2", entityName: "Cable Co", summary: "Refund $45 for outage", deadline: Calendar.current.date(byAdding: .day, value: -1, to: .now), isOverdue: true),
        WidgetCommitment(id: "3", entityName: "Acme Corp", summary: "Send invoice payment", deadline: Calendar.current.date(byAdding: .day, value: 3, to: .now), isOverdue: false),
        WidgetCommitment(id: "4", entityName: "Dr. Smith", summary: "Follow-up appointment", deadline: Calendar.current.date(byAdding: .day, value: 5, to: .now), isOverdue: false),
        WidgetCommitment(id: "5", entityName: "Insurance", summary: "Submit claim documents", deadline: Calendar.current.date(byAdding: .day, value: 7, to: .now), isOverdue: false),
    ])
}
