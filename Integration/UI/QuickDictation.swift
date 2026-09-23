import Cocoa
import ApplicationServices

final class QuickDictator {

    private var targetPID: pid_t = 0
    private var targetElement: AXUIElement?
    private var capturedSecureField = false
    private var lastUserApplicationPID: pid_t = 0
    private var activationObserver: NSObjectProtocol?

    init() {
        rememberUserApplication(NSWorkspace.shared.frontmostApplication)
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self?.rememberUserApplication(app)
        }
    }

    // Capture the exact focused control while the user's cursor is still there.
    func captureFocus() {
        targetPID = 0
        targetElement = nil
        capturedSecureField = false

        var focusedApplicationValue: CFTypeRef?
        let systemWide = AXUIElementCreateSystemWide()
        let focusedApplicationResult = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedApplicationAttribute as CFString,
            &focusedApplicationValue
        )

        var candidatePID: pid_t = 0
        if focusedApplicationResult == .success,
           let focusedApplicationValue {
            AXUIElementGetPid(focusedApplicationValue as! AXUIElement, &candidatePID)
        }

        if !isUserApplication(pid: candidatePID) {
            let frontmost = NSWorkspace.shared.frontmostApplication
            rememberUserApplication(frontmost)
            candidatePID = isUserApplication(pid: frontmost?.processIdentifier ?? 0)
                ? (frontmost?.processIdentifier ?? 0)
                : lastUserApplicationPID
        }

        guard isUserApplication(pid: candidatePID),
              let app = NSRunningApplication(processIdentifier: candidatePID) else {
            print("ℹ️ No target application captured yet")
            return
        }

        targetPID = candidatePID
        lastUserApplicationPID = candidatePID
        let applicationElement = AXUIElementCreateApplication(targetPID)
        var focusedValue: CFTypeRef?
        let focusResult = AXUIElementCopyAttributeValue(
            applicationElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        )

        if focusResult == .success, let focusedValue {
            let element = focusedValue as! AXUIElement
            var subroleValue: CFTypeRef?
            AXUIElementCopyAttributeValue(
                element,
                kAXSubroleAttribute as CFString,
                &subroleValue
            )
            capturedSecureField = (subroleValue as? String) == "AXSecureTextField"
            if !capturedSecureField {
                targetElement = element
            }
        }

        print("🎯 Captured target app: \(app.localizedName ?? "unknown") (PID \(targetPID))")
    }

    private func rememberUserApplication(_ app: NSRunningApplication?) {
        guard let app, isUserApplication(pid: app.processIdentifier) else { return }
        lastUserApplicationPID = app.processIdentifier
    }

    private func isUserApplication(pid: pid_t) -> Bool {
        guard pid != 0,
              pid != ProcessInfo.processInfo.processIdentifier,
              let app = NSRunningApplication(processIdentifier: pid) else {
            return false
        }
        let ignoredBundleIDs: Set<String> = [
            "com.apple.loginwindow",
            "com.apple.systemuiserver",
            "com.apple.dock",
            "com.apple.controlcenter",
            "com.apple.spotlight",
        ]
        if let bundleIdentifier = app.bundleIdentifier,
           ignoredBundleIDs.contains(bundleIdentifier.lowercased()) {
            return false
        }
        return app.activationPolicy == .regular
    }

    /// Instantly pastes dictated notes into the target application.
    func pasteDictationResult(
        _ text: String,
        completion: @escaping (Bool) -> Void
    ) {
        guard !text.isEmpty else {
            completion(true)
            return
        }

        guard !capturedSecureField else {
            print("🔒 Dictation is disabled for secure password fields")
            completion(false)
            return
        }

        // Always copy text to clipboard so notes are never lost
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Resolve target application PID
        var pidToUse = targetPID
        if pidToUse == 0 || !isUserApplication(pid: pidToUse) {
            pidToUse = lastUserApplicationPID
        }
        if pidToUse == 0 || !isUserApplication(pid: pidToUse) {
            if let front = NSWorkspace.shared.frontmostApplication, isUserApplication(pid: front.processIdentifier) {
                pidToUse = front.processIdentifier
            }
        }

        guard pidToUse != 0,
              let targetApp = NSRunningApplication(processIdentifier: pidToUse) else {
            print("📋 Notes copied to clipboard. Paste manually with ⌘V.")
            completion(false)
            return
        }

        // Deactivate ourselves so macOS gives full focus to the target app
        NSApp.deactivate()
        targetApp.activate()

        waitForTargetFocus(targetPID: pidToUse, attempt: 0) { [weak self] in
            guard let self else { return }

            // Method 1: Direct AX text insertion into focused text element (TextEdit, Notes, Pages, etc.)
            if let element = self.currentTargetElement(for: pidToUse),
               self.canInsertSelectedText(into: element) {
                let axResult = AXUIElementSetAttributeValue(
                    element,
                    kAXSelectedTextAttribute as CFString,
                    text as CFTypeRef
                )
                if axResult == .success {
                    print("✅ Inserted dictated notes directly into \(targetApp.localizedName ?? "app") via Accessibility")
                    completion(true)
                    return
                }
            }

            // Method 2: Simulated Command+V keystroke with realistic hardware timing
            if HotkeyManager.isAccessibilityGranted() {
                self.postPasteKeystrokes(to: pidToUse)
                print("✅ Pasted dictated notes into \(targetApp.localizedName ?? "app") via simulated keystrokes")
                completion(true)
            } else {
                // If accessibility is not granted, try AppleScript as secondary attempt
                self.postAppleScriptPaste()
                print("📋 Notes copied to clipboard. Enable Accessibility in Settings for automatic paste.")
                completion(false)
            }
        }
    }

    private func waitForTargetFocus(targetPID: pid_t, attempt: Int, completion: @escaping () -> Void) {
        if NSWorkspace.shared.frontmostApplication?.processIdentifier == targetPID || attempt >= 8 {
            // Settle window focus so the text caret/cursor is active
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                completion()
            }
            return
        }

        NSRunningApplication(processIdentifier: targetPID)?.activate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { [weak self] in
            self?.waitForTargetFocus(targetPID: targetPID, attempt: attempt + 1, completion: completion)
        }
    }

    private func currentTargetElement(for pid: pid_t) -> AXUIElement? {
        if let targetElement {
            var elementPID: pid_t = 0
            if AXUIElementGetPid(targetElement, &elementPID) == .success,
               elementPID == pid {
                return targetElement
            }
        }

        let applicationElement = AXUIElementCreateApplication(pid)
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            applicationElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        ) == .success,
              let focusedValue else {
            return nil
        }
        let element = focusedValue as! AXUIElement
        targetElement = element
        return element
    }

    private func canInsertSelectedText(into element: AXUIElement) -> Bool {
        var settable = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(
            element,
            kAXSelectedTextAttribute as CFString,
            &settable
        ) == .success && settable.boolValue
    }

    private func postPasteKeystrokes(to pid: pid_t) {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }

        let cmdKeyCode: CGKeyCode = 0x37 // Command
        let vKeyCode: CGKeyCode = 0x09   // 'v'

        guard let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: cmdKeyCode, keyDown: true),
              let vDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let vUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false),
              let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: cmdKeyCode, keyDown: false) else {
            return
        }

        cmdDown.flags = .maskCommand
        vDown.flags = .maskCommand
        vUp.flags = .maskCommand
        cmdUp.flags = []

        // Post directly to target process event queue
        cmdDown.postToPid(pid)
        Thread.sleep(forTimeInterval: 0.02)
        vDown.postToPid(pid)
        Thread.sleep(forTimeInterval: 0.03)
        vUp.postToPid(pid)
        Thread.sleep(forTimeInterval: 0.02)
        cmdUp.postToPid(pid)

        // Also post to HID event tap as system-wide fallback
        cmdDown.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.01)
        vDown.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.02)
        vUp.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.01)
        cmdUp.post(tap: .cghidEventTap)
    }

    private func postAppleScriptPaste() {
        DispatchQueue.global(qos: .userInitiated).async {
            let script = "tell application \"System Events\" to keystroke \"v\" using command down"
            if let appleScript = NSAppleScript(source: script) {
                var error: NSDictionary?
                appleScript.executeAndReturnError(&error)
            }
        }
    }

    deinit {
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        }
    }
}
