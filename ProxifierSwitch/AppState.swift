import AppKit
import Combine
import Foundation
import UserNotifications

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var currentSSID: String?
    @Published private(set) var proxifierIsRunning = false
    @Published private(set) var lastEvent = "尚未检查"

    let settingsStore: SettingsStore
    private let wiFiMonitor: WiFiMonitor
    private let proxifierController: ProxifierController
    private let diagnostics: Diagnostics
    private var debounceTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init(
        settingsStore: SettingsStore,
        wiFiMonitor: WiFiMonitor = WiFiMonitor(),
        proxifierController: ProxifierController = ProxifierController(),
        diagnostics: Diagnostics = Diagnostics.shared
    ) {
        self.settingsStore = settingsStore
        self.wiFiMonitor = wiFiMonitor
        self.proxifierController = proxifierController
        self.diagnostics = diagnostics

        wiFiMonitor.onNetworkChange = { [weak self] in
            self?.scheduleCheck(reason: "网络变化")
        }
        wiFiMonitor.start()
        observeSettingsChanges()
        observeApplicationChanges()
        scheduleCheck(reason: "启动")
    }

    deinit {
        debounceTask?.cancel()
        cancellables.removeAll()
        wiFiMonitor.stop()
    }

    var automationStatusText: String {
        if settingsStore.automationEnabled, settingsStore.targetSSID.isEmpty {
            return "未配置"
        }
        return settingsStore.automationEnabled ? "已启用" : "已暂停"
    }

    var currentSSIDText: String {
        currentSSID?.isEmpty == false ? currentSSID! : "未连接"
    }

    var proxifierStatusText: String {
        proxifierIsRunning ? "运行中" : "未运行"
    }

    var menuBarImageName: String {
        settingsStore.automationEnabled ? "MenuBarActive" : "MenuBarPaused"
    }

    func scheduleCheck(reason: String) {
        debounceTask?.cancel()
        let delay = SettingsStore.clampedDebounceSeconds(settingsStore.debounceSeconds)
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.checkNow(reason: reason)
        }
    }

    func checkNow(reason: String = "立即检查") async {
        updateCurrentSSID(await wiFiMonitor.currentSSID())
        let isRunning = proxifierController.isRunning()
        updateProxifierIsRunning(isRunning)
        diagnostics.log("Check reason=\(reason), ssid=\(currentSSIDText), proxifier=\(proxifierStatusText)")

        guard settingsStore.automationEnabled else {
            updateLastEvent("自动控制已暂停")
            diagnostics.log("Skipped check because automation is paused")
            return
        }

        guard !settingsStore.targetSSID.isEmpty else {
            updateLastEvent("请先配置目标 Wi-Fi")
            diagnostics.log("Skipped check because target SSID is empty")
            return
        }

        let isAllowedWiFi = settingsStore.targetSSID == currentSSID
        if isAllowedWiFi {
            await ensureProxifierOpen(reason: reason, currentlyRunning: isRunning)
        } else {
            await ensureProxifierClosed(reason: reason, currentlyRunning: isRunning)
        }

        updateLastEvent("\(reason)：\(currentSSIDText)")
    }

    func toggleAutomation() {
        settingsStore.automationEnabled.toggle()
    }

    func diagnosticReport() -> String {
        diagnostics.diagnosticReport(
            currentSSID: currentSSIDText,
            proxifierStatus: proxifierStatusText,
            automationStatus: automationStatusText,
            settingsStore: settingsStore
        )
    }

    private func ensureProxifierOpen(reason: String, currentlyRunning: Bool) async {
        guard !currentlyRunning else {
            updateProxifierIsRunning(true)
            diagnostics.log("Proxifier already running")
            return
        }

        let didOpen = await proxifierController.open(at: settingsStore.proxifierApplicationPath)
        updateProxifierIsRunning(didOpen || proxifierController.isRunning())
        diagnostics.log("Open Proxifier result: \(didOpen)")
        if didOpen {
            sendNotification(title: "已打开 Proxifier", body: "\(reason)：\(currentSSIDText)")
        }
    }

    private func ensureProxifierClosed(reason: String, currentlyRunning: Bool) async {
        guard currentlyRunning else {
            updateProxifierIsRunning(false)
            diagnostics.log("Proxifier already closed")
            return
        }

        let didClose = await proxifierController.terminate()
        updateProxifierIsRunning(proxifierController.isRunning())
        diagnostics.log("Close Proxifier result: \(didClose)")
        if didClose {
            sendNotification(title: "已关闭 Proxifier", body: "\(reason)：\(currentSSIDText)")
        }
    }

    private func observeSettingsChanges() {
        settingsStore.$automationEnabled
            .dropFirst()
            .sink { [weak self] isEnabled in
                Task { @MainActor in
                    if isEnabled {
                        self?.scheduleCheck(reason: "启用自动控制")
                    } else {
                        self?.updateLastEvent("自动控制已暂停")
                    }
                }
            }
            .store(in: &cancellables)

        settingsStore.$targetSSID
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.scheduleCheck(reason: "目标 Wi-Fi 已更新")
                }
            }
            .store(in: &cancellables)

        settingsStore.$proxifierApplicationPath
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.scheduleCheck(reason: "Proxifier 路径已更新")
                }
            }
            .store(in: &cancellables)
    }

    private func observeApplicationChanges() {
        let notificationCenter = NSWorkspace.shared.notificationCenter

        notificationCenter.publisher(for: NSWorkspace.didLaunchApplicationNotification)
            .merge(with: notificationCenter.publisher(for: NSWorkspace.didTerminateApplicationNotification))
            .compactMap { notification in
                notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            }
            .filter { application in
                application.bundleIdentifier == AppConstants.proxifierBundleIdentifier
            }
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.refreshProxifierStatus(reason: "Proxifier 运行状态变化")
                }
            }
            .store(in: &cancellables)
    }

    private func refreshProxifierStatus(reason: String) {
        updateProxifierIsRunning(proxifierController.isRunning())
        updateLastEvent(reason)
        diagnostics.log("\(reason): \(proxifierStatusText)")
    }

    private func updateCurrentSSID(_ ssid: String?) {
        guard currentSSID != ssid else { return }
        currentSSID = ssid
    }

    private func updateProxifierIsRunning(_ isRunning: Bool) {
        guard proxifierIsRunning != isRunning else { return }
        proxifierIsRunning = isRunning
    }

    private func updateLastEvent(_ event: String) {
        guard lastEvent != event else { return }
        lastEvent = event
    }

    private func sendNotification(title: String, body: String) {
        guard settingsStore.showNotifications else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                Diagnostics.shared.error("Failed to send notification: \(error.localizedDescription)")
            }
        }
    }
}
