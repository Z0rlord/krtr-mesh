/**
 * KRTR Protocol - Core messaging protocol adapted from bitchat
 * Implements binary protocol, message types, and packet structures
 */

import { Buffer } from 'buffer';
import uuid from 'react-native-uuid';

// Message types for KRTR protocol
export const MessageType = {
  ANNOUNCE: 0x01,        // Peer announcement with public key
  KEY_EXCHANGE: 0x02,    // Key exchange messages
  LEAVE: 0x03,           // Graceful disconnect
  MESSAGE: 0x04,         // Chat messages (private/broadcast)
  FRAGMENT_START: 0x05,  // Start of fragmented message
  FRAGMENT_CONTINUE: 0x06, // Continuation fragment
  FRAGMENT_END: 0x07,    // Final fragment
  CHANNEL_ANNOUNCE: 0x08, // Channel status announcement
  CHANNEL_RETENTION: 0x09, // Channel retention policy
  DELIVERY_ACK: 0x0A,    // Acknowledge message received
  DELIVERY_STATUS_REQUEST: 0x0B, // Request delivery status
  READ_RECEIPT: 0x0C     // Message read confirmation
};

// Special recipient IDs
export const SpecialRecipients = {
  BROADCAST: Buffer.alloc(8, 0xFF) // All 0xFF = broadcast
};

// Privacy-preserving padding utilities
export class MessagePadding {
  static blockSizes = [256, 512, 1024, 2048];

  static pad(data, targetSize) {
    if (data.length >= targetSize) return data;
    
    const paddingNeeded = targetSize - data.length;
    if (paddingNeeded > 255) return data; // PKCS#7 limit
    
    const padded = Buffer.concat([data]);
    const randomBytes = Buffer.alloc(paddingNeeded - 1);
    // Fill with random bytes
    for (let i = 0; i < randomBytes.length; i++) {
      randomBytes[i] = Math.floor(Math.random() * 256);
    }
    
    padded = Buffer.concat([padded, randomBytes, Buffer.from([paddingNeeded])]);
    return padded;
  }

  static unpad(data) {
    if (data.length === 0) return data;
    
    const paddingLength = data[data.length - 1];
    if (paddingLength <= 0 || paddingLength > data.length) return data;
    
    return data.slice(0, data.length - paddingLength);
  }

  static optimalBlockSize(dataSize) {
    const totalSize = dataSize + 16; // Account for encryption overhead
    
    for (const blockSize of this.blockSizes) {
      if (totalSize <= blockSize) return blockSize;
    }
    
    return dataSize; // For very large messages
  }
}

// Main packet structure for KRTR protocol
export class KrtrPacket {
  constructor({
    type,
    senderID,
    recipientID = null,
    timestamp = null,
    payload,
    signature = null,
    ttl = 7
  }) {
    this.version = 1;
    this.type = type;
    this.senderID = senderID;
    this.recipientID = recipientID;
    this.timestamp = timestamp || Date.now();
    this.payload = payload;
    this.signature = signature;
    this.ttl = ttl;
  }

  // Convert packet to binary data for transmission
  toBinaryData() {
    return BinaryProtocol.encode(this);
  }

  // Create packet from binary data
  static fromBinaryData(data) {
    return BinaryProtocol.decode(data);
  }
}

// Binary protocol implementation for efficient transmission
export class BinaryProtocol {
  static encode(packet) {
    try {
      const buffers = [];
      
      // Header: version (1) + type (1) + ttl (1) = 3 bytes
      buffers.push(Buffer.from([packet.version, packet.type, packet.ttl]));
      
      // Sender ID (8 bytes)
      const senderBuffer = Buffer.from(packet.senderID, 'utf8');
      const senderPadded = Buffer.alloc(8);
      senderBuffer.copy(senderPadded, 0, 0, Math.min(8, senderBuffer.length));
      buffers.push(senderPadded);
      
      // Recipient ID (8 bytes, optional)
      if (packet.recipientID) {
        const recipientBuffer = Buffer.from(packet.recipientID, 'utf8');
        const recipientPadded = Buffer.alloc(8);
        recipientBuffer.copy(recipientPadded, 0, 0, Math.min(8, recipientBuffer.length));
        buffers.push(recipientPadded);
      } else {
        buffers.push(Buffer.alloc(8, 0));
      }
      
      // Timestamp (8 bytes)
      const timestampBuffer = Buffer.alloc(8);
      timestampBuffer.writeBigUInt64BE(BigInt(packet.timestamp));
      buffers.push(timestampBuffer);
      
      // Payload length (4 bytes) + payload
      const payloadLength = Buffer.alloc(4);
      payloadLength.writeUInt32BE(packet.payload.length);
      buffers.push(payloadLength);
      buffers.push(packet.payload);
      
      // Signature (optional, 64 bytes if present)
      if (packet.signature) {
        buffers.push(packet.signature);
      }
      
      return Buffer.concat(buffers);
    } catch (error) {
      console.error('[KRTR Protocol] Encoding error:', error);
      return null;
    }
  }

  static decode(data) {
    try {
      if (data.length < 27) return null; // Minimum packet size
      
      let offset = 0;
      
      // Header
      const version = data[offset++];
      const type = data[offset++];
      const ttl = data[offset++];
      
      // Sender ID (8 bytes)
      const senderBuffer = data.slice(offset, offset + 8);
      const senderID = senderBuffer.toString('utf8').replace(/\0+$/, '');
      offset += 8;
      
      // Recipient ID (8 bytes)
      const recipientBuffer = data.slice(offset, offset + 8);
      const recipientID = recipientBuffer.every(b => b === 0) ? 
        null : recipientBuffer.toString('utf8').replace(/\0+$/, '');
      offset += 8;
      
      // Timestamp (8 bytes)
      const timestamp = Number(data.readBigUInt64BE(offset));
      offset += 8;
      
      // Payload length and payload
      const payloadLength = data.readUInt32BE(offset);
      offset += 4;
      
      if (offset + payloadLength > data.length) return null;
      
      const payload = data.slice(offset, offset + payloadLength);
      offset += payloadLength;
      
      // Signature (optional)
      let signature = null;
      if (offset + 64 <= data.length) {
        signature = data.slice(offset, offset + 64);
      }
      
      return new KrtrPacket({
        type,
        senderID,
        recipientID,
        timestamp,
        payload,
        signature,
        ttl
      });
    } catch (error) {
      console.error('[KRTR Protocol] Decoding error:', error);
      return null;
    }
  }
}

// Message structure for KRTR
export class KrtrMessage {
  constructor({
    id = null,
    sender,
    content,
    timestamp = null,
    isRelay = false,
    originalSender = null,
    isPrivate = false,
    recipientNickname = null,
    senderPeerID = null,
    mentions = null,
    channel = null,
    encryptedContent = null,
    isEncrypted = false,
    deliveryStatus = null
  }) {
    this.id = id || uuid.v4();
    this.sender = sender;
    this.content = content;
    this.timestamp = timestamp || new Date();
    this.isRelay = isRelay;
    this.originalSender = originalSender;
    this.isPrivate = isPrivate;
    this.recipientNickname = recipientNickname;
    this.senderPeerID = senderPeerID;
    this.mentions = mentions;
    this.channel = channel;
    this.encryptedContent = encryptedContent;
    this.isEncrypted = isEncrypted;
    this.deliveryStatus = deliveryStatus || (isPrivate ? 'sending' : null);
  }
}

// Delivery status tracking
export const DeliveryStatus = {
  SENDING: 'sending',
  SENT: 'sent',
  DELIVERED: 'delivered',
  READ: 'read',
  FAILED: 'failed',
  PARTIALLY_DELIVERED: 'partially_delivered'
};

// Delivery acknowledgment structure
export class DeliveryAck {
  constructor(originalMessageID, recipientID, recipientNickname, hopCount = 0) {
    this.originalMessageID = originalMessageID;
    this.ackID = uuid.v4();
    this.recipientID = recipientID;
    this.recipientNickname = recipientNickname;
    this.timestamp = new Date();
    this.hopCount = hopCount;
  }

  encode() {
    return Buffer.from(JSON.stringify(this), 'utf8');
  }

  static decode(data) {
    try {
      const json = JSON.parse(data.toString('utf8'));
      const ack = new DeliveryAck(
        json.originalMessageID,
        json.recipientID,
        json.recipientNickname,
        json.hopCount
      );
      ack.ackID = json.ackID;
      ack.timestamp = new Date(json.timestamp);
      return ack;
    } catch (error) {
      console.error('[KRTR Protocol] DeliveryAck decode error:', error);
      return null;
    }
  }
}

// Read receipt structure
export class ReadReceipt {
  constructor(originalMessageID, readerID, readerNickname) {
    this.originalMessageID = originalMessageID;
    this.receiptID = uuid.v4();
    this.readerID = readerID;
    this.readerNickname = readerNickname;
    this.timestamp = new Date();
  }

  encode() {
    return Buffer.from(JSON.stringify(this), 'utf8');
  }

  static decode(data) {
    try {
      const json = JSON.parse(data.toString('utf8'));
      const receipt = new ReadReceipt(
        json.originalMessageID,
        json.readerID,
        json.readerNickname
      );
      receipt.receiptID = json.receiptID;
      receipt.timestamp = new Date(json.timestamp);
      return receipt;
    } catch (error) {
      console.error('[KRTR Protocol] ReadReceipt decode error:', error);
      return null;
    }
  }
}
