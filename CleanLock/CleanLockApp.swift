import SwiftUI

@main
struct CleanLockApp: App {
    @StateObject private var session = CleaningSession()

    /// Fixed window size — sized to fit header, cards, and the start button without clipping.
    static let windowSize = CGSize(width: 440, height: 640)

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
