import SwiftUI

@main
struct CleanLockApp: App {
    @StateObject private var session = CleaningSession()

    /// Keep Sparkle alive for the app lifetime.
    private let updates = UpdateManager.shared

    /// Fixed window size — sized to fit header, cards, and the start button without clipping.
    static let windowSize = CGSize(width: 440, height: 660)

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(session)
                .frame(width: Self.windowSize.width, height: Self.windowSize.height)
        }
        .windowResizability(.contentSize)
        .windowStyle(.automatic)
        .defaultSize(width: Self.windowSize.width, height: Self.windowSize.height)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .appInfo) {
                Button("About CleanLock") {
                    AboutPanel.show()
                }
            }
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    updates.checkForUpdates(nil)
                }
                .disabled(!updates.canCheckForUpdates)
            }
            CommandMenu("Cleaning") {
                Button("Start Cleaning Mode") {
                    session.startCleaning()
                }
                .keyboardShortcut("c", modifiers: [.command, .control])
                .disabled(session.isCleaning)
            }
        }
    }
}
