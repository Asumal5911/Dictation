import SwiftUI

struct MenuView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Mac Local Dictation")
                    .font(.headline)
                Spacer()
                Circle()
                    .fill(appState.isBackendRunning ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                    .shadow(color: appState.isBackendRunning ? .green.opacity(0.65) : .clear, radius: 4)
            }
            .padding(.bottom, 2)

            HStack(spacing: 8) {
                Circle()
                    .fill(appState.isBackendRunning ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(appState.engineStatusText)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(appState.isBackendRunning ? .green : .red)
            }

            Text(appState.connectionState)
                .font(.caption)
                .foregroundColor(.secondary)

            // Permissions section
            VStack(alignment: .leading, spacing: 6) {
                // Microphone status
                if !appState.hasMicrophone {
                    HStack {
                        Image(systemName: "mic.slash.fill")
                            .foregroundColor(.red)
                        Text("Microphone Needed")
                            .font(.caption)
                        Spacer()
                        Button("Enable") {
                            appState.requestMicrophoneAccess()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                } else {
                    HStack {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundColor(.green)
                        Text("Microphone Access Granted")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                // Accessibility status
                if !appState.hasAccessibility {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Accessibility Needed (auto-paste & Fn)")
                            .font(.caption)
                        Spacer()
                        Button("Enable") {
                            appState.requestAccessibility()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                } else {
                    HStack {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundColor(.green)
                        Text("Accessibility Granted")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 2)

            // Live Audio Level Meter
            if appState.isQuickDictating || appState.isRecording {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Input Level:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(appState.audioLevel > 0.05 ? "Voice Detected" : "Listening…")
                            .font(.caption2)
                            .foregroundColor(appState.audioLevel > 0.05 ? .green : .secondary)
                    }

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .frame(width: geometry.size.width, height: 8)
                                .opacity(0.3)
                                .foregroundColor(.gray)
                                .cornerRadius(4)
                            Rectangle()
                                .frame(
                                    width: min(CGFloat(appState.audioLevel) * geometry.size.width, geometry.size.width),
                                    height: 8
                                )
                                .foregroundColor(.green)
                                .cornerRadius(4)
                                .animation(.easeOut(duration: 0.08), value: appState.audioLevel)
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

            if appState.isBackendRunning {
                Button(action: appState.stopBackgroundTasks) {
                    Label("Dictation Engine Running", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .foregroundColor(.green)

                Button(action: appState.stopBackgroundTasks) {
                    Label("Stop Dictation Engine", systemImage: "stop.circle")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
            } else {
                Button(action: appState.startBackgroundTasks) {
                    Label("Start Dictation Engine", systemImage: "play.circle.fill")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }

            Button(action: appState.toggleQuickDictation) {
                Label(
                    appState.isQuickDictating ? "Finish Dictation" : "Trigger Quick Dictation",
                    systemImage: appState.isQuickDictating ? "checkmark.circle.fill" : "waveform.circle"
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Text("Press ⌥D (Option+D) or tap Fn to dictate. Hold Fn for push-to-talk.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            Button(action: { NSApplication.shared.terminate(nil) }) {
                Text("Close UI (Keep Engine Running)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)

            Button(action: {
                appState.stopBackgroundTasks()
                NSApplication.shared.terminate(nil)
            }) {
                Text("Stop Engine & Quit Completely")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .frame(width: 310)
    }

    private func timeString(time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = Int(time) / 60 % 60
        let seconds = Int(time) % 60
        return String(format: "%02i:%02i:%02i", hours, minutes, seconds)
    }
}
