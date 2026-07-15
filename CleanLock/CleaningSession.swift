import AppKit
import Combine
import CoreGraphics
import Foundation
import SwiftUI

@MainActor
final class CleaningSession: ObservableObject {
    private static let failsafeDefaultsKey = "failsafeDurationSeconds"

    @Published private(set) var isCleaning = false
    @Published private(set) var unlockProgress: Double = 0
    @Published private(set) var accessibilityGranted = false
    @Published private(set) var eventTapReady = false
    @Published var lastError: String?
    @Published var failsafeDuration: FailsafeDuration {
        didSet {
            UserDefaults.standard.set(failsafeDuration.rawValue, forKey: Self.failsafeDefaultsKey)
        }
    }

    private let blocker = InputBlocker()
    private var overlayController: OverlayController?
    private var permissionPollTimer: Timer?

    /// Cleaning is allowed when Accessibility trusts this process or a blocking tap works.
    var permissionGranted: Bool { accessibilityGranted || eventTapReady }

    var unlockChordLabel: String { "⌘ ⌥ ⌃" }

    init() {
        let saved = UserDefaults.standard.integer(forKey: Self.failsafeDefaultsKey)
        failsafeDuration = FailsafeDuration(rawValue: saved) ?? .default
        refreshPermissions()

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
        accessibilityGranted = Permissions.accessibilityStatus() == .granted
        eventTapReady = Permissions.canCreateBlockingEventTap()
        if permissionGranted {
            lastError = nil
            stopPermissionPolling()
        }
    }

    func startPermissionPolling() {
        stopPermissionPolling()
        permissionPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshPermissions()
            }
        }
    }

    func stopPermissionPolling() {
        permissionPollTimer?.invalidate()
        permissionPollTimer = nil
    }

    func requestPermissions() {
        // Do not call AXIsProcessTrustedWithOptions(prompt: true) — that dialog is easy to
        // Deny and makes TCC worse. Send the user to Settings instead.
        Permissions.openAccessibilitySettings()
        refreshPermissions()
        startPermissionPolling()
        if !permissionGranted {
            lastError = "Turn on CleanLock under Privacy & Security → Accessibility, then quit with ⌘Q and reopen from /Applications."
        }
    }

    func startCleaning() {
        refreshPermissions()

        // Always attempt the tap — TCC UI can lag behind reality after a relaunch.
        guard !isCleaning else { return }

        blocker.requiredFlags = InputBlocker.defaultUnlockFlags
        guard blocker.start(failsafeDuration: failsafeDuration.seconds) else {
            requestPermissions()
            lastError = "macOS blocked the input lock. Enable CleanLock in Accessibility, quit (⌘Q), reopen /Applications/CleanLock, then try again."
            accessibilityGranted = false
            eventTapReady = false
            return
        }

        // Tap succeeded — treat permissions as granted even if AXIsProcessTrusted lagged.
        accessibilityGranted = true
        eventTapReady = true

        let controller = OverlayController(session: self)
        controller.show()
        overlayController = controller
        unlockProgress = 0
        isCleaning = true
        lastError = nil
        stopPermissionPolling()

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
