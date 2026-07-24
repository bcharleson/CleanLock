import AppKit
import Sparkle

/// Sparkle-backed update checks — same pattern as Grok.
final class UpdateManager: NSObject {
    static let shared = UpdateManager()

    private var updaterController: SPUStandardUpdaterController!

    var updater: SPUUpdater {
        updaterController.updater
    }

    private override init() {
        super.init()
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
    }

    @objc func checkForUpdates(_ sender: Any?) {
        updaterController.checkForUpdates(sender)
    }

    var canCheckForUpdates: Bool {
        updater.canCheckForUpdates
    }
}

extension UpdateManager: SPUUpdaterDelegate {}
