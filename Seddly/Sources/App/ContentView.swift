import SwiftUI

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        if hasCompletedOnboarding {
            TabView {
                LedgerView()
                    .tabItem {
                        Label("Ledger", systemImage: "list.bullet.clipboard")
                    }

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
            }
        } else {
            OnboardingView()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [LocalCommitment.self, LocalEntity.self, ProcessingQueue.self], inMemory: true)
}
