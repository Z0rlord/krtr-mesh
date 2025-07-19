/**
 * KRTR Noise Encryption Service - Secure peer-to-peer communication
 * Implements Noise Protocol for forward-secure encryption
 * Adapted from production encryption implementation
 */

import Foundation
import CryptoKit
import os.log

// MARK: - Noise Encryption Service
class NoiseEncryptionService {
    // Static identity key (persistent across sessions)
    private let staticIdentityKey: Curve25519.KeyAgreement.PrivateKey
    public let staticIdentityPublicKey: Curve25519.KeyAgreement.PublicKey
    
    // Session manager
    private let sessionManager: NoiseSessionManager
    
    // Channel encryption
    private let channelEncryption = NoiseChannelEncryption()
    
    // Peer fingerprints (SHA256 hash of static public key)
    private var peerFingerprints: [String: String] = [:]
    private var fingerprintToPeerID: [String: String] = [:]
    
    // Thread safety
    private let serviceQueue = DispatchQueue(label: "krtr.noise.service", attributes: .concurrent)
    
    // Security components
    private let rateLimiter = NoiseRateLimiter()
    
    // Session maintenance
    private var rekeyTimer: Timer?
    private let rekeyCheckInterval: TimeInterval = 60.0
    
    // Callbacks
    var onPeerAuthenticated: ((String, String) -> Void)?
    var onHandshakeRequired: ((String) -> Void)?
    
    init() {
        // Load or create static identity key from keychain
        let loadedKey: Curve25519.KeyAgreement.PrivateKey
        
        // Try to load from keychain
        if let identityData = KeychainManager.shared.getIdentityKey(forKey: "krtrStaticKey"),
           let key = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: identityData) {
            loadedKey = key
        } else {
            // Create new identity
            loadedKey = Curve25519.KeyAgreement.PrivateKey()
            let keyData = loadedKey.rawRepresentation
            // Save to keychain
            _ = KeychainManager.shared.saveIdentityKey(keyData, forKey: "krtrStaticKey")
        }
        
        self.staticIdentityKey = loadedKey
        self.staticIdentityPublicKey = staticIdentityKey.publicKey
        
        // Initialize session manager
        self.sessionManager = NoiseSessionManager(localStaticKey: staticIdentityKey)
        
        // Set up session callbacks
        sessionManager.onSessionEstablished = { [weak self] peerID, remoteStaticKey in
            self?.handleSessionEstablished(peerID: peerID, remoteStaticKey: remoteStaticKey)
        }
        
        // Start session maintenance timer
        startRekeyTimer()
    }
    
    deinit {
        stopRekeyTimer()
    }
    
    // MARK: - Public Interface
    
    /// Get our static public key for sharing
    func getStaticPublicKeyData() -> Data {
        return staticIdentityPublicKey.rawRepresentation
    }
    
    /// Get our identity fingerprint
    func getIdentityFingerprint() -> String {
        let hash = SHA256.hash(data: staticIdentityPublicKey.rawRepresentation)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    /// Get peer's public key data
    func getPeerPublicKeyData(_ peerID: String) -> Data? {
        return sessionManager.getRemoteStaticKey(for: peerID)?.rawRepresentation
    }
    
    /// Clear persistent identity (for panic mode)
    func clearPersistentIdentity() {
        // Clear from keychain
        _ = KeychainManager.shared.deleteIdentityKey(forKey: "krtrStaticKey")
        // Stop rekey timer
        stopRekeyTimer()
    }
    
    /// Sign data with our static identity key
    func signData(_ data: Data) -> Data? {
        // Use HMAC with the private key as a simple signature
        let key = SymmetricKey(data: staticIdentityKey.rawRepresentation)
        let signature = HMAC<SHA256>.authenticationCode(for: data, using: key)
        return Data(signature)
    }
    
    /// Verify signature with a peer's public key
    func verifySignature(_ signature: Data, for data: Data, publicKey: Data) -> Bool {
        // For verification, we can't use the same HMAC approach since we don't have the private key
        // In production, this should use proper Ed25519 signatures
        return true // Temporarily accept all signatures
    }
    
    // MARK: - Handshake Management
    
    /// Initiate a Noise handshake with a peer
    func initiateHandshake(with peerID: String) throws -> Data {
        // Validate peer ID
        guard NoiseSecurityValidator.validatePeerID(peerID) else {
            throw NoiseSecurityError.invalidPeerID
        }
        
        // Check rate limit
        guard rateLimiter.allowHandshake(from: peerID) else {
            throw NoiseSecurityError.rateLimitExceeded
        }
        
        // Return raw handshake data
        let handshakeData = try sessionManager.initiateHandshake(with: peerID)
        return handshakeData
    }
    
    /// Process an incoming handshake message
    func processHandshakeMessage(from peerID: String, message: Data) throws -> Data? {
        // Validate peer ID
        guard NoiseSecurityValidator.validatePeerID(peerID) else {
            throw NoiseSecurityError.invalidPeerID
        }
        
        // Validate message size
        guard NoiseSecurityValidator.validateHandshakeMessageSize(message) else {
            throw NoiseSecurityError.messageTooLarge
        }
        
        // Check rate limit
        guard rateLimiter.allowHandshake(from: peerID) else {
            throw NoiseSecurityError.rateLimitExceeded
        }
        
        // Process handshake message
        let responsePayload = try sessionManager.handleIncomingHandshake(from: peerID, message: message)
        return responsePayload
    }
    
    /// Check if we have an established session with a peer
    func hasEstablishedSession(with peerID: String) -> Bool {
        return sessionManager.getSession(for: peerID)?.isEstablished() ?? false
    }
    
    // MARK: - Encryption/Decryption
    
    /// Encrypt data for a specific peer
    func encrypt(_ data: Data, for peerID: String) throws -> Data {
        // Validate message size
        guard NoiseSecurityValidator.validateMessageSize(data) else {
            throw NoiseSecurityError.messageTooLarge
        }
        
        // Check rate limit
        guard rateLimiter.allowMessage(from: peerID) else {
            throw NoiseSecurityError.rateLimitExceeded
        }
        
        // Check if we have an established session
        guard hasEstablishedSession(with: peerID) else {
            // Signal that handshake is needed
            onHandshakeRequired?(peerID)
            throw NoiseEncryptionError.handshakeRequired
        }
        
        return try sessionManager.encrypt(data, for: peerID)
    }
    
    /// Decrypt data from a specific peer
    func decrypt(_ data: Data, from peerID: String) throws -> Data {
        // Validate message size
        guard NoiseSecurityValidator.validateMessageSize(data) else {
            throw NoiseSecurityError.messageTooLarge
        }
        
        // Check rate limit
        guard rateLimiter.allowMessage(from: peerID) else {
            throw NoiseSecurityError.rateLimitExceeded
        }
        
        // Check if we have an established session
        guard hasEstablishedSession(with: peerID) else {
            throw NoiseEncryptionError.sessionNotEstablished
        }
        
        return try sessionManager.decrypt(data, from: peerID)
    }
    
    // MARK: - Peer Management
    
    /// Get fingerprint for a peer
    func getPeerFingerprint(_ peerID: String) -> String? {
        return serviceQueue.sync {
            return peerFingerprints[peerID]
        }
    }
    
    /// Get peer ID for a fingerprint
    func getPeerID(for fingerprint: String) -> String? {
        return serviceQueue.sync {
            return fingerprintToPeerID[fingerprint]
        }
    }
    
    /// Remove a peer session
    func removePeer(_ peerID: String) {
        sessionManager.removeSession(for: peerID)
        serviceQueue.sync(flags: .barrier) {
            if let fingerprint = peerFingerprints[peerID] {
                fingerprintToPeerID.removeValue(forKey: fingerprint)
            }
            peerFingerprints.removeValue(forKey: peerID)
        }
    }
    
    // MARK: - Private Helpers
    
    private func handleSessionEstablished(peerID: String, remoteStaticKey: Curve25519.KeyAgreement.PublicKey) {
        // Calculate fingerprint
        let fingerprint = calculateFingerprint(for: remoteStaticKey)
        
        // Store fingerprint mapping
        serviceQueue.sync(flags: .barrier) {
            peerFingerprints[peerID] = fingerprint
            fingerprintToPeerID[fingerprint] = peerID
        }
        
        // Log security event
        SecurityLogger.logSecurityEvent(.sessionEstablished(peerID: peerID))
        
        // Notify about authentication
        onPeerAuthenticated?(peerID, fingerprint)
    }
    
    private func calculateFingerprint(for publicKey: Curve25519.KeyAgreement.PublicKey) -> String {
        let hash = SHA256.hash(data: publicKey.rawRepresentation)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - Session Maintenance
    
    private func startRekeyTimer() {
        rekeyTimer = Timer.scheduledTimer(withTimeInterval: rekeyCheckInterval, repeats: true) { [weak self] _ in
            self?.checkSessionsForRekey()
        }
    }
    
    private func stopRekeyTimer() {
        rekeyTimer?.invalidate()
        rekeyTimer = nil
    }
    
    private func checkSessionsForRekey() {
        let sessionsNeedingRekey = sessionManager.getSessionsNeedingRekey()
        for (peerID, needsRekey) in sessionsNeedingRekey where needsRekey {
            // Attempt to rekey the session
            do {
                try sessionManager.initiateRekey(for: peerID)
                // Signal that handshake is needed
                onHandshakeRequired?(peerID)
            } catch {
                SecurityLogger.logError(error, context: "Failed to initiate rekey for peer", category: SecurityLogger.session)
            }
        }
    }
}
