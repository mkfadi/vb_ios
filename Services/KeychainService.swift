// KeychainService.swift – Sicheres Speichern von GitHub-Credentials im Keychain

import Foundation
import Security

struct KeychainService {

    // Bundle-Prefix für eindeutige Keychain-Schlüssel
    private static let tokenKey = "de.lucksmith.vb-ios.github-token"
    private static let repoKey  = "de.lucksmith.vb-ios.github-repo"

    // Speichert einen String-Wert verschlüsselt im Keychain
    @discardableResult
    static func save(_ value: String, forKey key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        delete(forKey: key) // Alten Eintrag zuerst entfernen (Update-Pattern)

        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrAccount:      key,
            kSecValueData:        data,
            // Nur verfügbar wenn Gerät entsperrt ist, kein iCloud-Sync
            kSecAttrAccessible:   kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    // Lädt einen String-Wert aus dem Keychain
    static func load(forKey key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // Löscht einen Eintrag aus dem Keychain
    @discardableResult
    static func delete(forKey key: String) -> Bool {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: key
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }

    // Öffentliche Convenience-Methoden für GitHub-Daten

    @discardableResult
    static func saveToken(_ token: String) -> Bool { save(token, forKey: tokenKey) }

    static func loadToken() -> String? { load(forKey: tokenKey) }

    @discardableResult
    static func saveRepo(_ repo: String) -> Bool { save(repo, forKey: repoKey) }

    static func loadRepo() -> String? { load(forKey: repoKey) }

    // Löscht alle gespeicherten Credentials (für Abmelden)
    static func clearAll() {
        delete(forKey: tokenKey)
        delete(forKey: repoKey)
    }
}
