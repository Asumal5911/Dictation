import SwiftUI

struct FloatingDictationView: View {
    @ObservedObject var appState: AppState
    @State private var isHovering = false
    
    var body: some View {
        Group {
            if appState.isQuickDictating {
                // ACTIVE STATE
                HStack(spacing: 12) {
                    Button(action: {
                        withAnimation(.spring()) {
                            appState.cancelQuickDictation()
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .frame(width: 20, height: 20)
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // "Waveform" indicator
                    HStack(spacing: 3) {
                        ForEach(0..<8, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white)
                                .frame(width: 3, height: CGFloat.random(in: 4...16))
                                .animation(.easeInOut(duration: 0.2).repeatForever(), value: appState.isQuickDictating)
                        }
                    }
                    .frame(width: 40, height: 20)
                    
                    // Confirm/Finish Button
                    Button(action: {
                        withAnimation(.spring()) {
                            appState.finishQuickDictation()
                        }
                    }) {
                        Image(systemName: "checkmark.circle.fill")
                            .resizable()
                            .frame(width: 20, height: 20)
                            .foregroundColor(.white)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.85))
                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                )
                
            } else {
                // IDLE / DEFAULT STATE: Shorter thin horizontal rectangle with rounded corners, no icons, transparent
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        appState.startQuickDictation()
                    }
                }) {
                    RoundedRectangle(cornerRadius: 3.0, style: .continuous)
                        .fill(Color.black.opacity(isHovering ? 0.55 : 0.20))
                        .overlay(
                            RoundedRectangle(cornerRadius: 3.0, style: .continuous)
                                .stroke(Color.white.opacity(isHovering ? 0.30 : 0.12), lineWidth: 0.5)
                        )
                        .shadow(color: .black.opacity(0.10), radius: 2, x: 0, y: 1)
                        .frame(width: 42, height: 6)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                self.isHovering = hovering
            }
        }
        // Make the window draggable by its background
        .gesture(DragGesture().onChanged { _ in
            if let window = NSApplication.shared.windows.first(where: { $0.title == "FloatingOverlay" }) {
                window.performDrag(with: NSApp.currentEvent!)
            }
        })
    }
}
