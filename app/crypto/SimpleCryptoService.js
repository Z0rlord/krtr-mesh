/**
 * KRTR Simple Crypto Service - Expo-compatible encryption implementation
 * Uses expo-crypto and Web Crypto API for cross-platform compatibility
 */

import * as Crypto from 'expo-crypto';
import AsyncStorage from '@react-native-async-storage/async-storage';

export class SimpleCryptoService {
  constructor() {
    // Simple key pairs using random bytes
    this.keyPair = null;
    this.identityKeyPair = null;
    
    // Peer storage
    this.peerPublicKeys = new Map();
    this.sharedSecrets = new Map();
    
    this.initialize();
  }

  async initialize() {
    try {
      // Generate ephemeral keys for this session
      await this.generateEphemeralKeys();
      
      // Load or create persistent identity key
      await this.loadOrCreateIdentityKey();
      
      console.log('[KRTR Crypto] Simple crypto service initialized');
    } catch (error) {
      console.error('[KRTR Crypto] Initialization error:', error);
      throw error;
    }
  }

  async generateEphemeralKeys() {
    try {
      // Generate 32-byte keys using expo-crypto
      const privateKey = await Crypto.getRandomBytesAsync(32);
      const publicKey = await Crypto.digestStringAsync(
        Crypto.CryptoDigestAlgorithm.SHA256,
        privateKey.toString(),
        { encoding: Crypto.CryptoEncoding.HEX }
      );
      
      this.keyPair = {
        publicKey: Buffer.from(publicKey, 'hex'),
        privateKey: Buffer.from(privateKey)
      };
      
      console.log('[KRTR Crypto] Generated ephemeral keys');
    } catch (error) {
      console.error('[KRTR Crypto] Key generation error:', error);
      throw error;
    }
  }

  async loadOrCreateIdentityKey() {
    try {
      const keyData = await AsyncStorage.getItem('krtr_identity_key');
      
      if (keyData) {
        const parsed = JSON.parse(keyData);
        this.identityKeyPair = {
          publicKey: Buffer.from(parsed.publicKey, 'base64'),
          privateKey: Buffer.from(parsed.privateKey, 'base64'),
        };
        console.log('[KRTR Crypto] Loaded existing identity key');
      } else {
        // Create new identity key
        const privateKey = await Crypto.getRandomBytesAsync(32);
        const publicKey = await Crypto.digestStringAsync(
          Crypto.CryptoDigestAlgorithm.SHA256,
          privateKey.toString(),
          { encoding: Crypto.CryptoEncoding.HEX }
        );
        
        this.identityKeyPair = {
          publicKey: Buffer.from(publicKey, 'hex'),
          privateKey: Buffer.from(privateKey)
        };
        
        // Save to storage
        const keyData = {
          publicKey: this.identityKeyPair.publicKey.toString('base64'),
          privateKey: this.identityKeyPair.privateKey.toString('base64'),
        };
        
        await AsyncStorage.setItem('krtr_identity_key', JSON.stringify(keyData));
        console.log('[KRTR Crypto] Created new identity key');
      }
    } catch (error) {
      console.error('[KRTR Crypto] Identity key error:', error);
      throw error;
    }
  }

  generateShortID() {
    // Create short ID from public key hash
    const hash = this.keyPair.publicKey.toString('hex');
    return hash.substring(0, 8);
  }

  getCombinedPublicKeyData() {
    // Return combined public key data
    return {
      encryptionKey: this.keyPair.publicKey,
      signingKey: this.keyPair.publicKey, // Simplified: same key for both
      identityKey: this.identityKeyPair.publicKey,
    };
  }

  async addPeer(peerID, publicKeyData) {
    try {
      const { encryptionKey, signingKey, identityKey } = publicKeyData;
      
      // Store peer keys
      this.peerPublicKeys.set(peerID, encryptionKey);
      
      // Generate simple shared secret using XOR (simplified)
      const sharedSecret = Buffer.alloc(32);
      for (let i = 0; i < 32; i++) {
        sharedSecret[i] = this.keyPair.privateKey[i] ^ encryptionKey[i % encryptionKey.length];
      }
      this.sharedSecrets.set(peerID, sharedSecret);
      
      console.log(`[KRTR Crypto] Added peer: ${peerID}`);
    } catch (error) {
      console.error('[KRTR Crypto] Add peer error:', error);
      throw error;
    }
  }

  async encrypt(data, peerID) {
    try {
      const sharedSecret = this.sharedSecrets.get(peerID);
      if (!sharedSecret) {
        throw new Error(`No shared secret for peer: ${peerID}`);
      }

      // Simple XOR encryption (for demo purposes)
      const encrypted = Buffer.alloc(data.length);
      for (let i = 0; i < data.length; i++) {
        encrypted[i] = data[i] ^ sharedSecret[i % sharedSecret.length];
      }

      // Add random nonce
      const nonce = await Crypto.getRandomBytesAsync(16);
      const result = Buffer.concat([Buffer.from(nonce), encrypted]);
      
      return result;
    } catch (error) {
      console.error('[KRTR Crypto] Encryption error:', error);
      throw error;
    }
  }

  async decrypt(encryptedData, peerID) {
    try {
      const sharedSecret = this.sharedSecrets.get(peerID);
      if (!sharedSecret) {
        throw new Error(`No shared secret for peer: ${peerID}`);
      }

      if (encryptedData.length < 16) {
        throw new Error('Encrypted data too short');
      }

      // Extract nonce and ciphertext
      const nonce = encryptedData.slice(0, 16);
      const ciphertext = encryptedData.slice(16);

      // Simple XOR decryption
      const decrypted = Buffer.alloc(ciphertext.length);
      for (let i = 0; i < ciphertext.length; i++) {
        decrypted[i] = ciphertext[i] ^ sharedSecret[i % sharedSecret.length];
      }

      return decrypted;
    } catch (error) {
      console.error('[KRTR Crypto] Decryption error:', error);
      throw error;
    }
  }

  async sign(data) {
    try {
      // Simple signature using hash
      const signature = await Crypto.digestStringAsync(
        Crypto.CryptoDigestAlgorithm.SHA256,
        data.toString() + this.keyPair.privateKey.toString(),
        { encoding: Crypto.CryptoEncoding.HEX }
      );
      return Buffer.from(signature, 'hex');
    } catch (error) {
      console.error('[KRTR Crypto] Signing error:', error);
      throw error;
    }
  }

  async verify(signature, data, peerID) {
    try {
      const peerPublicKey = this.peerPublicKeys.get(peerID);
      if (!peerPublicKey) {
        throw new Error(`No public key for peer: ${peerID}`);
      }

      // Simple verification using hash
      const expectedSignature = await Crypto.digestStringAsync(
        Crypto.CryptoDigestAlgorithm.SHA256,
        data.toString() + peerPublicKey.toString(),
        { encoding: Crypto.CryptoEncoding.HEX }
      );
      
      return signature.toString('hex') === expectedSignature;
    } catch (error) {
      console.error('[KRTR Crypto] Verification error:', error);
      return false;
    }
  }

  // Channel encryption using password-derived keys
  async encryptChannelMessage(message, channelName, password) {
    try {
      // Simple key derivation
      const keyMaterial = channelName + password;
      const key = await Crypto.digestStringAsync(
        Crypto.CryptoDigestAlgorithm.SHA256,
        keyMaterial,
        { encoding: Crypto.CryptoEncoding.HEX }
      );
      
      // Simple XOR encryption
      const messageBuffer = Buffer.from(message, 'utf8');
      const keyBuffer = Buffer.from(key, 'hex');
      const encrypted = Buffer.alloc(messageBuffer.length);
      
      for (let i = 0; i < messageBuffer.length; i++) {
        encrypted[i] = messageBuffer[i] ^ keyBuffer[i % keyBuffer.length];
      }

      // Add nonce
      const nonce = await Crypto.getRandomBytesAsync(16);
      return Buffer.concat([Buffer.from(nonce), encrypted]);
    } catch (error) {
      console.error('[KRTR Crypto] Channel encryption error:', error);
      throw error;
    }
  }

  async decryptChannelMessage(encryptedData, channelName, password) {
    try {
      if (encryptedData.length < 16) {
        throw new Error('Encrypted data too short');
      }

      // Extract nonce and ciphertext
      const nonce = encryptedData.slice(0, 16);
      const ciphertext = encryptedData.slice(16);

      // Simple key derivation
      const keyMaterial = channelName + password;
      const key = await Crypto.digestStringAsync(
        Crypto.CryptoDigestAlgorithm.SHA256,
        keyMaterial,
        { encoding: Crypto.CryptoEncoding.HEX }
      );
      
      // Simple XOR decryption
      const keyBuffer = Buffer.from(key, 'hex');
      const decrypted = Buffer.alloc(ciphertext.length);
      
      for (let i = 0; i < ciphertext.length; i++) {
        decrypted[i] = ciphertext[i] ^ keyBuffer[i % keyBuffer.length];
      }

      return decrypted.toString('utf8');
    } catch (error) {
      console.error('[KRTR Crypto] Channel decryption error:', error);
      throw error;
    }
  }

  getIdentityFingerprint() {
    if (!this.identityKeyPair?.publicKey) return null;
    
    // Create fingerprint from identity key
    const hash = this.identityKeyPair.publicKey.toString('hex');
    return hash.substring(0, 16);
  }

  async clearPersistentIdentity() {
    try {
      await AsyncStorage.removeItem('krtr_identity_key');
      this.identityKeyPair = null;
      console.log('[KRTR Crypto] Cleared persistent identity');
    } catch (error) {
      console.error('[KRTR Crypto] Clear identity error:', error);
      throw error;
    }
  }
}

// Export singleton instance
export const encryptionService = new SimpleCryptoService();
