/**
 * KRTR Zero-Knowledge Service Factory
 * Clean, production-ready ZK proof interface
 */

import { Platform } from 'react-native';
import { ZKNativeService } from './ZKNativeModule';
import { ZKServerService } from './ZKServerService';

// Clean factory pattern for ZK services
export class ZKServiceFactory {
    static create(config = {}) {
        const {
            preferNative = true,
            serverUrl = 'https://zk.krtr.mesh',
            fallbackToMock = __DEV__
        } = config;

        // Try native implementation first (most secure)
        if (preferNative && Platform.OS !== 'web') {
            try {
                const nativeService = new ZKNativeService();
                if (nativeService.isAvailable) {
                    console.log('✅ Using native ZK implementation');
                    return nativeService;
                }
            } catch (error) {
                console.log('⚠️ Native ZK not available:', error.message);
            }
        }

        // Fallback to server-side implementation (secure)
        try {
            console.log('✅ Using server-side ZK implementation');
            return new ZKServerService(serverUrl);
        } catch (error) {
            console.log('⚠️ Server ZK not available:', error.message);
        }

        // Development fallback only
        if (fallbackToMock) {
            console.log('⚠️ Using mock ZK implementation (development only)');
            return new ZKMockService();
        }

        throw new Error('No ZK implementation available');
    }
}

// Mock service for development/testing
class ZKMockService {
    constructor() {
        this.stats = {
            proofsGenerated: 0,
            proofsVerified: 0,
            averageProofTime: 0,
            totalProofTime: 0
        };
    }

    async generateMembershipProof(membershipKey, groupRoot, pathElements, pathIndices) {
        await this.simulateDelay(100);
        this.stats.proofsGenerated++;

        return {
            proof: new Uint8Array(32).fill(0).map(() => Math.floor(Math.random() * 256)),
            publicInputs: [1, 2, 3]
        };
    }

    async verifyMembershipProof(proof, publicInputs, groupRoot) {
        await this.simulateDelay(50);
        this.stats.proofsVerified++;
        return true;
    }

    async generateReputationProof(reputationScore, threshold, nonce) {
        await this.simulateDelay(100);
        this.stats.proofsGenerated++;

        return {
            proof: new Uint8Array(32).fill(0).map(() => Math.floor(Math.random() * 256)),
            publicInputs: [threshold > reputationScore ? 0 : 1]
        };
    }

    async verifyReputationProof(proof, publicInputs, threshold) {
        await this.simulateDelay(50);
        this.stats.proofsVerified++;
        return true;
    }

    async simulateDelay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
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

// Legacy compatibility export
export const ZKService = ZKMockService;