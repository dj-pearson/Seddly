import WidgetKit
import SwiftUI
import SwiftData

struct WatchComplicationEntry: TimelineEntry {
    let date: Date
    let overdueCount: Int
    let pendingCount: Int
}

struct WatchComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchComplicationEntry {
        WatchComplicationEntry(date: .now, overdueCount: 2, pendingCount: 5)
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchComplicationEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchComplicationEntry>) -> Void) {
        let entry = loadEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadEntry() -> WatchComplicationEntry {
        guard let container = try? SharedModelContainer.create() else {
            return WatchComplicationEntry(date: .now, overdueCount: 0, pendingCount: 0)
        }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<LocalCommitment>(
            predicate: #Predicate { $0.statusRaw == "pending" }
        )
        let commitments = (try? context.fetch(descriptor)) ?? []

        let overdueCount = commitments.filter { commitment in
            guard let deadline = commitment.deadline else { return false }
            return deadline < .now
        }.count

        return WatchComplicationEntry(
            date: .now,
            overdueCount: overdueCount,
            pendingCount: commitments.count
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
        case .accessoryRectangular:
            rectangularView
        case .accessoryCorner:
            cornerView
        case .accessoryInline:
            inlineView
        default:
            circularView
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
                Text("Seddly")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if entry.overdueCount > 0 {
                    Text("\(entry.overdueCount) overdue")
                        .font(.headline)
                        .foregroundStyle(.red)
                } else {
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
        if entry.overdueCount > 0 {
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
    WatchComplicationEntry(date: .now, overdueCount: 3, pendingCount: 8)
    WatchComplicationEntry(date: .now, overdueCount: 0, pendingCount: 5)
}
