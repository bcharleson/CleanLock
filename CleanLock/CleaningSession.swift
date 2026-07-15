import AppKit
import Combine
import CoreGraphics
import Foundation
import SwiftUI

@MainActor
final class CleaningSession: ObservableObject {
    @Published private(set) var isCleaning = false
    @Published private(set) var unlockProgress: Double = 0
    @Published private(set) var permissionGranted = Permissions.accessibilityStatus() == .granted
    @Published var lastError: String?

    private let blocker = InputBlocker()
    private var overlayController: OverlayController?

    /// Human-readable unlock chord for the UI.
    var unlockChordLabel: String { "⌘ ⌥ ⌃" }

    init() {
        blocker.onUnlockProgress = { [weak self] progress in
            Task { @MainActor in
                self?.unlockProgress = progress
            }
        }
        blocker.onUnlocked = { [weak self] in
            Task { @MainActor in
                self?.stopCleaning()
            }
        }
    }

    func refreshPermissions() {
        permissionGranted = Permissions.accessibilityStatus() == .granted
    }

    func requestPermissions() {
        _ = Permissions.requestAccessibility(openSettingsIfDenied: true)
        // Give System Settings a moment; user may grant and return.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.refreshPermissions()
        }
    }

    func startCleaning() {
        refreshPermissions()
        guard permissionGranted else {
            requestPermissions()
            lastError = "Accessibility permission is required to lock the keyboard and trackpad."
            return
        }

        guard !isCleaning else { return }

        blocker.requiredFlags = InputBlocker.defaultUnlockFlags
        guard blocker.start() else {
            lastError = "Could not create an input event tap. Check Accessibility permission, then try again."
            return
        }

        let controller = OverlayController(session: self)
        controller.show()
        overlayController = controller
        unlockProgress = 0
        isCleaning = true
        lastError = nil

        // Hide cursor while cleaning — less visual noise on a black screen.
        NSCursor.hide()
    }

    func stopCleaning() {
        guard isCleaning || blocker.isBlocking else {
            overlayController?.hide()
            overlayController = nil
            return
        }

        blocker.stop()
        overlayController?.hide()
        overlayController = nil
        isCleaning = false
        unlockProgress = 0
        NSCursor.unhide()
        NSApp.activate(ignoringOtherApps: true)
    }
}
