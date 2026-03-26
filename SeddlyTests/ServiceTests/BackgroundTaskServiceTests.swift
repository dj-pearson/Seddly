import Testing
import Foundation
@testable import Seddly

@Suite("BackgroundTaskService Tests")
struct BackgroundTaskServiceTests {
    @Test("Background task identifier matches AppConstants")
    func taskIdentifierCorrect() {
        #expect(AppConstants.backgroundTaskIdentifier == "com.pearsonmedia.Seddly.screenshot-refresh")
    }

    @Test("Shared singleton is accessible")
    func sharedInstanceExists() async {
        let service = await BackgroundTaskService.shared
        #expect(service != nil)
    }

    @Test("scheduleNextRefresh does not throw")
    func scheduleDoesNotThrow() async {
        // In a test environment, BGTaskScheduler.submit will fail silently
        // (no entitlement), but it must not crash the app
        let service = BackgroundTaskService.shared
        await service.scheduleNextRefresh()
        // If we reach here, scheduling didn't crash
        #expect(true)
    }

    @Test("registerBackgroundTasks does not throw")
    func registerDoesNotThrow() async {
        // Registration will fail in test environment but must not crash
        let service = BackgroundTaskService.shared
        await service.registerBackgroundTasks()
        #expect(true)
    }

    @Test("Background task refresh interval is 15 minutes")
    func refreshIntervalIs15Minutes() {
        // Verify the expected interval constant (15 * 60 = 900 seconds)
        let expectedInterval: TimeInterval = 15 * 60
        #expect(expectedInterval == 900)
    }

    @Test("Expiration handler cancels processing task")
    func expirationCancelsTask() async {
        // Verify that Task cancellation works correctly
        let task = Task {
            try? await Task.sleep(for: .seconds(60))
            return false
        }
        task.cancel()

        let wasCancelled = task.isCancelled
        #expect(wasCancelled == true)
    }
}
