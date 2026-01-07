import Cocoa
import ApplicationServices

class TextInjector {
    
    static func inject(_ text: String) {
        DictationState.shared.lastInjectionError = ""
        // Method 1: AXUIElement (Accessibility API)
        if injectViaAccessibility(text) {
            return
        }
        
        // Method 2: Paste via Clipboard
        if !pasteViaClipboard(text) {
            DictationState.shared.lastInjectionError = "Paste blocked by the active app. Text copied to clipboard."
        }
    }

    static func injectTerminal(_ text: String) {
        DictationState.shared.lastInjectionError = ""
        if TerminalInjector.typeText(text) {
            return
        }

        if !pasteViaClipboard(text) {
            DictationState.shared.lastInjectionError = "Paste blocked by the active app. Text copied to clipboard."
        }
    }

    static func injectVsCodeTerminal(_ text: String, app: NSRunningApplication?) -> Bool {
        guard let app else { return false }
        copyToClipboard(text)
        return VSCodeTerminalInjector.pasteViaCommandPalette(app: app)
    }

    static func copyOnly(_ text: String) {
        copyToClipboard(text)
        DictationState.shared.lastInjectionError = "Text copied to clipboard. Press Cmd+V to paste."
    }

    static func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    private static func injectViaAccessibility(_ text: String) -> Bool {
        guard AXIsProcessTrusted() else {
            return false
        }

        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: AnyObject?
        
        let result = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        
        if result == .success, let element = focusedElement {
            let axElement = element as! AXUIElement
            // Try inserting at selection first, then fall back to setting value.
            if isAttributeSettable(axElement, kAXSelectedTextAttribute as CFString) {
                let selectedError = AXUIElementSetAttributeValue(axElement, kAXSelectedTextAttribute as CFString, text as CFTypeRef)
                if selectedError == .success {
                    return true
                }
            }

            if isAttributeSettable(axElement, kAXValueAttribute as CFString) {
                let valueError = AXUIElementSetAttributeValue(axElement, kAXValueAttribute as CFString, text as CFTypeRef)
                if valueError == .success {
                    return true
                }
            }
        }
        
        return false
    }
    
    private static func pasteViaClipboard(_ text: String) -> Bool {
        let pasteboard = NSPasteboard.general
        let originalString = pasteboard.string(forType: .string)
        
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // Simulate Cmd+V
        let source = CGEventSource(stateID: .combinedSessionState)
        
        let vKeyCode: CGKeyCode = 0x09 // 'v'
        
        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
        cmdDown?.flags = .maskCommand
        
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        cmdUp?.flags = .maskCommand
        
        cmdDown?.post(tap: .cghidEventTap)
        // Small delay helps ensure the keydown is processed before keyup.
        usleep(20000)
        cmdUp?.post(tap: .cghidEventTap)
        
        // Restore clipboard after a short delay to avoid clobbering user's clipboard.
        if let originalString {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                pasteboard.clearContents()
                pasteboard.setString(originalString, forType: .string)
            }
        }
        
        // Signal clipboard fallback
        DispatchQueue.main.async {
            DictationState.shared.lastInjectionError = "Text copied to clipboard. Press Cmd+V to paste."
        }
        return true
    }

    private static func isAttributeSettable(_ element: AXUIElement, _ attribute: CFString) -> Bool {
        var settable: DarwinBoolean = false
        let error = AXUIElementIsAttributeSettable(element, attribute, &settable)
        return error == .success && settable.boolValue
    }
}
