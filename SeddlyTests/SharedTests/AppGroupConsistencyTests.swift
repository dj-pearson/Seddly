import Testing
import Foundation
@testable import Seddly

/// US-166: The App Group identifier must be byte-identical across the main
/// app, Share Extension, Widget, and Watch targets. A typo in any of the four
/// `.entitlements` files would silently break inter-target data access (the
/// shared ModelContainer, UserDefaults suite, background-task lastProcessedDate
/// flag — all of it). Catching drift here is far cheaper than reproducing it
/// on-device.
@Suite("App Group Consistency Tests")
struct AppGroupConsistencyTests {

    private static let expectedGroupID = "group.com.pearsonmedia.Seddly"

    /// Absolute paths to every entitlement file that declares an App Group.
    /// Update this list if a new extension is added.
    private static let entitlementsFiles: [String] = [
        "Seddly/Resources/Seddly.entitlements",
        "SeddlyShareExtension/SeddlyShareExtension.entitlements",
        "SeddlyWidget/SeddlyWidget.entitlements",
        "SeddlyWatch/SeddlyWatch.entitlements"
    ]

    @Test("AppConstants.appGroupIdentifier matches the canonical value")
    func swiftConstantMatches() {
        #expect(AppConstants.appGroupIdentifier == Self.expectedGroupID)
    }

    @Test("Every entitlements file declares the canonical App Group")
    func entitlementsFilesAgree() throws {
        let repoRoot = Self.repoRoot()
        for relativePath in Self.entitlementsFiles {
            let url = repoRoot.appendingPathComponent(relativePath)
            let data = try Data(contentsOf: url)
            let plist = try PropertyListSerialization.propertyList(
                from: data,
                format: nil
            ) as? [String: Any]

            let groups = plist?["com.apple.security.application-groups"] as? [String]
            #expect(groups != nil,
                    "\(relativePath) is missing com.apple.security.application-groups")
            #expect(groups?.contains(Self.expectedGroupID) == true,
                    "\(relativePath) does not declare \(Self.expectedGroupID)")
        }
    }

    /// Walk up from the compiled test bundle's source file to the repo root.
    /// Swift Testing runs with the project working dir, but depending on how
    /// xcodebuild is invoked (`test`, `test-without-building`, CI) the cwd
    /// can differ. `#file` is the stable anchor.
    private static func repoRoot() -> URL {
        URL(fileURLWithPath: #file)
            .deletingLastPathComponent()   // SharedTests
            .deletingLastPathComponent()   // SeddlyTests
            .deletingLastPathComponent()   // repo root
    }
}
