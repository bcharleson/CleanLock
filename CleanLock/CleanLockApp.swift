import SwiftUI

@main
struct CleanLockApp: App {
    @StateObject private var session = CleaningSession()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(session)
                .frame(minWidth: 420, minHeight: 480)
        }
        .windowResizability(.contentSize)
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
