import AppKit

/// Reactivates the app you came from and posts a synthetic Cmd+V.
///
/// Copied from Clip-9 rather than shared — the two projects are deliberately independent.
/// This is the one part of Calc-9 that requires Accessibility permission.
enum PasteSimulator {

    static func paste(into targetApp: NSRunningApplication) {
        targetApp.activate(options: [.activateIgnoringOtherApps])

        // Let the app become frontmost before the keystrokes land.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            postCmdV()
        }
    }

    private static func postCmdV() {
        let src = CGEventSource(stateID: .hidSystemState)

        // keyCode 9 = 'v'
        guard let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: true),
              let keyUp   = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: false)
        else { return }

        keyDown.flags = .maskCommand
        keyUp.flags   = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
