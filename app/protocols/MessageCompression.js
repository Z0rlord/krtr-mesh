/**
 * KRTR Message Compression - LZ4 compression for bandwidth optimization
 * Intelligent compression with entropy detection and adaptive thresholds
 */

import LZ4 from 'lz4js';
import { Buffer } from 'buffer';

export class MessageCompression {
  constructor() {
    // Compression settings
    this.compressionThreshold = 100; // bytes
    this.maxCompressionRatio = 0.9; // Don't compress if ratio > 90%

    // Statistics
    this.stats = {
      messagesCompressed: 0,
      messagesDecompressed: 0,
      bytesBeforeCompression: 0,
      bytesAfterCompression: 0,
      compressionErrors: 0,
      decompressionErrors: 0,
    };
  }

  /**
   * Compress message data if beneficial
   * @param {Buffer} data - Data to compress
   * @param {number} threshold - Minimum size to attempt compression
   * @returns {Object} - {data: Buffer, compressed: boolean}
   */
  compress(data, threshold = null) {
    const compressionThreshold = threshold || this.compressionThreshold;

    try {
      // Skip compression for small messages
      if (data.length < compressionThreshold) {
        return { data, compressed: false };
      }

      // Check entropy to avoid compressing already-compressed data
      if (this.hasHighEntropy(data)) {
        return { data, compressed: false };
      }

      // Attempt LZ4 compression
      const compressed = Buffer.from(LZ4.compress(data));

      // Check if compression was beneficial
      const compressionRatio = compressed.length / data.length;
      if (compressionRatio > this.maxCompressionRatio) {
        return { data, compressed: false };
      }

      // Update statistics
      this.stats.messagesCompressed++;
      this.stats.bytesBeforeCompression += data.length;
      this.stats.bytesAfterCompression += compressed.length;

      console.log(
        `[KRTR Compression] Compressed ${data.length} -> ${
          compressed.length
        } bytes (${Math.round((1 - compressionRatio) * 100)}% savings)`
      );

      return { data: compressed, compressed: true };
    } catch (error) {
      console.error('[KRTR Compression] Compression error:', error);
      this.stats.compressionErrors++;
      return { data, compressed: false };
    }
  }

  /**
   * Decompress message data
   * @param {Buffer} data - Compressed data
   * @returns {Buffer} - Decompressed data
   */
  decompress(data) {
    try {
      const decompressed = Buffer.from(LZ4.decompress(data));

      this.stats.messagesDecompressed++;

      console.log(
        `[KRTR Compression] Decompressed ${data.length} -> ${decompressed.length} bytes`
      );

      return decompressed;
    } catch (error) {
      console.error('[KRTR Compression] Decompression error:', error);
      this.stats.decompressionErrors++;
      throw error;
    }
  }

  /**
   * Check if data has high entropy (likely already compressed)
   * @param {Buffer} data - Data to analyze
   * @returns {boolean} - True if high entropy
   */
  hasHighEntropy(data) {
    if (data.length < 64) return false;

    // Sample first 64 bytes for entropy calculation
    const sample = data.slice(0, 64);
    const frequencies = new Array(256).fill(0);

    // Count byte frequencies
    for (let i = 0; i < sample.length; i++) {
      frequencies[sample[i]]++;
    }

    // Calculate Shannon entropy
    let entropy = 0;
    for (let i = 0; i < 256; i++) {
      if (frequencies[i] > 0) {
        const probability = frequencies[i] / sample.length;
        entropy -= probability * Math.log2(probability);
      }
    }

    // High entropy threshold (close to random data)
    return entropy > 7.5; // Out of max 8.0
  }

  /**
   * Get compression statistics
   * @returns {Object} - Compression stats
   */
  getStats() {
    const totalSavings =
      this.stats.bytesBeforeCompression - this.stats.bytesAfterCompression;
    const averageRatio =
      this.stats.bytesBeforeCompression > 0
        ? this.stats.bytesAfterCompression / this.stats.bytesBeforeCompression
        : 0;

    return {
      ...this.stats,
      totalBytesSaved: totalSavings,
      averageCompressionRatio: averageRatio,
      averageSavingsPercent: Math.round((1 - averageRatio) * 100),
    };
  }

  /**
   * Reset statistics
   */
  resetStats() {
    this.stats = {
      messagesCompressed: 0,
      messagesDecompressed: 0,
      bytesBeforeCompression: 0,
      bytesAfterCompression: 0,
      compressionErrors: 0,
      decompressionErrors: 0,
    };
  }

  /**
   * Update compression threshold based on power mode
   * @param {string} powerMode - Current power mode
   */
  updateForPowerMode(powerMode) {
    const thresholds = {
      performance: 100,
      balanced: 100,
      powerSaver: 50,
      ultraLowPower: 50,
    };

    this.compressionThreshold = thresholds[powerMode] || 100;
    console.log(
      `[KRTR Compression] Updated threshold for ${powerMode}: ${this.compressionThreshold} bytes`
    );
  }
}

/**
 * Message fragmentation for large messages
 */
export class MessageFragmentation {
  constructor() {
    this.maxFragmentSize = 500; // bytes (BLE MTU consideration)
    this.fragmentTimeout = 30000; // 30 seconds
    this.activeFragments = new Map(); // fragmentID -> {fragments, timestamp, totalFragments}

    // Statistics
    this.stats = {
      messagesFragmented: 0,
      messagesReassembled: 0,
      fragmentsSent: 0,
      fragmentsReceived: 0,
      timeouts: 0,
      errors: 0,
    };

    this.setupCleanup();
  }

  /**
   * Fragment a large message
   * @param {Buffer} data - Message data to fragment
   * @param {string} messageID - Unique message identifier
   * @returns {Array} - Array of fragment packets
   */
  fragment(data, messageID) {
    try {
      if (data.length <= this.maxFragmentSize) {
        return [{ data, isFragment: false }];
      }

      const fragments = [];
      const totalFragments = Math.ceil(data.length / this.maxFragmentSize);

      for (let i = 0; i < totalFragments; i++) {
        const start = i * this.maxFragmentSize;
        const end = Math.min(start + this.maxFragmentSize, data.length);
        const fragmentData = data.slice(start, end);

        const fragmentHeader = {
          messageID,
          fragmentIndex: i,
          totalFragments,
          isFirst: i === 0,
          isLast: i === totalFragments - 1,
        };

        // Create fragment packet
        const fragmentPacket = this.createFragmentPacket(
          fragmentHeader,
          fragmentData
        );
        fragments.push(fragmentPacket);
      }

      this.stats.messagesFragmented++;
      this.stats.fragmentsSent += fragments.length;

      console.log(
        `[KRTR Fragmentation] Fragmented message ${messageID} into ${totalFragments} fragments`
      );

      return fragments;
    } catch (error) {
      console.error('[KRTR Fragmentation] Fragmentation error:', error);
      this.stats.errors++;
      throw error;
    }
  }

  /**
   * Process incoming fragment
   * @param {Object} fragmentPacket - Fragment packet
   * @returns {Object|null} - Complete message if reassembly finished, null otherwise
   */
  processFragment(fragmentPacket) {
    try {
      const { messageID, fragmentIndex, totalFragments, isFirst, isLast } =
        fragmentPacket.header;
      const fragmentData = fragmentPacket.data;

      this.stats.fragmentsReceived++;

      // Initialize fragment collection if first fragment
      if (isFirst || !this.activeFragments.has(messageID)) {
        this.activeFragments.set(messageID, {
          fragments: new Array(totalFragments),
          receivedCount: 0,
          totalFragments,
          timestamp: Date.now(),
        });
      }

      const fragmentCollection = this.activeFragments.get(messageID);

      // Check if fragment already received
      if (fragmentCollection.fragments[fragmentIndex]) {
        return null; // Duplicate fragment
      }

      // Store fragment
      fragmentCollection.fragments[fragmentIndex] = fragmentData;
      fragmentCollection.receivedCount++;

      // Check if all fragments received
      if (
        fragmentCollection.receivedCount === fragmentCollection.totalFragments
      ) {
        // Reassemble message
        const completeMessage = this.reassembleMessage(
          fragmentCollection.fragments
        );

        // Clean up
        this.activeFragments.delete(messageID);

        this.stats.messagesReassembled++;

        console.log(
          `[KRTR Fragmentation] Reassembled message ${messageID} from ${totalFragments} fragments`
        );

        return {
          messageID,
          data: completeMessage,
          isComplete: true,
        };
      }

      return null; // Still waiting for more fragments
    } catch (error) {
      console.error('[KRTR Fragmentation] Fragment processing error:', error);
      this.stats.errors++;
      return null;
    }
  }

  /**
   * Create fragment packet with header
   * @param {Object} header - Fragment header
   * @param {Buffer} data - Fragment data
   * @returns {Object} - Fragment packet
   */
  createFragmentPacket(header, data) {
    const headerBuffer = Buffer.from(JSON.stringify(header), 'utf8');
    const headerLength = Buffer.alloc(2);
    headerLength.writeUInt16BE(headerBuffer.length);

    return {
      data: Buffer.concat([headerLength, headerBuffer, data]),
      header,
      isFragment: true,
    };
  }

  /**
   * Parse fragment packet
   * @param {Buffer} packetData - Raw packet data
   * @returns {Object} - Parsed fragment packet
   */
  parseFragmentPacket(packetData) {
    try {
      const headerLength = packetData.readUInt16BE(0);
      const headerBuffer = packetData.slice(2, 2 + headerLength);
      const data = packetData.slice(2 + headerLength);

      const header = JSON.parse(headerBuffer.toString('utf8'));

      return { header, data };
    } catch (error) {
      console.error('[KRTR Fragmentation] Parse fragment error:', error);
      throw error;
    }
  }

  /**
   * Reassemble fragments into complete message
   * @param {Array} fragments - Array of fragment buffers
   * @returns {Buffer} - Complete message
   */
  reassembleMessage(fragments) {
    return Buffer.concat(fragments);
  }

  /**
   * Clean up expired fragments
   */
  setupCleanup() {
    setInterval(() => {
      const now = Date.now();
      let cleanedCount = 0;

      for (const [messageID, fragmentCollection] of this.activeFragments) {
        if (now - fragmentCollection.timestamp > this.fragmentTimeout) {
          this.activeFragments.delete(messageID);
          cleanedCount++;
          this.stats.timeouts++;
        }
      }

      if (cleanedCount > 0) {
        console.log(
          `[KRTR Fragmentation] Cleaned up ${cleanedCount} expired fragment collections`
        );
      }
    }, 60000); // Check every minute
  }

  /**
   * Get fragmentation statistics
   * @returns {Object} - Fragmentation stats
   */
  getStats() {
    return {
      ...this.stats,
      activeFragmentCollections: this.activeFragments.size,
      maxFragmentSize: this.maxFragmentSize,
      fragmentTimeout: this.fragmentTimeout,
    };
  }

  /**
   * Update fragment size based on power mode
   * @param {string} powerMode - Current power mode
   */
  updateForPowerMode(powerMode) {
    const fragmentSizes = {
      performance: 500,
      balanced: 500,
      powerSaver: 400,
      ultraLowPower: 300,
    };

    this.maxFragmentSize = fragmentSizes[powerMode] || 500;
    console.log(
      `[KRTR Fragmentation] Updated fragment size for ${powerMode}: ${this.maxFragmentSize} bytes`
    );
  }
}
