import SwiftUI

struct MenuBarView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var settingsStore: SettingsStore

    var body: some View {
        VStack(alignment: .leading) {
            Text("自动控制：\(appState.automationStatusText)")
            Text("Wi-Fi：\(appState.currentSSIDText) · Proxifier：\(appState.proxifierStatusText)")
                .lineLimit(1)
                .truncationMode(.tail)
            Divider()
            Button(settingsStore.automationEnabled ? "暂停自动控制" : "启用自动控制") {
                appState.toggleAutomation()
            }
            Divider()
            Button("设置...") {
                openSettingsWindow()
            }
            Button("退出") {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private func openSettingsWindow() {
        // SwiftUI exposes Settings as a scene; these selectors are the macOS-compatible way to reveal it.
        if NSApplication.shared.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) {
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }

        NSApplication.shared.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
