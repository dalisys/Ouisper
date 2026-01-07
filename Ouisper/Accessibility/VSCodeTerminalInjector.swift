import AppKit

enum VSCodeTerminalInjector {
    static func isVSCodeFamily(_ app: NSRunningApplication?) -> Bool {
        guard let app else { return false }
        if let bundleId = app.bundleIdentifier, vsCodeBundleIds.contains(bundleId) {
            return true
        }
        let name = (app.localizedName ?? "").lowercased()
        return name.contains("visual studio code") || name == "code" || name.contains("cursor") || name.contains("antigravity")
    }

    static func pasteViaCommandPalette(app: NSRunningApplication) -> Bool {
        guard let processName = processName(for: app) else { return false }

        let script = """
        tell application "\(processName)" to activate
        delay 0.1
        tell application "System Events"
            tell process "\(processName)"
                try
                    click menu item "Terminal" of menu "View" of menu bar 1
                on error
                    key code 50 using {control down}
                end try
                delay 0.15
                try
                    click menu item "Paste" of menu "Edit" of menu bar 1
                on error
                    try
                        click menu item "Paste" of menu "Terminal" of menu bar 1
                    on error
                        keystroke "p" using {command down, shift down}
                        delay 0.2
                        keystroke "Terminal: Paste"
                        delay 0.1
                        key code 36
                    end try
                end try
            end tell
        end tell
        """

        var errorInfo: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            _ = appleScript.executeAndReturnError(&errorInfo)
            if errorInfo != nil {
                DictationState.shared.lastInjectionError = "VS Code terminal paste failed. Text copied to clipboard."
                return false
            }
            return true
        }
        return false
    }

    private static func processName(for app: NSRunningApplication) -> String? {
        if let bundleId = app.bundleIdentifier, let mapped = processNames[bundleId] {
            return mapped
        }
        return app.localizedName
    }

    private static let vsCodeBundleIds: Set<String> = [
        "com.microsoft.VSCode",
        "com.microsoft.VSCodeInsiders",
        "com.microsoft.VSCodeExploration",
        "com.todesktop.230313mzl4w4u92"
    ]

    private static let processNames: [String: String] = [
        "com.microsoft.VSCode": "Code",
        "com.microsoft.VSCodeInsiders": "Code - Insiders",
        "com.microsoft.VSCodeExploration": "Code - Exploration",
        "com.todesktop.230313mzl4w4u92": "Cursor"
    ]
}
