import SwiftUI

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var clipboardMonitor = ClipboardMonitorService()

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                if horizontalSizeClass == .regular {
                    // iPad: three-column split view
                    TabView {
                        IPadLedgerView()
                            .tabItem {
                                Label("Ledger", systemImage: "list.bullet.clipboard")
                            }

                        SettingsView()
                            .tabItem {
                                Label("Settings", systemImage: "gear")
                            }
                    }
                } else {
                    // iPhone: standard tab layout
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
