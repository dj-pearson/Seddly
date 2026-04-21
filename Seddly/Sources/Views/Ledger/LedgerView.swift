import SwiftUI
import SwiftData

struct LedgerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(SubscriptionService.self) private var subscriptionService
    @Environment(\.authService) private var authService
    // US-145: Cap the SwiftData fetch so we never materialize an unbounded number
    // of LocalCommitment rows. Users with deeper history still reach older records
    // via search (which falls back to a predicate-driven fetch) or the sync'd
    // cloud ledger on Pro+.
    @Query private var commitments: [LocalCommitment]
    @State private var viewModel = LedgerViewModel()
    @State private var showingManualEntry = false
    @State private var showingFilter = false
    @State private var showingUpgrade = false
    @State private var showingReviewQueue = false
    private static let appGroupDefaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier)
    @AppStorage("autoAnalyze", store: appGroupDefaults) private var autoAnalyze = false
    @AppStorage("offlineMode", store: appGroupDefaults) private var offlineMode = false
    @State private var isProcessing = false
    @State private var newCommitmentsCount = 0
    @State private var showingBulkAction = false
    @State private var showingDismissConfirm = false
    @State private var showingFulfillConfirm = false
    @State private var pendingSwipeCommitment: LocalCommitment?
    // US-149: Snooze state
    @State private var pendingSnoozeCommitment: LocalCommitment?
    @State private var showingSnoozeMenu = false
    @State private var showingAIReview = false
    @State private var pendingAIText: String?
    @State private var pendingAICallback: ((String?) -> Void)?
    @State private var undoState: UndoState?
    @State private var undoDismissTask: Task<Void, Never>?
    // US-154: Retain handles to in-flight Tasks so we can cancel them when the
    // view disappears or the app backgrounds. Prevents wasted work, AI-endpoint
    // quota burn, and races with view teardown.
    @State private var foregroundProcessTask: Task<Void, Never>?
    @State private var syncTask: Task<Void, Never>?
    @State private var scenePhaseBadgeTask: Task<Void, Never>?
    @State private var aiReviewTask: Task<Void, Never>?

    init() {
        var descriptor = FetchDescriptor<LocalCommitment>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = LedgerViewModel.fetchCeiling
        _commitments = Query(descriptor, animation: .default)
    }

    private var networkMonitor: NetworkMonitorService { NetworkMonitorService.shared }

    private var visibleCommitments: [LocalCommitment] {
        viewModel.applyHistoryLimit(Array(commitments), tier: subscriptionService.currentTier)
    }

    private var activeCommitments: [LocalCommitment] {
        visibleCommitments.filter { $0.status != .dismissed && $0.status != .fulfilled }
    }

    @Query(
        filter: #Predicate<ProcessingQueue> { $0.processingStatusRaw == "awaitingReview" },
        sort: \ProcessingQueue.createdAt
    )
    private var awaitingAIReview: [ProcessingQueue]

    private var reviewQueueItems: [LocalCommitment] {
        commitments.filter { $0.needsAIProcessing || ($0.confidenceScore >= 4 && $0.confidenceScore <= 6 && $0.source == .auto) }
    }

    @State private var showingBackfill = false
    @AppStorage("showBackfillReviewBanner", store: appGroupDefaults) private var showBackfillReviewBanner = false
    @AppStorage("isSignedIn", store: appGroupDefaults) private var isSignedIn = false

    var body: some View {
        NavigationStack {
            Group {
                if visibleCommitments.isEmpty {
                    EmptyLedgerView(
                        onAddManually: { showingManualEntry = true },
                        onScanScreenshots: { showingBackfill = true }
                    )
                } else {
                    commitmentList
                }
            }
            .navigationTitle("Seddly")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if viewModel.isSelecting {
                        Button("Done") {
                            viewModel.clearSelection()
                        }
                    } else {
                        Button {
                            if subscriptionService.currentTier == .free &&
                                activeCommitments.count >= AppConstants.maxFreeCommitments {
                                showingUpgrade = true
                            } else {
                                showingManualEntry = true
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    if !visibleCommitments.isEmpty {
                        Button(viewModel.isSelecting ? "Cancel" : "Select") {
                            UISelectionFeedbackGenerator().selectionChanged()
                            if viewModel.isSelecting {
                                viewModel.clearSelection()
                            } else {
                                viewModel.isSelecting = true
                            }
                        }
                    }
                }
                ToolbarItemGroup(placement: .topBarLeading) {
                    Menu {
                        Picker("Sort", selection: $viewModel.sortOrder) {
                            ForEach(LedgerViewModel.SortOrder.allCases, id: \.self) { order in
                                Text(order.rawValue).tag(order)
                            }
                        }
                        Divider()
                        // US-149: Let users reveal snoozed commitments or see
                        // only snoozed ones without leaving the Ledger.
                        Picker("Snoozed", selection: $viewModel.snoozeVisibility) {
                            ForEach(LedgerViewModel.SnoozeVisibility.allCases, id: \.self) { vis in
                                Text(vis.rawValue).tag(vis)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }

                    // US-148: Filter button with active-count badge so users see
                    // at a glance how many filters are narrowing their ledger.
                    Button {
                        showingFilter.toggle()
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: viewModel.hasActiveFilters
                                  ? "line.3.horizontal.decrease.circle.fill"
                                  : "line.3.horizontal.decrease.circle")
                            if viewModel.activeFilterCount > 0 {
                                Text("\(viewModel.activeFilterCount)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 4)
                                    .frame(minWidth: 14, minHeight: 14)
                                    .background(Color.accentColor)
                                    .clipShape(Capsule())
                                    .offset(x: 6, y: -6)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                    .accessibilityLabel(
                        viewModel.activeFilterCount > 0
                        ? "Filters, \(viewModel.activeFilterCount) active"
                        : "Filters"
                    )
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Search commitments")
            .overlay(alignment: .top) {
                if !networkMonitor.isConnected {
                    offlineBanner
                }
            }
            .overlay(alignment: .top) {
                if isProcessing && networkMonitor.isConnected {
                    processingBanner
                }
            }
            .overlay(alignment: .top) {
                if showBackfillReviewBanner {
                    backfillReviewBanner
                }
            }
            .overlay(alignment: .bottom) {
                VStack(spacing: 0) {
                    if !awaitingAIReview.isEmpty && !autoAnalyze {
                        aiReviewBanner
                    }
                    if !reviewQueueItems.isEmpty {
                        reviewQueueBanner
                    }
                    if subscriptionService.currentTier == .free && activeCommitments.count >= AppConstants.maxFreeCommitments {
                        upgradeBanner
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if viewModel.isSelecting && !viewModel.selectedCommitments.isEmpty {
                    bulkActionBar
                }
            }
            .overlay(alignment: .bottom) {
                if undoState != nil {
                    undoToast
                }
            }
            .confirmationDialog("Bulk Action", isPresented: $showingBulkAction) {
                Menu("Set Status") {
                    ForEach(CommitmentStatus.allCases) { status in
                        Button(status.label) {
                            performBulkWithUndo(status: status)
                        }
                    }
                }
                Menu("Set Category") {
                    ForEach(CommitmentCategory.allCases) { category in
                        Button(category.label) {
                            viewModel.bulkUpdateCategory(category, in: visibleCommitments)
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Dismiss Commitment?", isPresented: $showingDismissConfirm) {
                Button("Dismiss", role: .destructive) {
                    if let commitment = pendingSwipeCommitment {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        performWithUndo(commitment: commitment, newStatus: .dismissed)
                    }
                    pendingSwipeCommitment = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingSwipeCommitment = nil
                }
            } message: {
                if let commitment = pendingSwipeCommitment {
                    Text("\"\(commitment.summary)\" will be dismissed. You can undo this action for 5 seconds.")
                }
            }
            .alert("Mark as Fulfilled?", isPresented: $showingFulfillConfirm) {
                Button("Fulfill") {
                    if let commitment = pendingSwipeCommitment {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        performWithUndo(commitment: commitment, newStatus: .fulfilled)
                    }
                    pendingSwipeCommitment = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingSwipeCommitment = nil
                }
            } message: {
                if let commitment = pendingSwipeCommitment {
                    Text("\"\(commitment.summary)\" will be marked as fulfilled. You can undo this action for 5 seconds.")
                }
            }
            // US-149: Snooze preset picker
            .confirmationDialog(
                "Snooze commitment",
                isPresented: $showingSnoozeMenu,
                titleVisibility: .visible,
                presenting: pendingSnoozeCommitment
            ) { commitment in
                Button("1 day") {
                    viewModel.snooze(commitment, days: 1)
                    HapticsService.tap()
                    pendingSnoozeCommitment = nil
                }
                Button("3 days") {
                    viewModel.snooze(commitment, days: 3)
                    HapticsService.tap()
                    pendingSnoozeCommitment = nil
                }
                Button("7 days") {
                    viewModel.snooze(commitment, days: 7)
                    HapticsService.tap()
                    pendingSnoozeCommitment = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingSnoozeCommitment = nil
                }
            } message: { commitment in
                Text("Hide \"\(commitment.summary)\" from the active ledger. The deadline and reminders stay on the original date.")
            }
            .sheet(isPresented: $showingAIReview) {
                if let text = pendingAIText {
                    AITextReviewView(
                        extractedText: text,
                        onApprove: {
                            pendingAICallback?(text)
                            showingAIReview = false
                        },
                        onEdit: { editedText in
                            pendingAICallback?(editedText)
                            showingAIReview = false
                        },
                        onSkip: {
                            pendingAICallback?(nil)
                            showingAIReview = false
                        }
                    )
                }
            }
            .sheet(isPresented: $showingManualEntry) {
                ManualEntryView()
            }
            .sheet(isPresented: $showingFilter) {
                FilterView(
                    selectedStatus: $viewModel.filterStatus,
                    selectedEntityName: $viewModel.filterEntityName,
                    hasDeadlineOnly: $viewModel.filterHasDeadlineOnly,
                    dateRangeStart: $viewModel.filterDateStart,
                    dateRangeEnd: $viewModel.filterDateEnd,
                    selectedCategory: $viewModel.filterCategory,
                    amountMin: $viewModel.filterAmountMin,
                    amountMax: $viewModel.filterAmountMax
                )
                .presentationDetents([.large])
            }
            .sheet(isPresented: $showingUpgrade) {
                NavigationStack {
                    SubscriptionView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { showingUpgrade = false }
                            }
                        }
                }
            }
            .sheet(isPresented: $showingReviewQueue) {
                ReviewQueueView()
            }
            .sheet(isPresented: $showingBackfill) {
                NavigationStack {
                    BackfillView {
                        showingBackfill = false
                    }
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showingBackfill = false }
                        }
                    }
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    scenePhaseBadgeTask?.cancel()
                    scenePhaseBadgeTask = Task {
                        await StatusUpdateService.processAndUpdateBadge(in: modelContext)
                    }
                    processOnForeground()
                    syncIfProPlus()
                    PhotoCleanupService.cleanupStaleReferences(in: modelContext)
                    // US-149: Clear any snoozes whose date has passed so the
                    // commitment re-enters the active ledger and a fresh
                    // deadline reminder can be scheduled.
                    wakeExpiredSnoozes()
                    // US-151: Refresh the Live Activity for the next-due
                    // pending commitment on every foreground.
                    reconcileLiveActivity()
                } else if newPhase == .background {
                    // Mark current time so "New" badges clear next session
                    (UserDefaults(suiteName: AppConstants.appGroupIdentifier) ?? .standard).set(Date.now, forKey: "lastViewedDate")
                    // US-154: Cancel long-running tasks on background; the OS
                    // will suspend us anyway, but explicit cancellation lets
                    // batched operations short-circuit cleanly.
                    cancelInFlightTasks()
                }
            }
            .onDisappear {
                // US-154: NavigationStack may reuse the LedgerView instance, but
                // scene transitions route through here on tab swaps too. Cancel
                // in-flight work to free up the main actor and stop burning
                // network/AI quota while the user is elsewhere.
                cancelInFlightTasks()
            }
        }
    }

    // MARK: - Hero header stats (US-136)

    private var headerPendingCount: Int {
        visibleCommitments.filter { $0.status == .pending || $0.status == .overdue }.count
    }

    private var headerWeeklyStats: (fulfilled: Int, total: Int, weekly: [Int]) {
        let cal = Calendar.current
        guard let weekStart = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: .now)) else {
            return (0, 0, Array(repeating: 0, count: 7))
        }
        var daily = Array(repeating: 0, count: 7)
        var fulfilled = 0
        var total = 0
        for c in visibleCommitments {
            if c.updatedAt >= weekStart {
                total += 1
                if c.status == .fulfilled {
                    fulfilled += 1
                    let dayIdx = cal.dateComponents([.day], from: weekStart, to: c.updatedAt).day ?? 0
                    if dayIdx >= 0 && dayIdx < 7 { daily[dayIdx] += 1 }
                }
            }
        }
        return (fulfilled, total, daily)
    }

    private var headerStreakDays: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        var streak = 0
        for offset in 0..<60 {
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { break }
            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            let anyFulfilled = visibleCommitments.contains { $0.status == .fulfilled && $0.updatedAt >= day && $0.updatedAt < next }
            if anyFulfilled { streak += 1 } else if offset > 0 { break } else { /* today empty: keep checking backwards */ }
        }
        return streak
    }

    private var ledgerHeroHeader: some View {
        let stats = headerWeeklyStats
        return LedgerHeaderView(
            pendingCount: headerPendingCount,
            fulfilledThisWeek: stats.fulfilled,
            totalThisWeek: stats.total,
            streakDays: headerStreakDays,
            weekly: stats.weekly
        )
        .padding(.horizontal)
        .padding(.top, SeddlySpacing.md)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var commitmentList: some View {
        // US-148: Resolve the displayed set once per render so both the results-count
        // header and the ForEach below share the same slice without recomputing
        // (memoization in LedgerViewModel short-circuits repeat calls anyway).
        let displayed = viewModel.sortedCommitments(visibleCommitments)
        let showingResultsLine = !viewModel.searchText.isEmpty || viewModel.activeFilterCount > 0
        let hasZeroResultsButDataExists = displayed.isEmpty && !visibleCommitments.isEmpty

        return List {
            Section {
                ledgerHeroHeader
            }

            if showingResultsLine {
                Section {
                    HStack(spacing: 6) {
                        Text("Showing \(displayed.count) of \(visibleCommitments.count)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if hasZeroResultsButDataExists {
                            Spacer()
                            Button("Clear filters") {
                                clearAllFilters()
                            }
                            .font(.caption2.weight(.semibold))
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Showing \(displayed.count) of \(visibleCommitments.count) commitments")
                }
                .listRowBackground(Color.clear)
            }

            if newCommitmentsCount > 0 {
                Section {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.accent)
                        Text("\(newCommitmentsCount) new commitment\(newCommitmentsCount == 1 ? "" : "s") detected")
                            .font(.subheadline)
                            .foregroundStyle(.accent)
                    }
                }
            }

            ForEach(displayed) { commitment in
                if viewModel.isSelecting {
                    Button {
                        viewModel.toggleSelection(for: commitment)
                    } label: {
                        HStack(spacing: SeddlySpacing.lg) {
                            Image(systemName: viewModel.isSelected(commitment) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(viewModel.isSelected(commitment) ? .accent : .secondary)
                            CommitmentCardView(commitment: commitment)
                        }
                    }
                    .foregroundStyle(.primary)
                    .accessibilityHint(viewModel.isSelected(commitment) ? "Double-tap to deselect" : "Double-tap to select for bulk action")
                } else {
                    NavigationLink(value: commitment) {
                        CommitmentCardView(commitment: commitment)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            pendingSwipeCommitment = commitment
                            showingDismissConfirm = true
                        } label: {
                            Label("Dismiss", systemImage: "xmark")
                        }
                        // US-149: Full-swipe snooze (3 days) on the trailing
                        // edge as a secondary action. Tap to get preset menu.
                        Button {
                            pendingSnoozeCommitment = commitment
                            showingSnoozeMenu = true
                        } label: {
                            Label("Snooze", systemImage: "bell.slash")
                        }
                        .tint(.orange)
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            pendingSwipeCommitment = commitment
                            showingFulfillConfirm = true
                        } label: {
                            Label("Fulfilled", systemImage: "checkmark")
                        }
                        .tint(.green)
                    }
                    .accessibilityHint("Swipe right to mark fulfilled, swipe left to dismiss or snooze")
                }
            }

            if viewModel.isSelecting {
                Section {
                    HStack {
                        Button("Select All") {
                            viewModel.selectAll(viewModel.sortedCommitments(visibleCommitments))
                        }
                        .font(.caption)
                        Spacer()
                        Text("\(viewModel.selectedCommitments.count) selected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if viewModel.hasMoreItems {
                Section {
                    HStack {
                        Spacer()
                        if viewModel.isLoadingMore {
                            ProgressView()
                        } else {
                            Button("Load More") {
                                viewModel.loadNextPage()
                            }
                            .font(.subheadline)
                        }
                        Spacer()
                    }
                    .onAppear {
                        viewModel.loadNextPage()
                    }
                }
            }
        }
        .refreshable {
            await refreshLedger()
        }
        .navigationDestination(for: LocalCommitment.self) { commitment in
            CommitmentDetailView(commitment: commitment)
        }
    }

    /// US-151: Shared LiveActivityService instance so reconcile calls target
    /// the same actor state across refresh cycles.
    private static let liveActivityService = LiveActivityService()

    /// Pushes the current pending-commitment snapshot to LiveActivityService
    /// so the Lock Screen / Dynamic Island reflect the soonest deadline.
    private func reconcileLiveActivity() {
        let snapshot = commitments
            .filter { $0.status == .pending && !$0.isSnoozed && $0.deadline != nil }
            .map {
                LiveActivityService.PendingCommitment(
                    id: $0.id,
                    entityName: $0.entityName,
                    summary: $0.summary,
                    deadline: $0.deadline ?? .now
                )
            }
        Task.detached(priority: .utility) {
            await LedgerView.liveActivityService.reconcile(pendingCommitments: snapshot)
        }
    }

    /// US-149: Wakes up commitments whose snoozedUntil has passed and
    /// reschedules their approach/overdue notifications so users get a
    /// fresh nudge once the snooze window ends.
    private func wakeExpiredSnoozes() {
        let woken = viewModel.wakeExpiredSnoozes(in: Array(commitments))
        guard !woken.isEmpty else { return }
        let wokenSet = Set(woken)
        let wokenCommitments = commitments.filter { wokenSet.contains($0.id) }
        Task.detached(priority: .utility) {
            let service = NotificationService()
            for commitment in wokenCommitments {
                await service.scheduleDeadlineApproaching(for: commitment)
                await service.scheduleDeadlinePassed(for: commitment)
            }
        }
        try? modelContext.save()
    }

    /// US-148: Reset all filters and the search field in one tap from the
    /// zero-results affordance.
    private func clearAllFilters() {
        viewModel.filterStatus = nil
        viewModel.filterEntityName = nil
        viewModel.filterHasDeadlineOnly = false
        viewModel.filterDateStart = nil
        viewModel.filterDateEnd = nil
        viewModel.filterCategory = nil
        viewModel.filterAmountMin = nil
        viewModel.filterAmountMax = nil
        viewModel.searchText = ""
    }

    private func refreshLedger() async {
        await StatusUpdateService.processAndUpdateBadge(in: modelContext)

        if subscriptionService.currentTier >= .pro {
            let processingService = ScreenshotProcessingService()
            let lastProcessed = UserDefaults(suiteName: AppConstants.appGroupIdentifier)?
                .object(forKey: "lastProcessedDate") as? Date

            let effectiveOffline = offlineMode || !networkMonitor.isConnected
            let aiEndpoint = effectiveOffline ? nil : AppConfiguration.aiExtractionEndpoint
            let authToken = aiEndpoint != nil ? await authService.validAccessToken() : nil

            let result = await processingService.processNewScreenshots(
                since: lastProcessed,
                context: modelContext,
                aiEndpoint: aiEndpoint,
                authToken: authToken,
                subscriptionTier: subscriptionService.currentTier,
                autoAnalyze: autoAnalyze,
                offlineMode: effectiveOffline
            )

            withAnimation {
                newCommitmentsCount = result.commitmentsDetected
            }

            if newCommitmentsCount > 0 {
                try? await Task.sleep(for: .seconds(5))
                withAnimation { newCommitmentsCount = 0 }
            }
        }

        if subscriptionService.currentTier == .proPlus, isSignedIn, networkMonitor.isConnected {
            if let cfg = AppConfiguration.supabase {
                let syncService = SyncService(supabaseURL: cfg.url, supabaseKey: cfg.anonKey, authService: authService)
                try? await syncService.pullCommitments(context: modelContext)
                try? await syncService.syncCommitments(context: modelContext)
            }
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private var backfillReviewBanner: some View {
        Button {
            showBackfillReviewBanner = false
        } label: {
            HStack {
                Image(systemName: "checklist")
                    .foregroundStyle(.accent)
                Text("Review your commitments — tap any to edit or dismiss")
                    .font(.caption)
                Spacer()
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .padding(.top, 4)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // US-153: Extracted to LedgerBannerViews for #Preview + reuse.
    private var offlineBanner: some View {
        LedgerOfflineBanner()
            .animation(.easeInOut, value: networkMonitor.isConnected)
    }

    private var processingBanner: some View { LedgerProcessingBanner() }

    private var aiReviewBanner: some View {
        Button {
            presentNextAIReview()
        } label: {
            HStack {
                Image(systemName: "eye.trianglebadge.exclamationmark")
                    .foregroundStyle(.blue)
                Text("\(awaitingAIReview.count) screenshot\(awaitingAIReview.count == 1 ? "" : "s") ready for AI analysis — review before sending")
                    .font(.caption)
                Spacer()
                Text("Review")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .padding(.bottom, 4)
    }

    private func presentNextAIReview() {
        guard let item = awaitingAIReview.first,
              let text = item.extractedText else { return }

        pendingAIText = text
        pendingAICallback = { approvedText in
            aiReviewTask?.cancel()
            aiReviewTask = Task {
                defer { Task { @MainActor in aiReviewTask = nil } }
                if let approvedText {
                    if let endpoint = AppConfiguration.aiExtractionEndpoint, networkMonitor.isConnected {
                        let service = ScreenshotProcessingService()
                        let token = await authService.validAccessToken()
                        _ = await service.processReviewedItem(
                            item,
                            approvedText: approvedText,
                            aiEndpoint: endpoint,
                            authToken: token,
                            context: modelContext
                        )
                        @AppStorage("approvedExtractionCount", store: LedgerView.appGroupDefaults) var count = 0
                        count += 1
                    } else {
                        // No AI endpoint configured (or offline) — preserve the
                        // user's approval by marking completed; the on-device
                        // rule-based path in processNewScreenshots already
                        // created a fallback LocalCommitment for this asset.
                        item.processingStatus = .completed
                        try? modelContext.save()
                    }
                } else {
                    // User skipped — mark as completed without AI
                    item.processingStatus = .skipped
                    try? modelContext.save()
                }
            }
        }
        showingAIReview = true
    }

    private var reviewQueueBanner: some View {
        Button {
            showingReviewQueue = true
        } label: {
            HStack {
                Image(systemName: "eye.circle.fill")
                    .foregroundStyle(.yellow)
                Text("\(reviewQueueItems.count) item\(reviewQueueItems.count == 1 ? "" : "s") to review")
                    .font(.caption)
                Spacer()
                Text("Review")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .padding(.bottom, 4)
    }

    private var bulkActionBar: some View {
        HStack(spacing: 16) {
            Button {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                viewModel.bulkUpdateStatus(.fulfilled, in: visibleCommitments)
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "checkmark.circle")
                    Text("Fulfill").font(.caption2)
                }
            }

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                viewModel.bulkUpdateStatus(.dismissed, in: visibleCommitments)
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "xmark.circle")
                    Text("Dismiss").font(.caption2)
                }
            }

            Button {
                showingBulkAction = true
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "ellipsis.circle")
                    Text("More").font(.caption2)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: SeddlyRadius.large))
        .padding(.horizontal)
        .padding(.bottom)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Bulk actions for \(viewModel.selectedCommitments.count) selected items")
    }

    private var totalActiveCount: Int {
        commitments.filter { $0.status != .dismissed && $0.status != .fulfilled }.count
    }

    private var hiddenCount: Int {
        max(0, totalActiveCount - AppConstants.maxFreeCommitments)
    }

    private var upgradeBanner: some View {
        Button {
            showingUpgrade = true
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundStyle(.accent)
                    if hiddenCount > 0 {
                        Text("You have \(totalActiveCount) commitments but your free plan allows \(AppConstants.maxFreeCommitments).")
                            .font(.caption)
                            .fontWeight(.medium)
                    } else {
                        Text("Free limit reached (\(AppConstants.maxFreeCommitments)).")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if hiddenCount > 0 {
                    Text("Upgrade to Pro to track all \(totalActiveCount) — \(hiddenCount) commitment\(hiddenCount == 1 ? " is" : "s are") hidden.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Upgrade to Pro for unlimited commitments.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .padding(.bottom)
    }

    private func processOnForeground() {
        // Free tier: no auto-scan
        guard subscriptionService.currentTier >= .pro else { return }
        guard !isProcessing else { return }
        isProcessing = true

        foregroundProcessTask?.cancel()
        foregroundProcessTask = Task {
            defer { Task { @MainActor in foregroundProcessTask = nil } }
            let processingService = ScreenshotProcessingService()
            let lastProcessed = UserDefaults(suiteName: AppConstants.appGroupIdentifier)?
                .object(forKey: "lastProcessedDate") as? Date

            let effectiveOffline = offlineMode || !networkMonitor.isConnected
            let aiEndpoint = effectiveOffline ? nil : AppConfiguration.aiExtractionEndpoint
            let authToken = aiEndpoint != nil ? await authService.validAccessToken() : nil

            let result = await processingService.processNewScreenshots(
                since: lastProcessed,
                context: modelContext,
                aiEndpoint: aiEndpoint,
                authToken: authToken,
                subscriptionTier: subscriptionService.currentTier,
                autoAnalyze: autoAnalyze,
                offlineMode: effectiveOffline
            )

            withAnimation {
                newCommitmentsCount = result.commitmentsDetected
                isProcessing = false
            }

            // Update daily digest with real data
            updateDailyDigest(
                screenshotsProcessed: result.screenshotsProcessed,
                commitmentsDetected: result.commitmentsDetected
            )

            if newCommitmentsCount > 0 {
                try? await Task.sleep(for: .seconds(5))
                withAnimation { newCommitmentsCount = 0 }
            }
        }
    }

    private func syncIfProPlus() {
        guard subscriptionService.currentTier == .proPlus, isSignedIn, networkMonitor.isConnected else { return }

        syncTask?.cancel()
        syncTask = Task {
            defer { Task { @MainActor in syncTask = nil } }
            guard let cfg = AppConfiguration.supabase else { return }
            let syncService = SyncService(supabaseURL: cfg.url, supabaseKey: cfg.anonKey, authService: authService)
            if Task.isCancelled { return }
            try? await syncService.pullCommitments(context: modelContext)
            if Task.isCancelled { return }
            try? await syncService.syncCommitments(context: modelContext)
        }
    }

    /// US-154: Cancels every long-running Task this view started so they don't
    /// continue doing work after the user has moved on.
    private func cancelInFlightTasks() {
        foregroundProcessTask?.cancel()
        foregroundProcessTask = nil
        syncTask?.cancel()
        syncTask = nil
        scenePhaseBadgeTask?.cancel()
        scenePhaseBadgeTask = nil
        aiReviewTask?.cancel()
        aiReviewTask = nil
    }

    private func updateDailyDigest(screenshotsProcessed: Int, commitmentsDetected: Int) {
        // Count upcoming deadlines this week
        let weekFromNow = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
        let upcomingDeadlines = visibleCommitments.filter { commitment in
            guard let deadline = commitment.deadline,
                  commitment.status == .pending else { return false }
            return deadline > .now && deadline <= weekFromNow
        }.count

        // Get user-configured digest time
        let digestTime = (UserDefaults(suiteName: AppConstants.appGroupIdentifier) ?? .standard).object(forKey: "dailyDigestTime") as? [String: Int]
        let hour = digestTime?["hour"] ?? 20
        let minute = digestTime?["minute"] ?? 0

        DigestNotificationService.scheduleDailyDigest(
            hour: hour,
            minute: minute,
            screenshotsProcessed: screenshotsProcessed,
            commitmentsDetected: commitmentsDetected,
            upcomingDeadlines: upcomingDeadlines
        )
    }

    // MARK: - Undo Support

    private struct UndoState {
        let commitments: [(LocalCommitment, CommitmentStatus)]
        let label: String
    }

    private func performWithUndo(commitment: LocalCommitment, newStatus: CommitmentStatus) {
        let previousStatus = commitment.status
        if newStatus == .fulfilled {
            viewModel.fulfill(commitment)
        } else if newStatus == .dismissed {
            viewModel.dismiss(commitment)
        } else {
            commitment.status = newStatus
            commitment.updatedAt = .now
        }
        showUndo(
            commitments: [(commitment, previousStatus)],
            label: "\(newStatus.label): \(commitment.summary)"
        )
    }

    private func performBulkWithUndo(status: CommitmentStatus) {
        let affected = visibleCommitments.filter { viewModel.selectedCommitments.contains($0.id) }
        let previousStates = affected.map { ($0, $0.status) }
        viewModel.bulkUpdateStatus(status, in: visibleCommitments)
        showUndo(
            commitments: previousStates,
            label: "Bulk \(status.label) (\(affected.count) items)"
        )
    }

    private func showUndo(commitments: [(LocalCommitment, CommitmentStatus)], label: String) {
        // Cancel any existing undo timer
        undoDismissTask?.cancel()

        withAnimation {
            undoState = UndoState(commitments: commitments, label: label)
        }

        // Auto-dismiss after 5 seconds
        undoDismissTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            withAnimation { undoState = nil }
        }
    }

    private func performUndo() {
        guard let state = undoState else { return }
        undoDismissTask?.cancel()

        for (commitment, previousStatus) in state.commitments {
            commitment.status = previousStatus
            commitment.updatedAt = .now
        }

        withAnimation { undoState = nil }
    }

    // US-153: Extracted to LedgerBannerViews.
    private var undoToast: some View {
        LedgerUndoToast(
            label: undoState?.label ?? "",
            onUndo: { performUndo() }
        )
    }
}

#Preview {
    LedgerView()
        .modelContainer(for: [LocalCommitment.self, LocalEntity.self, ProcessingQueue.self], inMemory: true)
        .environment(SubscriptionService())
}
