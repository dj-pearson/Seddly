import SwiftUI
import SwiftData

@Observable
final class LedgerViewModel {
    private static let sortOrderKey = "ledger_sortOrder"
    private static let filterStatusKey = "ledger_filterStatus"
    private static let filterCategoryKey = "ledger_filterCategory"

    var sortOrder: SortOrder = .deadline {
        didSet {
            UserDefaults.standard.set(sortOrder.rawValue, forKey: Self.sortOrderKey)
            cachedSortKey = nil
        }
    }
    var filterStatus: CommitmentStatus? {
        didSet {
            UserDefaults.standard.set(filterStatus?.rawValue, forKey: Self.filterStatusKey)
            cachedSortKey = nil
        }
    }
    var filterEntityName: String? { didSet { cachedSortKey = nil } }
    var filterHasDeadlineOnly = false { didSet { cachedSortKey = nil } }
    var filterDateStart: Date? { didSet { cachedSortKey = nil } }
    var filterDateEnd: Date? { didSet { cachedSortKey = nil } }
    var filterCategory: CommitmentCategory? {
        didSet {
            UserDefaults.standard.set(filterCategory?.rawValue, forKey: Self.filterCategoryKey)
            cachedSortKey = nil
        }
    }
    var filterAmountMin: Double? { didSet { cachedSortKey = nil } }
    var filterAmountMax: Double? { didSet { cachedSortKey = nil } }
    /// US-149: Controls whether snoozed commitments are hidden (default),
    /// shown exclusively, or included alongside the rest of the ledger.
    var snoozeVisibility: SnoozeVisibility = .hideSnoozed {
        didSet { cachedSortKey = nil }
    }
    var searchText = "" { didSet { cachedSortKey = nil } }

    enum SnoozeVisibility: String, CaseIterable, Hashable {
        case hideSnoozed = "Hide snoozed"
        case snoozedOnly = "Snoozed only"
        case showAll     = "Show all"
    }

    // MARK: - Filter/sort memoization (US-145)
    /// Caches the last filter+sort result so repeated renders with identical inputs
    /// skip the O(n) filter/sort/search pipeline. Invalidated whenever any filter,
    /// sort, search, pagination, or input-identity signal changes.
    private var cachedSortKey: Int?
    private var cachedSortResult: [LocalCommitment] = []

    init() {
        if let savedSort = UserDefaults.standard.string(forKey: Self.sortOrderKey),
           let sort = SortOrder(rawValue: savedSort) {
            sortOrder = sort
        }
        if let savedStatus = UserDefaults.standard.string(forKey: Self.filterStatusKey),
           let status = CommitmentStatus(rawValue: savedStatus) {
            filterStatus = status
        }
        if let savedCategory = UserDefaults.standard.string(forKey: Self.filterCategoryKey),
           let category = CommitmentCategory(rawValue: savedCategory) {
            filterCategory = category
        }
    }

    // MARK: - Pagination

    static let pageSize = 50
    /// Upper ceiling passed to SwiftData's FetchDescriptor.fetchLimit so we never
    /// materialize an unbounded number of commitments during Ledger rendering.
    /// Users who exceed this can still reach older records via search.
    static let fetchCeiling = 1500
    var displayedCount = 50
    var isLoadingMore = false
    var hasMoreItems = false

    func loadNextPage() {
        guard hasMoreItems, !isLoadingMore else { return }
        isLoadingMore = true
        displayedCount += Self.pageSize
        cachedSortKey = nil
        isLoadingMore = false
    }

    func resetPagination() {
        displayedCount = Self.pageSize
        isLoadingMore = false
        hasMoreItems = false
        cachedSortKey = nil
    }

    var hasActiveFilters: Bool {
        filterStatus != nil || filterEntityName != nil || filterHasDeadlineOnly || filterDateStart != nil || filterCategory != nil || filterAmountMin != nil || filterAmountMax != nil
    }

    /// US-148: Count of filters currently applied (excluding freeform search).
    var activeFilterCount: Int {
        var count = 0
        if filterStatus != nil { count += 1 }
        if filterEntityName != nil { count += 1 }
        if filterHasDeadlineOnly { count += 1 }
        if filterDateStart != nil || filterDateEnd != nil { count += 1 }
        if filterCategory != nil { count += 1 }
        if filterAmountMin != nil || filterAmountMax != nil { count += 1 }
        return count
    }

    enum SortOrder: String, CaseIterable {
        case deadline = "Deadline"
        case entity = "Entity"
        case dateAdded = "Date Added"
        case status = "Status"
    }

    /// Builds a hash of inputs that affect sort/filter output. Used to short-circuit
    /// repeated calls during SwiftUI re-renders when nothing relevant has changed.
    private func computeSortKey(for commitments: [LocalCommitment]) -> Int {
        var hasher = Hasher()
        hasher.combine(commitments.count)
        // A lightweight identity signal: first + last id + max updatedAt.
        if let first = commitments.first { hasher.combine(first.id); hasher.combine(first.updatedAt) }
        if let last = commitments.last { hasher.combine(last.id); hasher.combine(last.updatedAt) }
        hasher.combine(sortOrder)
        hasher.combine(filterStatus)
        hasher.combine(filterEntityName)
        hasher.combine(filterHasDeadlineOnly)
        hasher.combine(filterDateStart)
        hasher.combine(filterDateEnd)
        hasher.combine(filterCategory)
        hasher.combine(filterAmountMin)
        hasher.combine(filterAmountMax)
        hasher.combine(searchText)
        hasher.combine(snoozeVisibility)
        hasher.combine(displayedCount)
        return hasher.finalize()
    }

    func sortedCommitments(_ commitments: [LocalCommitment]) -> [LocalCommitment] {
        let key = computeSortKey(for: commitments)
        if cachedSortKey == key { return cachedSortResult }

        var filtered = commitments

        // US-149: Snooze visibility (applied before other filters so the count
        // reported by activeFilterCount stays meaningful).
        switch snoozeVisibility {
        case .hideSnoozed:
            filtered = filtered.filter { !$0.isSnoozed }
        case .snoozedOnly:
            filtered = filtered.filter { $0.isSnoozed }
        case .showAll:
            break
        }

        // Status filter
        if let filterStatus {
            filtered = filtered.filter { $0.status == filterStatus }
        }

        // Entity filter
        if let filterEntityName {
            filtered = filtered.filter { $0.entityName == filterEntityName }
        }

        // Deadline filter
        if filterHasDeadlineOnly {
            filtered = filtered.filter { $0.deadline != nil }
        }

        // Category filter
        if let filterCategory {
            filtered = filtered.filter { $0.category == filterCategory }
        }

        // Amount filter
        if let min = filterAmountMin {
            filtered = filtered.filter {
                guard let amount = $0.dollarAmount else { return false }
                return NSDecimalNumber(decimal: amount).doubleValue >= min
            }
        }
        if let max = filterAmountMax {
            filtered = filtered.filter {
                guard let amount = $0.dollarAmount else { return false }
                return NSDecimalNumber(decimal: amount).doubleValue <= max
            }
        }

        // Date range filter
        if let start = filterDateStart {
            filtered = filtered.filter { $0.createdAt >= start }
        }
        if let end = filterDateEnd {
            filtered = filtered.filter { $0.createdAt <= end }
        }

        // Search
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            filtered = filtered.filter {
                $0.summary.lowercased().contains(query) ||
                $0.entityName.lowercased().contains(query) ||
                $0.fullText.lowercased().contains(query)
            }
        }

        let sorted: [LocalCommitment]
        switch sortOrder {
        case .deadline:
            sorted = filtered.sorted {
                ($0.deadline ?? .distantFuture) < ($1.deadline ?? .distantFuture)
            }
        case .entity:
            sorted = filtered.sorted { $0.entityName < $1.entityName }
        case .dateAdded:
            sorted = filtered.sorted { $0.createdAt > $1.createdAt }
        case .status:
            let statusPriority: [CommitmentStatus: Int] = [
                .overdue: 0, .pending: 1, .disputed: 2, .fulfilled: 3, .dismissed: 4
            ]
            sorted = filtered.sorted {
                (statusPriority[$0.status] ?? 5) < (statusPriority[$1.status] ?? 5)
            }
        }

        // Apply pagination
        hasMoreItems = sorted.count > displayedCount
        let paged = Array(sorted.prefix(displayedCount))

        cachedSortKey = key
        cachedSortResult = paged
        return paged
    }

    /// Applies history limits based on subscription tier.
    /// Free: 30 days. Pro: 1 year. Pro+: unlimited.
    func applyHistoryLimit(_ commitments: [LocalCommitment], tier: SubscriptionService.SubscriptionTier) -> [LocalCommitment] {
        switch tier {
        case .free:
            let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .distantPast
            return commitments.filter { $0.createdAt >= cutoff }
        case .pro:
            let cutoff = Calendar.current.date(byAdding: .year, value: -1, to: .now) ?? .distantPast
            return commitments.filter { $0.createdAt >= cutoff }
        case .proPlus:
            return commitments
        }
    }

    /// Legacy convenience for free tier
    func applyFreeTierHistoryLimit(_ commitments: [LocalCommitment]) -> [LocalCommitment] {
        applyHistoryLimit(commitments, tier: .free)
    }

    func fulfill(_ commitment: LocalCommitment) {
        commitment.status = .fulfilled
        commitment.updatedAt = .now
        // Record as successful detection if it was auto-detected
        if commitment.source == .auto {
            ClassifierFeedbackService.recordAutoDetection()
        }
        WatchSyncService.shared.sendCommitmentUpdate(
            id: commitment.id, action: "updated",
            entityName: commitment.entityName, summary: commitment.summary,
            statusRaw: commitment.statusRaw
        )
    }

    func dismiss(_ commitment: LocalCommitment) {
        commitment.status = .dismissed
        commitment.updatedAt = .now
        // Record as false positive if it was auto-detected
        if commitment.source == .auto {
            ClassifierFeedbackService.recordDismissal()
        }
        WatchSyncService.shared.sendCommitmentUpdate(
            id: commitment.id, action: "updated",
            entityName: commitment.entityName, summary: commitment.summary,
            statusRaw: commitment.statusRaw
        )
    }

    // MARK: - Snooze (US-149)

    /// Snoozes a commitment by setting `snoozedUntil` to now + `days` days.
    /// The original deadline is untouched.
    func snooze(_ commitment: LocalCommitment, days: Int) {
        let target = Calendar.current.date(byAdding: .day, value: days, to: .now) ?? .now
        snooze(commitment, until: target)
    }

    func snooze(_ commitment: LocalCommitment, until date: Date) {
        commitment.snoozedUntil = date
        commitment.updatedAt = .now
        cachedSortKey = nil
    }

    /// Clears `snoozedUntil` so the commitment re-enters the active ledger.
    func unsnooze(_ commitment: LocalCommitment) {
        commitment.snoozedUntil = nil
        commitment.updatedAt = .now
        cachedSortKey = nil
    }

    /// Iterates the given commitments and clears any `snoozedUntil` that has
    /// already passed. Intended to be called on foreground. Returns the IDs
    /// of commitments that were woken so callers can re-schedule reminders.
    @discardableResult
    func wakeExpiredSnoozes(in commitments: [LocalCommitment]) -> [UUID] {
        var woken: [UUID] = []
        for commitment in commitments {
            guard let until = commitment.snoozedUntil, until <= .now else { continue }
            commitment.snoozedUntil = nil
            commitment.updatedAt = .now
            woken.append(commitment.id)
        }
        if !woken.isEmpty {
            cachedSortKey = nil
        }
        return woken
    }

    // MARK: - Bulk Edit

    var isSelecting = false
    var selectedCommitments: Set<UUID> = []

    func toggleSelection(for commitment: LocalCommitment) {
        if selectedCommitments.contains(commitment.id) {
            selectedCommitments.remove(commitment.id)
        } else {
            selectedCommitments.insert(commitment.id)
        }
    }

    func isSelected(_ commitment: LocalCommitment) -> Bool {
        selectedCommitments.contains(commitment.id)
    }

    func selectAll(_ commitments: [LocalCommitment]) {
        selectedCommitments = Set(commitments.map(\.id))
    }

    func clearSelection() {
        selectedCommitments.removeAll()
        isSelecting = false
    }

    func bulkUpdateStatus(_ status: CommitmentStatus, in commitments: [LocalCommitment]) {
        for commitment in commitments where selectedCommitments.contains(commitment.id) {
            commitment.status = status
            commitment.updatedAt = .now
            WatchSyncService.shared.sendCommitmentUpdate(
                id: commitment.id, action: "updated",
                entityName: commitment.entityName, summary: commitment.summary,
                statusRaw: commitment.statusRaw
            )
        }
        clearSelection()
    }

    func bulkUpdateCategory(_ category: CommitmentCategory, in commitments: [LocalCommitment]) {
        for commitment in commitments where selectedCommitments.contains(commitment.id) {
            commitment.category = category
            commitment.updatedAt = .now
        }
        clearSelection()
    }

    func bulkReassignEntity(_ entityName: String, entity: LocalEntity?, in commitments: [LocalCommitment]) {
        for commitment in commitments where selectedCommitments.contains(commitment.id) {
            commitment.entityName = entityName
            commitment.entity = entity
            commitment.updatedAt = .now
        }
        clearSelection()
    }
}
