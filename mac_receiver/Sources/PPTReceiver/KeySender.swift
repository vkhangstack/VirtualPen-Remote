import AppKit
import ApplicationServices
import CoreGraphics

/// Whitelisted commands. Anything else received over the wire is ignored,
/// so a client can never inject arbitrary keystrokes.
enum Command: String {
    case next = "NEXT"
    case prev = "PREV"
    case start = "START"     // play from first slide
    case resume = "RESUME"   // play from current slide
    case end = "END"
    case black = "BLACK"
    case white = "WHITE"
}

enum KeySender {
    private static let presentationApps = ["com.microsoft.Powerpoint", "com.apple.iWork.Keynote"]

    /// Posting synthetic key events requires Accessibility permission for the
    /// process that launched us (e.g. Terminal). Prompts the user if missing.
    static func ensureAccessibility() -> Bool {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }

    static func perform(_ cmd: Command) {
        focusPresentationApp {
            switch cmd {
            case .next: press(124)                                      // →
            case .prev: press(123)                                      // ←
            case .start: press(36, flags: [.maskCommand, .maskShift])   // ⌘⇧↩
            case .resume: press(36, flags: .maskCommand)                // ⌘↩
            case .end: press(53)                                        // Esc
            case .black: press(11)                                      // B
            case .white: press(13)                                      // W
            }
        }
    }

    /// Bring PowerPoint (or Keynote) to front before every command, since
    /// keystrokes always go to the frontmost app (often the terminal running us).
    private static func focusPresentationApp(then action: @escaping () -> Void) {
        let app = presentationApps.lazy
            .compactMap { NSRunningApplication.runningApplications(withBundleIdentifier: $0).first }
            .first
        guard let app, !app.isActive else { return action() }
        app.activate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: action)
    }

    private static func press(_ key: CGKeyCode, flags: CGEventFlags = []) {
        let source = CGEventSource(stateID: .hidSystemState)
        for keyDown in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: keyDown) else { return }
            event.flags = flags
            event.post(tap: .cghidEventTap)
        }
    }
}
