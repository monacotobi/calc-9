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

        let view = CalcView(state: state,
                            onDismiss: { [weak self] in self?.onDismiss() },
                            onToggleHelp: { [weak self] in
                                guard let self else { return }
                                self.setHelp(!self.state.showingHelp)
                            })
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
        state.showingHelp = false

        recenter(animated: false)
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

    // MARK: - Help

    /// The help sheet is taller than the calculator, so toggling it resizes the panel.
    /// Keeping the window centred means it grows in both directions rather than dropping
    /// off the bottom of the screen.
    func setHelp(_ showing: Bool) {
        guard state.showingHelp != showing else { return }
        state.showingHelp = showing
        recenter(animated: true)
    }

    private func recenter(animated: Bool) {
        guard let screen = NSScreen.main else { return }
        let sf = screen.visibleFrame
        let w = CalcLayout.width + CalcLayout.outerPadding * 2
        let contentH = state.showingHelp ? CalcLayout.helpContentHeight : CalcLayout.contentHeight
        let h = contentH + CalcLayout.outerPadding * 2
        let target = NSRect(x: sf.origin.x + (sf.width - w) / 2,
                            y: sf.origin.y + (sf.height - h) / 2,
                            width: w, height: h)
        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.14
                animator().setFrame(target, display: true)
            }
        } else {
            setFrame(target, display: false)
        }
    }

    // MARK: - Keyboard

    override func cancelOperation(_ sender: Any?) {
        handleEscape()
    }

    override func keyDown(with event: NSEvent) {
        let cmd = event.modifierFlags.contains(.command)

        // "?" toggles help. Not "i" — `pi` and `ceil` both contain that letter, and
        // letters have to reach the expression for function names to be typeable.
        if !cmd, event.charactersIgnoringModifiers == "?" || event.characters == "?" {
            setHelp(!state.showingHelp)
            return
        }

        switch event.keyCode {
        case 126:  // up
            state.moveUp()
            return
        case 125:  // down
            state.moveDown()
            return
        case 123:  // left — move the caret; Cmd jumps to the start
            state.moveCaretLeft(toStart: cmd)
            return
        case 124:  // right — move the caret; Cmd jumps to the end
            state.moveCaretRight(toEnd: cmd)
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
        case 117:  // forward delete
            state.deleteForward()
            return
        case 10:
            // The ISO key left of "1". On German layouts this is "^", and it is a DEAD
            // key: macOS reports no character while it waits to compose (ê, â), so it
            // would otherwise be swallowed entirely. Insert the caret directly.
            if !cmd { state.type("^") }
            return
        default:
            break
        }

        if cmd { return }  // leave other Cmd shortcuts alone

        // Anything printable types into the expression, which also snaps focus back out
        // of the tape. `characters` first so composed dead-key output is honoured.
        let typed = event.characters ?? event.charactersIgnoringModifiers
        if let chars = typed, !chars.isEmpty {
            let filtered = chars.unicodeScalars.filter { Self.allowedInput.contains($0) }
            if !filtered.isEmpty {
                // Typing while the reference is open means you are done reading it.
                setHelp(false)
                state.type(String(String.UnicodeScalarView(filtered)))
            }
        }
    }

    /// Digits, operators, parentheses, and letters — letters are needed for function
    /// names like `sqrt(`. Unknown names simply fail to evaluate, which shows as a blank
    /// result rather than an error while typing.
    private static let allowedInput = CharacterSet(charactersIn:
        "0123456789.+-*/%^()×÷−abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")

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

    /// Escape unwinds one layer at a time: help, then the tape, then the panel itself.
    private func handleEscape() {
        if state.showingHelp {
            setHelp(false)
        } else if case .tape = state.focus {
            state.focus = .field
        } else {
            onDismiss()
        }
    }
}
