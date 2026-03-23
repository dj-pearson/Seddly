# Seddly — iOS Screenshot Accountability Engine

## Project Overview
Native iOS app (Swift/SwiftUI) that extracts commitments from screenshots using on-device OCR + AI.

## Tech Stack
- **Language:** Swift 6 (Xcode 16.3 / Swift 6.2)
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
