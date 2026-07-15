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
    @Published private(set) var inputMonitoringGranted = false
    @Published var lastError: String?
    @Published var failsafeDuration: FailsafeDuration {
        didSet {
            UserDefaults.standard.set(failsafeDuration.rawValue, forKey: Self.failsafeDefaultsKey)
        }
    }

    private let blocker = InputBlocker()
    private var overlayController: OverlayController?
    private var permissionPollTimer: Timer?

    /// Both TCC permissions required for cleaning mode.
    var permissionGranted: Bool { accessibilityGranted && inputMonitoringGranted }

    /// Human-readable unlock chord for the UI.
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
        inputMonitoringGranted = Permissions.inputMonitoringStatus() == .granted
        if permissionGranted {
            lastError = nil
            stopPermissionPolling()
        }
    }

    /// Keep checking after the user toggles Settings — TCC can lag until relaunch.
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
        Permissions.requestAll(openSettingsIfDenied: true)
        refreshPermissions()
        startPermissionPolling()

        if !permissionGranted {
            lastError = missingPermissionMessage()
        }
    }

    func startCleaning() {
        refreshPermissions()
        guard permissionGranted else {
            requestPermissions()
            lastError = missingPermissionMessage()
            return
        }

        guard !isCleaning else { return }

        blocker.requiredFlags = InputBlocker.defaultUnlockFlags
        guard blocker.start(failsafeDuration: failsafeDuration.seconds) else {
            // Tap creation often fails when Input Monitoring was granted but the process
            // hasn't been restarted yet.
            lastError = "Could not lock input. Quit CleanLock completely (⌘Q) and reopen it, then try again."
            startPermissionPolling()
            return
        }

        let controller = OverlayController(session: self)
        controller.show()
        overlayController = controller
        unlockProgress = 0
        isCleaning = true
        lastError = nil

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

    private func missingPermissionMessage() -> String {
        if !accessibilityGranted && !inputMonitoringGranted {
            return "Enable Accessibility and Input Monitoring for CleanLock, then quit (⌘Q) and reopen the app."
        }
        if !accessibilityGranted {
            return "Enable Accessibility for CleanLock, then quit (⌘Q) and reopen the app."
        }
        return "Enable Input Monitoring for CleanLock, then quit (⌘Q) and reopen the app."
    }
}
