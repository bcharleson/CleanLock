# CleanLock

A tiny native macOS app that blacks out your displays and locks the keyboard + trackpad so you can sanitize them without typing gibberish or clicking random things.

**Unlock:** hold **⌘ ⌥ ⌃** together for **3 seconds**.

## Why this exists

Existing tools (MacScrub, macPause, KeepClean, TapLock) already solve this well. CleanLock is intentionally smaller: one job, MIT-licensed, easy to audit, and yours to fork.

| Feature | Behavior |
| --- | --- |
| Black overlay | Full-screen on every connected display |
| Input lock | Keyboard, trackpad, mouse, scroll, media keys via `CGEvent` tap |
| Unlock | Hold ⌘ + ⌥ + ⌃ for 3 seconds (progress ring) |
| Failsafe | Auto-unlock after 10 minutes |
| Privacy | No network, no analytics, no accounts — events never leave the device |

## Requirements

- macOS 14 Sonoma or later
- **Accessibility** permission (System Settings → Privacy & Security → Accessibility)

> CleanLock is **not sandboxed**. App Sandbox blocks the event taps needed to suppress input. Accessibility TCC is still required at runtime.

## Install

### Download

1. Grab the latest **`.dmg`** or **`.zip`** from [Releases](https://github.com/bcharleson/CleanLock/releases).
2. Open the DMG and drag **CleanLock** into Applications (or unzip the `.app`).
3. First launch: if macOS blocks it, right-click → **Open**, or allow it under **System Settings → Privacy & Security**.
4. Grant **Accessibility** when prompted.

### Build from source

```bash
brew install xcodegen   # once
cd CleanLock
xcodegen generate
open CleanLock.xcodeproj
```

In Xcode: select the **CleanLock** scheme → **Product → Run** (⌘R).

Or package a signed Release build:

```bash
./scripts/release.sh
# artifacts land in dist/CleanLock-1.0.0.{dmg,zip}
```

## Usage

1. Launch CleanLock.
2. Grant Accessibility if needed.
3. Click **Start Cleaning Mode**.
4. Wipe the screen / keyboard / trackpad.
5. Hold **⌘ ⌥ ⌃** for 3 seconds to unlock.

Emergency escapes if something goes wrong:

- Wait for the 10-minute failsafe, or
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
- Notarized releases + Homebrew cask

## Related projects

- [MacScrub](https://github.com/tufantunc/MacScrub) — polished menu-bar cleaner with configurable exit keys
- [macPause](https://github.com/gloverola/macPause) — failsafe-first menu bar utility
- [KeepClean](https://github.com/adhamhaithameid/keep-clean) — keyboard-only + timed modes
- [TapLock](https://github.com/ugurcandede/taplock-app) — lock + relax modes
