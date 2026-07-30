import Foundation
import Photos

actor ScreenshotService {
    /// Cache for fetchNewScreenshots results, expires after 30 seconds.
    private var cachedAssets: [PHAsset]?
    private var cachedSince: Date??
    private var cacheTimestamp: Date?
    private static let cacheTTL: TimeInterval = 30

    func requestAuthorization() async -> PHAuthorizationStatus {
        await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    func fetchNewScreenshots(since date: Date?) -> [PHAsset] {
        // Return cached results if still valid and same query
        if let cached = cachedAssets,
           let timestamp = cacheTimestamp,
           cachedSince == date,
           Date().timeIntervalSince(timestamp) < Self.cacheTTL {
            return cached
        }

        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        if let date {
            fetchOptions.predicate = NSPredicate(format: "creationDate > %@", date as NSDate)
        }

        guard let screenshotAlbum = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum,
            subtype: .smartAlbumScreenshots,
            options: nil
        ).firstObject else {
            return []
        }

        let results = PHAsset.fetchAssets(in: screenshotAlbum, options: fetchOptions)
        var assets: [PHAsset] = []
        results.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }

        // Cache results
        cachedAssets = assets
        cachedSince = date
        cacheTimestamp = Date()

        return assets
    }

    /// Invalidates the cache (e.g. when user triggers manual refresh or new screenshot is detected).
    func invalidateCache() {
        cachedAssets = nil
        cacheTimestamp = nil
    }
}
