import Cocoa
import ApplicationServices
import Carbon

class QuickDictator {
    
    private var targetElement: AXUIElement?
    private var initialPID: pid_t = 0
    private var savedClipboard: String?
    
    func captureFocus() -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedApp: CFTypeRef?
        
        let err = AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedApp)
        guard err == .success, let appElement = focusedApp as! AXUIElement? else { 
            print("Could not find focused application.")
            return false 
        }
        
        var focusedUIElement: CFTypeRef?
        let err2 = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedUIElement)
        
        guard err2 == .success, let element = focusedUIElement as! AXUIElement? else { 
            print("Could not find focused UI element.")
            return false 
        }
        
        // 1. Check if it's a secure password field
        var subrole: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subrole)
        
        if (subrole as? String == "AXSecureTextField") {
            print("SECURITY: Ignoring secure password field.")
            return false
        }
        
        self.targetElement = element
        
        // 2. Capture the PID to verify focus doesn't drastically change while we are dictating
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        self.initialPID = pid
        
        print("Captured focus on PID: \(pid)")
        return true
    }
    
    func injectText(_ text: String) {
        guard targetElement != nil else {
            fallbackToClipboard(text)
            return
        }
        
        // 1. Verify the app is still in front and context hasn't changed
        if let frontApp = NSWorkspace.shared.frontmostApplication, frontApp.processIdentifier != initialPID {
            print("Context changed (user switched apps). Aborting injection.")
            fallbackToClipboard(text)
            return
        }
        
        // 2. Inject via simulated paste (Cmd+V) 
        // This is the most reliable way to insert text at the cursor across all Mac apps (VSCode, Chrome, Word).
        simulatePaste(text)
    }
    
    private func simulatePaste(_ text: String) {
        let pasteboard = NSPasteboard.general
        self.savedClipboard = pasteboard.string(forType: .string) // Save old clipboard
        
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // Simulate Cmd+V
        let vKeyCode: CGKeyCode = 0x09 // 'v' key
        let source = CGEventSource(stateID: .hidSystemState)
        
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
        print("Successfully injected text via simulated paste.")
        
        // Note: Restoring clipboard immediately can sometimes race the OS paste handler.
        // A slight delay would be needed to restore it cleanly.
    }
    
    private func fallbackToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        print("Copied dictation to clipboard as fallback.")
        
        // Trigger a macOS notification
        let notification = NSUserNotification()
        notification.title = "Dictation Completed"
        notification.informativeText = "App focus was lost. Text copied to clipboard."
        NSUserNotificationCenter.default.deliver(notification)
    }
}

// --- Proof of Concept Execution ---

print("Starting Quick Dictation Accessibility Proof of Concept...")
let dictator = QuickDictator()

// 1. Capture focus (In a real app, this happens exactly on key-down of the hotkey)
if dictator.captureFocus() {
    print("Focus captured successfully. Simulating transcription latency (2 seconds)...")
    
    // Simulate the latency of the user talking and Whisper transcribing
    sleep(2)
    
    let transcriptionResult = "This is a quickly dictated sentence formatted perfectly."
    
    // 2. Inject
    dictator.injectText(transcriptionResult)
} else {
    print("Could not capture a valid text field (Make sure a text field is focused before running).")
}
