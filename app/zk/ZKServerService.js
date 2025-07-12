/**
 * KRTR ZK Server Service
 * Secure server-side zero-knowledge proof generation and verification
 */

export class ZKServerService {
  constructor(serverUrl = 'https://zk.krtr.mesh') {
    this.serverUrl = serverUrl;
    this.stats = {
      proofsGenerated: 0,
      proofsVerified: 0,
      averageProofTime: 0,
      totalProofTime: 0
    };
  }

  async generateMembershipProof(membershipKey, groupRoot, pathElements, pathIndices) {
    const startTime = Date.now();

    try {
      const response = await fetch(`${this.serverUrl}/api/zk/membership/generate`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          membershipKey,
          groupRoot,
          pathElements,
          pathIndices
        })
      });

      if (!response.ok) {
        throw new Error(`Server error: ${response.status}`);
      }

      const result = await response.json();
      const proofTime = Date.now() - startTime;
      this.updateStats(proofTime);

      return {
        proof: new Uint8Array(result.proof),
        publicInputs: result.publicInputs
      };
    } catch (error) {
      throw new Error(`Membership proof generation failed: ${error.message}`);
    }
  }

  async verifyMembershipProof(proof, publicInputs, groupRoot) {
    try {
      const response = await fetch(`${this.serverUrl}/api/zk/membership/verify`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          proof: Array.from(proof),
          publicInputs,
          groupRoot
        })
      });

      if (!response.ok) {
        throw new Error(`Server error: ${response.status}`);
      }

      const result = await response.json();
      this.stats.proofsVerified++;
      
      return result.isValid;
    } catch (error) {
      throw new Error(`Membership proof verification failed: ${error.message}`);
    }
  }

  async generateReputationProof(reputationScore, threshold, nonce) {
    const startTime = Date.now();

    try {
      const response = await fetch(`${this.serverUrl}/api/zk/reputation/generate`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          reputationScore,
          threshold,
          nonce
        })
      });

      if (!response.ok) {
        throw new Error(`Server error: ${response.status}`);
      }

      const result = await response.json();
      const proofTime = Date.now() - startTime;
      this.updateStats(proofTime);

      return {
        proof: new Uint8Array(result.proof),
        publicInputs: result.publicInputs
      };
    } catch (error) {
      throw new Error(`Reputation proof generation failed: ${error.message}`);
    }
  }

  async verifyReputationProof(proof, publicInputs, threshold) {
    try {
      const response = await fetch(`${this.serverUrl}/api/zk/reputation/verify`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          proof: Array.from(proof),
          publicInputs,
          threshold
        })
      });

      if (!response.ok) {
        throw new Error(`Server error: ${response.status}`);
      }

      const result = await response.json();
      this.stats.proofsVerified++;
      
      return result.isValid;
    } catch (error) {
      throw new Error(`Reputation proof verification failed: ${error.message}`);
    }
  }

  updateStats(proofTime) {
    this.stats.proofsGenerated++;
    this.stats.totalProofTime += proofTime;
    this.stats.averageProofTime = this.stats.totalProofTime / this.stats.proofsGenerated;
  }

  getStats() {
    return { ...this.stats };
  }

  resetStats() {
    this.stats = {
      proofsGenerated: 0,
      proofsVerified: 0,
      averageProofTime: 0,
      totalProofTime: 0
    };
  }
}
