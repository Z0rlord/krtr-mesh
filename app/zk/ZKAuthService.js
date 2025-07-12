/**
 * KRTR Zero-Knowledge Authentication Service
 * Handles anonymous authentication and authorization using ZK proofs
 */

import uuid from 'react-native-uuid';
import {
  ZKAuthChallenge,
  ZKMembershipProof,
  ZKReputationProof,
  MessageType,
} from '../protocols/KrtrProtocol';

export class ZKAuthService {
  constructor(zkService, meshService) {
    this.zkService = zkService;
    this.meshService = meshService;

    // Authentication state
    this.activeChallenges = new Map(); // challengeId -> challenge
    this.pendingAuths = new Map(); // peerID -> challengeId
    this.authorizedPeers = new Map(); // peerID -> { groups: Set, timestamp }

    // Group configurations
    this.groupRoots = new Map([
      ['public', 'public-group-root-hash'],
      ['trusted', 'trusted-group-root-hash'],
      ['admin', 'admin-group-root-hash'],
    ]);

    this.reputationThresholds = new Map([
      ['public', 0],
      ['trusted', 50],
      ['admin', 100],
    ]);

    // Statistics
    this.stats = {
      challengesSent: 0,
      challengesReceived: 0,
      authSuccesses: 0,
      authFailures: 0,
    };

    // Setup message handlers
    this.setupMessageHandlers();
  }

  setupMessageHandlers() {
    this.meshService.on(MessageType.ZK_AUTH_CHALLENGE, (peerID, challenge) => {
      this.handleAuthChallenge(peerID, challenge);
    });

    this.meshService.on(MessageType.ZK_AUTH_RESPONSE, (peerID, response) => {
      this.handleAuthResponse(peerID, response.challengeId, response.proofs);
    });
  }

  // Group management
  addGroup(name, rootHash, reputationThreshold = 0) {
    this.groupRoots.set(name, rootHash);
    this.reputationThresholds.set(name, reputationThreshold);
  }

  removeGroup(name) {
    if (['public', 'trusted', 'admin'].includes(name)) {
      throw new Error(`Cannot remove default group: ${name}`);
    }
    this.groupRoots.delete(name);
    this.reputationThresholds.delete(name);
  }

  getGroups() {
    return Array.from(this.groupRoots.keys());
  }

  // Authentication initiation
  async initiateAuthentication(peerID, groupName, timeout = 30000) {
    if (!this.groupRoots.has(groupName)) {
      throw new Error(`Unknown group: ${groupName}`);
    }

    const challengeId = uuid.v4();
    const groupRoot = this.groupRoots.get(groupName);
    const reputationThreshold = this.reputationThresholds.get(groupName);

    const challenge = new ZKAuthChallenge(
      challengeId,
      groupRoot,
      reputationThreshold
    );

    // Store challenge and set timeout
    this.activeChallenges.set(challengeId, challenge);
    this.pendingAuths.set(peerID, challengeId);

    setTimeout(() => {
      if (this.activeChallenges.has(challengeId)) {
        this.activeChallenges.delete(challengeId);
        this.pendingAuths.delete(peerID);
        this.stats.authFailures++;
      }
    }, timeout);

    // Send challenge to peer
    await this.meshService.sendMessage(
      peerID,
      MessageType.ZK_AUTH_CHALLENGE,
      challenge
    );
    this.stats.challengesSent++;

    return challengeId;
  }

  // Challenge handling
  async handleAuthChallenge(peerID, challenge) {
    this.stats.challengesReceived++;

    if (challenge.isExpired()) {
      return; // Ignore expired challenges
    }

    try {
      // Check if we can provide the required proofs
      const canProveMembership = await this.zkService.canProveMembership(
        challenge.groupRoot
      );
      const canProveReputation = await this.zkService.canProveReputation(
        challenge.reputationThreshold
      );

      if (!canProveMembership || !canProveReputation) {
        return; // Cannot satisfy challenge requirements
      }

      // Generate proofs
      const membershipProof = await this.zkService.generateMembershipProof(
        challenge.groupRoot
      );

      const reputationProof = await this.zkService.generateReputationProof(
        challenge.reputationThreshold
      );

      const response = {
        challengeId: challenge.challengeId,
        proofs: {
          membership: membershipProof,
          reputation: reputationProof,
        },
      };

      await this.meshService.sendMessage(
        peerID,
        MessageType.ZK_AUTH_RESPONSE,
        response
      );
    } catch (error) {
      console.error('Failed to handle auth challenge:', error);
    }
  }

  // Response handling
  async handleAuthResponse(peerID, challengeId, proofs) {
    const challenge = this.activeChallenges.get(challengeId);
    if (!challenge || challenge.isExpired()) {
      this.stats.authFailures++;
      return false;
    }

    try {
      // Verify membership proof
      const membershipValid = await this.zkService.verifyMembershipProof(
        proofs.membership.proof,
        proofs.membership.publicInputs,
        challenge.groupRoot
      );

      // Verify reputation proof
      const reputationValid = await this.zkService.verifyReputationProof(
        proofs.reputation.proof,
        proofs.reputation.publicInputs,
        challenge.reputationThreshold
      );

      if (membershipValid && reputationValid) {
        // Authentication successful
        const groupName = this.getGroupNameByRoot(challenge.groupRoot);
        this.authorizePeer(peerID, groupName);

        this.activeChallenges.delete(challengeId);
        this.pendingAuths.delete(peerID);
        this.stats.authSuccesses++;

        return true;
      } else {
        this.stats.authFailures++;
        return false;
      }
    } catch (error) {
      console.error('Failed to verify auth response:', error);
      this.stats.authFailures++;
      return false;
    }
  }

  // Authorization management
  authorizePeer(peerID, groupName) {
    if (!this.authorizedPeers.has(peerID)) {
      this.authorizedPeers.set(peerID, {
        groups: new Set(),
        timestamp: Date.now(),
      });
    }

    this.authorizedPeers.get(peerID).groups.add(groupName);
  }

  revokePeerAuthorization(peerID, groupName = null) {
    if (!this.authorizedPeers.has(peerID)) return;

    if (groupName) {
      this.authorizedPeers.get(peerID).groups.delete(groupName);
    } else {
      this.authorizedPeers.delete(peerID);
    }
  }

  isPeerAuthorized(peerID, groupName) {
    const peerAuth = this.authorizedPeers.get(peerID);
    return peerAuth && peerAuth.groups.has(groupName);
  }

  // Utility methods
  getGroupNameByRoot(rootHash) {
    for (const [name, root] of this.groupRoots.entries()) {
      if (root === rootHash) return name;
    }
    return null;
  }

  getStats() {
    return { ...this.stats };
  }

  cleanup() {
    this.meshService.off(MessageType.ZK_AUTH_CHALLENGE);
    this.meshService.off(MessageType.ZK_AUTH_RESPONSE);
  }
}
