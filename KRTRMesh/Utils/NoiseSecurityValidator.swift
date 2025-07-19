/**
 * KRTR Noise Security Validator - Security validation and rate limiting
 * Provides security checks and DoS protection for Noise Protocol operations
 */

import Foundation
import os.log

// MARK: - Security Validator
class NoiseSecurityValidator {
    // Message size limits
    static let maxMessageSize = 1024 * 1024 // 1MB
    static let maxHandshakeMessageSize = 4096 // 4KB
    static let minPeerIDLength = 8
    static let maxPeerIDLength = 64
    static let maxChannelNameLength = 64
    
    // Validation methods
    static func validatePeerID(_ peerID: String) -> Bool {
        // Check length
        guard peerID.count >= minPeerIDLength && peerID.count <= maxPeerIDLength else {
            return false
        }
        
        // Check for valid hex characters
        let hexCharacterSet = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        return peerID.unicodeScalars.allSatisfy { hexCharacterSet.contains($0) }
    }
    
    static func validateMessageSize(_ data: Data) -> Bool {
        return data.count <= maxMessageSize
    }
    
    static func validateHandshakeMessageSize(_ data: Data) -> Bool {
        return data.count <= maxHandshakeMessageSize
    }
    
    static func validateChannelName(_ channel: String) -> Bool {
        // Check length
        guard channel.count <= maxChannelNameLength else {
            return false
        }
        
        // Check for valid characters (alphanumeric, underscore, hyphen)
        let validCharacterSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        return channel.unicodeScalars.allSatisfy { validCharacterSet.contains($0) }
    }
    
    static func validateTimestamp(_ timestamp: UInt64) -> Bool {
        let now = UInt64(Date().timeIntervalSince1970 * 1000)
        let maxSkew: UInt64 = 300000 // 5 minutes in milliseconds
        
        // Allow some clock skew but reject messages that are too old or too far in the future
        return timestamp >= (now - maxSkew) && timestamp <= (now + maxSkew)
    }
}

// MARK: - Rate Limiter
class NoiseRateLimiter {
    private struct RateLimit {
        let maxRequests: Int
        let timeWindow: TimeInterval
        var requests: [Date] = []
    }
    
    private var handshakeLimits: [String: RateLimit] = [:]
    private var messageLimits: [String: RateLimit] = [:]
    private let queue = DispatchQueue(label: "krtr.noise.ratelimiter", attributes: .concurrent)
    
    // Rate limit configurations
    private let handshakeRateLimit = RateLimit(maxRequests: 10, timeWindow: 60.0) // 10 handshakes per minute
    private let messageRateLimit = RateLimit(maxRequests: 1000, timeWindow: 60.0) // 1000 messages per minute
    
    func allowHandshake(from peerID: String) -> Bool {
        return queue.sync(flags: .barrier) {
            return checkRateLimit(for: peerID, limits: &handshakeLimits, defaultLimit: handshakeRateLimit)
        }
    }
    
    func allowMessage(from peerID: String) -> Bool {
        return queue.sync(flags: .barrier) {
            return checkRateLimit(for: peerID, limits: &messageLimits, defaultLimit: messageRateLimit)
        }
    }
    
    private func checkRateLimit(for peerID: String, limits: inout [String: RateLimit], defaultLimit: RateLimit) -> Bool {
        let now = Date()
        
        // Get or create rate limit for this peer
        var limit = limits[peerID] ?? defaultLimit
        
        // Remove old requests outside the time window
        limit.requests = limit.requests.filter { request in
            now.timeIntervalSince(request) < limit.timeWindow
        }
        
        // Check if we're under the limit
        if limit.requests.count < limit.maxRequests {
            limit.requests.append(now)
            limits[peerID] = limit
            return true
        } else {
            SecurityLogger.log("Rate limit exceeded for peer: \(peerID)", category: SecurityLogger.encryption, level: .error)
            return false
        }
    }
    
    // Clean up old entries periodically
    func cleanup() {
        queue.async(flags: .barrier) { [self] in
            let now = Date()
            
            // Clean handshake limits
            for (peerID, var limit) in self.handshakeLimits {
                limit.requests = limit.requests.filter { request in
                    now.timeIntervalSince(request) < limit.timeWindow
                }
                if limit.requests.isEmpty {
                    self.handshakeLimits.removeValue(forKey: peerID)
                } else {
                    self.handshakeLimits[peerID] = limit
                }
            }
            
            // Clean message limits
            for (peerID, var limit) in self.messageLimits {
                limit.requests = limit.requests.filter { request in
                    now.timeIntervalSince(request) < limit.timeWindow
                }
                if limit.requests.isEmpty {
                    self.messageLimits.removeValue(forKey: peerID)
                } else {
                    self.messageLimits[peerID] = limit
                }
            }
        }
    }
}

// MARK: - Channel Encryption
class NoiseChannelEncryption {
    private var channelKeys: [String: SymmetricKey] = [:]
    private let queue = DispatchQueue(label: "krtr.noise.channels", attributes: .concurrent)
    
    func setChannelPassword(_ password: String, for channel: String) {
        queue.async(flags: .barrier) {
            // Derive key from password using PBKDF2
            let salt = Data("KRTR-Channel-\(channel)".utf8)
            let key = self.deriveKey(from: password, salt: salt)
            self.channelKeys[channel] = key
            
            // Save to keychain
            _ = KeychainManager.shared.saveChannelPassword(password, forChannel: channel)
        }
    }
    
    func loadChannelPassword(for channel: String) -> Bool {
        guard let password = KeychainManager.shared.getChannelPassword(forChannel: channel) else {
            return false
        }
        
        setChannelPassword(password, for: channel)
        return true
    }
    
    func removeChannelPassword(for channel: String) {
        queue.async(flags: .barrier) {
            self.channelKeys.removeValue(forKey: channel)
            _ = KeychainManager.shared.deleteChannelPassword(forChannel: channel)
        }
    }
    
    func encryptChannelMessage(_ message: String, for channel: String) throws -> Data {
        guard let key = queue.sync(execute: { channelKeys[channel] }) else {
            throw NoiseEncryptionError.sessionNotEstablished
        }
        
        let messageData = Data(message.utf8)
        let nonce = AES.GCM.Nonce()
        let sealedBox = try AES.GCM.seal(messageData, using: key, nonce: nonce)
        
        // Return nonce + ciphertext + tag
        var result = Data()
        result.append(sealedBox.nonce.withUnsafeBytes { Data($0) })
        result.append(sealedBox.ciphertext)
        result.append(sealedBox.tag)
        
        return result
    }
    
    func decryptChannelMessage(_ encryptedData: Data, for channel: String) throws -> String {
        guard let key = queue.sync(execute: { channelKeys[channel] }) else {
            throw NoiseEncryptionError.sessionNotEstablished
        }
        
        guard encryptedData.count >= 28 else { // 12 bytes nonce + 16 bytes tag minimum
            throw NoiseEncryptionError.invalidMessage
        }
        
        // Extract components
        let nonce = encryptedData.prefix(12)
        let ciphertext = encryptedData.dropFirst(12).dropLast(16)
        let tag = encryptedData.suffix(16)
        
        // Create sealed box
        let sealedBox = try AES.GCM.SealedBox(
            nonce: AES.GCM.Nonce(data: nonce),
            ciphertext: ciphertext,
            tag: tag
        )
        
        // Decrypt
        let plaintext = try AES.GCM.open(sealedBox, using: key)
        
        guard let message = String(data: plaintext, encoding: .utf8) else {
            throw NoiseEncryptionError.invalidMessage
        }
        
        return message
    }
    
    func createChannelKeyPacket(password: String, channel: String) -> Data? {
        let packet = ChannelKeyPacket(channel: channel, password: password)
        return try? JSONEncoder().encode(packet)
    }
    
    func processChannelKeyPacket(_ data: Data) -> (channel: String, password: String)? {
        guard let packet = try? JSONDecoder().decode(ChannelKeyPacket.self, from: data) else {
            return nil
        }
        return (packet.channel, packet.password)
    }
    
    private func deriveKey(from password: String, salt: Data) -> SymmetricKey {
        let passwordData = Data(password.utf8)
        let derivedKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: passwordData),
            salt: salt,
            info: Data("channel-key".utf8),
            outputByteCount: 32
        )
        return derivedKey
    }
}

// MARK: - Supporting Structures
private struct ChannelKeyPacket: Codable {
    let channel: String
    let password: String
}

// MARK: - Errors
enum NoiseSecurityError: Error {
    case invalidPeerID
    case messageTooLarge
    case rateLimitExceeded
    case invalidChannel
    case invalidTimestamp
}

enum NoiseEncryptionError: Error {
    case handshakeRequired
    case sessionNotEstablished
    case invalidMessage
    case handshakeFailed(Error)
}

// MARK: - CryptoKit Extensions
import CryptoKit

extension AES.GCM.Nonce {
    init(data: Data) throws {
        self = try AES.GCM.Nonce(data: data)
    }
}
