/**
 * KRTR Chat View Model - MVVM architecture for mesh chat interface
 * Manages chat state, peer connections, and user interactions
 */

import Foundation
import SwiftUI
import Combine
import os.log

@MainActor
class ChatViewModel: ObservableObject, KRTRMeshDelegate {
    // MARK: - Published Properties
    @Published var messages: [KRTRMessage] = []
    @Published var peers: [PeerInfo] = []
    @Published var nickname: String = "Anonymous"
    @Published var currentChannel: String = "#general"
    @Published var isConnected: Bool = false
    @Published var networkStatus: NetworkStatus = NetworkStatus(
        connectedPeers: 0,
        activePeers: 0,
        batteryLevel: 1.0,
        powerMode: .balanced,
        isScanning: false,
        isAdvertising: false,
        messagesSent: 0,
        messagesReceived: 0
    )
    
    // MARK: - Private Properties
    private let meshService = BluetoothMeshService()
    private let zkService: ZKServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private let messageQueue = DispatchQueue(label: "krtr.chat.messages", attributes: .concurrent)
    
    // Message management
    private var messagesSent = 0
    private var messagesReceived = 0
    
    // Peer management
    private var peerPublicKeys: [String: Data] = [:]
    
    init() {
        // Initialize ZK service
        self.zkService = ZKServiceFactory.create()
        
        // Set up mesh service delegate
        meshService.delegate = self
        
        // Load saved nickname
        loadNickname()
        
        // Setup battery monitoring
        setupBatteryMonitoring()
        
        SecurityLogger.log("ChatViewModel initialized", category: SecurityLogger.app, level: .info)
    }
    
    // MARK: - Public Interface
    
    func startServices() {
        meshService.startServices()
        isConnected = true
        SecurityLogger.log("Mesh services started", category: SecurityLogger.app, level: .info)
    }
    
    func cleanup() {
        meshService.cleanup()
        isConnected = false
        SecurityLogger.log("Mesh services cleaned up", category: SecurityLogger.app, level: .info)
    }
    
    func sendMessage(_ content: String) {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let messageID = UUID().uuidString
        
        // Check if it's a channel message
        if currentChannel.hasPrefix("#") {
            meshService.sendMessage(
                content,
                mentions: extractMentions(from: content),
                channel: currentChannel,
                messageID: messageID
            )
        } else {
            // Direct message
            meshService.sendMessage(
                content,
                messageID: messageID
            )
        }
        
        messagesSent += 1
        updateNetworkStatus()
        
        SecurityLogger.log("Message sent: \(messageID)", category: SecurityLogger.app, level: .debug)
    }
    
    func sendPrivateMessage(_ content: String, to peerID: String) {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let recipientNickname = peers.first { $0.id == peerID }?.nickname ?? "Unknown"
        let messageID = UUID().uuidString
        
        meshService.sendPrivateMessage(
            content,
            to: peerID,
            recipientNickname: recipientNickname,
            messageID: messageID
        )
        
        messagesSent += 1
        updateNetworkStatus()
        
        SecurityLogger.log("Private message sent to \(peerID): \(messageID)", category: SecurityLogger.app, level: .debug)
    }
    
    func setNickname(_ newNickname: String) {
        let trimmed = newNickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        nickname = trimmed
        saveNickname()
        
        SecurityLogger.log("Nickname updated: \(nickname)", category: SecurityLogger.app, level: .info)
    }
    
    func joinChannel(_ channel: String) {
        let formattedChannel = channel.hasPrefix("#") ? channel : "#\(channel)"
        currentChannel = formattedChannel
        
        SecurityLogger.log("Joined channel: \(currentChannel)", category: SecurityLogger.app, level: .info)
    }
    
    func leaveChannel() {
        if currentChannel != "#general" {
            meshService.sendChannelLeaveNotification(currentChannel)
            currentChannel = "#general"
            
            SecurityLogger.log("Left channel, returned to #general", category: SecurityLogger.app, level: .info)
        }
    }
    
    // MARK: - ZK Proof Integration
    
    func generateMembershipProof(for groupRoot: Data) async throws -> ZKProofResult {
        // TODO: Implement membership proof generation
        // This would use the user's membership key and group parameters
        let membershipKey = Data() // Placeholder
        let pathElements: [Data] = [] // Placeholder
        let pathIndices: [Int] = [] // Placeholder
        
        return try await zkService.generateMembershipProof(
            membershipKey: membershipKey,
            groupRoot: groupRoot,
            pathElements: pathElements,
            pathIndices: pathIndices
        )
    }
    
    func generateReputationProof(threshold: Int) async throws -> ZKProofResult {
        // TODO: Implement reputation proof generation
        // This would use the user's reputation score
        let reputationScore = 100 // Placeholder
        let nonce = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        
        return try await zkService.generateReputationProof(
            reputationScore: reputationScore,
            threshold: threshold,
            nonce: nonce
        )
    }
    
    // MARK: - Private Helpers
    
    private func loadNickname() {
        if let savedNickname = UserDefaults.standard.string(forKey: "krtr.nickname"),
           !savedNickname.isEmpty {
            nickname = savedNickname
        } else {
            // Generate random nickname
            nickname = "User\(Int.random(in: 1000...9999))"
            saveNickname()
        }
    }
    
    private func saveNickname() {
        UserDefaults.standard.set(nickname, forKey: "krtr.nickname")
    }
    
    private func extractMentions(from content: String) -> [String] {
        let mentionPattern = "@([a-zA-Z0-9_]+)"
        let regex = try? NSRegularExpression(pattern: mentionPattern, options: [])
        let matches = regex?.matches(in: content, options: [], range: NSRange(content.startIndex..., in: content)) ?? []
        
        return matches.compactMap { match in
            if let range = Range(match.range(at: 1), in: content) {
                return String(content[range])
            }
            return nil
        }
    }
    
    private func setupBatteryMonitoring() {
        BatteryOptimizer.shared.$batteryLevel
            .sink { [weak self] level in
                self?.updateNetworkStatus()
            }
            .store(in: &cancellables)
        
        BatteryOptimizer.shared.$currentPowerMode
            .sink { [weak self] mode in
                self?.updateNetworkStatus()
            }
            .store(in: &cancellables)
    }
    
    private func updateNetworkStatus() {
        networkStatus = NetworkStatus(
            connectedPeers: peers.filter { $0.isConnected }.count,
            activePeers: peers.count,
            batteryLevel: BatteryOptimizer.shared.batteryLevel,
            powerMode: BatteryOptimizer.shared.currentPowerMode,
            isScanning: true, // TODO: Get actual scanning state
            isAdvertising: true, // TODO: Get actual advertising state
            messagesSent: messagesSent,
            messagesReceived: messagesReceived
        )
    }
    
    // MARK: - Peer Management
    
    func registerPeerPublicKey(peerID: String, publicKeyData: Data) {
        peerPublicKeys[peerID] = publicKeyData
    }
    
    func getPeerPublicKey(for peerID: String) -> Data? {
        return peerPublicKeys[peerID]
    }
}

// MARK: - KRTRMeshDelegate Implementation
extension ChatViewModel {
    func didDiscoverPeer(_ peerID: String, nickname: String?, rssi: NSNumber?) {
        let peerInfo = PeerInfo(
            id: peerID,
            nickname: nickname ?? "Unknown",
            isConnected: false,
            rssi: rssi,
            lastSeen: Date()
        )

        if !peers.contains(where: { $0.id == peerID }) {
            peers.append(peerInfo)
            updateNetworkStatus()
            SecurityLogger.log("Discovered peer: \(peerID)", category: SecurityLogger.mesh, level: .debug)
        }
    }

    func didConnectToPeer(_ peerID: String) {
        if let index = peers.firstIndex(where: { $0.id == peerID }) {
            peers[index].isConnected = true
            peers[index].lastSeen = Date()
            updateNetworkStatus()
            SecurityLogger.log("Connected to peer: \(peerID)", category: SecurityLogger.mesh, level: .info)
        }
    }

    func didDisconnectFromPeer(_ peerID: String) {
        if let index = peers.firstIndex(where: { $0.id == peerID }) {
            peers[index].isConnected = false
            updateNetworkStatus()
            SecurityLogger.log("Disconnected from peer: \(peerID)", category: SecurityLogger.mesh, level: .info)
        }
    }

    func didAuthenticatePeer(peerID: String, fingerprint: String) {
        if let index = peers.firstIndex(where: { $0.id == peerID }) {
            peers[index].fingerprint = fingerprint
            peers[index].isAuthenticated = true
            SecurityLogger.log("Authenticated peer: \(peerID)", category: SecurityLogger.mesh, level: .info)
        }
    }

    func didReceiveMessage(_ message: KRTRMessage) {
        messageQueue.async { [weak self] in
            DispatchQueue.main.async {
                self?.messages.append(message)
                self?.messagesReceived += 1
                self?.updateNetworkStatus()
                SecurityLogger.log("Received message: \(message.id)", category: SecurityLogger.app, level: .debug)
            }
        }
    }

    func didReceivePrivateMessage(_ message: KRTRMessage) {
        messageQueue.async { [weak self] in
            DispatchQueue.main.async {
                self?.messages.append(message)
                self?.messagesReceived += 1
                self?.updateNetworkStatus()
                SecurityLogger.log("Received private message: \(message.id)", category: SecurityLogger.app, level: .debug)
            }
        }
    }

    func didReceiveDeliveryAck(_ ack: DeliveryAck) {
        SecurityLogger.log("Received delivery ACK for message: \(ack.messageID)", category: SecurityLogger.app, level: .debug)
    }

    func didReceiveReadReceipt(_ receipt: ReadReceipt) {
        SecurityLogger.log("Received read receipt for message: \(receipt.messageID)", category: SecurityLogger.app, level: .debug)
    }

    func didReceiveChannelKeyVerifyRequest(_ request: ChannelKeyVerifyRequest, from peerID: String) {
        SecurityLogger.log("Received channel key verify request from: \(peerID)", category: SecurityLogger.app, level: .debug)
    }

    func didReceiveChannelKeyVerifyResponse(_ response: ChannelKeyVerifyResponse, from peerID: String) {
        SecurityLogger.log("Received channel key verify response from: \(peerID)", category: SecurityLogger.app, level: .debug)
    }

    func didReceiveChannelPasswordUpdate(_ update: ChannelPasswordUpdate, from peerID: String) {
        SecurityLogger.log("Received channel password update from: \(peerID)", category: SecurityLogger.app, level: .debug)
    }

    func didReceiveChannelMetadata(_ metadata: ChannelMetadata, from peerID: String) {
        SecurityLogger.log("Received channel metadata from: \(peerID)", category: SecurityLogger.app, level: .debug)
    }

    func didReceiveZKProof(_ proof: ZKProof, from peerID: String) {
        SecurityLogger.log("Received ZK proof from: \(peerID)", category: SecurityLogger.zk, level: .debug)
    }

    func didReceiveZKChallenge(_ challenge: ZKChallenge, from peerID: String) {
        SecurityLogger.log("Received ZK challenge from: \(peerID)", category: SecurityLogger.zk, level: .debug)
    }

    func didReceiveZKResponse(_ response: ZKResponse, from peerID: String) {
        SecurityLogger.log("Received ZK response from: \(peerID)", category: SecurityLogger.zk, level: .debug)
    }

    func didUpdateNetworkStatus(_ status: NetworkStatus) {
        networkStatus = status
    }

    func didUpdatePeerList() {
        updateNetworkStatus()
    }

    func getCurrentNickname() -> String {
        return nickname
    }

    func getCurrentUserID() -> String {
        return meshService.myPeerID
    }
}

// MARK: - Supporting Data Structures
struct PeerInfo: Identifiable, Equatable {
    let id: String
    var nickname: String
    var isConnected: Bool
    var isAuthenticated: Bool = false
    var fingerprint: String?
    var rssi: NSNumber?
    var lastSeen: Date

    static func == (lhs: PeerInfo, rhs: PeerInfo) -> Bool {
        return lhs.id == rhs.id
    }
}
