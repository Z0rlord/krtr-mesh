/**
 * KRTR Zero-Knowledge Service Tests
 * Tests for ZK proof generation and verification functionality
 */

import { ZKService } from '../../app/zk/ZKService';

// Mock AsyncStorage for testing
jest.mock('@react-native-async-storage/async-storage', () => ({
  getItem: jest.fn(),
  setItem: jest.fn(),
  removeItem: jest.fn(),
  clear: jest.fn(),
}));

// Mock Noir libraries for testing
jest.mock('@noir-lang/noir_js', () => ({
  Noir: jest.fn().mockImplementation(() => ({
    generateFinalProof: jest.fn().mockResolvedValue({
      proof: new Uint8Array([1, 2, 3, 4]),
      publicInputs: [1, 2, 3]
    }),
    verifyFinalProof: jest.fn().mockResolvedValue(true),
  })),
}));

jest.mock('@noir-lang/backend_barretenberg', () => ({
  BarretenbergBackend: jest.fn().mockImplementation(() => ({
    generateFinalProof: jest.fn(),
    verifyFinalProof: jest.fn(),
  })),
}));

// Mock compiled circuits
jest.mock('../../circuits/membership/target/membership.json', () => ({}), { virtual: true });
jest.mock('../../circuits/reputation/target/reputation.json', () => ({}), { virtual: true });
jest.mock('../../circuits/message_proof/target/message_proof.json', () => ({}), { virtual: true });

describe('ZKService', () => {
  let zkService;

  beforeEach(() => {
    jest.clearAllMocks();
    zkService = new ZKService();
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('Initialization', () => {
    test('should initialize ZK service', async () => {
      expect(zkService).toBeDefined();
      expect(zkService.stats).toBeDefined();
      expect(zkService.stats.proofsGenerated).toBe(0);
      expect(zkService.stats.proofsVerified).toBe(0);
    });

    test('should have correct initial statistics', () => {
      expect(zkService.stats).toEqual({
        proofsGenerated: 0,
        proofsVerified: 0,
        averageProofTime: 0,
        totalProofTime: 0
      });
    });
  });

  describe('Membership Proofs', () => {
    test('should check if user can prove membership', async () => {
      // Mock the membership check
      zkService.zkIdentity = { membershipKey: 'test-key' };
      zkService.membershipTree = { root: 'test-root' };

      const canProve = await zkService.canProveMembership('test-group');
      expect(typeof canProve).toBe('boolean');
    });

    test('should generate membership proof with valid inputs', async () => {
      // Setup mock data
      zkService.zkIdentity = { membershipKey: 'test-key' };
      zkService.membershipTree = {
        root: 'test-root',
        getProof: jest.fn().mockReturnValue({
          pathElements: [1, 2, 3],
          pathIndices: [0, 1, 0]
        })
      };
      zkService.membershipNoir = {
        generateFinalProof: jest.fn().mockResolvedValue({
          proof: new Uint8Array([1, 2, 3, 4]),
          publicInputs: [1]
        })
      };

      const proof = await zkService.generateMembershipProof('test-group');

      expect(proof).toBeDefined();
      expect(proof.proof).toBeInstanceOf(Uint8Array);
      expect(Array.isArray(proof.publicInputs)).toBe(true);
    });

    test('should verify valid membership proof', async () => {
      zkService.membershipNoir = {
        verifyFinalProof: jest.fn().mockResolvedValue(true)
      };

      const mockProof = new Uint8Array([1, 2, 3, 4]);
      const mockPublicSignals = [1, 2, 3];

      const isValid = await zkService.verifyMembershipProof(mockProof, mockPublicSignals);

      expect(isValid).toBe(true);
      expect(zkService.stats.proofsVerified).toBe(1);
    });

    test('should reject invalid membership proof', async () => {
      zkService.membershipNoir = {
        verifyFinalProof: jest.fn().mockResolvedValue(false)
      };

      const mockProof = new Uint8Array([1, 2, 3, 4]);
      const mockPublicSignals = [1, 2, 3];

      const isValid = await zkService.verifyMembershipProof(mockProof, mockPublicSignals);

      expect(isValid).toBe(false);
      expect(zkService.stats.proofsVerified).toBe(1);
    });
  });

  describe('Reputation Proofs', () => {
    test('should check if user can prove reputation threshold', async () => {
      zkService.reputationData = { score: 150 };

      const canProve = await zkService.canProveReputation(100);
      expect(canProve).toBe(true);

      const cannotProve = await zkService.canProveReputation(200);
      expect(cannotProve).toBe(false);
    });

    test('should generate reputation proof with sufficient reputation', async () => {
      zkService.reputationData = {
        score: 150,
        nonce: 'test-nonce',
        history: []
      };
      zkService.reputationNoir = {
        generateFinalProof: jest.fn().mockResolvedValue({
          proof: new Uint8Array([5, 6, 7, 8]),
          publicInputs: [1]
        })
      };

      const proof = await zkService.generateReputationProof(100);

      expect(proof).toBeDefined();
      expect(proof.proof).toBeInstanceOf(Uint8Array);
      expect(Array.isArray(proof.publicInputs)).toBe(true);
    });

    test('should verify valid reputation proof', async () => {
      zkService.reputationNoir = {
        verifyFinalProof: jest.fn().mockResolvedValue(true)
      };

      const mockProof = new Uint8Array([5, 6, 7, 8]);
      const mockPublicSignals = [1];

      const isValid = await zkService.verifyReputationProof(mockProof, mockPublicSignals);

      expect(isValid).toBe(true);
      expect(zkService.stats.proofsVerified).toBe(1);
    });
  });

  describe('Message Proofs', () => {
    test('should generate message authenticity proof', async () => {
      zkService.zkIdentity = { signingKey: 'test-signing-key' };
      zkService.messageProofNoir = {
        generateFinalProof: jest.fn().mockResolvedValue({
          proof: new Uint8Array([9, 10, 11, 12]),
          publicInputs: [1]
        })
      };

      const messageContent = 'Hello, KRTR!';
      const timestamp = Date.now();

      const proof = await zkService.generateMessageProof(messageContent, timestamp);

      expect(proof).toBeDefined();
      expect(proof.proof).toBeInstanceOf(Uint8Array);
      expect(Array.isArray(proof.publicInputs)).toBe(true);
    });

    test('should verify valid message proof', async () => {
      zkService.messageProofNoir = {
        verifyFinalProof: jest.fn().mockResolvedValue(true)
      };

      const mockProof = new Uint8Array([9, 10, 11, 12]);
      const mockPublicSignals = [1];

      const isValid = await zkService.verifyMessageProof(mockProof, mockPublicSignals);

      expect(isValid).toBe(true);
      expect(zkService.stats.proofsVerified).toBe(1);
    });
  });

  describe('Statistics and Performance', () => {
    test('should track proof generation statistics', async () => {
      zkService.reputationData = { score: 150, nonce: 'test', history: [] };
      zkService.reputationNoir = {
        generateFinalProof: jest.fn().mockResolvedValue({
          proof: new Uint8Array([1, 2, 3, 4]),
          publicInputs: [1]
        })
      };

      await zkService.generateReputationProof(100);

      expect(zkService.stats.proofsGenerated).toBe(1);
      expect(zkService.stats.totalProofTime).toBeGreaterThan(0);
    });

    test('should get performance statistics', () => {
      const stats = zkService.getStats();

      expect(stats).toHaveProperty('proofsGenerated');
      expect(stats).toHaveProperty('proofsVerified');
      expect(stats).toHaveProperty('averageProofTime');
      expect(stats).toHaveProperty('totalProofTime');
    });

    test('should reset statistics', () => {
      zkService.stats.proofsGenerated = 5;
      zkService.stats.proofsVerified = 3;

      zkService.resetStats();

      expect(zkService.stats.proofsGenerated).toBe(0);
      expect(zkService.stats.proofsVerified).toBe(0);
      expect(zkService.stats.averageProofTime).toBe(0);
      expect(zkService.stats.totalProofTime).toBe(0);
    });
  });

  describe('Error Handling', () => {
    test('should handle missing circuits gracefully', async () => {
      zkService.membershipNoir = null;

      const canProve = await zkService.canProveMembership('test-group');
      expect(canProve).toBe(false);

      await expect(zkService.generateMembershipProof('test-group'))
        .rejects.toThrow('Membership circuit not available');
    });

    test('should handle proof generation errors', async () => {
      zkService.reputationNoir = {
        generateFinalProof: jest.fn().mockRejectedValue(new Error('Proof generation failed'))
      };
      zkService.reputationData = { score: 150, nonce: 'test', history: [] };

      await expect(zkService.generateReputationProof(100))
        .rejects.toThrow('Proof generation failed');
    });

    test('should handle proof verification errors gracefully', async () => {
      zkService.membershipNoir = {
        verifyFinalProof: jest.fn().mockRejectedValue(new Error('Verification failed'))
      };

      const mockProof = new Uint8Array([1, 2, 3, 4]);
      const mockPublicSignals = [1, 2, 3];

      const isValid = await zkService.verifyMembershipProof(mockProof, mockPublicSignals);
      expect(isValid).toBe(false);
    });
  });
});
