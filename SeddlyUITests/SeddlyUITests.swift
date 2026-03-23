import XCTest

final class SeddlyUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments.append("--uitesting")
        app.launch()
    }

    @MainActor
    func testOnboardingFlowDisplays() throws {
        // On first launch, onboarding should appear
        let welcomeText = app.staticTexts["Seddly"]
        XCTAssertTrue(welcomeText.waitForExistence(timeout: 5))
    }
}
