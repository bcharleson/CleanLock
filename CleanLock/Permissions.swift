import ApplicationServices
import AppKit
import Foundation

enum PermissionStatus {
    case granted
    case denied
}

enum Permissions {
    /// Accessibility is required for CGEvent taps that suppress input.
    static func accessibilityStatus() -> PermissionStatus {
        AXIsProcessTrusted() ? .granted : .denied
    }

    /// Prompts the user (once) and opens System Settings if still denied.
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

    static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
