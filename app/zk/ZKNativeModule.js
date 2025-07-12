/**
 * KRTR ZK Native Module
 * Clean interface for zero-knowledge proofs using native implementations
 */

import { NativeModules, Platform } from 'react-native';

// Native module interface
const { KRTRZKModule } = NativeModules;

export class ZKNativeService {
  constructor() {
    this.isAvailable = !!KRTRZKModule;
    this.stats = {
      proofsGenerated: 0,
      proofsVerified: 0,
      averageProofTime: 0,
      totalProofTime: 0,
    };
  }

  async isSupported() {
    if (!this.isAvailable) return false;
    return await KRTRZKModule.isSupported();
  }

  async generateMembershipProof(
    membershipKey,
    groupRoot,
    pathElements,
    pathIndices
  ) {
    if (!this.isAvailable) {
      throw new Error('ZK Native Module not available');
    }

    const startTime = Date.now();

    try {
      const result = await KRTRZKModule.generateMembershipProof({
        membershipKey,
        groupRoot,
        pathElements,
        pathIndices,
      });

      const proofTime = Date.now() - startTime;
      this.updateStats(proofTime);

      return {
        proof: new Uint8Array(result.proof),
        publicInputs: result.publicInputs,
      };
    } catch (error) {
      throw new Error(`Membership proof generation failed: ${error.message}`);
    }
  }

  async verifyMembershipProof(proof, publicInputs, groupRoot) {
    if (!this.isAvailable) {
      throw new Error('ZK Native Module not available');
    }

    try {
      const isValid = await KRTRZKModule.verifyMembershipProof({
        proof: Array.from(proof),
        publicInputs,
        groupRoot,
      });

      this.stats.proofsVerified++;
      return isValid;
    } catch (error) {
      throw new Error(`Membership proof verification failed: ${error.message}`);
    }
  }

  async generateReputationProof(reputationScore, threshold, nonce) {
    if (!this.isAvailable) {
      throw new Error('ZK Native Module not available');
    }

    const startTime = Date.now();

    try {
      const result = await KRTRZKModule.generateReputationProof({
        reputationScore,
        threshold,
        nonce,
      });

      const proofTime = Date.now() - startTime;
      this.updateStats(proofTime);

      return {
        proof: new Uint8Array(result.proof),
        publicInputs: result.publicInputs,
      };
    } catch (error) {
      throw new Error(`Reputation proof generation failed: ${error.message}`);
    }
  }

  async verifyReputationProof(proof, publicInputs, threshold) {
    if (!this.isAvailable) {
      throw new Error('ZK Native Module not available');
    }

    try {
      const isValid = await KRTRZKModule.verifyReputationProof({
        proof: Array.from(proof),
        publicInputs,
        threshold,
      });

      this.stats.proofsVerified++;
      return isValid;
    } catch (error) {
      throw new Error(`Reputation proof verification failed: ${error.message}`);
    }
  }

  updateStats(proofTime) {
    this.stats.proofsGenerated++;
    this.stats.totalProofTime += proofTime;
    this.stats.averageProofTime =
      this.stats.totalProofTime / this.stats.proofsGenerated;
  }

  getStats() {
    return { ...this.stats };
  }

  resetStats() {
    this.stats = {
      proofsGenerated: 0,
      proofsVerified: 0,
      averageProofTime: 0,
      totalProofTime: 0,
    };
  }
}
