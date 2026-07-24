# CleanLock

A tiny native macOS app that blacks out your displays and locks the keyboard + trackpad so you can sanitize them without typing gibberish or clicking random things.

**Unlock:** hold **⌘ ⌥ ⌃** together for **3 seconds**.

## Why this exists

One job: black out the display and lock input so you can sanitize your Mac without typing gibberish or clicking random things. MIT-licensed, easy to audit, and yours to fork.

| Feature | Behavior |
| --- | --- |
| Black overlay | Full-screen on every connected display |
| Input lock | Keyboard, trackpad, mouse, scroll, media keys via `CGEvent` tap |
| Unlock | Hold ⌘ + ⌥ + ⌃ for 3 seconds (progress ring) |
| Failsafe | Configurable auto-unlock (1 / 3 / 5 / 10 minutes) |
| Privacy | No analytics or accounts; input events never leave the device. Optional Sparkle update checks contact GitHub only. |

## Requirements

- macOS 14 Sonoma or later
- **Accessibility** permission (System Settings → Privacy & Security → Accessibility)

> CleanLock is **not sandboxed**. App Sandbox blocks the event taps needed to suppress input. Accessibility TCC is still required at runtime.

## Install

### Download

1. Grab the latest **`.dmg`** from [Releases](https://github.com/bcharleson/CleanLock/releases).
2. Open the DMG and drag **CleanLock** into Applications.
3. Grant **Accessibility** when prompted.

Releases are **Developer ID–signed and notarized**. Sparkle handles later updates via **CleanLock → Check for Updates…**.

### Build from source

```bash
brew install xcodegen   # once
cd CleanLock
xcodegen generate
open CleanLock.xcodeproj
```

In Xcode: select the **CleanLock** scheme → **Product → Run** (⌘R).

### Ship a release

See **[docs/RELEASING.md](docs/RELEASING.md)** for the full checklist. Short path:

```bash
# 1) Bump MARKETING_VERSION / CURRENT_PROJECT_VERSION in project.yml
#    and VERSION / BUILD defaults in scripts/release.sh
./scripts/release.sh
# 2) Commit appcast.xml + version bump, push main
# 3) gh release create vX.Y.Z dist/CleanLock-X.Y.Z.{dmg,zip} dist/SHA256SUMS.txt
```

## Usage

1. Launch CleanLock.
2. Grant Accessibility if needed.
3. Click **Start Cleaning Mode**.
4. Wipe the screen / keyboard / trackpad.
5. Hold **⌘ ⌥ ⌃** for 3 seconds to unlock.

Before starting, pick an **Auto-unlock after** duration (1, 3, 5, or 10 minutes) so you aren’t stuck longer than you want.

Emergency escapes if something goes wrong:

- Wait for the configured failsafe, or
- Force Quit via the Apple menu / Activity Monitor (power button still works at the hardware level).

## How it works

1. `InputBlocker` installs a session-level `CGEvent` tap and returns `nil` for keyboard/pointer events.
2. `OverlayController` places borderless black windows at `.screenSaver` level on every `NSScreen`.
3. Modifier state is watched; when the unlock chord stays held, a 30 Hz timer fills the progress ring and ends the session at 100%.

## Open source

- License: [MIT](LICENSE)
- No telemetry
- Contributions welcome — keep the surface area small

## Ideas for later (not in v1)

- Configurable unlock chord / hold duration
- Menu-bar-only mode (`LSUIElement`)
- Idle auto-timeout that resets while you’re wiping
- White / gray wipe backgrounds for seeing smudges
- Homebrew cask
