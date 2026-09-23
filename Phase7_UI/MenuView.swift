import SwiftUI

struct MenuView: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            // Header
            HStack {
                Text("Mac Local Dictation")
                    .font(.headline)
                Spacer()
                Circle()
                    .fill(appState.isRecording ? Color.red : Color.gray)
                    .frame(width: 10, height: 10)
            }
            .padding(.bottom, 4)
            
            // Status & Telemetry
            Group {
                Text("Status: \(appState.connectionState)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if appState.isRecording {
                    Text("Duration: \(timeString(time: appState.duration))")
                        .font(.system(.body, design: .monospaced))
                    
                    // Simple Audio Meter
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .frame(width: geometry.size.width, height: 8)
                                .opacity(0.3)
                                .foregroundColor(.gray)
                            
                            Rectangle()
                                .frame(width: min(CGFloat(appState.audioLevel) * geometry.size.width, geometry.size.width), height: 8)
                                .foregroundColor(.green)
                        }
                    }
                    .frame(height: 8)
                }
            }
            
            Divider()
            
            if appState.batteryWarning {
                Label("Battery Critical! Pausing formatting.", systemImage: "battery.25")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            // Main Controls
            if appState.isRecording {
                Button(action: {
                    appState.stopLecture()
                }) {
                    Label("Stop Lecture", systemImage: "stop.circle.fill")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.red)
            } else {
                Button(action: {
                    appState.startLecture()
                }) {
                    Label("Start Lecture", systemImage: "record.circle")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Button(action: {
                appState.toggleQuickDictation()
                // Auto-close the menu bar popover when launching the floating pill
            }) {
                Label("Trigger Quick Dictation Overlay", systemImage: "waveform.circle")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: {
                // Open Settings for Quick Dictation Hotkey
            }) {
                Label("Quick Dictation Settings...", systemImage: "keyboard")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(PlainButtonStyle())
            
            Divider()
            
            // Explicit Termination Options
            Button(action: {
                // Just close this UI process. The background agent continues!
                NSApplication.shared.terminate(nil)
            }) {
                Text("Close UI (Keep Recording in Background)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: {
                appState.stopLecture()
                // Send XPC kill to agent if desired, then quit
                NSApplication.shared.terminate(nil)
            }) {
                Text("Stop Recording & Quit Completely")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            .buttonStyle(PlainButtonStyle())
            
        }
        .padding()
        .frame(width: 280)
    }
    
    private func timeString(time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = Int(time) / 60 % 60
        let seconds = Int(time) % 60
        return String(format: "%02i:%02i:%02i", hours, minutes, seconds)
    }
}
