import Foundation

enum LanguagePreference {
    static func parse(_ raw: String) -> [String] {
        let cleaned = raw
            .lowercased()
            .replacingOccurrences(of: ";", with: ",")
            .replacingOccurrences(of: "|", with: ",")
        let parts = cleaned
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != "auto" }
        return parts
    }

    static func apiLanguage(_ raw: String) -> String {
        let parts = parse(raw)
        return parts.count == 1 ? parts[0] : ""
    }

    static func promptHint(_ raw: String) -> String? {
        let parts = parse(raw)
        if parts.count == 1 {
            return "The language is \(parts[0])."
        }
        if parts.count > 1 {
            return "The language could be one of: \(parts.joined(separator: ", "))."
        }
        return nil
    }
}
