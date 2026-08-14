import AppKit
import SwiftUI

/// Borderless, non-activating floating panel — the same shape as Clip-9's picker.
///
/// Non-activating matters: if showing the panel activated the app, the frontmost app would
/// change and the paste target would be lost.
final class CalcWindow: NSPanel {

    let state = CalcState()

    /// Called with the formatted result when the user commits with Enter.
    private let onCommit: (String) -> Void
    private let onDismiss: () -> Void

    init(onCommit: @escaping (String) -> Void, onDismiss: @escaping () -> Void) {
        self.onCommit = onCommit
        self.onDismiss = onDismiss

        super.init(
            contentRect: NSRect(x: 0, y: 0,
                                width: CalcLayout.width + CalcLayout.outerPadding * 2,
                                height: CalcLayout.contentHeight + CalcLayout.outerPadding * 2),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )

        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        alphaValue = 0

        let view = CalcView(state: state, onDismiss: { [weak self] in self?.onDismiss() })
            .padding(CalcLayout.outerPadding)
            .background(Color.black.opacity(0.98))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

        contentView = NSHostingView(rootView: view)
    }

    override var canBecomeKey: Bool { true }

    override func becomeKey() {
        super.becomeKey()
        state.isKey = true
    }

    override func resignKey() {
        super.resignKey()
        state.isKey = false
    }

    // MARK: - Show / hide

    func show() {
        state.focus = .field
        state.errorText = nil

        if let screen = NSScreen.main {
            let sf = screen.visibleFrame
            let w = CalcLayout.width + CalcLayout.outerPadding * 2
            let h = CalcLayout.contentHeight + CalcLayout.outerPadding * 2
            setFrame(NSRect(x: sf.origin.x + (sf.width - w) / 2,
                            y: sf.origin.y + (sf.height - h) / 2,
                            width: w, height: h),
                     display: false)
        }

        makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            animator().alphaValue = 1.0
        }
    }

    func hide() {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.12
            self.animator().alphaValue = 0.0
        }, completionHandler: {
            self.orderOut(nil)
        })
    }

    // MARK: - Keyboard

    override func cancelOperation(_ sender: Any?) {
        handleEscape()
    }

    override func keyDown(with event: NSEvent) {
        let cmd = event.modifierFlags.contains(.command)

        switch event.keyCode {
        case 126:  // up
            state.moveUp()
            return
        case 125:  // down
            state.moveDown()
            return
        case 36, 76:  // return, numpad enter
            handleReturn()
            return
        case 53:  // escape
            handleEscape()
            return
        case 51:  // delete
            if case .tape = state.focus {
                state.focus = .field
            } else if cmd {
                state.clear()
            } else {
                state.backspace()
            }
            return
        default:
            break
        }

        if cmd { return }  // leave other Cmd shortcuts alone

        // Anything printable types into the expression, which also snaps focus back out
        // of the tape.
        if let chars = event.charactersIgnoringModifiers, !chars.isEmpty {
            let allowed = CharacterSet(charactersIn: "0123456789.+-*/%()×÷−")
            let filtered = chars.unicodeScalars.filter { allowed.contains($0) }
            if !filtered.isEmpty {
                state.type(String(String.UnicodeScalarView(filtered)))
            }
        }
    }

    private func handleReturn() {
        switch state.focus {
        case .tape:
            state.insertSelectedResult()
        case .field:
            if let result = state.commit() {
                onCommit(result)
            }
            // On failure `state.errorText` is set and the panel stays open.
        }
    }

    /// Escape steps back out of the tape before it closes the panel.
    private func handleEscape() {
        if case .tape = state.focus {
            state.focus = .field
        } else {
            onDismiss()
        }
    }
}
