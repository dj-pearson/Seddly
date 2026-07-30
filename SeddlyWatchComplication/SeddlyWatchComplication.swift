import WidgetKit
import SwiftUI
import SwiftData

struct WatchComplicationEntry: TimelineEntry {
    let date: Date
    let overdueCount: Int
    let pendingCount: Int
    let mostUrgentSummary: String?
    let mostUrgentEntityName: String?
}

struct WatchComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchComplicationEntry {
        WatchComplicationEntry(date: .now, overdueCount: 2, pendingCount: 5, mostUrgentSummary: "Fix the leak", mostUrgentEntityName: "Landlord")
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchComplicationEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchComplicationEntry>) -> Void) {
        let entry = loadEntry()
        // Adaptive refresh: 5 minutes when overdue items exist, 30 minutes otherwise
        let refreshMinutes = entry.overdueCount > 0 ? 5 : 30
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: refreshMinutes, to: .now) ?? .now
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadEntry() -> WatchComplicationEntry {
        guard let container = try? SharedModelContainer.create() else {
            return WatchComplicationEntry(date: .now, overdueCount: 0, pendingCount: 0, mostUrgentSummary: nil, mostUrgentEntityName: nil)
        }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<LocalCommitment>(
            predicate: #Predicate { $0.statusRaw == "pending" }
        )
        let commitments = (try? context.fetch(descriptor)) ?? []

        let overdueCommitments = commitments.filter { commitment in
            guard let deadline = commitment.deadline else { return false }
            return deadline < .now
        }

        // Find most urgent: earliest deadline among overdue, or earliest upcoming deadline
        let mostUrgent: LocalCommitment? = if !overdueCommitments.isEmpty {
            overdueCommitments
                .sorted { ($0.deadline ?? .distantFuture) < ($1.deadline ?? .distantFuture) }
                .first
        } else {
            commitments
                .filter { $0.deadline != nil }
                .sorted { ($0.deadline ?? .distantFuture) < ($1.deadline ?? .distantFuture) }
                .first
        }

        return WatchComplicationEntry(
            date: .now,
            overdueCount: overdueCommitments.count,
            pendingCount: commitments.count,
            mostUrgentSummary: mostUrgent?.summary,
            mostUrgentEntityName: mostUrgent?.entityName
        )
    }
}

struct WatchComplicationView: View {
    var entry: WatchComplicationEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
                .widgetURL(deepLinkURL)
        case .accessoryRectangular:
            rectangularView
                .widgetURL(deepLinkURL)
        case .accessoryCorner:
            cornerView
                .widgetURL(deepLinkURL)
        case .accessoryInline:
            inlineView
                .widgetURL(deepLinkURL)
        default:
            circularView
                .widgetURL(deepLinkURL)
        }
    }

    private var deepLinkURL: URL {
        if entry.overdueCount > 0 {
            URL(string: "seddly-watch://ledger?filter=overdue")!
        } else {
            URL(string: "seddly-watch://ledger?filter=pending")!
        }
    }

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                if entry.overdueCount > 0 {
                    Text("\(entry.overdueCount)")
                        .font(.title2.bold())
                        .foregroundStyle(.red)
                    Text("DUE")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(entry.pendingCount)")
                        .font(.title2.bold())
                    Text("open")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var rectangularView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                if entry.overdueCount > 0, let summary = entry.mostUrgentSummary {
                    Text(entry.mostUrgentEntityName ?? "Overdue")
                        .font(.caption2)
                        .foregroundStyle(.red)
                    Text(summary)
                        .font(.caption)
                        .lineLimit(1)
                    Text("\(entry.overdueCount) overdue total")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else if let summary = entry.mostUrgentSummary {
                    Text("Seddly")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(summary)
                        .font(.caption)
                        .lineLimit(1)
                    Text("\(entry.pendingCount) pending")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Seddly")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(entry.pendingCount) pending")
                        .font(.headline)
                }
            }
            Spacer()
            Image(systemName: entry.overdueCount > 0 ? "exclamationmark.triangle.fill" : "checkmark.shield.fill")
                .foregroundStyle(entry.overdueCount > 0 ? .red : .green)
        }
    }

    private var cornerView: some View {
        Text("\(entry.overdueCount > 0 ? entry.overdueCount : entry.pendingCount)")
            .font(.title.bold())
            .foregroundStyle(entry.overdueCount > 0 ? .red : .primary)
            .widgetLabel {
                Text(entry.overdueCount > 0 ? "overdue" : "pending")
            }
    }

    private var inlineView: some View {
        if entry.overdueCount > 0, let entity = entry.mostUrgentEntityName {
            Text("\(entry.overdueCount) overdue — \(entity)")
        } else if entry.overdueCount > 0 {
            Text("\(entry.overdueCount) overdue commitments")
        } else {
            Text("\(entry.pendingCount) pending commitments")
        }
    }
}

struct SeddlyWatchComplication: Widget {
    let kind = "SeddlyWatchComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchComplicationProvider()) { entry in
            WatchComplicationView(entry: entry)
        }
        .configurationDisplayName("Commitments")
        .description("Overdue and pending commitment count.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryCorner,
            .accessoryInline
        ])
    }
}

#Preview(as: .accessoryCircular) {
    SeddlyWatchComplication()
} timeline: {
    WatchComplicationEntry(date: .now, overdueCount: 3, pendingCount: 8, mostUrgentSummary: "Fix the leak", mostUrgentEntityName: "Landlord")
    WatchComplicationEntry(date: .now, overdueCount: 0, pendingCount: 5, mostUrgentSummary: nil, mostUrgentEntityName: nil)
}
