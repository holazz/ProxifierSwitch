import SwiftUI

@main
struct ProxifierSwitchApp: App {
    @StateObject private var settingsStore: SettingsStore
    @StateObject private var appState: AppState

    init() {
        let settings = SettingsStore()
        _settingsStore = StateObject(wrappedValue: settings)
        _appState = StateObject(wrappedValue: AppState(settingsStore: settings))
    }

    var body: some Scene {
        MenuBarExtra("Proxifier Switch", image: appState.menuBarImageName) {
            MenuBarView(appState: appState, settingsStore: settingsStore)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(appState: appState, settingsStore: settingsStore)
        }
    }
}
