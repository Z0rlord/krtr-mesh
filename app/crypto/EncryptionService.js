/**
 * KRTR Encryption Service - End-to-end encryption implementation
 * Implements X25519 key exchange, AES-256-GCM encryption, and Ed25519 signatures
 */

import { NativeModules } from 'react-native';
import { Buffer } from 'buffer';
import AsyncStorage from '@react-native-async-storage/async-storage';
import * as Crypto from 'expo-crypto';

export class EncryptionService {
  constructor() {
    // Ephemeral keys for this session (regenerated each app start)
    this.keyPair = null; // X25519 key agreement
    this.signingKeyPair = null; // Ed25519 signing

    // Persistent identity key (for favorites)
    this.identityKeyPair = null; // Ed25519 identity

    // Peer key storage
    this.peerPublicKeys = new Map(); // peerID -> X25519 public key
    this.peerSigningKeys = new Map(); // peerID -> Ed25519 signing key
    this.peerIdentityKeys = new Map(); // peerID -> Ed25519 identity key
    this.sharedSecrets = new Map(); // peerID -> shared secret

    // Short ID for this device
    this.shortID = null;

    this.initialize();
  }

  async initialize() {
    try {
      // Initialize libsodium
      await Sodium.sodium_ready;

      // Generate ephemeral key pairs for this session
      await this.generateEphemeralKeys();

      // Load or create persistent identity key
      await this.loadOrCreateIdentityKey();

      // Generate short ID from public key
      this.shortID = this.generateShortID();

      console.log(
        `[KRTR Crypto] Encryption service initialized (ID: ${this.shortID})`
      );
    } catch (error) {
      console.error('[KRTR Crypto] Initialization error:', error);
      throw error;
    }
  }

  async generateEphemeralKeys() {
    try {
      // Generate X25519 key pair for key agreement
      this.keyPair = Sodium.crypto_box_keypair();

      // Generate Ed25519 key pair for signing
      this.signingKeyPair = Sodium.crypto_sign_keypair();

      console.log('[KRTR Crypto] Generated ephemeral keys');
    } catch (error) {
      console.error('[KRTR Crypto] Ephemeral key generation error:', error);
      throw error;
    }
  }

  async loadOrCreateIdentityKey() {
    try {
      // Try to load existing identity key
      const identityKeyData = await AsyncStorage.getItem('krtr_identity_key');

      if (identityKeyData) {
        // Load existing identity key
        const keyData = JSON.parse(identityKeyData);
        this.identityKeyPair = {
          publicKey: Buffer.from(keyData.publicKey, 'base64'),
          privateKey: Buffer.from(keyData.privateKey, 'base64'),
        };
        console.log('[KRTR Crypto] Loaded existing identity key');
      } else {
        // Create new identity key
        this.identityKeyPair = Sodium.crypto_sign_keypair();

        // Save to storage
        const keyData = {
          publicKey: this.identityKeyPair.publicKey.toString('base64'),
          privateKey: this.identityKeyPair.privateKey.toString('base64'),
        };
        await AsyncStorage.setItem(
          'krtr_identity_key',
          JSON.stringify(keyData)
        );

        console.log('[KRTR Crypto] Created new identity key');
      }
    } catch (error) {
      console.error('[KRTR Crypto] Identity key error:', error);
      throw error;
    }
  }

  generateShortID() {
    // Create short ID from public key hash
    const hash = Sodium.crypto_generichash(8, this.keyPair.publicKey);
    return hash.toString('hex').substring(0, 8);
  }

  getCombinedPublicKeyData() {
    // Combine all three public keys: encryption + signing + identity
    const combined = Buffer.alloc(96); // 32 + 32 + 32 bytes

    this.keyPair.publicKey.copy(combined, 0); // X25519 encryption key
    this.signingKeyPair.publicKey.copy(combined, 32); // Ed25519 signing key
    this.identityKeyPair.publicKey.copy(combined, 64); // Ed25519 identity key

    return combined;
  }

  async addPeerPublicKey(peerID, combinedKeyData) {
    try {
      if (combinedKeyData.length !== 96) {
        throw new Error(
          `Invalid key data size: ${combinedKeyData.length}, expected 96`
        );
      }

      // Extract the three keys
      const encryptionKey = combinedKeyData.slice(0, 32);
      const signingKey = combinedKeyData.slice(32, 64);
      const identityKey = combinedKeyData.slice(64, 96);

      // Store peer keys
      this.peerPublicKeys.set(peerID, encryptionKey);
      this.peerSigningKeys.set(peerID, signingKey);
      this.peerIdentityKeys.set(peerID, identityKey);

      // Generate shared secret for encryption
      const sharedSecret = Sodium.crypto_box_beforenm(
        encryptionKey,
        this.keyPair.privateKey
      );
      this.sharedSecrets.set(peerID, sharedSecret);

      console.log(`[KRTR Crypto] Added public keys for peer: ${peerID}`);
    } catch (error) {
      console.error(`[KRTR Crypto] Add peer key error for ${peerID}:`, error);
      throw error;
    }
  }

  async encrypt(data, peerID) {
    try {
      const sharedSecret = this.sharedSecrets.get(peerID);
      if (!sharedSecret) {
        throw new Error(`No shared secret for peer: ${peerID}`);
      }

      // Generate random nonce
      const nonce = Sodium.randombytes_buf(Sodium.crypto_box_NONCEBYTES);

      // Encrypt using shared secret
      const ciphertext = Sodium.crypto_box_easy_afternm(
        data,
        nonce,
        sharedSecret
      );

      // Combine nonce + ciphertext
      const encrypted = Buffer.alloc(nonce.length + ciphertext.length);
      nonce.copy(encrypted, 0);
      ciphertext.copy(encrypted, nonce.length);

      return encrypted;
    } catch (error) {
      console.error(`[KRTR Crypto] Encryption error for ${peerID}:`, error);
      throw error;
    }
  }

  async decrypt(encryptedData, peerID) {
    try {
      const sharedSecret = this.sharedSecrets.get(peerID);
      if (!sharedSecret) {
        throw new Error(`No shared secret for peer: ${peerID}`);
      }

      if (encryptedData.length < Sodium.crypto_box_NONCEBYTES) {
        throw new Error('Encrypted data too short');
      }

      // Extract nonce and ciphertext
      const nonce = encryptedData.slice(0, Sodium.crypto_box_NONCEBYTES);
      const ciphertext = encryptedData.slice(Sodium.crypto_box_NONCEBYTES);

      // Decrypt using shared secret
      const decrypted = Sodium.crypto_box_open_easy_afternm(
        ciphertext,
        nonce,
        sharedSecret
      );

      return decrypted;
    } catch (error) {
      console.error(`[KRTR Crypto] Decryption error for ${peerID}:`, error);
      throw error;
    }
  }

  async sign(data) {
    try {
      // Sign with ephemeral signing key
      const signature = Sodium.crypto_sign_detached(
        data,
        this.signingKeyPair.privateKey
      );
      return signature;
    } catch (error) {
      console.error('[KRTR Crypto] Signing error:', error);
      throw error;
    }
  }

  async verify(signature, data, peerID) {
    try {
      const peerSigningKey = this.peerSigningKeys.get(peerID);
      if (!peerSigningKey) {
        throw new Error(`No signing key for peer: ${peerID}`);
      }

      // Verify signature
      return Sodium.crypto_sign_verify_detached(
        signature,
        data,
        peerSigningKey
      );
    } catch (error) {
      console.error(`[KRTR Crypto] Verification error for ${peerID}:`, error);
      return false;
    }
  }

  // Channel encryption using password-derived keys
  async encryptChannelMessage(message, channelName, password) {
    try {
      // Derive key from password using Argon2id
      const salt = Sodium.crypto_generichash(
        32,
        Buffer.from(channelName, 'utf8')
      );
      const key = await this.deriveChannelKey(password, salt);

      // Generate random nonce
      const nonce = Sodium.randombytes_buf(Sodium.crypto_secretbox_NONCEBYTES);

      // Encrypt message
      const ciphertext = Sodium.crypto_secretbox_easy(
        Buffer.from(message, 'utf8'),
        nonce,
        key
      );

      // Combine nonce + ciphertext
      const encrypted = Buffer.alloc(nonce.length + ciphertext.length);
      nonce.copy(encrypted, 0);
      ciphertext.copy(encrypted, nonce.length);

      return encrypted;
    } catch (error) {
      console.error('[KRTR Crypto] Channel encryption error:', error);
      throw error;
    }
  }

  async decryptChannelMessage(encryptedData, channelName, password) {
    try {
      // Derive key from password
      const salt = Sodium.crypto_generichash(
        32,
        Buffer.from(channelName, 'utf8')
      );
      const key = await this.deriveChannelKey(password, salt);

      if (encryptedData.length < Sodium.crypto_secretbox_NONCEBYTES) {
        throw new Error('Encrypted data too short');
      }

      // Extract nonce and ciphertext
      const nonce = encryptedData.slice(0, Sodium.crypto_secretbox_NONCEBYTES);
      const ciphertext = encryptedData.slice(
        Sodium.crypto_secretbox_NONCEBYTES
      );

      // Decrypt message
      const decrypted = Sodium.crypto_secretbox_open_easy(
        ciphertext,
        nonce,
        key
      );

      return decrypted.toString('utf8');
    } catch (error) {
      console.error('[KRTR Crypto] Channel decryption error:', error);
      throw error;
    }
  }

  async deriveChannelKey(password, salt) {
    try {
      // Use Argon2id for secure key derivation
      const key = Sodium.crypto_pwhash(
        32, // 32 bytes output
        Buffer.from(password, 'utf8'), // password
        salt, // salt
        Sodium.crypto_pwhash_OPSLIMIT_INTERACTIVE, // operations limit
        Sodium.crypto_pwhash_MEMLIMIT_INTERACTIVE, // memory limit
        Sodium.crypto_pwhash_ALG_ARGON2ID // algorithm
      );

      return key;
    } catch (error) {
      console.error('[KRTR Crypto] Key derivation error:', error);
      throw error;
    }
  }

  // Identity management
  getPeerIdentityKey(peerID) {
    return this.peerIdentityKeys.get(peerID);
  }

  getIdentityFingerprint(peerID = null) {
    const publicKey = peerID
      ? this.peerIdentityKeys.get(peerID)
      : this.identityKeyPair.publicKey;

    if (!publicKey) return null;

    // Create fingerprint from identity key
    const hash = Sodium.crypto_generichash(16, publicKey);
    return hash.toString('hex');
  }

  async clearPersistentIdentity() {
    try {
      await AsyncStorage.removeItem('krtr_identity_key');
      this.identityKeyPair = null;
      console.log('[KRTR Crypto] Cleared persistent identity');
    } catch (error) {
      console.error('[KRTR Crypto] Clear identity error:', error);
    }
  }

  // Public API
  getShortID() {
    return this.shortID;
  }

  getPublicKey() {
    return this.keyPair.publicKey;
  }

  getSigningPublicKey() {
    return this.signingKeyPair.publicKey;
  }

  getIdentityPublicKey() {
    return this.identityKeyPair.publicKey;
  }

  hasPeerKeys(peerID) {
    return this.sharedSecrets.has(peerID);
  }

  getConnectedPeerCount() {
    return this.sharedSecrets.size;
  }

  // Emergency wipe
  async emergencyWipe() {
    try {
      // Clear all in-memory keys
      this.peerPublicKeys.clear();
      this.peerSigningKeys.clear();
      this.peerIdentityKeys.clear();
      this.sharedSecrets.clear();

      // Clear persistent identity
      await this.clearPersistentIdentity();

      // Regenerate ephemeral keys
      await this.generateEphemeralKeys();
      this.shortID = this.generateShortID();

      console.log('[KRTR Crypto] Emergency wipe completed');
    } catch (error) {
      console.error('[KRTR Crypto] Emergency wipe error:', error);
    }
  }

  getStats() {
    return {
      shortID: this.shortID,
      connectedPeers: this.sharedSecrets.size,
      hasIdentityKey: !!this.identityKeyPair,
      keyPairGenerated: !!this.keyPair,
    };
  }
}
