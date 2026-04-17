import SwiftUI
import SwiftData
import PhotosUI

struct CommitmentDetailView: View {
    @Bindable var commitment: LocalCommitment
    @Environment(SubscriptionService.self) private var subscriptionService
    @Environment(CalendarService.self) private var calendarService
    @Query(sort: \CustomWorkflow.createdAt) private var workflows: [CustomWorkflow]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false
    @State private var showingCustomReminder = false
    @State private var showDeleteConfirmation = false
    @State private var showDismissConfirmation = false
    @State private var customReminderDate = Date()
    @State private var screenshotImage: UIImage?
    @State private var isLoadingScreenshot = false
    @State private var screenshotLoadFailed = false
    @State private var showDeleteError = false
    @State private var showReminderToast = false
    @State private var reminderToastMessage = ""
    @State private var showNotificationPermissionAlert = false
    // US-149
    @State private var showingSnoozePicker = false
    @State private var snoozeCustomDate = Calendar.current.date(byAdding: .day, value: 3, to: .now) ?? .now

    var body: some View {
        List {
            // US-149 + US-153: Snooze banner extracted to CommitmentDetailSections.
            if commitment.isSnoozed, let until = commitment.snoozedUntil {
                Section {
                    CommitmentSnoozeBanner(until: until) {
                        commitment.snoozedUntil = nil
                        commitment.updatedAt = .now
                    }
                }
                .listRowBackground(Color.orange.opacity(0.08))
            }

            // Original screenshot section
            if let image = screenshotImage {
                Section {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            } else if isLoadingScreenshot {
                Section {
                    HStack {
                        ProgressView()
                        Text("Loading screenshot...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } else if screenshotLoadFailed {
                Section {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Text("Screenshot couldn't be loaded")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Retry") {
                            screenshotLoadFailed = false
                            Task { await loadScreenshot() }
                        }
                        .font(.subheadline)
                    }
                }
            } else if commitment.source == .manual {
                Section {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundStyle(.secondary)
                        Text("Manually added — no screenshot attached")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Details") {
                if let entity = commitment.entity {
                    NavigationLink {
                        EntityProfileView(entity: entity)
                    } label: {
                        LabeledContent("Who") {
                            Text(commitment.entityName)
                        }
                    }
                } else {
                    LabeledContent("Who") {
                        if isEditing {
                            TextField("Entity", text: $commitment.entityName)
                                .multilineTextAlignment(.trailing)
                        } else {
                            Text(commitment.entityName)
                        }
                    }
                }

                LabeledContent("What") {
                    if isEditing {
                        TextField("Summary", text: $commitment.summary)
                            .multilineTextAlignment(.trailing)
                    } else {
                        Text(commitment.summary)
                    }
                }

                if isEditing {
                    DatePicker(
                        "Deadline",
                        selection: Binding(
                            get: { commitment.deadline ?? .now },
                            set: { commitment.deadline = $0 }
                        ),
                        displayedComponents: .date
                    )
                    if let deadline = commitment.deadline,
                       Calendar.current.startOfDay(for: deadline) < Calendar.current.startOfDay(for: .now) {
                        Label("This date is in the past — the commitment will be immediately overdue.", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    LabeledContent("Amount") {
                        TextField("$0.00", value: $commitment.dollarAmount, format: .currency(code: "USD"))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                } else {
                    if let deadline = commitment.deadline {
                        VStack(alignment: .leading, spacing: 2) {
                            LabeledContent("Deadline") {
                                Text(deadline, style: .date)
                                    .foregroundStyle(deadlineColor)
                            }
                            // Show interpretation note if AI resolved an implicit deadline
                            if commitment.source == .auto,
                               let reasoning = commitment.aiReasoning,
                               containsDateInterpretation(reasoning) {
                                Text(extractDeadlineNote(from: commitment.fullText))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .italic()
                            }
                        }
                    }

                    if let amount = commitment.dollarAmount {
                        LabeledContent("Amount") {
                            Text(amount, format: .currency(code: "USD"))
                        }
                    }
                }

                Picker("Status", selection: Binding(
                    get: { commitment.status },
                    set: { newStatus in
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        commitment.status = newStatus
                        commitment.updatedAt = .now
                        // Sync status to calendar event
                        if let eventID = commitment.calendarEventID {
                            if newStatus == .fulfilled || newStatus == .dismissed {
                                calendarService.removeEvent(identifier: eventID)
                                commitment.calendarEventID = nil
                            } else {
                                calendarService.updateEvent(identifier: eventID, commitment: commitment)
                            }
                        }
                        WatchSyncService.shared.sendCommitmentUpdate(
                            id: commitment.id, action: "updated",
                            entityName: commitment.entityName, summary: commitment.summary,
                            statusRaw: commitment.statusRaw
                        )
                    }
                )) {
                    ForEach(CommitmentStatus.allCases) { status in
                        Text(status.label).tag(status)
                    }
                }

                Picker("Category", selection: Binding(
                    get: { commitment.category },
                    set: {
                        commitment.category = $0
                        commitment.updatedAt = .now
                    }
                )) {
                    ForEach(CommitmentCategory.allCases) { category in
                        Label(category.label, systemImage: category.icon).tag(category)
                    }
                }
            }

            if !workflows.isEmpty {
                Section("Custom Workflow") {
                    let activeWorkflow = workflows.first { $0.id == commitment.workflowID }
                    Picker("Workflow", selection: Binding(
                        get: { commitment.workflowID },
                        set: { newID in
                            commitment.workflowID = newID
                            commitment.customStatusLabel = nil
                            commitment.updatedAt = .now
                        }
                    )) {
                        Text("None").tag(UUID?.none)
                        ForEach(workflows) { workflow in
                            Text(workflow.name).tag(UUID?.some(workflow.id))
                        }
                    }

                    if let workflow = activeWorkflow {
                        Picker("Step", selection: Binding(
                            get: { commitment.customStatusLabel ?? workflow.steps.first ?? "" },
                            set: {
                                commitment.customStatusLabel = $0
                                commitment.updatedAt = .now
                            }
                        )) {
                            ForEach(workflow.steps, id: \.self) { step in
                                Text(step).tag(step)
                            }
                        }
                    }
                }
            }

            if let reasoning = commitment.aiReasoning {
                Section("Why Seddly Flagged This") {
                    HStack {
                        ConfidenceBadgeView(score: commitment.confidenceScore)
                        Text(reasoning)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !commitment.fullText.isEmpty && commitment.fullText != commitment.summary {
                Section("Original Text") {
                    Text(commitment.fullText)
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            Section("Notes") {
                TextField("Add notes...", text: Binding(
                    get: { commitment.notes ?? "" },
                    set: { commitment.notes = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
                .lineLimit(3...6)
            }

            // Related screenshots from same entity
            if let entity = commitment.entity {
                let related = entity.commitments
                    .filter { $0.id != commitment.id && $0.screenshotAssetID != nil }
                    .sorted { $0.createdAt > $1.createdAt }
                if !related.isEmpty {
                    Section("Related from \(entity.name)") {
                        ForEach(related.prefix(5)) { relatedCommitment in
                            NavigationLink(value: relatedCommitment) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(relatedCommitment.summary)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                    HStack {
                                        Text(relatedCommitment.createdAt, style: .date)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(relatedCommitment.status.label)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            if commitment.source != .manual {
                Section("Source") {
                    LabeledContent("Detected via") {
                        switch commitment.source {
                        case .auto: Text("Auto-scan")
                        case .shareSheet: Text("Share Sheet")
                        case .manual: Text("Manual")
                        }
                    }
                    if let date = commitment.screenshotDate {
                        LabeledContent("Screenshot taken") {
                            Text(date, style: .date)
                        }
                    }
                }
            }

            Section {
                ShareLink(
                    item: shareText,
                    subject: Text("Commitment from \(commitment.entityName)"),
                    message: Text(shareText)
                ) {
                    Label("Share as Text", systemImage: "square.and.arrow.up")
                }

                ShareLink(
                    item: CommitmentSharingService.generateReminderMessage(for: commitment),
                    subject: Text("Reminder: \(commitment.summary)"),
                    message: Text(CommitmentSharingService.generateReminderMessage(for: commitment))
                ) {
                    Label("Send Reminder to \(commitment.entityName)", systemImage: "paperplane")
                }

                if subscriptionService.currentTier >= .proPlus, let entity = commitment.entity {
                    NavigationLink {
                        EntityProfileView(entity: entity)
                    } label: {
                        Label("Export Entity Timeline (Pro+)", systemImage: "doc.text")
                    }
                }

                // Calendar integration
                if commitment.deadline != nil {
                    if let eventID = commitment.calendarEventID {
                        Button {
                            calendarService.removeEvent(identifier: eventID)
                            commitment.calendarEventID = nil
                            commitment.updatedAt = .now
                        } label: {
                            Label("Remove from Calendar", systemImage: "calendar.badge.minus")
                        }
                    } else {
                        Button {
                            addToCalendar()
                        } label: {
                            Label("Add to Calendar", systemImage: "calendar.badge.plus")
                        }
                    }
                }

                Button {
                    showingCustomReminder = true
                } label: {
                    Label("Set Custom Reminder", systemImage: "bell.badge")
                }
                .accessibilityHint("Opens a date picker to schedule a notification reminder")

                // US-149: Snooze keeps the deadline intact but hides the row
                // from the active ledger until the chosen date.
                if commitment.isSnoozed {
                    Button {
                        commitment.snoozedUntil = nil
                        commitment.updatedAt = .now
                    } label: {
                        Label("Unsnooze", systemImage: "bell.and.waves.left.and.right")
                    }
                    .accessibilityHint("Returns this commitment to the active ledger immediately.")
                } else {
                    Menu {
                        Button("1 day")  { snooze(days: 1) }
                        Button("3 days") { snooze(days: 3) }
                        Button("7 days") { snooze(days: 7) }
                        Button("Custom…") { showingSnoozePicker = true }
                    } label: {
                        Label("Snooze", systemImage: "moon.zzz")
                    }
                    .accessibilityHint("Hides this commitment from the active ledger for a chosen duration.")
                }

                Button(role: .destructive) {
                    showDismissConfirmation = true
                } label: {
                    Label("Dismiss Commitment", systemImage: "eye.slash")
                }
                .accessibilityHint("Hides this commitment from your active list. Can be changed later.")

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete Permanently", systemImage: "trash")
                }
                .accessibilityHint("Permanently removes this commitment. This cannot be undone.")
            }
        }
        .navigationTitle("Commitment")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Dismiss Commitment?", isPresented: $showDismissConfirmation) {
            Button("Dismiss", role: .destructive) {
                commitment.status = .dismissed
                commitment.updatedAt = .now
                WatchSyncService.shared.sendCommitmentUpdate(
                    id: commitment.id, action: "updated",
                    entityName: commitment.entityName, summary: commitment.summary,
                    statusRaw: commitment.statusRaw
                )
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This commitment will be marked as dismissed. You can change its status later.")
        }
        .alert("Delete Commitment?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteCommitment()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete this commitment and cannot be undone.")
        }
        // US-149: Custom snooze date picker
        .sheet(isPresented: $showingSnoozePicker) {
            NavigationStack {
                Form {
                    DatePicker(
                        "Snooze until",
                        selection: $snoozeCustomDate,
                        in: Date.now...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    Section {
                        Text("The original deadline and reminders stay scheduled. The commitment reappears in your ledger on the date you choose.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .navigationTitle("Snooze")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingSnoozePicker = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Snooze") {
                            commitment.snoozedUntil = snoozeCustomDate
                            commitment.updatedAt = .now
                            showingSnoozePicker = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(isEditing ? "Done" : "Edit") {
                    isEditing.toggle()
                    if !isEditing {
                        commitment.updatedAt = .now
                    }
                }
            }
        }
        .alert("Couldn't Delete Commitment", isPresented: $showDeleteError) {
            Button("OK") {}
        } message: {
            Text("Something went wrong while deleting. Please try again.")
        }
        .sheet(isPresented: $showingCustomReminder) {
            customReminderSheet
        }
        .alert("Notifications Disabled", isPresented: $showNotificationPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Seddly needs notification permission to send reminders. Please enable notifications in Settings.")
        }
        .overlay(alignment: .bottom) {
            if showReminderToast {
                HStack(spacing: 8) {
                    Text(reminderToastMessage)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Button {
                        withAnimation { showReminderToast = false }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .shadow(radius: 4)
                .padding(.bottom, 32)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onTapGesture {
                    withAnimation { showReminderToast = false }
                }
            }
        }
        .animation(.easeInOut, value: showReminderToast)
        .task {
            await loadScreenshot()
        }
    }

    private var customReminderSheet: some View {
        NavigationStack {
            Form {
                DatePicker("Remind me on", selection: $customReminderDate, in: Date.now..., displayedComponents: [.date, .hourAndMinute])
            }
            .navigationTitle("Custom Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingCustomReminder = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Set") {
                        scheduleCustomReminder()
                        showingCustomReminder = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    /// US-149: Snoozes the commitment by N days from now.
    private func snooze(days: Int) {
        let target = Calendar.current.date(byAdding: .day, value: days, to: .now) ?? .now
        commitment.snoozedUntil = target
        commitment.updatedAt = .now
        HapticsService.tap()
    }

    private func deleteCommitment() {
        let commitmentID = commitment.id
        let entityName = commitment.entityName
        let summary = commitment.summary
        // Remove calendar event if linked
        if let eventID = commitment.calendarEventID {
            calendarService.removeEvent(identifier: eventID)
        }
        // Remove notifications
        let notificationService = NotificationService()
        notificationService.removeNotifications(for: commitmentID)
        // Delete from SwiftData
        modelContext.delete(commitment)
        do {
            try modelContext.save()
            WatchSyncService.shared.sendCommitmentUpdate(
                id: commitmentID, action: "deleted",
                entityName: entityName, summary: summary,
                statusRaw: "deleted"
            )
            dismiss()
        } catch {
            showDeleteError = true
        }
    }

    private func addToCalendar() {
        Task {
            if !calendarService.isAuthorized {
                let granted = await calendarService.requestAccess()
                guard granted else { return }
            }
            if let eventID = calendarService.createEvent(for: commitment) {
                commitment.calendarEventID = eventID
                commitment.updatedAt = .now
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }

    private func scheduleCustomReminder() {
        Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()

            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                showNotificationPermissionAlert = true
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "Reminder: \(commitment.entityName)"
            content.body = commitment.summary
            content.sound = .default

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: customReminderDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: "custom-\(commitment.id.uuidString)",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)

            let formatted = customReminderDate.formatted(.dateTime.month(.wide).day().hour().minute())
            reminderToastMessage = "Reminder set for \(formatted)"
            withAnimation {
                showReminderToast = true
            }
            try? await Task.sleep(for: .seconds(8))
            withAnimation {
                showReminderToast = false
            }
        }
    }

    private func loadScreenshot() async {
        guard let assetID = commitment.screenshotAssetID,
              !assetID.starts(with: "share-") else { return }

        isLoadingScreenshot = true

        let results = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil)
        guard let asset = results.firstObject else {
            isLoadingScreenshot = false
            screenshotLoadFailed = true
            return
        }

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = false

        // 10-second timeout for screenshot loading
        let image: UIImage? = await withTaskGroup(of: UIImage?.self) { group in
            group.addTask {
                await withCheckedContinuation { continuation in
                    PHImageManager.default().requestImage(
                        for: asset,
                        targetSize: CGSize(width: 600, height: 600),
                        contentMode: .aspectFit,
                        options: options
                    ) { image, _ in
                        continuation.resume(returning: image)
                    }
                }
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(10))
                return nil
            }

            // Return whichever finishes first
            for await result in group {
                group.cancelAll()
                return result
            }
            return nil
        }

        isLoadingScreenshot = false
        if let image {
            screenshotImage = image
        } else {
            screenshotLoadFailed = true
        }
    }

    private func containsDateInterpretation(_ reasoning: String) -> Bool {
        let keywords = ["interpreted", "resolved", "next friday", "next week", "end of", "by tomorrow", "next monday", "next tuesday", "next wednesday", "next thursday", "next saturday", "next sunday", "this week", "this month"]
        let lower = reasoning.lowercased()
        return keywords.contains { lower.contains($0) }
    }

    private func extractDeadlineNote(from fullText: String) -> String {
        let datePatterns = ["next friday", "next week", "next monday", "next tuesday", "next wednesday", "next thursday", "next saturday", "next sunday", "end of week", "end of month", "end of day", "by tomorrow", "this friday", "this week"]
        let lower = fullText.lowercased()
        for pattern in datePatterns {
            if lower.contains(pattern) {
                return "Interpreted from \"\(pattern)\" in original text"
            }
        }
        return "Deadline resolved from original text"
    }

    private var deadlineColor: Color {
        SeddlyColors.urgency(commitment.urgencyLevel)
    }

    private var shareText: String {
        var text = "Commitment from \(commitment.entityName):\n\(commitment.summary)"
        if let deadline = commitment.deadline {
            text += "\nDeadline: \(deadline.formatted(date: .long, time: .omitted))"
        }
        if let amount = commitment.dollarAmount {
            text += "\nAmount: $\(amount)"
        }
        text += "\nStatus: \(commitment.status.label)"
        if let notes = commitment.notes, !notes.isEmpty {
            text += "\nNotes: \(notes)"
        }
        return text
    }
}
