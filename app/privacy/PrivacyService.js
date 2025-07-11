/**
 * KRTR Privacy Service - Cover traffic, timing randomization, and privacy features
 * Adapted from bitchat's privacy-preserving mechanisms
 */

import { Buffer } from 'buffer';
import { MessageType } from '../protocols/KrtrProtocol';

export class PrivacyService {
  constructor(meshService, batteryOptimizer) {
    this.meshService = meshService;
    this.batteryOptimizer = batteryOptimizer;
    
    // Cover traffic settings
    this.coverTrafficEnabled = true;
    this.coverTrafficInterval = { min: 30000, max: 120000 }; // 30s - 2min
    this.coverTrafficTimer = null;
    
    // Timing randomization
    this.timingRandomization = true;
    this.minDelay = 50;   // 50ms
    this.maxDelay = 500;  // 500ms
    
    // Message queue for timing randomization
    this.messageQueue = [];
    this.queueProcessor = null;
    
    // Privacy statistics
    this.stats = {
      coverMessagesGenerated: 0,
      messagesDelayed: 0,
      totalDelayTime: 0,
      averageDelay: 0
    };
    
    this.initialize();
  }

  initialize() {
    // Start cover traffic generation
    this.startCoverTraffic();
    
    // Start message queue processor
    this.startMessageQueueProcessor();
    
    // Listen for power mode changes
    this.batteryOptimizer.onPowerModeChanged = (powerMode) => {
      this.updateForPowerMode(powerMode);
    };
    
    console.log('[KRTR Privacy] Privacy service initialized');
  }

  /**
   * Send message with timing randomization
   * @param {string} content - Message content
   * @param {string} recipientID - Recipient ID (null for broadcast)
   * @param {boolean} isPrivate - Whether message is private
   * @returns {Promise} - Promise that resolves when message is sent
   */
  async sendMessageWithPrivacy(content, recipientID = null, isPrivate = false) {
    return new Promise((resolve, reject) => {
      const delay = this.timingRandomization ? this.generateRandomDelay() : 0;
      
      const queuedMessage = {
        content,
        recipientID,
        isPrivate,
        timestamp: Date.now(),
        delay,
        resolve,
        reject
      };
      
      this.messageQueue.push(queuedMessage);
      
      if (delay > 0) {
        this.stats.messagesDelayed++;
        this.stats.totalDelayTime += delay;
        this.stats.averageDelay = this.stats.totalDelayTime / this.stats.messagesDelayed;
      }
    });
  }

  /**
   * Generate random delay for timing obfuscation
   * @returns {number} - Delay in milliseconds
   */
  generateRandomDelay() {
    return Math.floor(Math.random() * (this.maxDelay - this.minDelay + 1)) + this.minDelay;
  }

  /**
   * Start processing message queue with timing randomization
   */
  startMessageQueueProcessor() {
    this.queueProcessor = setInterval(() => {
      this.processMessageQueue();
    }, 10); // Check every 10ms for precise timing
  }

  /**
   * Process queued messages based on their delays
   */
  async processMessageQueue() {
    const now = Date.now();
    const readyMessages = [];
    
    // Find messages ready to be sent
    for (let i = this.messageQueue.length - 1; i >= 0; i--) {
      const message = this.messageQueue[i];
      if (now >= message.timestamp + message.delay) {
        readyMessages.push(message);
        this.messageQueue.splice(i, 1);
      }
    }
    
    // Send ready messages
    for (const message of readyMessages) {
      try {
        await this.meshService.sendMessage(
          message.content,
          message.recipientID,
          message.isPrivate
        );
        message.resolve();
      } catch (error) {
        message.reject(error);
      }
    }
  }

  /**
   * Start cover traffic generation
   */
  startCoverTraffic() {
    if (!this.coverTrafficEnabled) return;
    
    const scheduleNextCoverMessage = () => {
      const interval = Math.floor(
        Math.random() * (this.coverTrafficInterval.max - this.coverTrafficInterval.min + 1)
      ) + this.coverTrafficInterval.min;
      
      this.coverTrafficTimer = setTimeout(() => {
        this.generateCoverTraffic();
        scheduleNextCoverMessage();
      }, interval);
    };
    
    scheduleNextCoverMessage();
    console.log('[KRTR Privacy] Cover traffic generation started');
  }

  /**
   * Generate and send cover traffic message
   */
  async generateCoverTraffic() {
    try {
      // Only generate cover traffic if we have connected peers
      const connectedPeers = this.meshService.getConnectedPeers();
      if (connectedPeers.length === 0) return;
      
      // Generate realistic-looking dummy message
      const coverMessage = this.generateCoverMessage();
      
      // Select random peer for cover traffic
      const randomPeer = connectedPeers[Math.floor(Math.random() * connectedPeers.length)];
      
      // Send cover message (will be discarded by recipient)
      await this.meshService.sendMessage(coverMessage, randomPeer, true);
      
      this.stats.coverMessagesGenerated++;
      
      console.log('[KRTR Privacy] Generated cover traffic message');
    } catch (error) {
      console.error('[KRTR Privacy] Cover traffic generation error:', error);
    }
  }

  /**
   * Generate realistic cover message content
   * @returns {string} - Cover message content
   */
  generateCoverMessage() {
    const coverMessages = [
      'hey',
      'what\'s up?',
      'how are you?',
      'thanks',
      'ok',
      'sure',
      'got it',
      'sounds good',
      'let me know',
      'talk later',
      'see you',
      'take care'
    ];
    
    // Add cover traffic marker (will be filtered out by recipient)
    const baseMessage = coverMessages[Math.floor(Math.random() * coverMessages.length)];
    return `__COVER__${baseMessage}`;
  }

  /**
   * Check if message is cover traffic
   * @param {string} content - Message content
   * @returns {boolean} - True if cover traffic
   */
  isCoverTraffic(content) {
    return content.startsWith('__COVER__');
  }

  /**
   * Filter out cover traffic from received messages
   * @param {Object} message - Received message
   * @returns {boolean} - True if message should be displayed
   */
  shouldDisplayMessage(message) {
    return !this.isCoverTraffic(message.content);
  }

  /**
   * Generate ephemeral identity for session
   * @returns {Object} - Ephemeral identity data
   */
  generateEphemeralIdentity() {
    const adjectives = [
      'Anonymous', 'Silent', 'Hidden', 'Ghost', 'Shadow', 'Phantom',
      'Stealth', 'Invisible', 'Masked', 'Covert', 'Secret', 'Unknown'
    ];
    
    const nouns = [
      'User', 'Peer', 'Node', 'Agent', 'Entity', 'Client',
      'Sender', 'Messenger', 'Contact', 'Source', 'Terminal', 'Device'
    ];
    
    const adjective = adjectives[Math.floor(Math.random() * adjectives.length)];
    const noun = nouns[Math.floor(Math.random() * nouns.length)];
    const number = Math.floor(Math.random() * 9999).toString().padStart(4, '0');
    
    return {
      nickname: `${adjective}${noun}${number}`,
      sessionID: this.generateSessionID(),
      timestamp: Date.now()
    };
  }

  /**
   * Generate random session ID
   * @returns {string} - Session ID
   */
  generateSessionID() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    let result = '';
    for (let i = 0; i < 8; i++) {
      result += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return result;
  }

  /**
   * Update privacy settings based on power mode
   * @param {string} powerMode - Current power mode
   */
  updateForPowerMode(powerMode) {
    const privacyConfigs = {
      performance: {
        coverTrafficEnabled: true,
        timingRandomization: true,
        minDelay: 50,
        maxDelay: 500,
        coverInterval: { min: 30000, max: 120000 }
      },
      balanced: {
        coverTrafficEnabled: true,
        timingRandomization: true,
        minDelay: 100,
        maxDelay: 750,
        coverInterval: { min: 60000, max: 180000 }
      },
      powerSaver: {
        coverTrafficEnabled: false,
        timingRandomization: true,
        minDelay: 200,
        maxDelay: 1000,
        coverInterval: { min: 120000, max: 300000 }
      },
      ultraLowPower: {
        coverTrafficEnabled: false,
        timingRandomization: false,
        minDelay: 0,
        maxDelay: 0,
        coverInterval: { min: 300000, max: 600000 }
      }
    };
    
    const config = privacyConfigs[powerMode] || privacyConfigs.balanced;
    
    // Update settings
    this.coverTrafficEnabled = config.coverTrafficEnabled;
    this.timingRandomization = config.timingRandomization;
    this.minDelay = config.minDelay;
    this.maxDelay = config.maxDelay;
    this.coverTrafficInterval = config.coverInterval;
    
    // Restart cover traffic with new settings
    if (this.coverTrafficTimer) {
      clearTimeout(this.coverTrafficTimer);
      this.coverTrafficTimer = null;
    }
    
    if (this.coverTrafficEnabled) {
      this.startCoverTraffic();
    }
    
    console.log(`[KRTR Privacy] Updated privacy settings for power mode: ${powerMode}`);
  }

  /**
   * Emergency privacy wipe
   */
  async emergencyWipe() {
    try {
      // Clear message queue
      this.messageQueue = [];
      
      // Stop cover traffic
      if (this.coverTrafficTimer) {
        clearTimeout(this.coverTrafficTimer);
        this.coverTrafficTimer = null;
      }
      
      // Reset statistics
      this.stats = {
        coverMessagesGenerated: 0,
        messagesDelayed: 0,
        totalDelayTime: 0,
        averageDelay: 0
      };
      
      console.log('[KRTR Privacy] Emergency privacy wipe completed');
    } catch (error) {
      console.error('[KRTR Privacy] Emergency wipe error:', error);
    }
  }

  /**
   * Get privacy statistics
   * @returns {Object} - Privacy stats
   */
  getStats() {
    return {
      ...this.stats,
      coverTrafficEnabled: this.coverTrafficEnabled,
      timingRandomization: this.timingRandomization,
      queuedMessages: this.messageQueue.length,
      delayRange: { min: this.minDelay, max: this.maxDelay },
      coverTrafficInterval: this.coverTrafficInterval
    };
  }

  /**
   * Cleanup resources
   */
  destroy() {
    // Stop cover traffic
    if (this.coverTrafficTimer) {
      clearTimeout(this.coverTrafficTimer);
    }
    
    // Stop queue processor
    if (this.queueProcessor) {
      clearInterval(this.queueProcessor);
    }
    
    // Clear message queue
    this.messageQueue = [];
    
    console.log('[KRTR Privacy] Privacy service destroyed');
  }
}
