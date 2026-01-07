import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarManager: MenuBarManager?
    var settingsWindow: NSWindow?
    var overlayWindow: RecordingOverlayWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize Core Components
        _ = DictationEngine.shared
        
        checkAccessibilityPermissions()
        
        menuBarManager = MenuBarManager()
        overlayWindow = RecordingOverlayWindow()
        // Overlay window is controlled by its view's opacity observing state, 
        // but we need to order it front once so it exists.
        overlayWindow?.orderFrontRegardless()
        
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func checkAccessibilityPermissions() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options)
    }
    
    @objc func openSettingsWindow() {
        if settingsWindow == nil {
            let settingsView = SettingsView()
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 420),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered, defer: false)
            window.center()
            window.setFrameAutosaveName("Settings")
            window.contentView = NSHostingView(rootView: settingsView)
            window.title = "Ouisper Settings"
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        
        settingsWindow?.makeKeyAndOrderFront(self)
        NSApp.activate(ignoringOtherApps: true)
    }
}
