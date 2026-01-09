import AppKit

enum BrowserPasteInjector {
    static func isBrowser(_ app: NSRunningApplication?) -> Bool {
        guard let app else { return false }
        if let bundleId = app.bundleIdentifier, browserBundleIds.contains(bundleId) {
            return true
        }
        let name = (app.localizedName ?? "").lowercased()
        return name.contains("chrome") || name.contains("safari") || name.contains("firefox") || name.contains("brave")
    }

    static func paste(app: NSRunningApplication) -> Bool {
        guard let processName = processName(for: app) else { return false }

        let script = """
        tell application "\(processName)" to activate
        delay 0.1
        tell application "System Events"
            tell process "\(processName)"
                try
                    click menu item "Paste" of menu "Edit" of menu bar 1
                on error
                    keystroke "v" using {command down}
                end try
            end tell
        end tell
        """

        var errorInfo: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            _ = appleScript.executeAndReturnError(&errorInfo)
            if errorInfo != nil {
                DictationState.shared.lastInjectionError = "Browser paste failed. Text copied to clipboard."
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

    private static let browserBundleIds: Set<String> = [
        "com.apple.Safari",
        "com.apple.SafariTechnologyPreview",
        "com.google.Chrome",
        "com.google.Chrome.canary",
        "org.mozilla.firefox",
        "org.mozilla.firefoxdeveloperedition",
        "com.brave.Browser",
        "com.microsoft.edgemac",
        "com.opera.Opera",
        "com.operasoftware.Opera",
        "com.vivaldi.Vivaldi",
        "company.thebrowser.Browser"
    ]

    private static let processNames: [String: String] = [
        "com.apple.Safari": "Safari",
        "com.apple.SafariTechnologyPreview": "Safari Technology Preview",
        "com.google.Chrome": "Google Chrome",
        "com.google.Chrome.canary": "Google Chrome Canary",
        "org.mozilla.firefox": "Firefox",
        "org.mozilla.firefoxdeveloperedition": "Firefox Developer Edition",
        "com.brave.Browser": "Brave Browser",
        "com.microsoft.edgemac": "Microsoft Edge",
        "com.opera.Opera": "Opera",
        "com.operasoftware.Opera": "Opera",
        "com.vivaldi.Vivaldi": "Vivaldi",
        "company.thebrowser.Browser": "Arc"
    ]
}
