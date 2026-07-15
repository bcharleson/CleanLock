import SwiftUI

struct CleaningOverlayView: View {
    @EnvironmentObject private var session: CleaningSession

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                UnlockRing(progress: session.unlockProgress)
                    .frame(width: 120, height: 120)

                Text("Cleaning mode")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))

                Text("Keyboard and trackpad are locked.\nWipe freely — nothing will register.")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Spacer().frame(height: 24)

                VStack(spacing: 10) {
                    Text("Hold to unlock")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                        .textCase(.uppercase)
                        .tracking(1.2)

                    HStack(spacing: 8) {
                        Keycap(label: "⌘")
                        Keycap(label: "⌥")
                        Keycap(label: "⌃")
                    }

                    Text("for 3 seconds")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.white.opacity(0.06))
                )

                Text("Auto-unlocks after 10 minutes as a failsafe")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.28))
                    .padding(.top, 8)

                Spacer()
            }
            .padding(40)
            // Fade the chrome when not unlocking so the screen stays wipe-friendly.
            .opacity(session.unlockProgress > 0.02 ? 1.0 : 0.35)
            .animation(.easeInOut(duration: 0.2), value: session.unlockProgress)
        }
    }
}

struct UnlockRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.12), lineWidth: 6)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Color.accentColor,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.05), value: progress)

            if progress > 0.01 {
                Text("\(Int((progress * 100).rounded()))%")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .monospacedDigit()
            } else {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
    }
}

struct Keycap: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 20, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.9))
            .frame(width: 44, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(.white.opacity(0.18), lineWidth: 1)
                    )
            )
    }
}
