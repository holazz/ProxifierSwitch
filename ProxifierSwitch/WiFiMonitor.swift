import CoreWLAN
import Foundation
import SystemConfiguration

final class WiFiMonitor {
    var onNetworkChange: (() -> Void)?
    private var dynamicStore: SCDynamicStore?
    private var runLoopSource: CFRunLoopSource?
    private var watchedInterfaceName: String?

    deinit {
        stop()
    }

    func start() {
        guard dynamicStore == nil else { return }

        let callback: SCDynamicStoreCallBack = { _, _, info in
            guard let info else { return }
            let monitor = Unmanaged<WiFiMonitor>.fromOpaque(info).takeUnretainedValue()
            monitor.onNetworkChange?()
        }

        var context = SCDynamicStoreContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        dynamicStore = SCDynamicStoreCreate(nil, "ProxifierSwitch" as CFString, callback, &context)
        guard let dynamicStore else { return }

        watchedInterfaceName = Self.wiFiInterfaceName()
        let keys = Self.notificationKeys(for: watchedInterfaceName) as CFArray

        guard SCDynamicStoreSetNotificationKeys(dynamicStore, keys, nil) else {
            self.dynamicStore = nil
            return
        }

        guard let source = SCDynamicStoreCreateRunLoopSource(nil, dynamicStore, 0) else {
            self.dynamicStore = nil
            return
        }

        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        runLoopSource = nil
        dynamicStore = nil
    }

    func currentSSID() async -> String? {
        if let ssid = CWWiFiClient.shared().interface()?.ssid(), !ssid.isEmpty {
            return ssid
        }
        return await airportSSID()
    }

    private static func notificationKeys(for interfaceName: String?) -> [CFString] {
        var keys = [
            "State:/Network/Global/IPv4",
            "State:/Network/Global/IPv6",
        ]

        if let interfaceName, !interfaceName.isEmpty {
            keys.append("State:/Network/Interface/\(interfaceName)/AirPort")
            keys.append("Setup:/Network/Interface/\(interfaceName)/AirPort")
        }

        return keys.map { $0 as CFString }
    }

    private static func wiFiInterfaceName() -> String? {
        CWWiFiClient.shared().interface()?.interfaceName
    }

    private func airportSSID() async -> String? {
        let airportPath = "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"
        guard FileManager.default.isExecutableFile(atPath: airportPath) else { return nil }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: airportPath)
        task.arguments = ["-I"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        return await withCheckedContinuation { continuation in
            let completion = SingleResumeContinuation<String?>()

            task.terminationHandler = { process in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                guard process.terminationStatus == 0 else {
                    completion.resume(nil, continuation: continuation)
                    return
                }
                completion.resume(Self.parseSSID(fromAirportOutput: data), continuation: continuation)
            }

            do {
                try task.run()
            } catch {
                completion.resume(nil, continuation: continuation)
                return
            }

            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)

                if completion.isPending, task.isRunning {
                    task.terminate()
                }
                completion.resume(nil, continuation: continuation)
            }
        }
    }

    private static func parseSSID(fromAirportOutput data: Data) -> String? {
        guard let output = String(data: data, encoding: .utf8) else { return nil }

        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("SSID:") else { continue }

            let ssid = trimmed
                .dropFirst("SSID:".count)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return ssid.isEmpty ? nil : ssid
        }

        return nil
    }
}
