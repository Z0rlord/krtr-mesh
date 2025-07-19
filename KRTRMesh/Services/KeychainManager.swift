/**
 * KRTR Keychain Manager - Secure storage for cryptographic keys
 * Handles persistent storage of identity keys and session data
 */

import Foundation
import Security
import os.log

class KeychainManager {
    static let shared = KeychainManager()
    
    private let service = "com.krtr.mesh"
    private let accessGroup: String? = nil // Use default access group
    
    private init() {}
    
    // MARK: - Identity Key Management
    
    func saveIdentityKey(_ keyData: Data, forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            SecurityLogger.log("Identity key saved successfully for: \(key)", category: SecurityLogger.encryption, level: .info)
            return true
        } else {
            SecurityLogger.log("Failed to save identity key for: \(key), status: \(status)", category: SecurityLogger.encryption, level: .error)
            return false
        }
    }
    
    func getIdentityKey(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess {
            SecurityLogger.log("Identity key retrieved successfully for: \(key)", category: SecurityLogger.encryption, level: .debug)
            return result as? Data
        } else if status == errSecItemNotFound {
            SecurityLogger.log("Identity key not found for: \(key)", category: SecurityLogger.encryption, level: .debug)
            return nil
        } else {
            SecurityLogger.log("Failed to retrieve identity key for: \(key), status: \(status)", category: SecurityLogger.encryption, level: .error)
            return nil
        }
    }
    
    func deleteIdentityKey(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status == errSecSuccess || status == errSecItemNotFound {
            SecurityLogger.log("Identity key deleted successfully for: \(key)", category: SecurityLogger.encryption, level: .info)
            return true
        } else {
            SecurityLogger.log("Failed to delete identity key for: \(key), status: \(status)", category: SecurityLogger.encryption, level: .error)
            return false
        }
    }
    
    // MARK: - Channel Password Management
    
    func saveChannelPassword(_ password: String, forChannel channel: String) -> Bool {
        let key = "channel_\(channel)"
        let passwordData = Data(password.utf8)
        return saveIdentityKey(passwordData, forKey: key)
    }
    
    func getChannelPassword(forChannel channel: String) -> String? {
        let key = "channel_\(channel)"
        guard let passwordData = getIdentityKey(forKey: key) else {
            return nil
        }
        return String(data: passwordData, encoding: .utf8)
    }
    
    func deleteChannelPassword(forChannel channel: String) -> Bool {
        let key = "channel_\(channel)"
        return deleteIdentityKey(forKey: key)
    }
    
    // MARK: - Session Data Management
    
    func saveSessionData(_ data: Data, forPeer peerID: String) -> Bool {
        let key = "session_\(peerID)"
        return saveIdentityKey(data, forKey: key)
    }
    
    func getSessionData(forPeer peerID: String) -> Data? {
        let key = "session_\(peerID)"
        return getIdentityKey(forKey: key)
    }
    
    func deleteSessionData(forPeer peerID: String) -> Bool {
        let key = "session_\(peerID)"
        return deleteIdentityKey(forKey: key)
    }
    
    // MARK: - Bulk Operations
    
    func deleteAllKeys() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status == errSecSuccess || status == errSecItemNotFound {
            SecurityLogger.log("All keys deleted successfully", category: SecurityLogger.encryption, level: .info)
            return true
        } else {
            SecurityLogger.log("Failed to delete all keys, status: \(status)", category: SecurityLogger.encryption, level: .error)
            return false
        }
    }
    
    func getAllStoredKeys() -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let items = result as? [[String: Any]] else {
            return []
        }
        
        return items.compactMap { item in
            return item[kSecAttrAccount as String] as? String
        }
    }
    
    // MARK: - Emergency Wipe
    
    func emergencyWipe() -> Bool {
        SecurityLogger.log("Emergency wipe initiated", category: SecurityLogger.encryption, level: .error)
        
        let success = deleteAllKeys()
        
        if success {
            SecurityLogger.log("Emergency wipe completed successfully", category: SecurityLogger.encryption, level: .error)
        } else {
            SecurityLogger.log("Emergency wipe failed", category: SecurityLogger.encryption, level: .error)
        }
        
        return success
    }
}

// MARK: - Keychain Error Handling
extension KeychainManager {
    private func keychainErrorDescription(for status: OSStatus) -> String {
        switch status {
        case errSecSuccess:
            return "Success"
        case errSecItemNotFound:
            return "Item not found"
        case errSecDuplicateItem:
            return "Duplicate item"
        case errSecAuthFailed:
            return "Authentication failed"
        case errSecNotAvailable:
            return "Keychain not available"
        case errSecParam:
            return "Invalid parameter"
        case errSecAllocate:
            return "Memory allocation failed"
        case errSecUnimplemented:
            return "Function not implemented"
        case errSecDiskFull:
            return "Disk full"
        case errSecIO:
            return "I/O error"
        case errSecOpWr:
            return "File already open for writing"
        case errSecInteractionNotAllowed:
            return "Interaction not allowed"
        case errSecDecode:
            return "Decode error"
        default:
            return "Unknown error (\(status))"
        }
    }
}
