import AppKit
import SwiftUI

/// Full-screen black overlays on every display so the screen can be wiped safely.
@MainActor
final class OverlayController {
    private weak var session: CleaningSession?
    private var windows: [NSWindow] = []

    init(session: CleaningSession) {
        self.session = session
    }

    func show() {
        hide()

        for screen in NSScreen.screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.setFrame(screen.frame, display: true)
            window.isReleasedWhenClosed = false
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.backgroundColor = .black
            window.isOpaque = true
            window.hasShadow = false
            window.ignoresMouseEvents = false
            window.acceptsMouseMovedEvents = true

            let root = CleaningOverlayView()
                .environmentObject(session!)
            window.contentView = NSHostingView(rootView: root)
            window.makeKeyAndOrderFront(nil)
            windows.append(window)
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        for window in windows {
            window.orderOut(nil)
            window.close()
        }
        windows.removeAll()
    }
}
