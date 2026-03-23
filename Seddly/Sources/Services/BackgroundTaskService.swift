import BackgroundTasks
import SwiftData

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
        scheduleNextRefresh()

        let processingTask = Task {
            await processNewScreenshots()
        }

        task.expirationHandler = {
            processingTask.cancel()
        }

        await processingTask.value
        task.setTaskCompleted(success: true)
    }

    private func processNewScreenshots() async {
        let screenshotService = ScreenshotService()
        let ocrService = OCRService()

        let lastProcessedDate = UserDefaults(suiteName: AppConstants.appGroupIdentifier)?
            .object(forKey: "lastProcessedDate") as? Date

        let newScreenshots = screenshotService.fetchNewScreenshots(since: lastProcessedDate)
        guard !newScreenshots.isEmpty else { return }

        guard let container = try? SharedModelContainer.create() else { return }
        let context = ModelContext(container)

        for asset in newScreenshots {
            let existingID = asset.localIdentifier
            let descriptor = FetchDescriptor<ProcessingQueue>(
                predicate: #Predicate { $0.screenshotAssetID == existingID }
            )
            let alreadyQueued = (try? context.fetchCount(descriptor)) ?? 0
            guard alreadyQueued == 0 else { continue }

            let queueItem = ProcessingQueue(screenshotAssetID: asset.localIdentifier)
            context.insert(queueItem)
        }

        try? context.save()

        UserDefaults(suiteName: AppConstants.appGroupIdentifier)?
            .set(Date.now, forKey: "lastProcessedDate")
    }
}
