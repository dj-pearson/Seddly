# Seddly — iOS Screenshot Accountability Engine

## Project Overview
Native iOS app (Swift/SwiftUI) that extracts commitments from screenshots using on-device OCR + AI.

## Tech Stack
- **Language:** Swift 6 language mode (`SWIFT_VERSION = 6.0`), built with Xcode 16.3 / Swift compiler 6.1
- **UI:** SwiftUI, iOS 17+ minimum
- **Architecture:** MVVM with `@Observable` and Swift Concurrency
- **Storage:** SwiftData with App Group shared container
- **AI:** Claude Sonnet API via Supabase Edge Functions
- **Subscriptions:** StoreKit 2
- **CI/CD:** GitHub Actions with XcodeGen, native xcodebuild, Apple-Actions

## Project Structure
```
project.yml          # XcodeGen project definition (generates .xcodeproj)
ExportOptions.plist  # Code signing config for IPA export
Seddly/Sources/      # Main app source code
  App/               # @main entry point, ContentView
  Models/            # SwiftData @Model classes + enums
  Views/             # SwiftUI views organized by feature
  ViewModels/        # @Observable view models
  Services/          # Business logic (OCR, AI, Photos, Notifications)
  Shared/            # Code shared with Share Extension (ModelContainer, constants)
SeddlyShareExtension/  # Share Sheet extension
SeddlyTests/           # Unit tests (Swift Testing framework)
SeddlyUITests/         # UI tests
```

## Build Commands
```bash
# Generate Xcode project from project.yml
xcodegen generate

# Build (CI — no signing)
xcodebuild build -project Seddly.xcodeproj -scheme Seddly \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# Run tests
xcodebuild test -project Seddly.xcodeproj -scheme Seddly \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest'
```

## Conventions
- Use Swift Testing (`@Test`, `#expect`) for unit tests, not XCTest
- All enums stored in SwiftData use raw String values with computed property wrappers
- Actor isolation: code is implicitly `@MainActor` (Xcode 16.3 default). Use `nonisolated` or `@concurrent` for background work.
- Services that do I/O are `actor` types; pure logic services are `struct`
- Privacy-first: screenshots never leave device. Only filtered OCR text sent to AI.
- Free tier = fully on-device, no account required

## Tracking & Analytics Policy
- **No cross-app or cross-website tracking.** Seddly does not integrate analytics SDKs (Firebase, Mixpanel, Amplitude, etc.), does not read the IDFA, and does not share data with third parties for advertising.
- Because there is no tracking, the app intentionally ships **without** `NSUserTrackingUsageDescription` and does **not** call `ATTrackingManager.requestTrackingAuthorization()`. No ATT prompt is shown at launch.
- If analytics or advertising SDKs are ever added, this stance must reverse: add the usage description key to Info.plist, present the ATT prompt before any tracking, and update `PrivacyInfo.xcprivacy` + the Play Data Safety form accordingly.
- The only outbound data flows are (1) Pro/Pro+ OCR text → Supabase Edge Function for Claude extraction, (2) Pro+ SwiftData sync → user's own Supabase account. Both are opt-in via subscription tier.
