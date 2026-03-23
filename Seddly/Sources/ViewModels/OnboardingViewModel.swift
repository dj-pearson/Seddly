import SwiftUI
import Photos

@Observable
final class OnboardingViewModel {
    var currentPage = 0
    var photoAuthStatus: PHAuthorizationStatus = .notDetermined
    var isRequestingPermission = false

    let totalPages = 5

    func requestPhotoAccess() async {
        isRequestingPermission = true
        photoAuthStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        isRequestingPermission = false
    }

    func requestNotificationAccess() async {
        let service = NotificationService()
        _ = try? await service.requestAuthorization()
    }

    func advancePage() {
        if currentPage < totalPages - 1 {
            currentPage += 1
        }
    }
}
