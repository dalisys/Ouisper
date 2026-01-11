import Cocoa
import Carbon
import Combine

class HotkeyManager: ObservableObject {
    static let shared = HotkeyManager()
    
    // Publishes events
    let onKeyDown = PassthroughSubject<Void, Never>()
    let onKeyUp = PassthroughSubject<Void, Never>()
    
    @Published var lastDetectedKeyCode: UInt16 = 0
    
    private var isKeyPressed = false
    private var eventHandlerRef: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupMonitor()
        setupCarbonEvents()
        
        // Observe settings changes to re-register Carbon hotkey if needed
        SettingsManager.shared.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateHotkeRegistration()
            }
        }.store(in: &cancellables)
        
        updateHotkeRegistration()
    }
    
    private func setupMonitor() {
        // Monitor for Fn key and modifiers (Flags Changed) - For Modifier-only shortcuts
        NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }
        
        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }

        // Monitor for regular keys like Insert (Key Down/Up) - Fallback / Debug
        NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            // print("Global Key Event: \(event.keyCode)") // Debug
            self?.handleNSEvent(event)
        }

        NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            self?.handleNSEvent(event)
            return event
        }
    }
    
    // MARK: - Carbon Hotkey Support
    
    private func setupCarbonEvents() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        var eventTypeRelease = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        
        let eventHandler: EventHandlerUPP = { (_, event, _) -> OSStatus in
            let kind = GetEventKind(event)
            if kind == kEventHotKeyPressed {
                HotkeyManager.shared.handleCarbonEvent(down: true)
            } else if kind == kEventHotKeyReleased {
                HotkeyManager.shared.handleCarbonEvent(down: false)
            }
            return noErr
        }
        
        InstallEventHandler(GetApplicationEventTarget(), eventHandler, 1, &eventType, nil, &eventHandlerRef)
        InstallEventHandler(GetApplicationEventTarget(), eventHandler, 1, &eventTypeRelease, nil, &eventHandlerRef)
    }
    
    func updateHotkeRegistration() {
        // Unregister existing
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        
        let option = SettingsManager.shared.hotkey
        
        // Only register Carbon hotkey for .custom
        guard option == .custom else { return }
        
        let code = SettingsManager.shared.customHotkeyKeyCode
        let mods = SettingsManager.shared.customHotkeyModifiers
        
        // If code is -1, it's a modifier-only key (handled by NSEvent)
        guard code != -1 else { return }
        
        let carbonID = EventHotKeyID(signature: OSType(0x4F555350), id: 1) // OUSP
        let carbonMods = convertNSEventModifiersToCarbon(Int(mods))
        
        RegisterEventHotKey(UInt32(code), carbonMods, carbonID, GetApplicationEventTarget(), 0, &hotKeyRef)
        print("Registered Carbon Hotkey: Code \(code), Mods \(carbonMods)")
    }
    
    func handleCarbonEvent(down: Bool) {
        if down {
            if !isKeyPressed {
                isKeyPressed = true
                onKeyDown.send()
                print("Carbon Hotkey Pressed")
            }
        } else {
            if isKeyPressed {
                isKeyPressed = false
                onKeyUp.send()
                print("Carbon Hotkey Released")
            }
        }
    }
    
    private func convertNSEventModifiersToCarbon(_ flags: Int) -> UInt32 {
        var carbonFlags: UInt32 = 0
        let nsFlags = NSEvent.ModifierFlags(rawValue: UInt(bitPattern: flags))
        
        if nsFlags.contains(.command) { carbonFlags |= UInt32(cmdKey) }
        if nsFlags.contains(.option) { carbonFlags |= UInt32(optionKey) }
        if nsFlags.contains(.control) { carbonFlags |= UInt32(controlKey) }
        if nsFlags.contains(.shift) { carbonFlags |= UInt32(shiftKey) }
        
        return carbonFlags
    }
    
    // MARK: - NSEvent Fallback (For Modifier-Only keys)
    
    private func handleNSEvent(_ event: NSEvent) {
        if event.type == .keyDown {
            DispatchQueue.main.async {
                self.lastDetectedKeyCode = event.keyCode
            }
        }
        
        // If we are using Carbon for .custom, we ignore NSEvents for it to avoid double-triggering
        // UNLESS it's the 'Insert' key which Carbon might sometimes miss if not mapped?
        // Actually, if updateHotkeRegistration registered it, Carbon handles it.
        
        let option = SettingsManager.shared.hotkey
        if option == .insert {
             if event.type == .keyDown && event.keyCode == 114 {
                if !isKeyPressed {
                    isKeyPressed = true
                    onKeyDown.send()
                    print("Hotkey Pressed: Insert")
                }
            } else if event.type == .keyUp && event.keyCode == 114 {
                if isKeyPressed {
                    isKeyPressed = false
                    onKeyUp.send()
                    print("Hotkey Released: Insert")
                }
            }
        }
    }
    
    private func handleFlagsChanged(_ event: NSEvent) {
        let option = SettingsManager.shared.hotkey
        let flags = event.modifierFlags
        let keyCode = event.keyCode
        
        var isTargetPressed = false
        
        switch option {
        case .fn:
            if keyCode == 63 {
                isTargetPressed = flags.contains(.function)
            } else {
                isTargetPressed = isKeyPressed && flags.contains(.function)
            }
            
        case .rightCommand: // 54
            if !flags.contains(.command) {
                isTargetPressed = false
            } else {
                if keyCode == 54 {
                    isTargetPressed = true
                } else {
                    isTargetPressed = isKeyPressed
                }
            }
            
        case .rightOption: // 61
            if !flags.contains(.option) {
                isTargetPressed = false
            } else {
                if keyCode == 61 {
                    isTargetPressed = true
                } else {
                    isTargetPressed = isKeyPressed
                }
            }
            
        case .control:
            isTargetPressed = flags.contains(.control)
            
        case .insert, .custom:
            // Custom with key is handled by Carbon.
            // Custom with modifiers-only... could be handled here.
            if option == .custom && SettingsManager.shared.customHotkeyKeyCode == -1 {
                 let targetMods = NSEvent.ModifierFlags(rawValue: UInt(bitPattern: SettingsManager.shared.customHotkeyModifiers))
                 isTargetPressed = flags.intersection([.command, .option, .control, .shift]) == targetMods.intersection([.command, .option, .control, .shift])
            } else {
                isTargetPressed = false
            }
        }
        
        if isTargetPressed && !isKeyPressed {
            isKeyPressed = true
            onKeyDown.send()
            print("Hotkey Pressed: \(option.rawValue)")
        } else if !isTargetPressed && isKeyPressed {
            isKeyPressed = false
            onKeyUp.send()
            print("Hotkey Released: \(option.rawValue)")
        }
    }
}