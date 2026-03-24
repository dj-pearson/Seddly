import BackgroundTasks
import SwiftData
import Photos
import UIKit

actor BackgroundTaskService {
    static let shared = BackgroundTaskService()

    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: AppConstants.backgroundTaskIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            Task {
                await self.handleScreenshotRefresh(refreshTask)
            }
        }
    }

    func scheduleNextRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: AppConstants.backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Background task scheduling failed — app will process on next foreground
        }
    }

    private func handleScreenshotRefresh(_ task: BGAppRefreshTask) async {
        // Schedule next refresh immediately to maintain frequency
        scheduleNextRefresh()

        let processingTask = Task {
            await processNewScreenshotsInBackground()
        }

        task.expirationHandler = {
            processingTask.cancel()
        }

        await processingTask.value
        task.setTaskCompleted(success: true)
    }

    /// Background processing: runs on-device OCR + classifier + rule filter only.
    /// No network calls. AI-eligible items are queued for foreground processing.
    private func processNewScreenshotsInBackground() async {
        let screenshotService = ScreenshotService()
        let ocrService = OCRService()
        let classifierService = ClassifierService()

        let lastProcessedDate = UserDefaults(suiteName: AppConstants.appGroupIdentifier)?
            .object(forKey: "lastProcessedDate") as? Date

        let newScreenshots = screenshotService.fetchNewScreenshots(since: lastProcessedDate)
        guard !newScreenshots.isEmpty else { return }

        guard let container = try? SharedModelContainer.create() else { return }
        let context = ModelContext(container)

        for asset in newScreenshots {
            // Check if cancelled (iOS is reclaiming time)
            guard !Task.isCancelled else { break }

            let existingID = asset.localIdentifier
            let descriptor = FetchDescriptor<ProcessingQueue>(
                predicate: #Predicate { $0.screenshotAssetID == existingID }
            )
            guard (try? context.fetchCount(descriptor)) ?? 0 == 0 else { continue }

            // Load image
            guard let image = await loadImage(from: asset) else { continue }

            // Layer 1: OCR (on-device, no network)
            guard let ocrText = try? await ocrService.recognizeText(in: image) else {
                let skipped = ProcessingQueue(screenshotAssetID: asset.localIdentifier)
                skipped.processingStatus = .skipped
                context.insert(skipped)
                continue
            }

            // Layer 2: Classification (on-device)
            let category = await classifierService.classify(image, ocrText: ocrText)

            let queueItem = ProcessingQueue(screenshotAssetID: asset.localIdentifier)
            queueItem.extractedText = ocrText
            queueItem.classifierResult = category.rawValue

            if !category.shouldProcess {
                queueItem.processingStatus = .skipped
                context.insert(queueItem)
                continue
            }

            // Layer 3: Rule-based filter (on-device)
            let ruleScore = RuleFilterService.score(text: ocrText)
            queueItem.ruleBasedScore = ruleScore

            if ruleScore >= ClassifierFeedbackService.currentThreshold() {
                // Passes threshold — queue for AI processing on next foreground session
                queueItem.processingStatus = .pending
            } else {
                queueItem.processingStatus = .completed
            }

            context.insert(queueItem)
        }

        // Update overdue statuses and app badge
        let overdueCount = StatusUpdateService.updateOverdueStatuses(in: context)
        await StatusUpdateService.updateBadgeCount(overdueCount)

        try? context.save()

        UserDefaults(suiteName: AppConstants.appGroupIdentifier)?
            .set(Date.now, forKey: "lastProcessedDate")

        // Count items pending AI processing for notification
        let pendingDescriptor = FetchDescriptor<ProcessingQueue>(
            predicate: #Predicate { $0.processingStatusRaw == "pending" }
        )
        let pendingCount = (try? context.fetchCount(pendingDescriptor)) ?? 0

        if pendingCount > 0 {
            await scheduleBackgroundResultNotification(pendingCount: pendingCount)
        }
    }

    private func scheduleBackgroundResultNotification(pendingCount: Int) async {
        let content = UNMutableNotificationContent()
        content.title = "Screenshots Processed"
        content.body = "\(pendingCount) screenshot\(pendingCount == 1 ? "" : "s") with potential commitments — open Seddly to review."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "background-result-\(UUID().uuidString.prefix(8))",
            content: content,
            trigger: nil // Fire immediately
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    private func loadImage(from asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .fastFormat // Use fast format for background
            options.isSynchronous = false
            options.isNetworkAccessAllowed = false // No network in background

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 800, height: 800),
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}
