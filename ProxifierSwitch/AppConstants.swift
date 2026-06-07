import Foundation

enum AppConstants {
    static var appBundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "com.local.ProxifierSwitch"
    }

    static let proxifierBundleIdentifier = "com.initex.proxifier.v3.macos"
    static let defaultProxifierApplicationPath = "/Applications/Proxifier.app"
}
