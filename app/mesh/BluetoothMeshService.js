/**
 * KRTR Bluetooth Mesh Service - Core mesh networking implementation
 * Handles peer discovery, connection management, and message routing
 */

import { BleManager } from 'react-native-ble-plx';
import { Buffer } from 'buffer';
import {
  KrtrPacket,
  MessageType,
  BinaryProtocol,
} from '../protocols/KrtrProtocol';
import { SimpleCryptoService } from '../crypto/SimpleCryptoService';
import { StoreAndForwardService } from './StoreAndForwardService';
import { BatteryOptimizer } from './BatteryOptimizer';
import { ZKService } from '../zk/ZKService';

// KRTR service UUID for BLE discovery
const KRTR_SERVICE_UUID = '6E400001-B5A3-F393-E0A9-E50E24DCCA9E';
const KRTR_CHARACTERISTIC_UUID = '6E400002-B5A3-F393-E0A9-E50E24DCCA9E';

export class BluetoothMeshService {
  constructor(delegate) {
    this.delegate = delegate;
    this.bleManager = new BleManager();
    this.encryptionService = new EncryptionService();
    this.storeAndForward = new StoreAndForwardService();
    this.batteryOptimizer = new BatteryOptimizer();
    this.zkService = new ZKService();

    // Peer management
    this.connectedPeers = new Map(); // peerID -> device
    this.peerRSSI = new Map(); // peerID -> RSSI value
    this.peerLastSeen = new Map(); // peerID -> timestamp
    this.processedMessages = new Set(); // Message deduplication

    // Connection state
    this.isScanning = false;
    this.isAdvertising = false;
    this.maxConnections = 10; // Will be adjusted by battery optimizer

    // Message routing
    this.messageCache = new Map(); // messageID -> packet (for deduplication)
    this.routingTable = new Map(); // destination -> next hop

    // Performance tracking
    this.stats = {
      messagesSent: 0,
      messagesReceived: 0,
      messagesRelayed: 0,
      bytesTransmitted: 0,
      bytesReceived: 0,
    };

    this.initialize();
  }

  async initialize() {
    try {
      // Initialize BLE manager
      const state = await this.bleManager.state();
      console.log('[KRTR Mesh] BLE State:', state);

      if (state !== 'PoweredOn') {
        console.warn('[KRTR Mesh] Bluetooth not powered on');
        return;
      }

      // Set up battery optimization
      this.batteryOptimizer.onPowerModeChanged = mode => {
        this.adjustForPowerMode(mode);
      };

      // Start mesh operations
      await this.startAdvertising();
      await this.startScanning();

      // Set up periodic maintenance
      this.setupMaintenanceTasks();

      console.log('[KRTR Mesh] Mesh service initialized');
    } catch (error) {
      console.error('[KRTR Mesh] Initialization error:', error);
    }
  }

  async startAdvertising() {
    if (this.isAdvertising) return;

    try {
      const powerMode = this.batteryOptimizer.getCurrentPowerMode();
      const advertisingInterval = this.getAdvertisingInterval(powerMode);

      await this.bleManager.startDeviceAdvertising(
        KRTR_SERVICE_UUID,
        'KRTR-' + this.encryptionService.getShortID(),
        {
          txPowerLevel: 'medium',
          isConnectable: true,
          includeDeviceName: true,
          interval: advertisingInterval,
        }
      );

      this.isAdvertising = true;
      console.log('[KRTR Mesh] Started advertising');
    } catch (error) {
      console.error('[KRTR Mesh] Advertising error:', error);
    }
  }

  async startScanning() {
    if (this.isScanning) return;

    try {
      const powerMode = this.batteryOptimizer.getCurrentPowerMode();
      const { scanDuration, pauseDuration } = this.getScanDutyCycle(powerMode);

      this.bleManager.startDeviceScan(
        [KRTR_SERVICE_UUID],
        { allowDuplicates: false },
        (error, device) => {
          if (error) {
            console.error('[KRTR Mesh] Scan error:', error);
            return;
          }

          this.handleDeviceDiscovered(device);
        }
      );

      this.isScanning = true;

      // Implement duty cycling for battery optimization
      this.scheduleDutyCycle(scanDuration, pauseDuration);

      console.log('[KRTR Mesh] Started scanning');
    } catch (error) {
      console.error('[KRTR Mesh] Scanning error:', error);
    }
  }

  async handleDeviceDiscovered(device) {
    try {
      const peerID = this.extractPeerID(device.name);
      if (!peerID || this.connectedPeers.has(peerID)) return;

      // Check connection limits
      if (this.connectedPeers.size >= this.maxConnections) {
        console.log('[KRTR Mesh] Connection limit reached, skipping peer');
        return;
      }

      // Update peer tracking
      this.peerRSSI.set(peerID, device.rssi);
      this.peerLastSeen.set(peerID, Date.now());

      // Attempt connection
      await this.connectToPeer(device, peerID);
    } catch (error) {
      console.error('[KRTR Mesh] Device discovery error:', error);
    }
  }

  async connectToPeer(device, peerID) {
    try {
      console.log(`[KRTR Mesh] Connecting to peer: ${peerID}`);

      const connectedDevice = await device.connect();
      await connectedDevice.discoverAllServicesAndCharacteristics();

      // Set up message handling
      const characteristic = await connectedDevice.characteristicForService(
        KRTR_SERVICE_UUID,
        KRTR_CHARACTERISTIC_UUID
      );

      // Monitor for incoming messages
      characteristic.monitor((error, characteristic) => {
        if (error) {
          console.error('[KRTR Mesh] Characteristic monitor error:', error);
          return;
        }

        this.handleIncomingData(peerID, characteristic.value);
      });

      // Store connection
      this.connectedPeers.set(peerID, connectedDevice);

      // Perform key exchange
      await this.performKeyExchange(peerID);

      // Notify delegate
      this.delegate?.didConnectToPeer?.(peerID);

      console.log(`[KRTR Mesh] Connected to peer: ${peerID}`);
    } catch (error) {
      console.error(`[KRTR Mesh] Connection error for ${peerID}:`, error);
    }
  }

  async performKeyExchange(peerID) {
    try {
      const publicKeyData = this.encryptionService.getCombinedPublicKeyData();

      const keyExchangePacket = new KrtrPacket({
        type: MessageType.KEY_EXCHANGE,
        senderID: this.encryptionService.getShortID(),
        recipientID: peerID,
        payload: publicKeyData,
      });

      await this.sendPacketToPeer(peerID, keyExchangePacket);
      console.log(`[KRTR Mesh] Sent key exchange to ${peerID}`);
    } catch (error) {
      console.error(`[KRTR Mesh] Key exchange error for ${peerID}:`, error);
    }
  }

  async handleIncomingData(peerID, base64Data) {
    try {
      const data = Buffer.from(base64Data, 'base64');
      const packet = BinaryProtocol.decode(data);

      if (!packet) {
        console.warn('[KRTR Mesh] Failed to decode packet');
        return;
      }

      this.stats.bytesReceived += data.length;
      this.stats.messagesReceived++;

      // Handle different message types
      switch (packet.type) {
        case MessageType.KEY_EXCHANGE:
          await this.handleKeyExchange(peerID, packet);
          break;
        case MessageType.MESSAGE:
          await this.handleMessage(peerID, packet);
          break;
        case MessageType.ANNOUNCE:
          await this.handlePeerAnnouncement(peerID, packet);
          break;
        case MessageType.DELIVERY_ACK:
          await this.handleDeliveryAck(peerID, packet);
          break;
        default:
          console.log(`[KRTR Mesh] Unknown message type: ${packet.type}`);
      }
    } catch (error) {
      console.error('[KRTR Mesh] Incoming data error:', error);
    }
  }

  async handleKeyExchange(peerID, packet) {
    try {
      await this.encryptionService.addPeerPublicKey(peerID, packet.payload);
      console.log(`[KRTR Mesh] Key exchange completed with ${peerID}`);
    } catch (error) {
      console.error(`[KRTR Mesh] Key exchange handling error: ${error}`);
    }
  }

  async handleMessage(peerID, packet) {
    try {
      // Check for duplicates
      const messageID = this.generateMessageID(packet);
      if (this.processedMessages.has(messageID)) {
        return; // Already processed
      }
      this.processedMessages.add(messageID);

      // Decrypt if encrypted
      let content = packet.payload;
      if (
        packet.recipientID &&
        packet.recipientID !== this.encryptionService.getShortID()
      ) {
        // This is a relayed message, don't decrypt
      } else {
        try {
          content = await this.encryptionService.decrypt(
            packet.payload,
            peerID
          );
        } catch (decryptError) {
          console.warn('[KRTR Mesh] Decryption failed, treating as plaintext');
        }
      }

      // Check if we should relay this message
      if (packet.ttl > 0 && this.shouldRelay(packet)) {
        await this.relayMessage(packet, peerID);
      }

      // Deliver to local user if intended for us
      if (
        !packet.recipientID ||
        packet.recipientID === this.encryptionService.getShortID()
      ) {
        this.delegate?.didReceiveMessage?.({
          id: messageID,
          sender: packet.senderID,
          content: content.toString('utf8'),
          timestamp: new Date(packet.timestamp),
          isRelay: packet.senderID !== peerID,
          senderPeerID: peerID,
        });
      }
    } catch (error) {
      console.error('[KRTR Mesh] Message handling error:', error);
    }
  }

  async relayMessage(packet, fromPeerID) {
    try {
      // Decrement TTL
      packet.ttl--;

      // Relay to all connected peers except sender
      const relayPromises = [];
      for (const [peerID, device] of this.connectedPeers) {
        if (peerID !== fromPeerID) {
          relayPromises.push(this.sendPacketToPeer(peerID, packet));
        }
      }

      await Promise.allSettled(relayPromises);
      this.stats.messagesRelayed++;

      console.log(`[KRTR Mesh] Relayed message (TTL: ${packet.ttl})`);
    } catch (error) {
      console.error('[KRTR Mesh] Relay error:', error);
    }
  }

  async sendMessage(content, recipientID = null, isPrivate = false) {
    try {
      let payload = Buffer.from(content, 'utf8');

      // Encrypt if private message
      if (isPrivate && recipientID) {
        payload = await this.encryptionService.encrypt(payload, recipientID);
      }

      const packet = new KrtrPacket({
        type: MessageType.MESSAGE,
        senderID: this.encryptionService.getShortID(),
        recipientID: recipientID,
        payload: payload,
      });

      // Send to all connected peers
      const sendPromises = [];
      for (const peerID of this.connectedPeers.keys()) {
        sendPromises.push(this.sendPacketToPeer(peerID, packet));
      }

      await Promise.allSettled(sendPromises);
      this.stats.messagesSent++;

      console.log('[KRTR Mesh] Message sent');
      return packet;
    } catch (error) {
      console.error('[KRTR Mesh] Send message error:', error);
      throw error;
    }
  }

  async sendPacketToPeer(peerID, packet) {
    try {
      const device = this.connectedPeers.get(peerID);
      if (!device) {
        throw new Error(`Peer ${peerID} not connected`);
      }

      const data = packet.toBinaryData();
      if (!data) {
        throw new Error('Failed to encode packet');
      }

      const characteristic = await device.characteristicForService(
        KRTR_SERVICE_UUID,
        KRTR_CHARACTERISTIC_UUID
      );

      const base64Data = data.toString('base64');
      await characteristic.writeWithResponse(base64Data);

      this.stats.bytesTransmitted += data.length;
    } catch (error) {
      console.error(`[KRTR Mesh] Send packet error to ${peerID}:`, error);
      throw error;
    }
  }

  // Utility methods
  extractPeerID(deviceName) {
    if (!deviceName || !deviceName.startsWith('KRTR-')) return null;
    return deviceName.substring(5);
  }

  generateMessageID(packet) {
    return `${packet.senderID}-${packet.timestamp}`;
  }

  shouldRelay(packet) {
    // Don't relay if TTL is 0 or we've already processed this message
    return packet.ttl > 0;
  }

  getAdvertisingInterval(powerMode) {
    const intervals = {
      performance: 100, // 100ms
      balanced: 500, // 500ms
      powerSaver: 1500, // 1.5s
      ultraLowPower: 3000, // 3s
    };
    return intervals[powerMode] || intervals.balanced;
  }

  getScanDutyCycle(powerMode) {
    const cycles = {
      performance: { scanDuration: 3000, pauseDuration: 2000 },
      balanced: { scanDuration: 2000, pauseDuration: 3000 },
      powerSaver: { scanDuration: 1000, pauseDuration: 8000 },
      ultraLowPower: { scanDuration: 500, pauseDuration: 20000 },
    };
    return cycles[powerMode] || cycles.balanced;
  }

  adjustForPowerMode(powerMode) {
    const connectionLimits = {
      performance: 20,
      balanced: 10,
      powerSaver: 5,
      ultraLowPower: 2,
    };

    this.maxConnections = connectionLimits[powerMode] || 10;
    console.log(
      `[KRTR Mesh] Adjusted for power mode: ${powerMode}, max connections: ${this.maxConnections}`
    );
  }

  scheduleDutyCycle(scanDuration, pauseDuration) {
    setTimeout(() => {
      if (this.isScanning) {
        this.bleManager.stopDeviceScan();
        this.isScanning = false;

        setTimeout(() => {
          if (!this.isScanning) {
            this.startScanning();
          }
        }, pauseDuration);
      }
    }, scanDuration);
  }

  async handlePeerAnnouncement(peerID, packet) {
    try {
      // Update peer information
      this.peerLastSeen.set(peerID, Date.now());
      console.log(`[KRTR Mesh] Received announcement from ${peerID}`);
    } catch (error) {
      console.error('[KRTR Mesh] Peer announcement error:', error);
    }
  }

  async handleDeliveryAck(peerID, packet) {
    try {
      // Parse delivery acknowledgment
      const ackData = JSON.parse(packet.payload.toString('utf8'));
      this.delegate?.didReceiveDeliveryAck?.(ackData);
      console.log(`[KRTR Mesh] Received delivery ack from ${peerID}`);
    } catch (error) {
      console.error('[KRTR Mesh] Delivery ack error:', error);
    }
  }

  setupMaintenanceTasks() {
    // Clean up old processed messages every 5 minutes
    setInterval(() => {
      if (this.processedMessages.size > 1000) {
        this.processedMessages.clear();
        console.log('[KRTR Mesh] Cleared processed messages cache');
      }
    }, 5 * 60 * 1000);

    // Update peer list every 30 seconds
    setInterval(() => {
      this.delegate?.didUpdatePeerList?.(
        Array.from(this.connectedPeers.keys())
      );
    }, 30 * 1000);

    // Clean up stale peer data every 2 minutes
    setInterval(() => {
      const now = Date.now();
      const staleThreshold = 5 * 60 * 1000; // 5 minutes

      for (const [peerID, lastSeen] of this.peerLastSeen) {
        if (now - lastSeen > staleThreshold) {
          this.peerLastSeen.delete(peerID);
          this.peerRSSI.delete(peerID);
        }
      }
    }, 2 * 60 * 1000);
  }

  // Public API
  getConnectedPeers() {
    return Array.from(this.connectedPeers.keys());
  }

  getPeerRSSI(peerID) {
    return this.peerRSSI.get(peerID) || null;
  }

  getStats() {
    return {
      ...this.stats,
      connectedPeers: this.connectedPeers.size,
      knownPeers: this.peerLastSeen.size,
    };
  }

  async disconnect() {
    try {
      this.bleManager.stopDeviceScan();
      await this.bleManager.stopDeviceAdvertising();

      for (const device of this.connectedPeers.values()) {
        await device.cancelConnection();
      }

      this.connectedPeers.clear();
      this.isScanning = false;
      this.isAdvertising = false;

      console.log('[KRTR Mesh] Disconnected from all peers');
    } catch (error) {
      console.error('[KRTR Mesh] Disconnect error:', error);
    }
  }
}
