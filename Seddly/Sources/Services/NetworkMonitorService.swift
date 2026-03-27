import Foundation
import Network

@Observable
final class NetworkMonitorService {
    static let shared = NetworkMonitorService()

    private(set) var isConnected = true
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.pearsonmedia.Seddly.networkMonitor")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
