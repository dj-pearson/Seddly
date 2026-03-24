import Photos
import SwiftData

/// Monitors the Photos library for deleted screenshots and cleans up
/// stale references in the local database.
struct PhotoCleanupService {
    /// Removes commitments and processing queue items whose referenced
    /// screenshot has been deleted from the Photos library.
    static func cleanupStaleReferences(in context: ModelContext) {
        let descriptor = FetchDescriptor<LocalCommitment>(
            predicate: #Predicate { $0.screenshotAssetID != nil }
        )
        guard let commitments = try? context.fetch(descriptor) else { return }

        // Collect all referenced asset IDs
        let assetIDs = commitments.compactMap(\.screenshotAssetID).filter { !$0.hasPrefix("share-") }
        guard !assetIDs.isEmpty else { return }

        // Check which assets still exist in the Photos library
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: assetIDs, options: nil)
        var existingIDs: Set<String> = []
        fetchResult.enumerateObjects { asset, _, _ in
            existingIDs.insert(asset.localIdentifier)
        }

        // Clear references for deleted photos (don't delete the commitment itself)
        var cleanedCount = 0
        for commitment in commitments {
            guard let assetID = commitment.screenshotAssetID,
                  !assetID.hasPrefix("share-"),
                  !existingIDs.contains(assetID) else { continue }
            commitment.screenshotAssetID = nil
            cleanedCount += 1
        }

        // Also clean up processing queue
        let queueDescriptor = FetchDescriptor<ProcessingQueue>()
        if let queueItems = try? context.fetch(queueDescriptor) {
            for item in queueItems {
                let id = item.screenshotAssetID
                if !id.hasPrefix("share-"), !existingIDs.contains(id) {
                    context.delete(item)
                }
            }
        }

        if cleanedCount > 0 {
            try? context.save()
        }
    }
}
