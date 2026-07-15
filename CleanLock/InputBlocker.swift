import AppKit
import CoreGraphics
import Foundation

/// Intercepts keyboard, mouse, and trackpad events via a CGEvent tap.
///
/// Events are swallowed while cleaning is active. Modifier-key state is still
/// observed so the unlock chord can be detected without reaching other apps.
final class InputBlocker {
    /// Default unlock chord: ⌘ + ⌥ + ⌃ held together.
    static let defaultUnlockFlags: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl]

    /// Seconds the unlock chord must be held continuously.
    static let unlockHoldDuration: TimeInterval = 3.0

    /// Absolute failsafe — cleaning always ends after this many seconds.
    static let failsafeDuration: TimeInterval = 10 * 60

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var unlockHoldStartedAt: Date?
    private var unlockTickTimer: Timer?
    private var failsafeTimer: Timer?
    private var chordCurrentlyHeld = false

    var requiredFlags: CGEventFlags = InputBlocker.defaultUnlockFlags
    var onUnlockProgress: ((Double) -> Void)?
    var onUnlocked: (() -> Void)?

    private(set) var isBlocking = false

    func start() -> Bool {
        guard !isBlocking else { return true }

        let mask = Self.eventMask
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else {
                return Unmanaged.passUnretained(event)
            }
            let blocker = Unmanaged<InputBlocker>.fromOpaque(refcon).takeUnretainedValue()
            return blocker.handle(type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isBlocking = true
        unlockHoldStartedAt = nil
        chordCurrentlyHeld = false
        startFailsafeTimer()
        return true
    }

    func stop() {
        failsafeTimer?.invalidate()
        failsafeTimer = nil
        stopUnlockTick()

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        unlockHoldStartedAt = nil
        chordCurrentlyHeld = false
        isBlocking = false
        DispatchQueue.main.async { [weak self] in
            self?.onUnlockProgress?(0)
        }
    }

    // MARK: - Event handling

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return nil
        }

        guard isBlocking else {
            return Unmanaged.passUnretained(event)
        }

        if type == .flagsChanged || type == .keyDown || type == .keyUp {
            evaluateChord(flags: event.flags)
        }

        // Swallow everything — including unlock-chord keys — until hold completes.
        return nil
    }

    private func evaluateChord(flags: CGEventFlags) {
        let relevant = flags.intersection([.maskCommand, .maskAlternate, .maskControl, .maskShift])
        let requiredHeld = requiredFlags.intersection(relevant) == requiredFlags

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            if requiredHeld {
                if !self.chordCurrentlyHeld {
                    self.chordCurrentlyHeld = true
                    self.unlockHoldStartedAt = Date()
                    self.startUnlockTick()
                }
                self.emitProgress()
            } else {
                self.resetUnlockHold()
            }
        }
    }

    private func startUnlockTick() {
        unlockTickTimer?.invalidate()
        unlockTickTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.emitProgress()
            }
        }
    }

    private func stopUnlockTick() {
        unlockTickTimer?.invalidate()
        unlockTickTimer = nil
    }

    private func resetUnlockHold() {
        chordCurrentlyHeld = false
        unlockHoldStartedAt = nil
        stopUnlockTick()
        onUnlockProgress?(0)
    }

    private func emitProgress() {
        guard let started = unlockHoldStartedAt else {
            onUnlockProgress?(0)
            return
        }
        let progress = min(1.0, Date().timeIntervalSince(started) / Self.unlockHoldDuration)
        onUnlockProgress?(progress)
        if progress >= 1.0 {
            stopUnlockTick()
            onUnlocked?()
        }
    }

    private func startFailsafeTimer() {
        failsafeTimer?.invalidate()
        failsafeTimer = Timer.scheduledTimer(withTimeInterval: Self.failsafeDuration, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.onUnlocked?()
            }
        }
    }

    // MARK: - Mask

    private static var eventMask: CGEventMask {
        var mask: CGEventMask = 0
        let types: [CGEventType] = [
            .keyDown, .keyUp, .flagsChanged,
            .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
            .otherMouseDown, .otherMouseUp,
            .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
            .scrollWheel,
            .tabletPointer, .tabletProximity,
        ]
        for type in types {
            mask |= (1 << type.rawValue)
        }
        // System-defined (brightness, volume, media / Fn-row).
        mask |= (1 << 14)
        return mask
    }
}
