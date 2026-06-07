import Foundation
import OSLog

final class Diagnostics {
    static let shared = Diagnostics()

    private let logger = Logger(subsystem: AppConstants.appBundleIdentifier, category: "default")
    private let lock = NSLock()
    private var entries: [String] = []
    private var isEnabled = true

    private init() {}

    func setEnabled(_ isEnabled: Bool) {
        lock.lock()
        defer { lock.unlock() }

        self.isEnabled = isEnabled
    }

    func log(_ message: String) {
        guard loggingIsEnabled() else { return }

        logger.info("\(message, privacy: .private)")
        append("INFO", message)
    }

    func error(_ message: String) {
        guard loggingIsEnabled() else { return }

        logger.error("\(message, privacy: .private)")
        append("ERROR", message)
    }

    @MainActor
    func diagnosticReport(
        currentSSID: String,
        proxifierStatus: String,
        automationStatus: String,
        settingsStore: SettingsStore
    ) -> String {
        let recentEntries = snapshot().joined(separator: "\n")
        let targetSSID = settingsStore.targetSSID.isEmpty ? "None" : settingsStore.targetSSID
        return """
        Proxifier Switch Diagnostics
        Generated: \(Self.timestamp())
        Automation: \(automationStatus)
        Current Wi-Fi: \(currentSSID)
        Proxifier: \(proxifierStatus)
        Target SSID: \(targetSSID)
        Proxifier Path: \(settingsStore.proxifierApplicationPath)
        Launch At Login: \(settingsStore.launchAtLogin)
        Notifications: \(settingsStore.showNotifications)
        Debounce Seconds: \(settingsStore.debounceSeconds)
        Diagnostic Logging: \(settingsStore.diagnosticLoggingEnabled)

        Recent Events:
        \(recentEntries.isEmpty ? "No recent events" : recentEntries)
        """
    }

    private func append(_ level: String, _ message: String) {
        lock.lock()
        defer { lock.unlock() }

        entries.append("[\(Self.timestamp())] \(level): \(message)")
        if entries.count > 100 {
            entries.removeFirst(entries.count - 100)
        }
    }

    private func snapshot() -> [String] {
        lock.lock()
        defer { lock.unlock() }

        return entries
    }

    private func loggingIsEnabled() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        return isEnabled
    }

    private static func timestamp() -> String {
        Date().ISO8601Format()
    }
}
