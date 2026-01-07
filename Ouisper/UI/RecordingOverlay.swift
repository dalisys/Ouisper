import SwiftUI
import AppKit

class RecordingOverlayWindow: NSWindow {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 60),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        positionAboveDock()
        
        let rootView = RecordingOverlayView()
        self.contentView = NSHostingView(rootView: rootView)
    }

    private func positionAboveDock() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let size = frame.size
        let visible = screen.visibleFrame
        let x = visible.midX - (size.width / 2)
        let y = visible.minY + 20
        setFrameOrigin(NSPoint(x: x, y: y))
    }
}

struct RecordingOverlayView: View {
    @StateObject private var dictationState = DictationState.shared
    
    var body: some View {
        HStack(spacing: 12) {
            if dictationState.status == .recording {
                Circle()
                    .fill(OuisperTheme.neon)
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle()
                            .stroke(OuisperTheme.neon.opacity(0.6), lineWidth: 6)
                            .scaleEffect(1.6)
                            .opacity(0.4)
                            .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: true)
                    )
                Text("Listening")
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                    .foregroundColor(OuisperTheme.mist)
            } else if dictationState.status == .processing {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: OuisperTheme.cyan))
                    .scaleEffect(0.8)
                Text("Processing")
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                    .foregroundColor(OuisperTheme.mist)
            } else if dictationState.status == .refining {
                Image(systemName: "sparkles")
                    .foregroundColor(OuisperTheme.violet)
                    .scaleEffect(1.2)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: true)
                Text("Refining")
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                    .foregroundColor(OuisperTheme.mist)
            } else if case .error = dictationState.status {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(OuisperTheme.ember)
                Text("Error")
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                    .foregroundColor(OuisperTheme.mist)
            } else if dictationState.status == .success {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(OuisperTheme.neon)
                Text("Done")
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                    .foregroundColor(OuisperTheme.mist)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(OuisperTheme.cardGradient)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.45), radius: 16, x: 0, y: 10)
        )
        .opacity(dictationState.status == .idle ? 0 : 1)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: dictationState.status == .idle)
    }
}
