import Foundation
import os

/// Centralized logging for Seddly. Uses os.Logger for structured logging
/// that integrates with Console.app and Instruments.
enum AppLogger {
    private static let subsystem = "com.pearsonmedia.Seddly"

    static let general = Logger(subsystem: subsystem, category: "general")
    static let ocr = Logger(subsystem: subsystem, category: "ocr")
    static let ai = Logger(subsystem: subsystem, category: "ai")
    static let sync = Logger(subsystem: subsystem, category: "sync")
    static let notifications = Logger(subsystem: subsystem, category: "notifications")
    static let processing = Logger(subsystem: subsystem, category: "processing")
    static let auth = Logger(subsystem: subsystem, category: "auth")
    static let network = Logger(subsystem: subsystem, category: "network")
}
