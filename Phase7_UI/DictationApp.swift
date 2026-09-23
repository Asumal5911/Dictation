import SwiftUI
import IOKit.pwr_mgt

@main
struct DictationApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        MenuBarExtra("Dictation", systemImage: appState.isRecording ? "mic.fill" : "mic") {
            MenuView(appState: appState)
        }
        .menuBarExtraStyle(.window)
    }
}

class AppState: ObservableObject {
    @Published var isRecording: Bool = false
    @Published var duration: TimeInterval = 0
    @Published var connectionState: String = "Connected to Recorder"
    @Published var batteryWarning: Bool = false
    @Published var audioLevel: Float = 0.0
    
    // Quick Dictation State
    @Published var isQuickDictating: Bool = false
    private var floatingPanel: NSPanel?
    
    private var timer: Timer?
    private var powerAssertionID: IOPMAssertionID = 0
    
    init() {
        // Automatically show the persistent floating widget on launch
        DispatchQueue.main.async {
            self.setupPersistentFloatingPill()
        }
    }
    
    func startLecture() {
        isRecording = true
        duration = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.duration += 1
        }
        preventSleep()
    }
    
    func stopLecture() {
        isRecording = false
        timer?.invalidate()
        timer = nil
        allowSleep()
    }
    
    // MARK: - Quick Dictation Overlay
    
    func toggleQuickDictation() {
        if isQuickDictating {
            finishQuickDictation()
        } else {
            startQuickDictation()
        }
    }
    
    private func setupPersistentFloatingPill() {
        if floatingPanel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 200, height: 60),
                styleMask: [.nonactivatingPanel, .borderless],
                backing: .buffered,
                defer: false
            )
            panel.title = "FloatingOverlay"
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            // Accept mouse events so hover and clicks work
            panel.ignoresMouseEvents = false
            
            let hostingView = NSHostingView(rootView: FloatingDictationView(appState: self))
            panel.contentView = hostingView
            
            if let screen = NSScreen.main {
                let rect = screen.visibleFrame
                // Position bottom right
                let x = rect.maxX - 150
                let y = rect.minY + 50
                panel.setFrameOrigin(NSPoint(x: x, y: y))
            }
            
            floatingPanel = panel
        }
        floatingPanel?.makeKeyAndOrderFront(nil)
    }
    
    func startQuickDictation() {
        isQuickDictating = true
        setupPersistentFloatingPill()
    }
    
    func finishQuickDictation() {
        isQuickDictating = false
        // DO NOT orderOut the panel. It stays on screen in idle mode!
        print("Finished Quick Dictation. Processing text...")
    }
    
    func cancelQuickDictation() {
        isQuickDictating = false
        // DO NOT orderOut the panel. It stays on screen in idle mode!
        print("Cancelled Quick Dictation.")
    }
    
    // MARK: - Sleep Management
    
    private func preventSleep() {
        let reasonForActivity = "Active Lecture Recording" as CFString
        _ = IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
                                        IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                        reasonForActivity,
                                        &powerAssertionID)
    }
    
    private func allowSleep() {
        if powerAssertionID != 0 {
            IOPMAssertionRelease(powerAssertionID)
            powerAssertionID = 0
        }
    }
}
