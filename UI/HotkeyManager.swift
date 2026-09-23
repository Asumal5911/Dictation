import Cocoa
import ApplicationServices
import Carbon

final class HotkeyManager {
    var onFnDown: (() -> Void)?
    var onFnUp: ((TimeInterval) -> Void)?
    var onToggleHotkey: (() -> Void)?

    private var isFnPressed = false
    private var pressedAt: Date?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    static func isAccessibilityGranted() -> Bool {
        return AXIsProcessTrusted()
    }

    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func startMonitoring() {
        if HotkeyManager.isAccessibilityGranted() {
            print("✅ Accessibility permissions are granted.")
        } else {
            print("ℹ️ Accessibility permission not yet granted; Option+D hotkey and clipboard copy available without it.")
        }

        // 1. Carbon Global Hotkey (Option + D): Works system-wide without Accessibility permissions!
        registerCarbonHotKey()

        // 2. Fn Key monitoring: Requires Accessibility/ListenEvent for global background interception
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }
    }

    private func registerCarbonHotKey() {
        let hotKeyID = EventHotKeyID(signature: OSType(0x44494354), id: 1) // 'DICT', 1
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (nextHandler, theEvent, userData) -> OSStatus in
                guard let userData = userData else { return noErr }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async {
                    manager.onToggleHotkey?()
                }
                return noErr
            },
            1,
            &eventType,
            selfPointer,
            &eventHandlerRef
        )

        // Option + D: kVK_ANSI_D (0x02), optionKey
        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_D),
            UInt32(optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if status == noErr {
            print("✅ Global hotkey Option+D registered (always active system-wide)")
        } else {
            print("⚠️ Failed to register Option+D hotkey (status: \(status))")
        }
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        let fnPressedNow = event.modifierFlags.contains(.function)

        if fnPressedNow && !isFnPressed {
            isFnPressed = true
            pressedAt = Date()
            onFnDown?()
            return
        }

        guard !fnPressedNow, isFnPressed else { return }
        isFnPressed = false
        let duration = Date().timeIntervalSince(pressedAt ?? Date())
        pressedAt = nil

        onFnUp?(duration)
    }

    deinit {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }
}
