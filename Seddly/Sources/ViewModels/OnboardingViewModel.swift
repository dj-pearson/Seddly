import SwiftUI
import Photos

@Observable
final class OnboardingViewModel {
    var currentPage = 0
    var photoAuthStatus: PHAuthorizationStatus = .notDetermined
    var isRequestingPermission = false

    let totalPages = 4

    var canProceed: Bool {
        currentPage < totalPages - 1
    }

    func requestPhotoAccess() async {
        isRequestingPermission = true
        photoAuthStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        isRequestingPermission = false
    }

    func advancePage() {
        if currentPage < totalPages - 1 {
            currentPage += 1
        }
    }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }
}
