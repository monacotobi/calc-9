import AppKit
import Carbon.HIToolbox

/// Global hotkey via Carbon's `RegisterEventHotKey`.
///
/// Deliberately NOT a `CGEventTap` like Clip-9 uses. A tap receives every keystroke you
/// type anywhere and passes the rest through; this registers one combination and can see
/// nothing else. Calc-9 needs Accessibility for pasting regardless, so this is not about
/// avoiding a prompt — it is about the app being unable to observe your typing even in
/// principle. It is also less code: no C function-pointer bridge, no global instance, and
/// no re-enabling a tap the system disabled.
///
/// Verified by spike (2026-08-14): fires with `AXIsProcessTrusted() == false`.
///
/// Two ordering requirements, both of which cause SILENT failure — registration returns
/// `noErr` while nothing ever fires:
///   1. `NSApplication.shared` must exist before any Carbon call here.
///   2. The handler must be installed on `GetEventDispatcherTarget()`, not
///      `GetApplicationEventTarget()`.
final class HotKeyManager {

    /// Set before `register()`; the C callback cannot capture context.
    fileprivate static var onTrigger: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    /// Cmd+Option+9.
    private let keyCode = UInt32(kVK_ANSI_9)
    private let modifiers = UInt32(cmdKey | optionKey)

    var isRegistered: Bool { hotKeyRef != nil }

    init(onTrigger: @escaping () -> Void) {
        HotKeyManager.onTrigger = onTrigger
        register()
    }

    deinit { unregister() }

    private func register() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))

        let handlerStatus = InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, _, _ -> OSStatus in
                DispatchQueue.main.async { HotKeyManager.onTrigger?() }
                return noErr
            },
            1, &eventType, nil, &handlerRef
        )
        guard handlerStatus == noErr else {
            NSLog("[HotKeyManager] InstallEventHandler failed: \(handlerStatus)")
            return
        }

        let id = EventHotKeyID(signature: OSType(0x43414c43), id: 1)  // 'CALC'
        let status = RegisterEventHotKey(keyCode, modifiers, id,
                                         GetEventDispatcherTarget(), 0, &hotKeyRef)
        if status == noErr {
            NSLog("[HotKeyManager] Cmd+Option+9 registered.")
        } else {
            // Most likely another app already owns the combination.
            NSLog("[HotKeyManager] RegisterEventHotKey failed: \(status)")
            hotKeyRef = nil
        }
    }

    private func unregister() {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref) }
        if let ref = handlerRef { RemoveEventHandler(ref) }
        hotKeyRef = nil
        handlerRef = nil
    }
}
