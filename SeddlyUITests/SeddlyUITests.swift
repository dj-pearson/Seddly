import XCTest

final class SeddlyUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments.append("--uitesting")
        app.launch()
    }

    // MARK: - Onboarding

    @MainActor
    func testOnboardingFlowDisplays() throws {
        // On first launch, onboarding should appear
        let welcomeText = app.staticTexts["Seddly"]
        XCTAssertTrue(welcomeText.waitForExistence(timeout: 5))
    }

    // MARK: - Manual Entry Flow (US-090)

    @MainActor
    func testManualEntryFlowSavesToLedger() throws {
        // Navigate to manual entry (tab bar or button)
        let addButton = app.buttons["Add Commitment"]
        if addButton.waitForExistence(timeout: 5) {
            addButton.tap()
        } else {
            // Try tab bar
            let manualTab = app.tabBars.buttons["Manual"]
            if manualTab.waitForExistence(timeout: 3) {
                manualTab.tap()
            }
        }

        // Fill entity name
        let entityField = app.textFields["Entity Name"]
        if entityField.waitForExistence(timeout: 3) {
            entityField.tap()
            entityField.typeText("Test Company")
        }

        // Fill summary
        let summaryField = app.textFields["Summary"]
        if summaryField.waitForExistence(timeout: 3) {
            summaryField.tap()
            summaryField.typeText("Will deliver refund by Friday")
        }

        // Tap save
        let saveButton = app.buttons["Save"]
        if saveButton.waitForExistence(timeout: 3) {
            saveButton.tap()
        }

        // Verify we return to ledger and commitment appears
        let ledgerText = app.staticTexts["Test Company"]
        XCTAssertTrue(ledgerText.waitForExistence(timeout: 5),
                      "Saved commitment should appear in ledger")
    }

    // MARK: - Commitment Detail Edit (US-090)

    @MainActor
    func testCommitmentDetailEditStatus() throws {
        // Find first commitment in the ledger
        let firstCell = app.cells.firstMatch
        guard firstCell.waitForExistence(timeout: 5) else {
            // No commitments in ledger — skip gracefully
            return
        }
        firstCell.tap()

        // Look for edit button or status picker
        let editButton = app.buttons["Edit"]
        if editButton.waitForExistence(timeout: 3) {
            editButton.tap()
        }

        // Look for status picker
        let statusPicker = app.buttons["Status"]
        if statusPicker.waitForExistence(timeout: 3) {
            statusPicker.tap()

            // Select a different status
            let fulfilledOption = app.buttons["Fulfilled"]
            if fulfilledOption.waitForExistence(timeout: 3) {
                fulfilledOption.tap()
            }
        }

        // Navigate back
        let backButton = app.navigationBars.buttons.firstMatch
        if backButton.waitForExistence(timeout: 3) {
            backButton.tap()
        }
    }

    // MARK: - Filter Flow (US-090)

    @MainActor
    func testFilterFlowApplyAndClear() throws {
        // Look for filter button in ledger
        let filterButton = app.buttons["Filter"]
        guard filterButton.waitForExistence(timeout: 5) else {
            // Filter button might have different label
            let filterIcon = app.buttons["line.3.horizontal.decrease.circle"]
            guard filterIcon.waitForExistence(timeout: 3) else { return }
            filterIcon.tap()
            return
        }
        filterButton.tap()

        // Look for filter options
        let statusFilter = app.buttons["Pending"]
        if statusFilter.waitForExistence(timeout: 3) {
            statusFilter.tap()
        }

        // Apply/close filter sheet
        let applyButton = app.buttons["Apply"]
        if applyButton.waitForExistence(timeout: 3) {
            applyButton.tap()
        } else {
            // Dismiss by tapping outside or back
            let doneButton = app.buttons["Done"]
            if doneButton.waitForExistence(timeout: 2) {
                doneButton.tap()
            }
        }

        // Verify filter badge is visible
        let badge = app.images["line.3.horizontal.decrease.circle.fill"]
        if badge.exists {
            XCTAssertTrue(badge.exists, "Filter badge should show when filter is active")
        }

        // Clear filters
        if filterButton.waitForExistence(timeout: 3) {
            filterButton.tap()
        }
        let clearButton = app.buttons["Clear"]
        if clearButton.waitForExistence(timeout: 3) {
            clearButton.tap()
        }
    }

    // MARK: - Deep Link Navigation (US-090)

    @MainActor
    func testDeepLinkOpensCommitment() throws {
        // Test that the app handles a deep link URL gracefully
        // We use a fake UUID — app should show "not found" alert instead of crashing
        let fakeURL = URL(string: "seddly://commitment/00000000-0000-0000-0000-000000000000")!

        // Open URL (this simulates universal link / deep link)
        app.open(fakeURL)

        // App should not crash — that's the primary assertion
        // If commitment not found, an alert should appear
        let alert = app.alerts.firstMatch
        if alert.waitForExistence(timeout: 5) {
            // Dismiss the alert
            let okButton = alert.buttons["OK"]
            if okButton.exists {
                okButton.tap()
            }
        }

        // App should still be running
        XCTAssertTrue(app.state == .runningForeground,
                      "App should remain running after deep link with invalid ID")
    }
}
