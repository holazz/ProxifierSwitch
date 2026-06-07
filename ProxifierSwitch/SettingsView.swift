import AppKit
import CoreWLAN
import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var settingsStore: SettingsStore
    @State private var availableSSIDs: [String] = []
    @State private var isScanningWiFi = false
    @State private var isShowingInvalidPathAlert = false
    private let debounceOptions = [1, 2, 3, 4, 5]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            settingsRow("自动控制") {
                HStack(spacing: 18) {
                    Toggle("启用", isOn: $settingsStore.automationEnabled)
                    Toggle("开机启动", isOn: $settingsStore.launchAtLogin)
                }
            }
            Divider()

            settingsRow("目标 Wi-Fi") {
                EditableComboBox(
                    text: selectedSSIDBinding,
                    items: selectableSSIDs,
                    placeholder: "输入或选择 Wi-Fi",
                    onWillPopUp: refreshAvailableSSIDs
                )
                .frame(width: 300, height: 26)
            }
            Divider()

            settingsRow("Proxifier") {
                HStack(spacing: 12) {
                    Text(settingsStore.proxifierApplicationPath)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .textSelection(.enabled)
                    Button("选择...") {
                        chooseProxifierApp()
                    }
                }
            }
            Divider()

            settingsRow("切换延迟") {
                Picker("切换延迟", selection: $settingsStore.debounceSeconds) {
                    ForEach(debounceOptions, id: \.self) { seconds in
                        Text("\(seconds) 秒")
                            .tag(Double(seconds))
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 112)
            }
            Divider()

            settingsRow("通知与日志") {
                HStack(spacing: 18) {
                    Toggle("状态通知", isOn: $settingsStore.showNotifications)
                    Toggle("诊断日志", isOn: $settingsStore.diagnosticLoggingEnabled)
                }
            }
            Divider()

            settingsRow("诊断") {
                Button("复制诊断信息") {
                    copyDiagnostics()
                }
            }
        }
        .padding(24)
        .frame(width: 620, height: 356)
        .alert("所选应用不是 Proxifier", isPresented: $isShowingInvalidPathAlert) {
            Button("好", role: .cancel) {}
        } message: {
            Text("请选择 bundle id 为 com.initex.proxifier.v3.macos 的 Proxifier.app。")
        }
        .task {
            await refreshAvailableSSIDs()
        }
    }

    private var selectedSSIDBinding: Binding<String> {
        Binding {
            settingsStore.targetSSID
        } set: { value in
            settingsStore.setTargetSSID(value)
        }
    }

    private var selectableSSIDs: [String] {
        SSIDNormalizer.normalizedList(availableSSIDs + [settingsStore.targetSSID])
    }

    private func chooseProxifierApp() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.applicationBundle]

        if panel.runModal() == .OK, let url = panel.url {
            let bundleID = Bundle(url: url)?.bundleIdentifier
            if bundleID == AppConstants.proxifierBundleIdentifier {
                settingsStore.proxifierApplicationPath = url.path
            } else {
                isShowingInvalidPathAlert = true
            }
        }
    }

    private func copyDiagnostics() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(appState.diagnosticReport(), forType: .string)
    }

    private func refreshAvailableSSIDs() async {
        guard !isScanningWiFi else { return }
        isScanningWiFi = true
        availableSSIDs = await scanWiFiNetworks()
        isScanningWiFi = false
    }

    private func settingsRow<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 18) {
            Text(title)
                .fontWeight(.semibold)
                .frame(width: 108, alignment: .leading)

            content()
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(minHeight: 44)
    }
}

private struct EditableComboBox: NSViewRepresentable {
    @Binding var text: String
    let items: [String]
    let placeholder: String
    let onWillPopUp: () async -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSComboBox {
        let comboBox = NSComboBox()
        comboBox.delegate = context.coordinator
        comboBox.usesDataSource = false
        comboBox.completes = true
        comboBox.numberOfVisibleItems = 8
        comboBox.placeholderString = placeholder
        comboBox.controlSize = .regular
        comboBox.font = .systemFont(ofSize: NSFont.systemFontSize)
        comboBox.addItems(withObjectValues: items)
        return comboBox
    }

    func updateNSView(_ comboBox: NSComboBox, context: Context) {
        let currentItems = (0..<comboBox.numberOfItems).compactMap { comboBox.itemObjectValue(at: $0) as? String }
        if currentItems != items {
            comboBox.removeAllItems()
            comboBox.addItems(withObjectValues: items)
        }

        if comboBox.stringValue != text {
            comboBox.stringValue = text
        }

        comboBox.placeholderString = placeholder
        context.coordinator.parent = self
    }

    final class Coordinator: NSObject, NSComboBoxDelegate, NSControlTextEditingDelegate {
        var parent: EditableComboBox

        init(_ parent: EditableComboBox) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let comboBox = notification.object as? NSComboBox else { return }
            updateText(comboBox.stringValue)
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            guard let comboBox = notification.object as? NSComboBox else { return }
            updateText(comboBox.stringValue)
        }

        func comboBoxSelectionDidChange(_ notification: Notification) {
            guard let comboBox = notification.object as? NSComboBox else { return }
            if let selectedValue = comboBox.objectValueOfSelectedItem as? String {
                updateText(selectedValue)
                comboBox.stringValue = selectedValue
            } else {
                updateText(comboBox.stringValue)
            }
        }

        func comboBoxWillPopUp(_ notification: Notification) {
            Task { await parent.onWillPopUp() }
        }

        private func updateText(_ value: String) {
            guard parent.text != value else { return }
            parent.text = value
        }
    }
}

private func scanWiFiNetworks() async -> [String] {
    await Task.detached(priority: .utility) {
        let interface = CWWiFiClient.shared().interface()
        let currentSSID = interface?.ssid()
        let cachedSSIDs = interface?.cachedScanResults()?
            .compactMap(\.ssid) ?? []
        let scannedSSIDs = (try? interface?.scanForNetworks(withName: nil))?
            .compactMap(\.ssid) ?? []

        return SSIDNormalizer.normalizedList(cachedSSIDs + scannedSSIDs + [currentSSID].compactMap { $0 })
    }.value
}
