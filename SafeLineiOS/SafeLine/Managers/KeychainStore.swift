import Foundation
import Security

/// Minimal Keychain wrapper for small values that must never leave this device:
/// the check-in contact/message, and the journal's AES key.
/// `.whenUnlockedThisDeviceOnly` keeps values off iCloud Keychain sync.
enum KeychainStore {
    @discardableResult
    static func set(_ data: Data, for key: String,
                     accessible: CFString = kSecAttrAccessibleWhenUnlockedThisDeviceOnly) -> Bool {
        delete(key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessible
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func get(_ key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    static func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }

    @discardableResult
    static func setString(_ value: String, for key: String) -> Bool {
        set(Data(value.utf8), for: key)
    }

    static func getString(_ key: String) -> String? {
        guard let data = get(key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
