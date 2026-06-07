import Combine
import Foundation
import UserNotifications

@MainActor
final class SettingsStore: ObservableObject {
    @Published var automationEnabled: Bool {
        didSet { defaults.set(automationEnabled, forKey: Keys.automationEnabled) }
    }

    @Published private(set) var targetSSID: String

    @Published var proxifierApplicationPath: String {
        didSet { defaults.set(proxifierApplicationPath, forKey: Keys.proxifierApplicationPath) }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
            configureLaunchAtLogin()
        }
    }

    @Published var showNotifications: Bool {
        didSet {
            defaults.set(showNotifications, forKey: Keys.showNotifications)
            if showNotifications {
                requestNotificationAuthorization()
            }
        }
    }

    @Published var debounceSeconds: Double {
        didSet {
            let clamped = Self.clampedDebounceSeconds(debounceSeconds)
            guard clamped == debounceSeconds else {
                debounceSeconds = clamped
                return
            }
            defaults.set(clamped, forKey: Keys.debounceSeconds)
        }
    }

    @Published var diagnosticLoggingEnabled: Bool {
        didSet {
            defaults.set(diagnosticLoggingEnabled, forKey: Keys.diagnosticLoggingEnabled)
            diagnostics.setEnabled(diagnosticLoggingEnabled)
        }
    }

    private let defaults = UserDefaults.standard
    private let loginItemManager = LoginItemManager()
    private let diagnostics = Diagnostics.shared
    private var isConfiguringLaunchAtLogin = false

    init() {
        defaults.register(defaults: [
            Keys.automationEnabled: false,
            Keys.targetSSID: "",
            Keys.proxifierApplicationPath: AppConstants.defaultProxifierApplicationPath,
            Keys.launchAtLogin: true,
            Keys.showNotifications: false,
            Keys.debounceSeconds: 1.0,
            Keys.diagnosticLoggingEnabled: true,
        ])

        automationEnabled = defaults.bool(forKey: Keys.automationEnabled)
        targetSSID = SSIDNormalizer.normalized(defaults.string(forKey: Keys.targetSSID) ?? "")
        proxifierApplicationPath = defaults.string(forKey: Keys.proxifierApplicationPath) ?? AppConstants.defaultProxifierApplicationPath
        launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        showNotifications = defaults.bool(forKey: Keys.showNotifications)
        debounceSeconds = Self.clampedDebounceSeconds(defaults.double(forKey: Keys.debounceSeconds))
        diagnosticLoggingEnabled = defaults.bool(forKey: Keys.diagnosticLoggingEnabled)

        diagnostics.setEnabled(diagnosticLoggingEnabled)
        reconcileLaunchAtLoginSetting()
        if showNotifications {
            requestNotificationAuthorization()
        }
    }

    func setTargetSSID(_ rawValue: String) {
        let normalized = SSIDNormalizer.normalized(rawValue)
        guard targetSSID != normalized else { return }
        targetSSID = normalized
        defaults.set(normalized, forKey: Keys.targetSSID)
    }

    static func clampedDebounceSeconds(_ value: Double) -> Double {
        max(1.0, min(value, 5.0))
    }

    private func configureLaunchAtLogin() {
        guard !isConfiguringLaunchAtLogin else { return }
        isConfiguringLaunchAtLogin = true
        defer { isConfiguringLaunchAtLogin = false }

        do {
            if launchAtLogin {
                try loginItemManager.install()
                diagnostics.log("Registered login item")
            } else {
                try loginItemManager.uninstall()
                diagnostics.log("Unregistered login item")
            }
        } catch {
            diagnostics.error("Failed to update login item: \(error.localizedDescription)")
        }
    }

    private func reconcileLaunchAtLoginSetting() {
        let isInstalled = loginItemManager.isInstalled()
        guard launchAtLogin != isInstalled else { return }

        if launchAtLogin {
            configureLaunchAtLogin()
        } else {
            defaults.set(isInstalled, forKey: Keys.launchAtLogin)
            launchAtLogin = isInstalled
        }
    }

    private func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { isGranted, error in
            if let error {
                Diagnostics.shared.error("Notification authorization failed: \(error.localizedDescription)")
            } else {
                Diagnostics.shared.log("Notification authorization granted: \(isGranted)")
            }
        }
    }

    private enum Keys {
        static let automationEnabled = "automationEnabled"
        static let targetSSID = "targetSSID"
        static let proxifierApplicationPath = "proxifierApplicationPath"
        static let launchAtLogin = "launchAtLogin"
        static let showNotifications = "showNotifications"
        static let debounceSeconds = "debounceSeconds"
        static let diagnosticLoggingEnabled = "diagnosticLoggingEnabled"
    }
}

enum SSIDNormalizer {
    static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalizedList(_ values: [String]) -> [String] {
        Array(Set(values.map(normalized).filter { !$0.isEmpty })).sorted()
    }
}
