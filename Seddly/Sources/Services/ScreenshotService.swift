import Photos

actor ScreenshotService {
    func requestAuthorization() async -> PHAuthorizationStatus {
        await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    func fetchNewScreenshots(since date: Date?) -> [PHAsset] {
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
        return assets
    }
}
