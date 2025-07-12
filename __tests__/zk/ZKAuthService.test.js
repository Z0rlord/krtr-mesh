/**
 * KRTR Zero-Knowledge Authentication Service Tests
 * Tests for anonymous authentication and authorization using ZK proofs
 */

import { ZKAuthService } from '../../app/zk/ZKAuthService';

// Mock the protocol classes
jest.mock('../../app/protocols/KrtrProtocol', () => ({
  ZKAuthChallenge: jest.fn().mockImplementation((id, root, threshold) => ({
    challengeId: id,
    groupRoot: root,
    reputationThreshold: threshold,
    timestamp: Date.now(),
    isExpired: jest.fn().mockReturnValue(false)
  })),
  ZKMembershipProof: jest.fn(),
  ZKReputationProof: jest.fn(),
  MessageType: {
    ZK_AUTH_CHALLENGE: 'zk_auth_challenge',
    ZK_AUTH_RESPONSE: 'zk_auth_response'
  }
}));

// Mock uuid
jest.mock('react-native-uuid', () => ({
  v4: jest.fn(() => 'test-uuid-1234')
}));

describe('ZKAuthService', () => {
  let zkAuthService;
  let mockZKService;
  let mockMeshService;

  beforeEach(() => {
    // Mock ZKService
    mockZKService = {
      canProveMembership: jest.fn().mockResolvedValue(true),
      canProveReputation: jest.fn().mockResolvedValue(true),
      generateMembershipProof: jest.fn().mockResolvedValue({
        proof: new Uint8Array([1, 2, 3, 4]),
        publicInputs: [1]
      }),
      generateReputationProof: jest.fn().mockResolvedValue({
        proof: new Uint8Array([5, 6, 7, 8]),
        publicInputs: [1]
      }),
      verifyMembershipProof: jest.fn().mockResolvedValue(true),
      verifyReputationProof: jest.fn().mockResolvedValue(true)
    };

    // Mock MeshService
    mockMeshService = {
      sendMessage: jest.fn().mockResolvedValue(true),
      on: jest.fn(),
      off: jest.fn()
    };

    zkAuthService = new ZKAuthService(mockZKService, mockMeshService);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('Initialization', () => {
    test('should initialize with correct default values', () => {
      expect(zkAuthService).toBeDefined();
      expect(zkAuthService.stats.challengesSent).toBe(0);
      expect(zkAuthService.stats.challengesReceived).toBe(0);
      expect(zkAuthService.stats.authSuccesses).toBe(0);
      expect(zkAuthService.stats.authFailures).toBe(0);
    });

    test('should have default group configurations', () => {
      expect(zkAuthService.groupRoots.has('public')).toBe(true);
      expect(zkAuthService.groupRoots.has('trusted')).toBe(true);
      expect(zkAuthService.groupRoots.has('admin')).toBe(true);
    });

    test('should have default reputation thresholds', () => {
      expect(zkAuthService.reputationThresholds.get('public')).toBe(0);
      expect(zkAuthService.reputationThresholds.get('trusted')).toBe(50);
      expect(zkAuthService.reputationThresholds.get('admin')).toBe(100);
    });
  });

  describe('Group Management', () => {
    test('should add new group successfully', () => {
      const groupName = 'moderators';
      const groupRoot = 'test-moderator-root';
      const reputationThreshold = 75;

      zkAuthService.addGroup(groupName, groupRoot, reputationThreshold);

      expect(zkAuthService.groupRoots.get(groupName)).toBe(groupRoot);
      expect(zkAuthService.reputationThresholds.get(groupName)).toBe(reputationThreshold);
    });

    test('should remove group successfully', () => {
      zkAuthService.addGroup('temp-group', 'temp-root', 25);
      expect(zkAuthService.groupRoots.has('temp-group')).toBe(true);

      zkAuthService.removeGroup('temp-group');
      expect(zkAuthService.groupRoots.has('temp-group')).toBe(false);
      expect(zkAuthService.reputationThresholds.has('temp-group')).toBe(false);
    });

    test('should list all groups', () => {
      const groups = zkAuthService.getGroups();
      expect(groups).toContain('public');
      expect(groups).toContain('trusted');
      expect(groups).toContain('admin');
    });
  });

  describe('Authentication Challenge', () => {
    test('should initiate authentication challenge', async () => {
      const peerID = 'test-peer-123';
      const groupName = 'trusted';

      const challengeId = await zkAuthService.initiateAuthentication(peerID, groupName);

      expect(challengeId).toBe('test-uuid-1234');
      expect(zkAuthService.activeChallenges.has(challengeId)).toBe(true);
      expect(zkAuthService.pendingAuths.has(peerID)).toBe(true);
      expect(zkAuthService.stats.challengesSent).toBe(1);
      expect(mockMeshService.sendMessage).toHaveBeenCalled();
    });

    test('should throw error for unknown group', async () => {
      const peerID = 'test-peer-123';
      const unknownGroup = 'nonexistent-group';

      await expect(zkAuthService.initiateAuthentication(peerID, unknownGroup))
        .rejects.toThrow('Unknown group: nonexistent-group');
    });

    test('should handle authentication challenge', async () => {
      const peerID = 'test-peer-456';
      const mockChallenge = {
        challengeId: 'challenge-123',
        groupRoot: 'test-root',
        reputationThreshold: 50,
        isExpired: jest.fn().mockReturnValue(false)
      };

      await zkAuthService.handleAuthChallenge(peerID, mockChallenge);

      expect(zkAuthService.stats.challengesReceived).toBe(1);
      expect(mockZKService.canProveMembership).toHaveBeenCalled();
      expect(mockZKService.canProveReputation).toHaveBeenCalled();
    });

    test('should reject expired challenges', async () => {
      const peerID = 'test-peer-456';
      const expiredChallenge = {
        challengeId: 'expired-challenge',
        groupRoot: 'test-root',
        reputationThreshold: 50,
        isExpired: jest.fn().mockReturnValue(true)
      };

      await zkAuthService.handleAuthChallenge(peerID, expiredChallenge);

      expect(zkAuthService.stats.challengesReceived).toBe(1);
      expect(mockZKService.canProveMembership).not.toHaveBeenCalled();
    });
  });

  describe('Authentication Response', () => {
    test('should handle valid authentication response', async () => {
      const peerID = 'test-peer-789';
      const challengeId = 'test-challenge-456';
      
      // Setup active challenge
      const mockChallenge = {
        challengeId,
        groupRoot: 'test-root',
        reputationThreshold: 50,
        isExpired: jest.fn().mockReturnValue(false)
      };
      zkAuthService.activeChallenges.set(challengeId, mockChallenge);

      const mockProofs = {
        membershipProof: {
          proof: new Uint8Array([1, 2, 3, 4]),
          publicInputs: [1]
        },
        reputationProof: {
          proof: new Uint8Array([5, 6, 7, 8]),
          publicInputs: [1]
        }
      };

      const result = await zkAuthService.handleAuthResponse(peerID, challengeId, mockProofs);

      expect(result).toBe(true);
      expect(zkAuthService.authorizedPeers.has(peerID)).toBe(true);
      expect(zkAuthService.stats.authSuccesses).toBe(1);
      expect(mockZKService.verifyMembershipProof).toHaveBeenCalled();
      expect(mockZKService.verifyReputationProof).toHaveBeenCalled();
    });

    test('should reject response for unknown challenge', async () => {
      const peerID = 'test-peer-789';
      const unknownChallengeId = 'unknown-challenge';
      const mockProofs = {};

      const result = await zkAuthService.handleAuthResponse(peerID, unknownChallengeId, mockProofs);

      expect(result).toBe(false);
      expect(zkAuthService.stats.authFailures).toBe(1);
    });

    test('should reject response with invalid proofs', async () => {
      const peerID = 'test-peer-789';
      const challengeId = 'test-challenge-456';
      
      // Setup active challenge
      const mockChallenge = {
        challengeId,
        groupRoot: 'test-root',
        reputationThreshold: 50,
        isExpired: jest.fn().mockReturnValue(false)
      };
      zkAuthService.activeChallenges.set(challengeId, mockChallenge);

      // Mock invalid proof verification
      mockZKService.verifyMembershipProof.mockResolvedValue(false);

      const mockProofs = {
        membershipProof: {
          proof: new Uint8Array([1, 2, 3, 4]),
          publicInputs: [1]
        }
      };

      const result = await zkAuthService.handleAuthResponse(peerID, challengeId, mockProofs);

      expect(result).toBe(false);
      expect(zkAuthService.authorizedPeers.has(peerID)).toBe(false);
      expect(zkAuthService.stats.authFailures).toBe(1);
    });
  });

  describe('Authorization Management', () => {
    test('should check peer authorization status', () => {
      const peerID = 'authorized-peer';
      const groupName = 'trusted';

      // Authorize peer
      zkAuthService.authorizedPeers.set(peerID, {
        groups: new Set([groupName]),
        timestamp: Date.now()
      });

      const isAuthorized = zkAuthService.isPeerAuthorized(peerID, groupName);
      expect(isAuthorized).toBe(true);

      const isNotAuthorized = zkAuthService.isPeerAuthorized(peerID, 'admin');
      expect(isNotAuthorized).toBe(false);
    });

    test('should revoke peer authorization', () => {
      const peerID = 'test-peer-revoke';
      
      // First authorize the peer
      zkAuthService.authorizedPeers.set(peerID, {
        groups: new Set(['trusted']),
        timestamp: Date.now()
      });

      expect(zkAuthService.isPeerAuthorized(peerID, 'trusted')).toBe(true);

      // Then revoke authorization
      zkAuthService.revokePeerAuth(peerID);

      expect(zkAuthService.isPeerAuthorized(peerID, 'trusted')).toBe(false);
      expect(zkAuthService.authorizedPeers.has(peerID)).toBe(false);
    });

    test('should get all authorized peers', () => {
      const peer1 = 'peer-1';
      const peer2 = 'peer-2';

      zkAuthService.authorizedPeers.set(peer1, {
        groups: new Set(['public']),
        timestamp: Date.now()
      });
      zkAuthService.authorizedPeers.set(peer2, {
        groups: new Set(['trusted']),
        timestamp: Date.now()
      });

      const authorizedPeers = zkAuthService.getAuthorizedPeers();
      expect(authorizedPeers).toContain(peer1);
      expect(authorizedPeers).toContain(peer2);
    });
  });

  describe('Statistics and Cleanup', () => {
    test('should get authentication statistics', () => {
      const stats = zkAuthService.getStats();

      expect(stats).toHaveProperty('challengesSent');
      expect(stats).toHaveProperty('challengesReceived');
      expect(stats).toHaveProperty('authSuccesses');
      expect(stats).toHaveProperty('authFailures');
      expect(stats).toHaveProperty('activeChallenges');
      expect(stats).toHaveProperty('authorizedPeers');
    });

    test('should reset statistics', () => {
      zkAuthService.stats.challengesSent = 5;
      zkAuthService.stats.authSuccesses = 3;

      zkAuthService.resetStats();

      expect(zkAuthService.stats.challengesSent).toBe(0);
      expect(zkAuthService.stats.authSuccesses).toBe(0);
    });

    test('should cleanup expired challenges', () => {
      const expiredChallenge = {
        challengeId: 'expired',
        timestamp: Date.now() - 600000, // 10 minutes ago
        isExpired: jest.fn().mockReturnValue(true)
      };

      zkAuthService.activeChallenges.set('expired', expiredChallenge);
      
      zkAuthService.cleanupExpiredChallenges();

      expect(zkAuthService.activeChallenges.has('expired')).toBe(false);
    });
  });
});
