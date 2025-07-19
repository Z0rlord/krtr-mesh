/**
 * KRTR Noise Session Manager - Manages Noise Protocol sessions
 * Handles session establishment, maintenance, and encryption/decryption
 */

import Foundation
import CryptoKit
import os.log

// MARK: - Noise Session Manager
class NoiseSessionManager {
    private let localStaticKey: Curve25519.KeyAgreement.PrivateKey
    private var sessions: [String: NoiseSession] = [:]
    private let sessionQueue = DispatchQueue(label: "krtr.noise.sessions", attributes: .concurrent)
    
    // Callbacks
    var onSessionEstablished: ((String, Curve25519.KeyAgreement.PublicKey) -> Void)?
    
    init(localStaticKey: Curve25519.KeyAgreement.PrivateKey) {
        self.localStaticKey = localStaticKey
    }
    
    // MARK: - Session Management
    
    func getSession(for peerID: String) -> NoiseSession? {
        return sessionQueue.sync {
            return sessions[peerID]
        }
    }
    
    func removeSession(for peerID: String) {
        sessionQueue.sync(flags: .barrier) {
            sessions.removeValue(forKey: peerID)
        }
    }
    
    func getRemoteStaticKey(for peerID: String) -> Curve25519.KeyAgreement.PublicKey? {
        return sessionQueue.sync {
            return sessions[peerID]?.remoteStaticKey
        }
    }
    
    // MARK: - Handshake Management
    
    func initiateHandshake(with peerID: String) throws -> Data {
        let session = sessionQueue.sync(flags: .barrier) { () -> NoiseSession in
            if let existingSession = sessions[peerID] {
                return existingSession
            } else {
                let newSession = NoiseSession(localStaticKey: localStaticKey, isInitiator: true)
                sessions[peerID] = newSession
                return newSession
            }
        }
        
        return try session.initiateHandshake()
    }
    
    func handleIncomingHandshake(from peerID: String, message: Data) throws -> Data? {
        let session = sessionQueue.sync(flags: .barrier) { () -> NoiseSession in
            if let existingSession = sessions[peerID] {
                return existingSession
            } else {
                let newSession = NoiseSession(localStaticKey: localStaticKey, isInitiator: false)
                sessions[peerID] = newSession
                return newSession
            }
        }
        
        let response = try session.processHandshakeMessage(message)
        
        // Check if handshake is complete
        if session.isEstablished(), let remoteKey = session.remoteStaticKey {
            onSessionEstablished?(peerID, remoteKey)
        }
        
        return response
    }
    
    // MARK: - Encryption/Decryption
    
    func encrypt(_ data: Data, for peerID: String) throws -> Data {
        guard let session = getSession(for: peerID), session.isEstablished() else {
            throw NoiseEncryptionError.sessionNotEstablished
        }
        
        return try session.encrypt(data)
    }
    
    func decrypt(_ data: Data, from peerID: String) throws -> Data {
        guard let session = getSession(for: peerID), session.isEstablished() else {
            throw NoiseEncryptionError.sessionNotEstablished
        }
        
        return try session.decrypt(data)
    }
    
    // MARK: - Session Maintenance
    
    func getSessionsNeedingRekey() -> [String: Bool] {
        return sessionQueue.sync {
            var result: [String: Bool] = [:]
            for (peerID, session) in sessions {
                result[peerID] = session.needsRekey()
            }
            return result
        }
    }
    
    func initiateRekey(for peerID: String) throws {
        guard let session = getSession(for: peerID) else {
            throw NoiseEncryptionError.sessionNotEstablished
        }
        
        try session.initiateRekey()
    }
}

// MARK: - Noise Session
class NoiseSession {
    private let localStaticKey: Curve25519.KeyAgreement.PrivateKey
    private let isInitiator: Bool
    
    // Session state
    private var handshakeState: HandshakeState = .initial
    private var sendingKey: SymmetricKey?
    private var receivingKey: SymmetricKey?
    private var sendingNonce: UInt64 = 0
    private var receivingNonce: UInt64 = 0
    
    // Remote peer information
    private(set) var remoteStaticKey: Curve25519.KeyAgreement.PublicKey?
    
    // Ephemeral keys for handshake
    private var localEphemeralKey: Curve25519.KeyAgreement.PrivateKey?
    private var remoteEphemeralKey: Curve25519.KeyAgreement.PublicKey?
    
    // Session creation time for rekey scheduling
    private let creationTime = Date()
    private let rekeyInterval: TimeInterval = 3600 // 1 hour
    
    enum HandshakeState {
        case initial
        case waitingForResponse
        case established
        case failed
    }
    
    init(localStaticKey: Curve25519.KeyAgreement.PrivateKey, isInitiator: Bool) {
        self.localStaticKey = localStaticKey
        self.isInitiator = isInitiator
    }
    
    // MARK: - Handshake
    
    func initiateHandshake() throws -> Data {
        guard handshakeState == .initial else {
            throw NoiseEncryptionError.handshakeFailed(NSError(domain: "NoiseSession", code: 1, userInfo: [NSLocalizedDescriptionKey: "Handshake already in progress"]))
        }
        
        // Generate ephemeral key
        localEphemeralKey = Curve25519.KeyAgreement.PrivateKey()
        
        // Create handshake message
        var message = Data()
        message.append(localEphemeralKey!.publicKey.rawRepresentation)
        message.append(localStaticKey.publicKey.rawRepresentation)
        
        handshakeState = .waitingForResponse
        
        return message
    }
    
    func processHandshakeMessage(_ message: Data) throws -> Data? {
        switch handshakeState {
        case .initial:
            // We're the responder, process initiation message
            return try processHandshakeInitiation(message)
            
        case .waitingForResponse:
            // We're the initiator, process response
            try processHandshakeResponse(message)
            return nil
            
        case .established:
            throw NoiseEncryptionError.handshakeFailed(NSError(domain: "NoiseSession", code: 2, userInfo: [NSLocalizedDescriptionKey: "Handshake already complete"]))
            
        case .failed:
            throw NoiseEncryptionError.handshakeFailed(NSError(domain: "NoiseSession", code: 3, userInfo: [NSLocalizedDescriptionKey: "Handshake failed"]))
        }
    }
    
    private func processHandshakeInitiation(_ message: Data) throws -> Data {
        guard message.count >= 64 else { // 32 bytes ephemeral + 32 bytes static
            throw NoiseEncryptionError.handshakeFailed(NSError(domain: "NoiseSession", code: 4, userInfo: [NSLocalizedDescriptionKey: "Invalid handshake message size"]))
        }
        
        // Extract remote keys
        let remoteEphemeralData = message.prefix(32)
        let remoteStaticData = message.dropFirst(32).prefix(32)
        
        guard let remoteEphemeral = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: remoteEphemeralData),
              let remoteStatic = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: remoteStaticData) else {
            throw NoiseEncryptionError.handshakeFailed(NSError(domain: "NoiseSession", code: 5, userInfo: [NSLocalizedDescriptionKey: "Invalid remote keys"]))
        }
        
        self.remoteEphemeralKey = remoteEphemeral
        self.remoteStaticKey = remoteStatic
        
        // Generate our ephemeral key
        localEphemeralKey = Curve25519.KeyAgreement.PrivateKey()
        
        // Derive session keys
        try deriveSessionKeys()
        
        // Create response message
        var response = Data()
        response.append(localEphemeralKey!.publicKey.rawRepresentation)
        response.append(localStaticKey.publicKey.rawRepresentation)
        
        handshakeState = .established
        
        return response
    }
    
    private func processHandshakeResponse(_ message: Data) throws {
        guard message.count >= 64 else {
            throw NoiseEncryptionError.handshakeFailed(NSError(domain: "NoiseSession", code: 6, userInfo: [NSLocalizedDescriptionKey: "Invalid response message size"]))
        }
        
        // Extract remote keys
        let remoteEphemeralData = message.prefix(32)
        let remoteStaticData = message.dropFirst(32).prefix(32)
        
        guard let remoteEphemeral = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: remoteEphemeralData),
              let remoteStatic = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: remoteStaticData) else {
            throw NoiseEncryptionError.handshakeFailed(NSError(domain: "NoiseSession", code: 7, userInfo: [NSLocalizedDescriptionKey: "Invalid remote keys in response"]))
        }
        
        self.remoteEphemeralKey = remoteEphemeral
        self.remoteStaticKey = remoteStatic
        
        // Derive session keys
        try deriveSessionKeys()
        
        handshakeState = .established
    }
    
    private func deriveSessionKeys() throws {
        guard let localEphemeral = localEphemeralKey,
              let remoteEphemeral = remoteEphemeralKey,
              let remoteStatic = remoteStaticKey else {
            throw NoiseEncryptionError.handshakeFailed(NSError(domain: "NoiseSession", code: 8, userInfo: [NSLocalizedDescriptionKey: "Missing keys for derivation"]))
        }
        
        // Perform key exchanges
        let ee = try localEphemeral.sharedSecretFromKeyAgreement(with: remoteEphemeral)
        let es = try localStaticKey.sharedSecretFromKeyAgreement(with: remoteEphemeral)
        let se = try localEphemeral.sharedSecretFromKeyAgreement(with: remoteStatic)
        let ss = try localStaticKey.sharedSecretFromKeyAgreement(with: remoteStatic)
        
        // Combine shared secrets
        var combinedSecret = Data()
        combinedSecret.append(ee.withUnsafeBytes { Data($0) })
        combinedSecret.append(es.withUnsafeBytes { Data($0) })
        combinedSecret.append(se.withUnsafeBytes { Data($0) })
        combinedSecret.append(ss.withUnsafeBytes { Data($0) })
        
        // Derive session keys using HKDF
        let salt = Data("KRTR-Noise-Session".utf8)
        let info = Data("session-keys".utf8)
        
        let derivedKeys = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: combinedSecret),
            salt: salt,
            info: info,
            outputByteCount: 64
        )
        
        let keyData = derivedKeys.withUnsafeBytes { Data($0) }
        
        // Split into sending and receiving keys
        if isInitiator {
            sendingKey = SymmetricKey(data: keyData.prefix(32))
            receivingKey = SymmetricKey(data: keyData.suffix(32))
        } else {
            sendingKey = SymmetricKey(data: keyData.suffix(32))
            receivingKey = SymmetricKey(data: keyData.prefix(32))
        }
    }
    
    // MARK: - Encryption/Decryption
    
    func encrypt(_ data: Data) throws -> Data {
        guard let key = sendingKey else {
            throw NoiseEncryptionError.sessionNotEstablished
        }
        
        // Create nonce
        var nonce = Data(count: 12)
        withUnsafeBytes(of: sendingNonce.bigEndian) { bytes in
            nonce.replaceSubrange(4..<12, with: bytes)
        }
        
        // Encrypt
        let sealedBox = try AES.GCM.seal(data, using: key, nonce: AES.GCM.Nonce(data: nonce))
        
        // Increment nonce
        sendingNonce += 1
        
        // Return nonce + ciphertext + tag
        var result = Data()
        result.append(nonce)
        result.append(sealedBox.ciphertext)
        result.append(sealedBox.tag)
        
        return result
    }
    
    func decrypt(_ data: Data) throws -> Data {
        guard let key = receivingKey else {
            throw NoiseEncryptionError.sessionNotEstablished
        }
        
        guard data.count >= 28 else { // 12 bytes nonce + 16 bytes tag minimum
            throw NoiseEncryptionError.invalidMessage
        }
        
        // Extract components
        let nonce = data.prefix(12)
        let ciphertext = data.dropFirst(12).dropLast(16)
        let tag = data.suffix(16)
        
        // Create sealed box
        let sealedBox = try AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: nonce), ciphertext: ciphertext, tag: tag)
        
        // Decrypt
        let plaintext = try AES.GCM.open(sealedBox, using: key)
        
        // Increment nonce
        receivingNonce += 1
        
        return plaintext
    }
    
    // MARK: - Session State
    
    func isEstablished() -> Bool {
        return handshakeState == .established
    }
    
    func needsRekey() -> Bool {
        return Date().timeIntervalSince(creationTime) > rekeyInterval
    }
    
    func initiateRekey() throws {
        // Reset session for rekey
        handshakeState = .initial
        sendingKey = nil
        receivingKey = nil
        sendingNonce = 0
        receivingNonce = 0
        localEphemeralKey = nil
        remoteEphemeralKey = nil
    }
}
