import SwiftUI

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("selectedTab") private var selectedTab = 0
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var clipboardMonitor = ClipboardMonitorService()

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                if horizontalSizeClass == .regular {
                    // iPad: three-column split view
                    TabView(selection: $selectedTab) {
                        IPadLedgerView()
                            .tabItem {
                                Label("Ledger", systemImage: "list.bullet.clipboard")
                            }
                            .tag(0)

                        SettingsView()
                            .tabItem {
                                Label("Settings", systemImage: "gear")
                            }
                            .tag(1)
                    }
                } else {
                    // iPhone: standard tab layout
                    TabView(selection: $selectedTab) {
                        LedgerView()
                            .tabItem {
                                Label("Ledger", systemImage: "list.bullet.clipboard")
                            }
                            .tag(0)

                        SettingsView()
                            .tabItem {
                                Label("Settings", systemImage: "gear")
                            }
                            .tag(1)
                    }
                }
            } else {
                OnboardingView()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                clipboardMonitor.checkClipboard()
            }
        }
        .sheet(isPresented: $clipboardMonitor.showClipboardPrompt) {
            if let text = clipboardMonitor.detectedText {
                ClipboardCommitmentView(
                    text: text,
                    confidenceScore: clipboardMonitor.confidenceScore,
                    onDismiss: { clipboardMonitor.dismiss() }
                )
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [LocalCommitment.self, LocalEntity.self, ProcessingQueue.self], inMemory: true)
}
