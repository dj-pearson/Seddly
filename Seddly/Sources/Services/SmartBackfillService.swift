import Foundation
import Photos
import UIKit

/// Groups related screenshots from the same conversation thread before AI extraction
/// to produce higher-quality, deduplicated commitments.
actor SmartBackfillService {
    private let ocrService = OCRService()
    private let classifierService = ClassifierService()

    struct ScreenshotGroup: Identifiable {
        let id = UUID()
        var assets: [PHAsset]
        var texts: [String]
        var combinedText: String { texts.joined(separator: "\n---\n") }
        var earliestDate: Date? { assets.compactMap(\.creationDate).min() }
    }

    /// Groups screenshots taken within a short time window with similar content.
    func groupRelatedScreenshots(assets: [PHAsset]) async -> [ScreenshotGroup] {
        // First pass: extract text from all assets
        var assetTexts: [(asset: PHAsset, text: String)] = []

        for asset in assets {
            guard let image = await loadImage(from: asset),
                  let text = try? await ocrService.recognizeText(in: image) else { continue }

            let category = await classifierService.classify(image, ocrText: text)
            guard category.shouldProcess else { continue }

            assetTexts.append((asset, text))
        }

        // Second pass: group by time proximity (within 5 minutes) and content similarity
        var groups: [ScreenshotGroup] = []
        var used = Set<String>()

        for item in assetTexts {
            let assetID = item.asset.localIdentifier
            guard !used.contains(assetID) else { continue }
            used.insert(assetID)

            var group = ScreenshotGroup(assets: [item.asset], texts: [item.text])

            // Find related screenshots
            for other in assetTexts {
                let otherID = other.asset.localIdentifier
                guard !used.contains(otherID) else { continue }

                let isTimeClose = areWithinMinutes(item.asset, other.asset, minutes: 5)
                let isContentSimilar = textSimilarity(item.text, other.text) > 0.3

                if isTimeClose && isContentSimilar {
                    group.assets.append(other.asset)
                    group.texts.append(other.text)
                    used.insert(otherID)
                }
            }

            groups.append(group)
        }

        return groups
    }

    private func areWithinMinutes(_ a: PHAsset, _ b: PHAsset, minutes: Int) -> Bool {
        guard let dateA = a.creationDate, let dateB = b.creationDate else { return false }
        return abs(dateA.timeIntervalSince(dateB)) <= Double(minutes * 60)
    }

    /// Simple Jaccard similarity on word sets.
    private func textSimilarity(_ a: String, _ b: String) -> Double {
        let wordsA = Set(a.lowercased().split(separator: " ").map(String.init))
        let wordsB = Set(b.lowercased().split(separator: " ").map(String.init))

        guard !wordsA.isEmpty || !wordsB.isEmpty else { return 0 }
        let intersection = wordsA.intersection(wordsB).count
        let union = wordsA.union(wordsB).count
        return Double(intersection) / Double(union)
    }

    private func loadImage(from asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isSynchronous = false

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 1024, height: 1024),
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}
