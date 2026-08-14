import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?
    private var hotKeyManager: HotKeyManager?
    private var window: CalcWindow?

    /// The app that was frontmost when the panel opened. The paste target.
    private var previousApp: NSRunningApplication?

    private var loginItemMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        setupWindow()
        setupStatusBar()

        hotKeyManager = HotKeyManager { [weak self] in
            self?.showPanel(rememberFrontmostApp: true)
        }

        checkAccessibilityPermission()

        // Launching an LSUIElement app otherwise looks like nothing happened: no window,
        // no Dock icon. Show the panel once so there is visible feedback.
        showPanel(rememberFrontmostApp: true)
    }

    // MARK: - Window

    private func setupWindow() {
        window = CalcWindow(
            onCommit: { [weak self] result in
                guard let self else { return }
                self.window?.hide()

                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(result, forType: .string)

                // No target when opened from the menu bar — copy only.
                guard let target = self.previousApp else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    PasteSimulator.paste(into: target)
                }
            },
            onDismiss: { [weak self] in
                self?.window?.hide()
            }
        )
    }

    private func showPanel(rememberFrontmostApp: Bool) {
        previousApp = rememberFrontmostApp ? NSWorkspace.shared.frontmostApplication : nil
        window?.show()
    }

    // MARK: - Status bar

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "function",
                                            accessibilityDescription: "Calc-9")

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show Calc-9  ⌘⌥9",
                                action: #selector(showFromMenu), keyEquivalent: ""))
        menu.addItem(.separator())

        let loginItem = NSMenuItem(title: "Launch at Login",
                                   action: #selector(toggleLoginItem), keyEquivalent: "")
        menu.addItem(loginItem)
        loginItemMenuItem = loginItem

        menu.addItem(NSMenuItem(title: "Accessibility Settings...",
                                action: #selector(openAccessibilitySettings), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Calc-9",
                                action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        menu.delegate = self
        statusItem?.menu = menu
    }

    /// Opened from the menu bar there is no sensible paste target — the menu bar itself was
    /// frontmost — so this copies without pasting.
    @objc private func showFromMenu() {
        showPanel(rememberFrontmostApp: false)
    }

    @objc private func toggleLoginItem() {
        LoginItem.setEnabled(!LoginItem.isEnabled)
        refreshLoginItemState()
    }

    private func refreshLoginItemState() {
        loginItemMenuItem?.state = LoginItem.isEnabled ? .on : .off
        loginItemMenuItem?.title = LoginItem.statusDescription == "needs approval in System Settings"
            ? "Launch at Login — approve in System Settings"
            : "Launch at Login"
    }

    // MARK: - Accessibility

    /// Needed only for pasting. The hotkey works without it, so a refusal degrades the app
    /// rather than breaking it: results still land on the clipboard.
    private func checkAccessibilityPermission() {
        guard !AXIsProcessTrusted() else { return }
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Accessibility Access Needed to Paste"
            alert.informativeText = """
                Calc-9 pastes results into the app you were using, which macOS puts behind \
                Accessibility access.

                Without it, Calc-9 still works — the hotkey opens the panel and results are \
                copied to your clipboard. You just paste them yourself with Cmd+V.

                Enable it in System Settings > Privacy & Security > Accessibility.
                """
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Later")
            alert.alertStyle = .informational
            if alert.runModal() == .alertFirstButtonReturn {
                self.openAccessibilitySettings()
            }
        }
    }

    @objc private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

extension AppDelegate: NSMenuDelegate {
    /// Read the real login-item state each time the menu opens, so it cannot drift from
    /// what System Settings says.
    func menuWillOpen(_ menu: NSMenu) {
        refreshLoginItemState()
    }
}
