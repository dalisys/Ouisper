import Foundation
import Security

class KeychainManager {
    static let shared = KeychainManager()
    
    private init() {}

    private var service: String {
        Bundle.main.bundleIdentifier ?? "Ouisper"
    }

    private var shouldUseKeychain: Bool {
#if DEBUG
        return false
#else
        return true
#endif
    }

    private func debugDefaultsKey(_ key: String) -> String {
        "debug.key.\(key)"
    }
    
    func save(key: String, value: String) -> Bool {
        if !shouldUseKeychain {
            UserDefaults.standard.set(value, forKey: debugDefaultsKey(key))
            return true
        }
        let data = value.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    func load(key: String) -> String? {
        if !shouldUseKeychain {
            return UserDefaults.standard.string(forKey: debugDefaultsKey(key))
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }
        
        return nil
    }
    
    func delete(key: String) -> Bool {
        if !shouldUseKeychain {
            UserDefaults.standard.removeObject(forKey: debugDefaultsKey(key))
            return true
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess
    }
}
