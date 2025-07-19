/**
 * KRTR Protocol - Binary protocol and message definitions
 * Handles packet structure, message types, and serialization
 */

import Foundation

// MARK: - Message Types
enum MessageType: UInt8 {
    case announce = 0x01
    case message = 0x02
    case leave = 0x03
    case deliveryAck = 0x04
    case readReceipt = 0x05
    case noiseHandshakeInit = 0x10
    case noiseHandshakeResp = 0x11
    case noiseEncrypted = 0x12
    case noiseIdentityAnnounce = 0x13
    case versionHello = 0x20
    case versionAck = 0x21
    case channelKeyVerifyRequest = 0x30
    case channelKeyVerifyResponse = 0x31
    case channelPasswordUpdate = 0x32
    case channelMetadata = 0x33
    case zkProof = 0x40
    case zkChallenge = 0x41
    case zkResponse = 0x42
}

// MARK: - Special Recipients
struct SpecialRecipients {
    static let broadcast = Data([0xFF, 0xFF, 0xFF, 0xFF])
    static let channel = Data([0xFE, 0xFE, 0xFE, 0xFE])
}

// MARK: - KRTR Packet
struct KRTRPacket {
    let type: UInt8
    let senderID: Data
    let recipientID: Data
    let timestamp: UInt64
    let payload: Data
    let signature: Data?
    let ttl: UInt8
    
    init(type: UInt8, senderID: Data, recipientID: Data, timestamp: UInt64, payload: Data, signature: Data?, ttl: UInt8) {
        self.type = type
        self.senderID = senderID
        self.recipientID = recipientID
        self.timestamp = timestamp
        self.payload = payload
        self.signature = signature
        self.ttl = ttl
    }
    
    // Convert packet to binary data for transmission
    func toBinaryData() -> Data? {
        var data = Data()
        
        // Header: [type:1][ttl:1][senderID_len:1][recipientID_len:1]
        data.append(type)
        data.append(ttl)
        data.append(UInt8(senderID.count))
        data.append(UInt8(recipientID.count))
        
        // IDs
        data.append(senderID)
        data.append(recipientID)
        
        // Timestamp (8 bytes, big endian)
        var timestampBE = timestamp.bigEndian
        data.append(Data(bytes: &timestampBE, count: 8))
        
        // Payload length (4 bytes, big endian)
        var payloadLen = UInt32(payload.count).bigEndian
        data.append(Data(bytes: &payloadLen, count: 4))
        
        // Payload
        data.append(payload)
        
        // Signature (optional)
        if let sig = signature {
            var sigLen = UInt16(sig.count).bigEndian
            data.append(Data(bytes: &sigLen, count: 2))
            data.append(sig)
        } else {
            // No signature
            data.append(Data([0x00, 0x00]))
        }
        
        return data
    }
    
    // Parse binary data into packet
    static func from(_ data: Data) -> KRTRPacket? {
        guard data.count >= 8 else { return nil }
        
        var offset = 0
        
        // Parse header
        let type = data[offset]
        offset += 1
        
        let ttl = data[offset]
        offset += 1
        
        let senderIDLen = Int(data[offset])
        offset += 1
        
        let recipientIDLen = Int(data[offset])
        offset += 1
        
        // Parse IDs
        guard offset + senderIDLen + recipientIDLen <= data.count else { return nil }
        
        let senderID = data.subdata(in: offset..<offset + senderIDLen)
        offset += senderIDLen
        
        let recipientID = data.subdata(in: offset..<offset + recipientIDLen)
        offset += recipientIDLen
        
        // Parse timestamp
        guard offset + 8 <= data.count else { return nil }
        let timestampData = data.subdata(in: offset..<offset + 8)
        let timestamp = timestampData.withUnsafeBytes { $0.load(as: UInt64.self).bigEndian }
        offset += 8
        
        // Parse payload length
        guard offset + 4 <= data.count else { return nil }
        let payloadLenData = data.subdata(in: offset..<offset + 4)
        let payloadLen = Int(payloadLenData.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })
        offset += 4
        
        // Parse payload
        guard offset + payloadLen <= data.count else { return nil }
        let payload = data.subdata(in: offset..<offset + payloadLen)
        offset += payloadLen
        
        // Parse signature
        guard offset + 2 <= data.count else { return nil }
        let sigLenData = data.subdata(in: offset..<offset + 2)
        let sigLen = Int(sigLenData.withUnsafeBytes { $0.load(as: UInt16.self).bigEndian })
        offset += 2
        
        var signature: Data?
        if sigLen > 0 {
            guard offset + sigLen <= data.count else { return nil }
            signature = data.subdata(in: offset..<offset + sigLen)
        }
        
        return KRTRPacket(
            type: type,
            senderID: senderID,
            recipientID: recipientID,
            timestamp: timestamp,
            payload: payload,
            signature: signature,
            ttl: ttl
        )
    }
}

// MARK: - KRTR Message
struct KRTRMessage {
    let id: String
    let sender: String
    let content: String
    let timestamp: Date
    let isRelay: Bool
    let originalSender: String?
    let isPrivate: Bool
    let recipientNickname: String?
    let senderPeerID: String
    let mentions: [String]?
    let channel: String?
    
    func toBinaryPayload() -> Data? {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .millisecondsSince1970
            return try encoder.encode(self)
        } catch {
            return nil
        }
    }
    
    static func fromBinaryPayload(_ data: Data) -> KRTRMessage? {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .millisecondsSince1970
            return try decoder.decode(KRTRMessage.self, from: data)
        } catch {
            return nil
        }
    }
}

// MARK: - Codable conformance
extension KRTRMessage: Codable {}

// MARK: - Utility Extensions
extension Data {
    init?(hexString: String) {
        let len = hexString.count / 2
        var data = Data(capacity: len)
        var index = hexString.startIndex
        for _ in 0..<len {
            let nextIndex = hexString.index(index, offsetBy: 2)
            if let b = UInt8(hexString[index..<nextIndex], radix: 16) {
                data.append(b)
            } else {
                return nil
            }
            index = nextIndex
        }
        self = data
    }
    
    func hexEncodedString() -> String {
        return map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Bounded Set for Memory Management
class BoundedSet<T: Hashable> {
    private var set = Set<T>()
    private var insertionOrder = [T]()
    private let maxSize: Int
    private let queue = DispatchQueue(label: "boundedset", attributes: .concurrent)
    
    init(maxSize: Int) {
        self.maxSize = maxSize
    }
    
    func insert(_ element: T) {
        queue.async(flags: .barrier) {
            if !self.set.contains(element) {
                if self.set.count >= self.maxSize {
                    // Remove oldest element
                    let oldest = self.insertionOrder.removeFirst()
                    self.set.remove(oldest)
                }
                self.set.insert(element)
                self.insertionOrder.append(element)
            }
        }
    }
    
    func contains(_ element: T) -> Bool {
        return queue.sync {
            return set.contains(element)
        }
    }
    
    func remove(_ element: T) {
        queue.async(flags: .barrier) {
            if self.set.remove(element) != nil {
                if let index = self.insertionOrder.firstIndex(of: element) {
                    self.insertionOrder.remove(at: index)
                }
            }
        }
    }
    
    func removeAll() {
        queue.async(flags: .barrier) {
            self.set.removeAll()
            self.insertionOrder.removeAll()
        }
    }
}
