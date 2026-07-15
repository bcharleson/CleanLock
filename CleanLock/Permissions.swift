import ApplicationServices
import AppKit
import Foundation
import IOKit.hid

enum PermissionStatus {
    case granted
    case denied
}

enum Permissions {
    /// Accessibility is required for CGEvent taps that suppress input.
    static func accessibilityStatus() -> PermissionStatus {
        AXIsProcessTrusted() ? .granted : .denied
    }

    /// Input Monitoring (Listen Event) is required on modern macOS for global event taps.
    static func inputMonitoringStatus() -> PermissionStatus {
        if #available(macOS 10.15, *) {
            return IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
                ? .granted
                : .denied
        }
        return .granted
    }

    static var allRequiredGranted: Bool {
        accessibilityStatus() == .granted && inputMonitoringStatus() == .granted
    }

    /// Prompts for Accessibility and opens System Settings if still denied.
    @discardableResult
    static func requestAccessibility(openSettingsIfDenied: Bool = true) -> PermissionStatus {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        if trusted {
            return .granted
        }
        if openSettingsIfDenied {
            openAccessibilitySettings()
        }
        return .denied
    }

    /// Requests Input Monitoring; opens Settings when the user still needs to enable it.
    @discardableResult
    static func requestInputMonitoring(openSettingsIfDenied: Bool = true) -> PermissionStatus {
        if inputMonitoringStatus() == .granted {
            return .granted
        }
        if #available(macOS 10.15, *) {
            _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        }
        if inputMonitoringStatus() == .granted {
            return .granted
        }
        if openSettingsIfDenied {
            openInputMonitoringSettings()
        }
        return .denied
    }

    static func requestAll(openSettingsIfDenied: Bool = true) {
        if accessibilityStatus() != .granted {
            _ = requestAccessibility(openSettingsIfDenied: openSettingsIfDenied)
            return
        }
        if inputMonitoringStatus() != .granted {
            _ = requestInputMonitoring(openSettingsIfDenied: openSettingsIfDenied)
        }
    }

    static func openAccessibilitySettings() {
        openPrivacySettings(anchor: "Privacy_Accessibility")
    }

    static func openInputMonitoringSettings() {
        openPrivacySettings(anchor: "Privacy_ListenEvent")
    }

    private static func openPrivacySettings(anchor: String) {
        // Prefer modern Settings deep link; fall back to legacy pane URL.
        let candidates = [
            "x-apple.systempreferences:com.apple.preference.security?\(anchor)",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?\(anchor)",
        ]
        for candidate in candidates {
            if let url = URL(string: candidate), NSWorkspace.shared.open(url) {
                return
            }
        }
    }
}
