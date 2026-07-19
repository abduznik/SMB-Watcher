import Foundation
import Security

/// Stores and retrieves SMB credentials in the macOS Keychain.
final class KeychainService {
    private let service = "com.smbwatcher.credentials"

    /// Saves a username and password for the given instance id.
    func save(username: String, password: String, for instanceID: UUID) throws {
        let account = accountName(for: instanceID)
        let passwordData = password.data(using: .utf8)!

        // Delete any existing item first
        try? delete(for: instanceID)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: passwordData,
            kSecAttrLabel as String: username,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    /// Retrieves the stored username and password for the given instance id.
    func load(for instanceID: UUID) -> (username: String, password: String)? {
        let account = accountName(for: instanceID)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let result = item as? [String: Any] else {
            return nil
        }

        guard let passwordData = result[kSecValueData as String] as? Data,
              let password = String(data: passwordData, encoding: .utf8),
              let username = result[kSecAttrLabel as String] as? String
        else {
            return nil
        }

        return (username: username, password: password)
    }

    /// Deletes credentials for the given instance id.
    func delete(for instanceID: UUID) throws {
        let account = accountName(for: instanceID)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    /// Deletes all credentials managed by SMBWatcher.
    func deleteAll() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    private func accountName(for instanceID: UUID) -> String {
        "smbwatcher.\(instanceID.uuidString)"
    }
}

enum KeychainError: Error, LocalizedError {
    case saveFailed(OSStatus)
    case deleteFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status): return "Keychain save failed: \(status)"
        case .deleteFailed(let status): return "Keychain delete failed: \(status)"
        }
    }
}
