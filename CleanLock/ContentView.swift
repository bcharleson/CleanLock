import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var session: CleaningSession
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.35)
            main
            Divider().opacity(0.35)
            footer
        }
        .frame(width: CleanLockApp.windowSize.width, height: CleanLockApp.windowSize.height)
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                session.refreshPermissions()
                if !session.permissionGranted {
                    session.startPermissionPolling()
                }
            }
        }
        .onAppear {
            session.refreshPermissions()
            if !session.permissionGranted {
                session.startPermissionPolling()
            }
            lockWindowSize()
        }
    }

    /// Disable zoom/resize so the window stays at the designed fixed size.
    private func lockWindowSize() {
        DispatchQueue.main.async {
            guard let window = NSApplication.shared.windows.first(where: {
                $0.contentView?.subviews.isEmpty == false
            }) else { return }
            let size = CleanLockApp.windowSize
            window.styleMask.remove(.resizable)
            window.setContentSize(size)
            window.minSize = size
            window.maxSize = size
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 48, height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.accentColor.opacity(0.15))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("CleanLock")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("Sanitize your screen and keyboard safely")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(24)
    }

    private var main: some View {
        VStack(alignment: .leading, spacing: 20) {
            permissionCard

            failsafePicker

            VStack(alignment: .leading, spacing: 10) {
                Text("How it works")
                    .font(.headline)

                FeatureRow(
                    icon: "rectangle.inset.filled",
                    title: "Black screen",
                    detail: "Every display goes black so you can wipe the glass."
                )
                FeatureRow(
                    icon: "keyboard",
                    title: "Input locked",
                    detail: "Keyboard and trackpad events are blocked until you unlock."
                )
                FeatureRow(
                    icon: "hand.raised",
                    title: "Hold \(session.unlockChordLabel) for 3s",
                    detail: "Intentional unlock chord — random presses won’t exit."
                )
                FeatureRow(
                    icon: "timer",
                    title: "Auto-unlock failsafe",
                    detail: "Ends on its own after \(session.failsafeDuration.label) if you forget the chord."
                )
            }

            if let error = session.lastError {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                session.startCleaning()
            } label: {
                Text(session.isCleaning ? "Cleaning…" : "Start Cleaning Mode")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(session.isCleaning)
            .keyboardShortcut(.defaultAction)
        }
        .padding(24)
    }

    private var failsafePicker: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Auto-unlock after")
                    .font(.headline)
                Text("Safety net so you can’t stay locked out.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Picker("", selection: $session.failsafeDuration) {
                ForEach(FailsafeDuration.allCases) { duration in
                    Text(duration.label).tag(duration)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(minWidth: 120)
            .disabled(session.isCleaning)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    private var permissionCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: session.permissionGranted ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                .font(.title2)
                .foregroundStyle(session.permissionGranted ? Color.accentColor : .orange)

            VStack(alignment: .leading, spacing: 8) {
                Text(session.permissionGranted ? "Permissions granted" : "Permissions required")
                    .font(.headline)

                Text(
                    session.permissionGranted
                        ? "CleanLock can intercept input while cleaning mode is active. Events stay on-device and are never logged."
                        : "macOS needs Accessibility and Input Monitoring. After enabling both, fully quit CleanLock (⌘Q) and reopen it."
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 4) {
                    PermissionStatusRow(
                        title: "Accessibility",
                        granted: session.accessibilityGranted
                    )
                    PermissionStatusRow(
                        title: "Input Monitoring",
                        granted: session.inputMonitoringGranted
                    )
                }

                if !session.permissionGranted {
                    HStack(spacing: 16) {
                        Button("Open System Settings") {
                            session.requestPermissions()
                        }
                        .buttonStyle(.link)

                        Button("Check again") {
                            session.refreshPermissions()
                            if !session.permissionGranted {
                                session.startPermissionPolling()
                                session.lastError = "If the toggles are already on, quit CleanLock with ⌘Q and reopen it from Applications."
                            }
                        }
                        .buttonStyle(.link)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Link("𝕏 \(AboutPanel.xHandle)", destination: AboutPanel.xProfileURL)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("·")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Text("MIT")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()

            Text("⌃⌘C to start")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .monospaced()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }
}

private struct PermissionStatusRow: View {
    let title: String
    let granted: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(granted ? Color.accentColor : .secondary)
                .font(.caption)
            Text(title)
                .font(.caption)
                .foregroundStyle(granted ? .primary : .secondary)
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .frame(width: 22)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
