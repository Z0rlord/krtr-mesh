/**
 * KRTR Zero-Knowledge Authentication Service
 * Handles anonymous authentication and authorization using ZK proofs
 */

import { ZKAuthChallenge, ZKMembershipProof, ZKReputationProof, MessageType } from '../protocols/KrtrProtocol';
import uuid from 'react-native-uuid';

export class ZKAuthService {
  constructor(zkService, meshService) {
    this.zkService = zkService;
    this.meshService = meshService;
    
    // Active challenges and responses
    this.activeChallenges = new Map(); // challengeId -> challenge
    this.pendingAuths = new Map(); // peerID -> authState
    this.authorizedPeers = new Map(); // peerID -> authInfo
    
    // Group membership configuration
    this.groupRoots = new Map(); // groupName -> merkleRoot
    this.reputationThresholds = new Map(); // groupName -> threshold
    
    // Statistics
    this.stats = {
      challengesSent: 0,
      challengesReceived: 0,
      proofsGenerated: 0,
      proofsVerified: 0,
      authSuccesses: 0,
      authFailures: 0
    };
    
    this.initialize();
  }

  initialize() {
    // Set up default groups
    this.setupDefaultGroups();
    
    // Set up challenge cleanup
    this.setupChallengeCleanup();
    
    console.log('[KRTR ZK Auth] Authentication service initialized');
  }

  setupDefaultGroups() {
    // Default public group (anyone can join)
    this.groupRoots.set('public', '0x1234567890abcdef'); // Placeholder root
    this.reputationThresholds.set('public', 0);
    
    // Trusted group (requires positive reputation)
    this.groupRoots.set('trusted', '0xfedcba0987654321'); // Placeholder root
    this.reputationThresholds.set('trusted', 10);
    
    // VIP group (requires high reputation)
    this.groupRoots.set('vip', '0xabcdef1234567890'); // Placeholder root
    this.reputationThresholds.set('vip', 100);
  }

  setupChallengeCleanup() {
    // Clean up expired challenges every minute
    setInterval(() => {
      this.cleanupExpiredChallenges();
    }, 60 * 1000);
  }

  // Challenge-Response Authentication
  async initiateAuthentication(peerID, groupName = 'public') {
    try {
      const groupRoot = this.groupRoots.get(groupName);
      const reputationThreshold = this.reputationThresholds.get(groupName) || 0;
      
      if (!groupRoot) {
        throw new Error(`Unknown group: ${groupName}`);
      }
      
      // Create authentication challenge
      const challengeId = uuid.v4();
      const challenge = new ZKAuthChallenge(challengeId, groupRoot, reputationThreshold);
      
      // Store challenge
      this.activeChallenges.set(challengeId, challenge);
      this.pendingAuths.set(peerID, {
        challengeId,
        groupName,
        status: 'challenge_sent',
        timestamp: Date.now()
      });
      
      // Send challenge to peer
      await this.sendChallenge(peerID, challenge);
      
      this.stats.challengesSent++;
      
      console.log(`[KRTR ZK Auth] Sent authentication challenge to ${peerID} for group ${groupName}`);
      
      return challengeId;
    } catch (error) {
      console.error('[KRTR ZK Auth] Authentication initiation error:', error);
      throw error;
    }
  }

  async handleAuthChallenge(peerID, challenge) {
    try {
      this.stats.challengesReceived++;
      
      // Check if challenge is valid and not expired
      if (challenge.isExpired()) {
        console.warn('[KRTR ZK Auth] Received expired challenge');
        return;
      }
      
      // Generate appropriate proofs based on challenge requirements
      const proofs = await this.generateAuthProofs(challenge);
      
      // Send response to peer
      await this.sendAuthResponse(peerID, challenge.challengeId, proofs);
      
      console.log(`[KRTR ZK Auth] Sent authentication response to ${peerID}`);
    } catch (error) {
      console.error('[KRTR ZK Auth] Challenge handling error:', error);
      this.stats.authFailures++;
    }
  }

  async generateAuthProofs(challenge) {
    const proofs = {};
    
    try {
      // Generate membership proof
      const membershipProof = await this.zkService.generateMembershipProof(
        challenge.groupRoot,
        challenge.challengeId
      );
      proofs.membership = membershipProof;
      
      // Generate reputation proof if required
      if (challenge.requiredReputation > 0) {
        const canProveReputation = await this.zkService.canProveReputation(challenge.requiredReputation);
        
        if (canProveReputation) {
          const reputationProof = await this.zkService.generateReputationProof(challenge.requiredReputation);
          proofs.reputation = reputationProof;
        } else {
          throw new Error(`Insufficient reputation: required ${challenge.requiredReputation}`);
        }
      }
      
      this.stats.proofsGenerated++;
      
      return proofs;
    } catch (error) {
      console.error('[KRTR ZK Auth] Proof generation error:', error);
      throw error;
    }
  }

  async handleAuthResponse(peerID, challengeId, proofs) {
    try {
      const challenge = this.activeChallenges.get(challengeId);
      const authState = this.pendingAuths.get(peerID);
      
      if (!challenge || !authState) {
        console.warn('[KRTR ZK Auth] Invalid authentication response');
        return false;
      }
      
      // Verify membership proof
      let membershipValid = false;
      if (proofs.membership) {
        membershipValid = await this.zkService.verifyMembershipProof(
          proofs.membership.proof,
          proofs.membership.publicSignals
        );
      }
      
      // Verify reputation proof if required
      let reputationValid = true;
      if (challenge.requiredReputation > 0 && proofs.reputation) {
        reputationValid = await this.zkService.verifyReputationProof(
          proofs.reputation.proof,
          proofs.reputation.publicSignals
        );
      } else if (challenge.requiredReputation > 0) {
        reputationValid = false; // Required but not provided
      }
      
      const authSuccess = membershipValid && reputationValid;
      
      if (authSuccess) {
        // Store authorization
        this.authorizedPeers.set(peerID, {
          groupName: authState.groupName,
          membershipProof: proofs.membership,
          reputationProof: proofs.reputation,
          authorizedAt: Date.now(),
          nullifierHash: proofs.membership?.nullifierHash
        });
        
        this.stats.authSuccesses++;
        console.log(`[KRTR ZK Auth] Successfully authenticated ${peerID} for group ${authState.groupName}`);
      } else {
        this.stats.authFailures++;
        console.warn(`[KRTR ZK Auth] Authentication failed for ${peerID}`);
      }
      
      // Cleanup
      this.activeChallenges.delete(challengeId);
      this.pendingAuths.delete(peerID);
      
      this.stats.proofsVerified++;
      
      return authSuccess;
    } catch (error) {
      console.error('[KRTR ZK Auth] Response handling error:', error);
      this.stats.authFailures++;
      return false;
    }
  }

  // Message sending with ZK authentication
  async sendChallenge(peerID, challenge) {
    const packet = {
      type: MessageType.ZK_AUTH_CHALLENGE,
      senderID: this.meshService.encryptionService.getShortID(),
      recipientID: peerID,
      payload: challenge.encode()
    };
    
    await this.meshService.sendPacketToPeer(peerID, packet);
  }

  async sendAuthResponse(peerID, challengeId, proofs) {
    const response = {
      challengeId,
      proofs,
      timestamp: Date.now()
    };
    
    const packet = {
      type: MessageType.ZK_AUTH_RESPONSE,
      senderID: this.meshService.encryptionService.getShortID(),
      recipientID: peerID,
      payload: Buffer.from(JSON.stringify(response), 'utf8')
    };
    
    await this.meshService.sendPacketToPeer(peerID, packet);
  }

  // Authorization checking
  isPeerAuthorized(peerID, groupName = 'public') {
    const authInfo = this.authorizedPeers.get(peerID);
    return authInfo && authInfo.groupName === groupName;
  }

  getPeerAuthInfo(peerID) {
    return this.authorizedPeers.get(peerID);
  }

  getAuthorizedPeers(groupName = null) {
    if (!groupName) {
      return Array.from(this.authorizedPeers.keys());
    }
    
    return Array.from(this.authorizedPeers.entries())
      .filter(([_, authInfo]) => authInfo.groupName === groupName)
      .map(([peerID, _]) => peerID);
  }

  // Group management
  addGroup(groupName, merkleRoot, reputationThreshold = 0) {
    this.groupRoots.set(groupName, merkleRoot);
    this.reputationThresholds.set(groupName, reputationThreshold);
    
    console.log(`[KRTR ZK Auth] Added group: ${groupName} (reputation: ${reputationThreshold})`);
  }

  removeGroup(groupName) {
    this.groupRoots.delete(groupName);
    this.reputationThresholds.delete(groupName);
    
    // Remove authorizations for this group
    for (const [peerID, authInfo] of this.authorizedPeers) {
      if (authInfo.groupName === groupName) {
        this.authorizedPeers.delete(peerID);
      }
    }
    
    console.log(`[KRTR ZK Auth] Removed group: ${groupName}`);
  }

  getGroups() {
    return Array.from(this.groupRoots.keys()).map(groupName => ({
      name: groupName,
      root: this.groupRoots.get(groupName),
      reputationThreshold: this.reputationThresholds.get(groupName),
      authorizedPeers: this.getAuthorizedPeers(groupName).length
    }));
  }

  // Cleanup
  cleanupExpiredChallenges() {
    let cleanedCount = 0;
    
    for (const [challengeId, challenge] of this.activeChallenges) {
      if (challenge.isExpired()) {
        this.activeChallenges.delete(challengeId);
        cleanedCount++;
      }
    }
    
    // Clean up stale pending auths (older than 10 minutes)
    const staleThreshold = Date.now() - (10 * 60 * 1000);
    for (const [peerID, authState] of this.pendingAuths) {
      if (authState.timestamp < staleThreshold) {
        this.pendingAuths.delete(peerID);
        cleanedCount++;
      }
    }
    
    if (cleanedCount > 0) {
      console.log(`[KRTR ZK Auth] Cleaned up ${cleanedCount} expired challenges/auths`);
    }
  }

  // Statistics and monitoring
  getStats() {
    return {
      ...this.stats,
      activeChallenges: this.activeChallenges.size,
      pendingAuths: this.pendingAuths.size,
      authorizedPeers: this.authorizedPeers.size,
      groups: this.groupRoots.size,
      successRate: this.stats.challengesSent > 0 ? 
        (this.stats.authSuccesses / this.stats.challengesSent * 100).toFixed(1) + '%' : '0%'
    };
  }

  // Emergency cleanup
  async emergencyWipe() {
    this.activeChallenges.clear();
    this.pendingAuths.clear();
    this.authorizedPeers.clear();
    
    // Reset stats
    this.stats = {
      challengesSent: 0,
      challengesReceived: 0,
      proofsGenerated: 0,
      proofsVerified: 0,
      authSuccesses: 0,
      authFailures: 0
    };
    
    console.log('[KRTR ZK Auth] Emergency wipe completed');
  }
}
