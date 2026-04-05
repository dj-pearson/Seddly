import SwiftUI
import UIKit

// MARK: - Floating Tab Bar Appearance (US-143)
//
// Applies a premium floating tab bar treatment: translucent material
// background, inset from edges, continuous corners, subtle accent glow.
private enum SeddlyTabBarAppearance {
    static func configure() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        appearance.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.6)
        appearance.shadowColor = .clear

        // Tint selected items with accent color
        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.selected.iconColor = UIColor.tintColor
        itemAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor.tintColor,
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold)
        ]
        itemAppearance.normal.iconColor = UIColor.secondaryLabel
        itemAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.secondaryLabel
        ]

        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("selectedTab") private var selectedTab = 0
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var clipboardMonitor = ClipboardMonitorService()

    init() {
        SeddlyTabBarAppearance.configure()
    }

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
        .onChange(of: selectedTab) { _, _ in
            HapticsService.select()
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
