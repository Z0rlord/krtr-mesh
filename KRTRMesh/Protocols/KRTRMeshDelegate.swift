/**
 * KRTR Mesh Delegate - Protocol for communication between mesh service and UI
 */

import Foundation

protocol KRTRMeshDelegate: AnyObject {
    // Peer management
    func didDiscoverPeer(_ peerID: String, nickname: String?, rssi: NSNumber?)
    func didConnectToPeer(_ peerID: String)
    func didDisconnectFromPeer(_ peerID: String)
    func didAuthenticatePeer(peerID: String, fingerprint: String)
    
    // Message handling
    func didReceiveMessage(_ message: KRTRMessage)
    func didReceivePrivateMessage(_ message: KRTRMessage)
    func didReceiveDeliveryAck(_ ack: DeliveryAck)
    func didReceiveReadReceipt(_ receipt: ReadReceipt)
    
    // Channel management
    func didReceiveChannelKeyVerifyRequest(_ request: ChannelKeyVerifyRequest, from peerID: String)
    func didReceiveChannelKeyVerifyResponse(_ response: ChannelKeyVerifyResponse, from peerID: String)
    func didReceiveChannelPasswordUpdate(_ update: ChannelPasswordUpdate, from peerID: String)
    func didReceiveChannelMetadata(_ metadata: ChannelMetadata, from peerID: String)
    
    // ZK Proof handling
    func didReceiveZKProof(_ proof: ZKProof, from peerID: String)
    func didReceiveZKChallenge(_ challenge: ZKChallenge, from peerID: String)
    func didReceiveZKResponse(_ response: ZKResponse, from peerID: String)
    
    // Network status
    func didUpdateNetworkStatus(_ status: NetworkStatus)
    func didUpdatePeerList()
    
    // User information
    func getCurrentNickname() -> String
    func getCurrentUserID() -> String
}

// MARK: - Supporting Data Structures

struct DeliveryAck: Codable {
    let messageID: String
    let recipientID: String
    let timestamp: Date
    let status: DeliveryStatus
    
    enum DeliveryStatus: String, Codable {
        case delivered = "delivered"
        case failed = "failed"
        case encrypted = "encrypted"
    }
    
    func encode() -> Data? {
        return try? JSONEncoder().encode(self)
    }
    
    static func decode(from data: Data) -> DeliveryAck? {
        return try? JSONDecoder().decode(DeliveryAck.self, from: data)
    }
}

struct ReadReceipt: Codable {
    let messageID: String
    let readerID: String
    let timestamp: Date
    
    func encode() -> Data? {
        return try? JSONEncoder().encode(self)
    }
    
    static func decode(from data: Data) -> ReadReceipt? {
        return try? JSONDecoder().decode(ReadReceipt.self, from: data)
    }
}

struct ChannelKeyVerifyRequest: Codable {
    let channel: String
    let requesterID: String
    let keyCommitment: String
    let timestamp: Date
    
    func encode() -> Data? {
        return try? JSONEncoder().encode(self)
    }
    
    static func decode(from data: Data) -> ChannelKeyVerifyRequest? {
        return try? JSONDecoder().decode(ChannelKeyVerifyRequest.self, from: data)
    }
}

struct ChannelKeyVerifyResponse: Codable {
    let channel: String
    let responderID: String
    let isValid: Bool
    let timestamp: Date
    
    func encode() -> Data? {
        return try? JSONEncoder().encode(self)
    }
    
    static func decode(from data: Data) -> ChannelKeyVerifyResponse? {
        return try? JSONDecoder().decode(ChannelKeyVerifyResponse.self, from: data)
    }
}

struct ChannelPasswordUpdate: Codable {
    let channel: String
    let ownerID: String
    let ownerFingerprint: String
    let encryptedPassword: Data
    let newKeyCommitment: String
    
    func encode() -> Data? {
        return try? JSONEncoder().encode(self)
    }
    
    static func decode(from data: Data) -> ChannelPasswordUpdate? {
        return try? JSONDecoder().decode(ChannelPasswordUpdate.self, from: data)
    }
}

struct ChannelMetadata: Codable {
    let channel: String
    let ownerID: String
    let description: String?
    let memberCount: Int?
    let isPrivate: Bool
    let timestamp: Date
    
    func encode() -> Data? {
        return try? JSONEncoder().encode(self)
    }
    
    static func decode(from data: Data) -> ChannelMetadata? {
        return try? JSONDecoder().decode(ChannelMetadata.self, from: data)
    }
}

// MARK: - ZK Proof Structures
struct ZKProof: Codable {
    let proofType: ZKProofType
    let proof: Data
    let publicInputs: [String]
    let timestamp: Date
    
    enum ZKProofType: String, Codable {
        case membership = "membership"
        case reputation = "reputation"
        case messageAuth = "message_auth"
    }
    
    func encode() -> Data? {
        return try? JSONEncoder().encode(self)
    }
    
    static func decode(from data: Data) -> ZKProof? {
        return try? JSONDecoder().decode(ZKProof.self, from: data)
    }
}

struct ZKChallenge: Codable {
    let challengeType: String
    let challenge: Data
    let timestamp: Date
    
    func encode() -> Data? {
        return try? JSONEncoder().encode(self)
    }
    
    static func decode(from data: Data) -> ZKChallenge? {
        return try? JSONDecoder().decode(ZKChallenge.self, from: data)
    }
}

struct ZKResponse: Codable {
    let challengeID: String
    let response: Data
    let timestamp: Date
    
    func encode() -> Data? {
        return try? JSONEncoder().encode(self)
    }
    
    static func decode(from data: Data) -> ZKResponse? {
        return try? JSONDecoder().decode(ZKResponse.self, from: data)
    }
}

// MARK: - Network Status
struct NetworkStatus {
    let connectedPeers: Int
    let activePeers: Int
    let batteryLevel: Float
    let powerMode: PowerMode
    let isScanning: Bool
    let isAdvertising: Bool
    let messagesSent: Int
    let messagesReceived: Int
}

enum PowerMode {
    case performance
    case balanced
    case powerSaver
    case ultraLowPower
    
    var maxConnections: Int {
        switch self {
        case .performance: return 20
        case .balanced: return 10
        case .powerSaver: return 5
        case .ultraLowPower: return 2
        }
    }
    
    var messageAggregationWindow: TimeInterval {
        switch self {
        case .performance: return 0.05  // 50ms
        case .balanced: return 0.1      // 100ms
        case .powerSaver: return 0.2    // 200ms
        case .ultraLowPower: return 0.5 // 500ms
        }
    }
    
    var advertisingInterval: TimeInterval {
        switch self {
        case .performance: return 0     // Continuous
        case .balanced: return 5        // Every 5 seconds
        case .powerSaver: return 15     // Every 15 seconds
        case .ultraLowPower: return 30  // Every 30 seconds
        }
    }
}
