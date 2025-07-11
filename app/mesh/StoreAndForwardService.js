/**
 * KRTR Store and Forward Service - Offline message caching and delivery
 * Intelligent message caching with tiered retention policies
 */

import AsyncStorage from '@react-native-async-storage/async-storage';
import { KrtrMessage, DeliveryStatus } from '../protocols/KrtrProtocol';

export class StoreAndForwardService {
  constructor() {
    // Message cache for offline peers
    this.messageCache = new Map(); // peerID -> messages[]
    this.favoriteCache = new Map(); // peerID -> messages[] (longer retention)
    this.deliveryQueue = new Map(); // messageID -> delivery attempts

    // Cache limits and TTL
    this.regularCacheLimit = 100; // messages per peer
    this.favoriteCacheLimit = 1000; // messages per favorite peer
    this.regularTTL = 12 * 60 * 60 * 1000; // 12 hours
    this.favoriteTTL = 7 * 24 * 60 * 60 * 1000; // 7 days

    // Delivery tracking
    this.maxDeliveryAttempts = 5;
    this.deliveryRetryInterval = 30 * 1000; // 30 seconds

    this.initialize();
  }

  async initialize() {
    try {
      // Load cached messages from persistent storage
      await this.loadCachedMessages();

      // Set up periodic cleanup
      this.setupCleanupTasks();

      console.log('[KRTR Store&Forward] Service initialized');
    } catch (error) {
      console.error('[KRTR Store&Forward] Initialization error:', error);
    }
  }

  async loadCachedMessages() {
    try {
      const regularCacheData = await AsyncStorage.getItem('krtr_message_cache');
      const favoriteCacheData = await AsyncStorage.getItem('krtr_favorite_cache');

      if (regularCacheData) {
        const parsed = JSON.parse(regularCacheData);
        for (const [peerID, messages] of Object.entries(parsed)) {
          this.messageCache.set(peerID, messages.map(msg => ({
            ...msg,
            timestamp: new Date(msg.timestamp)
          })));
        }
      }

      if (favoriteCacheData) {
        const parsed = JSON.parse(favoriteCacheData);
        for (const [peerID, messages] of Object.entries(parsed)) {
          this.favoriteCache.set(peerID, messages.map(msg => ({
            ...msg,
            timestamp: new Date(msg.timestamp)
          })));
        }
      }

      console.log(`[KRTR Store&Forward] Loaded ${this.messageCache.size} regular and ${this.favoriteCache.size} favorite caches`);
    } catch (error) {
      console.error('[KRTR Store&Forward] Load cache error:', error);
    }
  }

  async saveCachedMessages() {
    try {
      // Convert Maps to objects for JSON serialization
      const regularCacheObj = {};
      for (const [peerID, messages] of this.messageCache) {
        regularCacheObj[peerID] = messages;
      }

      const favoriteCacheObj = {};
      for (const [peerID, messages] of this.favoriteCache) {
        favoriteCacheObj[peerID] = messages;
      }

      await AsyncStorage.setItem('krtr_message_cache', JSON.stringify(regularCacheObj));
      await AsyncStorage.setItem('krtr_favorite_cache', JSON.stringify(favoriteCacheObj));

      console.log('[KRTR Store&Forward] Cached messages saved');
    } catch (error) {
      console.error('[KRTR Store&Forward] Save cache error:', error);
    }
  }

  async cacheMessage(message, recipientID, isFavorite = false) {
    try {
      const cache = isFavorite ? this.favoriteCache : this.messageCache;
      const limit = isFavorite ? this.favoriteCacheLimit : this.regularCacheLimit;

      if (!cache.has(recipientID)) {
        cache.set(recipientID, []);
      }

      const messages = cache.get(recipientID);

      // Add message with metadata
      const cachedMessage = {
        ...message,
        cachedAt: new Date(),
        deliveryAttempts: 0,
        isFavorite
      };

      messages.push(cachedMessage);

      // Enforce cache limits (FIFO)
      if (messages.length > limit) {
        messages.splice(0, messages.length - limit);
      }

      // Save to persistent storage
      await this.saveCachedMessages();

      console.log(`[KRTR Store&Forward] Cached message for ${recipientID} (favorite: ${isFavorite})`);
    } catch (error) {
      console.error('[KRTR Store&Forward] Cache message error:', error);
    }
  }

  async deliverCachedMessages(peerID, meshService) {
    try {
      const regularMessages = this.messageCache.get(peerID) || [];
      const favoriteMessages = this.favoriteCache.get(peerID) || [];
      const allMessages = [...regularMessages, ...favoriteMessages];

      if (allMessages.length === 0) {
        return;
      }

      console.log(`[KRTR Store&Forward] Delivering ${allMessages.length} cached messages to ${peerID}`);

      const deliveryPromises = [];

      for (const message of allMessages) {
        // Check if message is still valid (not expired)
        if (this.isMessageExpired(message)) {
          continue;
        }

        // Attempt delivery
        const deliveryPromise = this.attemptDelivery(message, peerID, meshService);
        deliveryPromises.push(deliveryPromise);
      }

      // Wait for all deliveries to complete
      const results = await Promise.allSettled(deliveryPromises);

      // Remove successfully delivered messages
      let deliveredCount = 0;
      for (let i = 0; i < results.length; i++) {
        if (results[i].status === 'fulfilled') {
          const message = allMessages[i];
          this.removeCachedMessage(message.id, peerID);
          deliveredCount++;
        }
      }

      console.log(`[KRTR Store&Forward] Delivered ${deliveredCount}/${allMessages.length} messages to ${peerID}`);

      // Save updated cache
      await this.saveCachedMessages();
    } catch (error) {
      console.error('[KRTR Store&Forward] Delivery error:', error);
    }
  }

  async attemptDelivery(message, peerID, meshService) {
    try {
      // Increment delivery attempts
      message.deliveryAttempts = (message.deliveryAttempts || 0) + 1;

      // Check if we've exceeded max attempts
      if (message.deliveryAttempts > this.maxDeliveryAttempts) {
        console.warn(`[KRTR Store&Forward] Max delivery attempts reached for message ${message.id}`);
        throw new Error('Max delivery attempts exceeded');
      }

      // Attempt to send the message
      await meshService.sendMessage(message.content, peerID, message.isPrivate);

      // Mark as delivered
      message.deliveryStatus = DeliveryStatus.DELIVERED;
      message.deliveredAt = new Date();

      console.log(`[KRTR Store&Forward] Successfully delivered message ${message.id} to ${peerID}`);
      return true;
    } catch (error) {
      console.error(`[KRTR Store&Forward] Delivery attempt failed for ${message.id}:`, error);

      // Schedule retry if not exceeded max attempts
      if (message.deliveryAttempts < this.maxDeliveryAttempts) {
        setTimeout(() => {
          this.attemptDelivery(message, peerID, meshService);
        }, this.deliveryRetryInterval);
      }

      throw error;
    }
  }

  removeCachedMessage(messageID, peerID) {
    // Remove from regular cache
    const regularMessages = this.messageCache.get(peerID);
    if (regularMessages) {
      const index = regularMessages.findIndex(msg => msg.id === messageID);
      if (index !== -1) {
        regularMessages.splice(index, 1);
        if (regularMessages.length === 0) {
          this.messageCache.delete(peerID);
        }
        return;
      }
    }

    // Remove from favorite cache
    const favoriteMessages = this.favoriteCache.get(peerID);
    if (favoriteMessages) {
      const index = favoriteMessages.findIndex(msg => msg.id === messageID);
      if (index !== -1) {
        favoriteMessages.splice(index, 1);
        if (favoriteMessages.length === 0) {
          this.favoriteCache.delete(peerID);
        }
      }
    }
  }

  isMessageExpired(message) {
    const now = Date.now();
    const cachedAt = new Date(message.cachedAt).getTime();
    const ttl = message.isFavorite ? this.favoriteTTL : this.regularTTL;

    return (now - cachedAt) > ttl;
  }

  setupCleanupTasks() {
    // Clean up expired messages every hour
    setInterval(() => {
      this.cleanupExpiredMessages();
    }, 60 * 60 * 1000);

    // Save cache every 5 minutes
    setInterval(() => {
      this.saveCachedMessages();
    }, 5 * 60 * 1000);
  }

  async cleanupExpiredMessages() {
    try {
      let cleanedCount = 0;

      // Clean regular cache
      for (const [peerID, messages] of this.messageCache) {
        const validMessages = messages.filter(msg => !this.isMessageExpired(msg));
        if (validMessages.length !== messages.length) {
          cleanedCount += messages.length - validMessages.length;
          if (validMessages.length === 0) {
            this.messageCache.delete(peerID);
          } else {
            this.messageCache.set(peerID, validMessages);
          }
        }
      }

      // Clean favorite cache
      for (const [peerID, messages] of this.favoriteCache) {
        const validMessages = messages.filter(msg => !this.isMessageExpired(msg));
        if (validMessages.length !== messages.length) {
          cleanedCount += messages.length - validMessages.length;
          if (validMessages.length === 0) {
            this.favoriteCache.delete(peerID);
          } else {
            this.favoriteCache.set(peerID, validMessages);
          }
        }
      }

      if (cleanedCount > 0) {
        console.log(`[KRTR Store&Forward] Cleaned up ${cleanedCount} expired messages`);
        await this.saveCachedMessages();
      }
    } catch (error) {
      console.error('[KRTR Store&Forward] Cleanup error:', error);
    }
  }

  // Public API
  getCachedMessageCount(peerID) {
    const regular = this.messageCache.get(peerID)?.length || 0;
    const favorite = this.favoriteCache.get(peerID)?.length || 0;
    return { regular, favorite, total: regular + favorite };
  }

  getTotalCachedMessages() {
    let total = 0;
    for (const messages of this.messageCache.values()) {
      total += messages.length;
    }
    for (const messages of this.favoriteCache.values()) {
      total += messages.length;
    }
    return total;
  }

  async clearCache(peerID = null) {
    if (peerID) {
      // Clear cache for specific peer
      this.messageCache.delete(peerID);
      this.favoriteCache.delete(peerID);
    } else {
      // Clear all caches
      this.messageCache.clear();
      this.favoriteCache.clear();
    }

    await this.saveCachedMessages();
    console.log(`[KRTR Store&Forward] Cleared cache${peerID ? ` for ${peerID}` : ''}`);
  }

  getStats() {
    return {
      regularCacheSize: this.messageCache.size,
      favoriteCacheSize: this.favoriteCache.size,
      totalCachedMessages: this.getTotalCachedMessages(),
      cacheLimit: {
        regular: this.regularCacheLimit,
        favorite: this.favoriteCacheLimit
      },
      ttl: {
        regular: this.regularTTL,
        favorite: this.favoriteTTL
      }
    };
  }
}
