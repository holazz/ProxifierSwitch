import AppKit
import Foundation

struct ProxifierController {
    func isRunning() -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: AppConstants.proxifierBundleIdentifier).isEmpty
    }

    func open(at path: String) async -> Bool {
        guard let url = applicationURL(preferredPath: path) else { return false }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-gj", "-a", url.path]
        task.standardOutput = Pipe()
        task.standardError = Pipe()

        return await withCheckedContinuation { continuation in
            let completion = SingleResumeContinuation<Bool>()
            task.terminationHandler = { process in
                completion.resume(process.terminationStatus == 0, continuation: continuation)
            }

            do {
                try task.run()
            } catch {
                completion.resume(false, continuation: continuation)
                return
            }

            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)

                if completion.isPending, task.isRunning {
                    task.terminate()
                }
                completion.resume(false, continuation: continuation)
            }
        }
    }

    func terminate() async -> Bool {
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: AppConstants.proxifierBundleIdentifier)
        guard !apps.isEmpty else { return true }
        apps.forEach { _ = $0.terminate() }

        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if !isRunning() {
                return true
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }

        return !isRunning()
    }

    private func applicationURL(preferredPath path: String) -> URL? {
        let url = URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
        if FileManager.default.fileExists(atPath: url.path) {
            return url
        }

        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: AppConstants.proxifierBundleIdentifier)
    }
}

final class SingleResumeContinuation<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var didResume = false

    var isPending: Bool {
        lock.lock()
        defer { lock.unlock() }

        return !didResume
    }

    func resume(_ result: Value, continuation: CheckedContinuation<Value, Never>) {
        lock.lock()
        let shouldResume: Bool
        if didResume {
            shouldResume = false
        } else {
            didResume = true
            shouldResume = true
        }
        lock.unlock()

        guard shouldResume else { return }
        continuation.resume(returning: result)
    }
}
