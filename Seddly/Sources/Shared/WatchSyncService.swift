import Foundation
import WatchConnectivity
import SwiftData
import Combine

/// US-197: Swift 6 strict concurrency rejected `static let shared` here —
/// "static property 'shared' is not concurrency-safe because non-'Sendable'
/// type 'WatchSyncService' may have shared mutable state". The observation is
/// correct: this type holds unguarded mutable state (`isReachable`,
/// `syncStatus`, `pendingTransfers`, `modelContainer`) and is `@Observable`,
/// so SwiftUI reads it from the main actor.
///
/// The state was already main-actor-confined in practice — every
/// WCSessionDelegate callback below already wraps its body in
/// `Task { @MainActor in ... }`. Declaring the isolation makes that contract
/// explicit and checkable rather than incidental. The delegate methods are
/// `nonisolated` because WCSessionDelegate is not main-actor-isolated; their
/// bodies are unchanged, since they already hop.
@MainActor
@Observable
final class WatchSyncService: NSObject, WCSessionDelegate {
    static let shared = WatchSyncService()

    var isReachable = false
    var lastSyncDate: Date?
    var syncStatus: WatchSyncStatus = .idle

    enum WatchSyncStatus: String {
        case idle
        case syncing
        case synced
        case unreachable
    }

    private var session: WCSession?
    private var pendingTransfers: [[String: Any]] = []
    private var modelContainer: ModelContainer?

    private override init() {
        super.init()
    }

    func activate(with container: ModelContainer) {
        guard WCSession.isSupported() else { return }
        modelContainer = container
        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }

    // MARK: - Send Updates

    func sendCommitmentUpdate(id: UUID, action: String, entityName: String, summary: String, statusRaw: String) {
        let userInfo: [String: Any] = [
            "action": action,
            "commitmentID": id.uuidString,
            "entityName": entityName,
            "summary": summary,
            "statusRaw": statusRaw,
            "timestamp": Date().timeIntervalSince1970
        ]
        transferUserInfo(userInfo)
    }

    func requestSync() {
        guard let session, session.activationState == .activated else { return }
        syncStatus = .syncing
        let message: [String: Any] = [
            "action": "requestSync",
            "timestamp": Date().timeIntervalSince1970
        ]
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil)
        }
        flushPendingTransfers()
        syncStatus = session.isReachable ? .synced : .unreachable
        lastSyncDate = Date()
    }

    func sendFulfillment(commitmentID: UUID) {
        let userInfo: [String: Any] = [
            "action": "fulfilled",
            "commitmentID": commitmentID.uuidString,
            "statusRaw": "completed",
            "timestamp": Date().timeIntervalSince1970
        ]
        transferUserInfo(userInfo)
    }

    private func transferUserInfo(_ userInfo: [String: Any]) {
        guard let session, session.activationState == .activated else {
            pendingTransfers.append(userInfo)
            return
        }

        #if os(iOS)
        if session.isReachable || session.isPaired {
            session.transferUserInfo(userInfo)
        } else {
            pendingTransfers.append(userInfo)
            syncStatus = .unreachable
        }
        #else
        session.transferUserInfo(userInfo)
        #endif
    }

    private func flushPendingTransfers() {
        guard let session, session.activationState == .activated else { return }
        let transfers = pendingTransfers
        pendingTransfers.removeAll()
        for info in transfers {
            session.transferUserInfo(info)
        }
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            if activationState == .activated {
                self.isReachable = session.isReachable
                self.syncStatus = session.isReachable ? .synced : .unreachable
                self.flushPendingTransfers()
            }
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        Task { @MainActor in
            self.syncStatus = .unreachable
        }
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        Task { @MainActor in
            self.syncStatus = .unreachable
        }
        session.activate()
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
            self.syncStatus = session.isReachable ? .synced : .unreachable
        }
    }
    #endif

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
            self.syncStatus = session.isReachable ? .synced : .unreachable
            if session.isReachable {
                self.flushPendingTransfers()
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let action = userInfo["action"] as? String,
              let commitmentIDString = userInfo["commitmentID"] as? String,
              let commitmentID = UUID(uuidString: commitmentIDString) else { return }

        Task { @MainActor in
            self.syncStatus = .syncing
            self.handleReceivedUpdate(action: action, commitmentID: commitmentID, userInfo: userInfo)
            self.lastSyncDate = Date()
            self.syncStatus = .synced
        }
    }

    @MainActor
    private func handleReceivedUpdate(action: String, commitmentID: UUID, userInfo: [String: Any]) {
        guard let modelContainer else { return }
        let context = modelContainer.mainContext

        switch action {
        case "fulfilled", "updated":
            let descriptor = FetchDescriptor<LocalCommitment>(
                predicate: #Predicate { $0.id == commitmentID }
            )
            do {
                guard let commitment = try context.fetch(descriptor).first else { return }
                if let statusRaw = userInfo["statusRaw"] as? String {
                    commitment.statusRaw = statusRaw
                }
                commitment.updatedAt = Date()
                try context.save()
            } catch {
                AppLogger.sync.error("WatchSync: failed to update commitment \(commitmentID): \(error.localizedDescription)")
            }

        case "created":
            // New commitments are created through the shared SwiftData container.
            // The receiving side just needs to know to refresh its UI.
            break

        case "deleted":
            let descriptor = FetchDescriptor<LocalCommitment>(
                predicate: #Predicate { $0.id == commitmentID }
            )
            do {
                if let commitment = try context.fetch(descriptor).first {
                    context.delete(commitment)
                    try context.save()
                }
            } catch {
                AppLogger.sync.error("WatchSync: failed to delete commitment \(commitmentID): \(error.localizedDescription)")
            }

        default:
            break
        }
    }
}
