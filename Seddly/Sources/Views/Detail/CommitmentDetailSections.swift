import SwiftUI

// MARK: - US-153 — Extracted sub-views for CommitmentDetailView

/// Banner that shows when a commitment is currently snoozed. Used at the top
/// of the detail view so users see at a glance that the row is hidden from
/// the active ledger and can unsnooze in one tap.
struct CommitmentSnoozeBanner: View {
    let until: Date
    let onUnsnooze: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "moon.zzz.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Snoozed")
                    .font(.subheadline.weight(.semibold))
                Text("Returns on \(until.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Unsnooze", action: onUnsnooze)
                .font(.caption.weight(.semibold))
        }
    }
}

#Preview("Snoozed banner") {
    List {
        Section {
            CommitmentSnoozeBanner(
                until: Date.now.addingTimeInterval(3 * 24 * 3600),
                onUnsnooze: {}
            )
        }
        .listRowBackground(Color.orange.opacity(0.08))
    }
}
