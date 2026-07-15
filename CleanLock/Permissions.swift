import ApplicationServices
import AppKit
import Foundation

enum PermissionStatus {
    case granted
    case denied
}

enum Permissions {
    /// Accessibility is the permission CleanLock needs to create a blocking event tap.
    static func accessibilityStatus() -> PermissionStatus {
        AXIsProcessTrusted() ? .granted : .denied
    }

    /// True when we can create the kind of tap cleaning mode uses.
    /// More reliable than TCC UI state after reinstalls / multiple app copies.
    static func canCreateBlockingEventTap() -> Bool {
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, _, event, _ in Unmanaged.passUnretained(event) },
            userInfo: nil
        ) else {
            return false
        }
        CGEvent.tapEnable(tap: tap, enable: false)
        return true
    }

    /// Ready to clean when Accessibility trusts us *or* a blocking tap can be created.
    static var isReadyForCleaning: Bool {
        accessibilityStatus() == .granted || canCreateBlockingEventTap()
    }

    /// Opens Accessibility settings only — does not show the system AX prompt dialog.
    /// (Repeated AX prompts are easy to Deny and leave permissions stuck.)
    static func openAccessibilitySettings() {
        openPrivacySettings(anchor: "Privacy_Accessibility")
    }

    private static func openPrivacySettings(anchor: String) {
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
