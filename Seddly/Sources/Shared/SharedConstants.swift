import Foundation

enum AppConstants {
    static let appGroupIdentifier = "group.com.pearsonmedia.Seddly"
    static let mainBundleIdentifier = "com.pearsonmedia.Seddly"
    static let shareExtensionBundleIdentifier = "com.pearsonmedia.Seddly.ShareExtension"
    static let backgroundTaskIdentifier = "com.pearsonmedia.Seddly.screenshot-refresh"

    static let maxFreeCommitments = 5
    static let defaultConfidenceThreshold = 40
    static let autoApproveAfterCount = 5

    enum SubscriptionProductID {
        static let proMonthly = "com.pearsonmedia.Seddly.pro.monthly"
        static let proYearly = "com.pearsonmedia.Seddly.pro.yearly"
        static let proPlusMonthly = "com.pearsonmedia.Seddly.proplus.monthly"
        static let proPlusYearly = "com.pearsonmedia.Seddly.proplus.yearly"
    }
}
