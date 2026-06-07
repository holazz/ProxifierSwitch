import Foundation
import ServiceManagement

struct LoginItemManager {
    func isInstalled() -> Bool {
        SMAppService.mainApp.status == .enabled
    }

    func install() throws {
        if SMAppService.mainApp.status != .enabled {
            try SMAppService.mainApp.register()
        }
    }

    func uninstall() throws {
        if SMAppService.mainApp.status == .enabled {
            try SMAppService.mainApp.unregister()
        }
    }
}
