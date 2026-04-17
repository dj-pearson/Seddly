import ActivityKit
import SwiftUI
import WidgetKit

/// US-151: Renders the Live Activity on the Lock Screen and Dynamic Island
/// for the next-due pending commitment. The app starts the activity via
/// LiveActivityService; this file only defines the presentation.
struct CommitmentLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CommitmentActivityAttributes.self) { context in
            lockScreen(context: context)
                .activityBackgroundTint(Color.accentColor.opacity(0.15))
                .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label(context.attributes.entityName, systemImage: "person.fill")
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(context.state.deadline, style: .timer)
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(isOverdue(context) ? .red : .orange)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            } compactLeading: {
                Image(systemName: "clock.badge.exclamationmark")
                    .foregroundStyle(isOverdue(context) ? .red : .orange)
            } compactTrailing: {
                Text(context.state.deadline, style: .timer)
                    .monospacedDigit()
                    .frame(maxWidth: 52)
            } minimal: {
                Image(systemName: "clock.badge.exclamationmark")
                    .foregroundStyle(isOverdue(context) ? .red : .orange)
            }
            .widgetURL(URL(string: "seddly://commitment/\(context.attributes.commitmentID)"))
        }
    }

    private func isOverdue(
        _ context: ActivityViewContext<CommitmentActivityAttributes>
    ) -> Bool {
        context.state.deadline < .now
    }

    @ViewBuilder
    private func lockScreen(
        context: ActivityViewContext<CommitmentActivityAttributes>
    ) -> some View {
        let overdue = context.state.deadline < .now
        HStack(spacing: 12) {
            Image(systemName: "checkmark.shield.fill")
                .font(.title2)
                .foregroundStyle(.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.entityName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(context.state.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(overdue ? "Overdue" : "Due in")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(context.state.deadline, style: .timer)
                    .monospacedDigit()
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(overdue ? .red : .orange)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
