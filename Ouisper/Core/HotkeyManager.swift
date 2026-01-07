import Cocoa
import Combine

class HotkeyManager: ObservableObject {
    static let shared = HotkeyManager()
    
    // Publishes events
    let onKeyDown = PassthroughSubject<Void, Never>()
    let onKeyUp = PassthroughSubject<Void, Never>()
    
    private var isFnPressed = false
    
    private init() {
        setupMonitor()
    }
    
    private func setupMonitor() {
        // Monitor for Fn key (Flags Changed)
        NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }
        
        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }
    }
    
    private func handleFlagsChanged(_ event: NSEvent) {
        // Check for Fn key
        // Note: exact flag checking might depend on keyboard.
        // usually .function or .numericPad/function row depending on settings.
        
        let flags = event.modifierFlags
        let fnPressed = flags.contains(.function) // This detects Fn key
        
        if fnPressed && !isFnPressed {
            isFnPressed = true
            onKeyDown.send()
            print("Fn Key Pressed")
        } else if !fnPressed && isFnPressed {
            isFnPressed = false
            onKeyUp.send()
            print("Fn Key Released")
        }
    }
}
