import AppKit

enum TerminalInjector {
    static func typeText(_ text: String) -> Bool {
        guard !text.isEmpty else { return true }
        let source = CGEventSource(stateID: .combinedSessionState)
        let scalars = Array(text.utf16)
        let chunkSize = 80

        var index = 0
        while index < scalars.count {
            let end = min(index + chunkSize, scalars.count)
            let slice = Array(scalars[index..<end])

            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
            keyDown?.keyboardSetUnicodeString(stringLength: slice.count, unicodeString: slice)
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
            keyUp?.keyboardSetUnicodeString(stringLength: slice.count, unicodeString: slice)

            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)

            usleep(1000)
            index = end
        }

        return true
    }
}
