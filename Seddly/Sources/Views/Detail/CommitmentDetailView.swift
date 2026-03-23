import SwiftUI
import SwiftData
import PhotosUI

struct CommitmentDetailView: View {
    @Bindable var commitment: LocalCommitment
    @Environment(SubscriptionService.self) private var subscriptionService
    @Environment(CalendarService.self) private var calendarService
    @Query(sort: \CustomWorkflow.createdAt) private var workflows: [CustomWorkflow]
    @State private var isEditing = false
    @State private var showingCustomReminder = false
    @State private var customReminderDate = Date()
    @State private var screenshotImage: UIImage?

    var body: some View {
        List {
            // Original screenshot section
            if let image = screenshotImage {
                Section {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
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

                    LabeledContent("Amount") {
                        TextField("$0.00", value: $commitment.dollarAmount, format: .currency(code: "USD"))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                } else {
                    if let deadline = commitment.deadline {
                        LabeledContent("Deadline") {
                            Text(deadline, style: .date)
                                .foregroundStyle(deadlineColor)
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

                Button(role: .destructive) {
                    commitment.status = .dismissed
                    commitment.updatedAt = .now
                } label: {
                    Label("Dismiss Commitment", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Commitment")
        .navigationBarTitleDisplayMode(.inline)
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
        .sheet(isPresented: $showingCustomReminder) {
            customReminderSheet
        }
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

    private func addToCalendar() {
        Task {
            if !calendarService.isAuthorized {
                let granted = await calendarService.requestAccess()
                guard granted else { return }
            }
            if let eventID = calendarService.createEvent(for: commitment) {
                commitment.calendarEventID = eventID
                commitment.updatedAt = .now
            }
        }
    }

    private func scheduleCustomReminder() {
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
        UNUserNotificationCenter.current().add(request)
    }

    private func loadScreenshot() async {
        guard let assetID = commitment.screenshotAssetID,
              !assetID.starts(with: "share-") else { return }

        let results = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil)
        guard let asset = results.firstObject else { return }

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = false

        screenshotImage = await withCheckedContinuation { continuation in
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

    private var deadlineColor: Color {
        switch commitment.urgencyLevel {
        case .overdue: .red
        case .approaching: .yellow
        case .safe: .green
        case .none: .secondary
        }
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
