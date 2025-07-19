#!/usr/bin/env node

/**
 * KRTR ZK Bridge Service
 * 
 * Node.js service that executes Noir circuits and returns proofs to Swift
 * This bridge enables real ZK proof generation using compiled Noir circuits
 */

const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

class ZKBridge {
    constructor() {
        this.circuitsPath = path.join(__dirname, '..', 'circuits');
        this.tempPath = path.join(__dirname, '..', '.temp');
        
        // Ensure temp directory exists
        if (!fs.existsSync(this.tempPath)) {
            fs.mkdirSync(this.tempPath, { recursive: true });
        }
    }

    /**
     * Load circuit from compiled JSON file
     */
    loadCircuit(circuitName) {
        const circuitPath = path.join(this.circuitsPath, circuitName, 'target', `krtr_${circuitName}.json`);
        
        if (!fs.existsSync(circuitPath)) {
            throw new Error(`Circuit not found: ${circuitPath}`);
        }
        
        const circuitData = JSON.parse(fs.readFileSync(circuitPath, 'utf8'));
        
        if (!circuitData.abi || !circuitData.bytecode) {
            throw new Error(`Invalid circuit format: missing abi or bytecode`);
        }
        
        return circuitData;
    }

    /**
     * Generate membership proof using Noir circuit
     */
    async generateMembershipProof(params) {
        const { membershipKey, groupRoot, pathElements, pathIndices } = params;
        
        try {
            // Load membership circuit
            const circuit = this.loadCircuit('membership');
            
            // Prepare witness data
            const witness = {
                secret_key: this.toFieldElement(membershipKey),
                path_elements: pathElements.map(el => this.toFieldElement(el)),
                path_indices: pathIndices,
                group_root: this.toFieldElement(groupRoot),
                nullifier_hash: this.generateNullifierHash(membershipKey),
                signal_hash: this.generateSignalHash(membershipKey, groupRoot)
            };
            
            // Execute circuit with nargo
            const proof = await this.executeCircuit('membership', witness);
            
            return {
                proof: proof.proof,
                publicInputs: [witness.group_root, witness.nullifier_hash, witness.signal_hash],
                proofType: 'membership',
                timestamp: Date.now()
            };
            
        } catch (error) {
            throw new Error(`Membership proof generation failed: ${error.message}`);
        }
    }

    /**
     * Generate reputation proof using Noir circuit
     */
    async generateReputationProof(params) {
        const { reputationScore, threshold, nonce } = params;
        
        try {
            // Load reputation circuit
            const circuit = this.loadCircuit('reputation');
            
            // Prepare witness data
            const witness = {
                message_count: Math.floor(reputationScore / 10), // Derive from score
                positive_ratings: Math.floor(reputationScore * 0.8),
                negative_ratings: Math.floor(reputationScore * 0.2),
                secret_salt: this.toFieldElement(nonce),
                reputation_threshold: threshold,
                commitment: this.generateCommitment(reputationScore, nonce)
            };
            
            // Execute circuit with nargo
            const proof = await this.executeCircuit('reputation', witness);
            
            return {
                proof: proof.proof,
                publicInputs: [witness.reputation_threshold, witness.commitment],
                proofType: 'reputation',
                timestamp: Date.now()
            };
            
        } catch (error) {
            throw new Error(`Reputation proof generation failed: ${error.message}`);
        }
    }

    /**
     * Generate message authentication proof using Noir circuit
     */
    async generateMessageAuthProof(params) {
        const { message, senderKey, timestamp } = params;
        
        try {
            // Load message proof circuit
            const circuit = this.loadCircuit('message_proof');
            
            // Prepare witness data
            const witness = {
                message_content: this.toFieldElement(message),
                sender_private_key: this.toFieldElement(senderKey),
                nonce: this.generateNonce(),
                message_hash: this.hashMessage(message),
                sender_public_key: this.derivePublicKey(senderKey),
                timestamp: timestamp
            };
            
            // Execute circuit with nargo
            const proof = await this.executeCircuit('message_proof', witness);
            
            return {
                proof: proof.proof,
                publicInputs: [witness.message_hash, witness.sender_public_key, witness.timestamp],
                proofType: 'messageAuth',
                timestamp: Date.now()
            };
            
        } catch (error) {
            throw new Error(`Message auth proof generation failed: ${error.message}`);
        }
    }

    /**
     * Verify a ZK proof using Noir circuit
     */
    async verifyProof(proof, publicInputs, proofType) {
        try {
            // Load appropriate circuit
            const circuit = this.loadCircuit(proofType === 'messageAuth' ? 'message_proof' : proofType);
            
            // Execute verification with nargo
            const result = await this.executeVerification(proofType, proof, publicInputs);
            
            return result.valid === true;
            
        } catch (error) {
            console.error(`Proof verification failed: ${error.message}`);
            return false;
        }
    }

    /**
     * Execute Noir circuit using nargo
     */
    async executeCircuit(circuitName, witness) {
        return new Promise((resolve, reject) => {
            const circuitDir = path.join(this.circuitsPath, circuitName);
            const witnessFile = path.join(this.tempPath, `${circuitName}_witness.json`);
            
            // Write witness data to file
            fs.writeFileSync(witnessFile, JSON.stringify(witness, null, 2));
            
            // Execute nargo prove
            const nargoProcess = spawn('nargo', ['prove', '--witness-path', witnessFile], {
                cwd: circuitDir,
                stdio: ['pipe', 'pipe', 'pipe']
            });
            
            let stdout = '';
            let stderr = '';
            
            nargoProcess.stdout.on('data', (data) => {
                stdout += data.toString();
            });
            
            nargoProcess.stderr.on('data', (data) => {
                stderr += data.toString();
            });
            
            nargoProcess.on('close', (code) => {
                // Clean up witness file
                if (fs.existsSync(witnessFile)) {
                    fs.unlinkSync(witnessFile);
                }
                
                if (code === 0) {
                    try {
                        // Read proof file generated by nargo
                        const proofFile = path.join(circuitDir, 'proofs', `${circuitName}.proof`);
                        const proof = fs.readFileSync(proofFile, 'utf8');
                        
                        resolve({
                            proof: proof.trim(),
                            stdout: stdout,
                            stderr: stderr
                        });
                    } catch (error) {
                        reject(new Error(`Failed to read proof file: ${error.message}`));
                    }
                } else {
                    reject(new Error(`nargo prove failed with code ${code}: ${stderr}`));
                }
            });
            
            nargoProcess.on('error', (error) => {
                reject(new Error(`Failed to spawn nargo: ${error.message}`));
            });
        });
    }

    /**
     * Execute proof verification using nargo
     */
    async executeVerification(circuitName, proof, publicInputs) {
        return new Promise((resolve, reject) => {
            const circuitDir = path.join(this.circuitsPath, circuitName === 'messageAuth' ? 'message_proof' : circuitName);
            const proofFile = path.join(this.tempPath, `${circuitName}_verify.proof`);
            
            // Write proof to file
            fs.writeFileSync(proofFile, proof);
            
            // Execute nargo verify
            const nargoProcess = spawn('nargo', ['verify', '--proof-path', proofFile], {
                cwd: circuitDir,
                stdio: ['pipe', 'pipe', 'pipe']
            });
            
            let stdout = '';
            let stderr = '';
            
            nargoProcess.stdout.on('data', (data) => {
                stdout += data.toString();
            });
            
            nargoProcess.stderr.on('data', (data) => {
                stderr += data.toString();
            });
            
            nargoProcess.on('close', (code) => {
                // Clean up proof file
                if (fs.existsSync(proofFile)) {
                    fs.unlinkSync(proofFile);
                }
                
                resolve({
                    valid: code === 0,
                    stdout: stdout,
                    stderr: stderr
                });
            });
            
            nargoProcess.on('error', (error) => {
                reject(new Error(`Failed to spawn nargo verify: ${error.message}`));
            });
        });
    }

    /**
     * Convert data to field element (simplified for demo)
     */
    toFieldElement(data) {
        if (typeof data === 'string') {
            // Convert string to bytes then to field element
            const bytes = Buffer.from(data, 'utf8');
            return Array.from(bytes).reduce((acc, byte, i) => acc + (byte * Math.pow(256, i)), 0) % (2n ** 254n - 1n);
        } else if (data instanceof Uint8Array || Buffer.isBuffer(data)) {
            return Array.from(data).reduce((acc, byte, i) => acc + (byte * Math.pow(256, i)), 0) % (2n ** 254n - 1n);
        }
        return data;
    }

    /**
     * Generate nullifier hash for membership proof
     */
    generateNullifierHash(membershipKey) {
        const hash = require('crypto').createHash('sha256');
        hash.update(membershipKey);
        hash.update('nullifier');
        return this.toFieldElement(hash.digest());
    }

    /**
     * Generate signal hash for membership proof
     */
    generateSignalHash(membershipKey, groupRoot) {
        const hash = require('crypto').createHash('sha256');
        hash.update(membershipKey);
        hash.update(groupRoot);
        hash.update('signal');
        return this.toFieldElement(hash.digest());
    }

    /**
     * Generate commitment for reputation proof
     */
    generateCommitment(reputationScore, nonce) {
        const hash = require('crypto').createHash('sha256');
        hash.update(Buffer.from(reputationScore.toString()));
        hash.update(nonce);
        return this.toFieldElement(hash.digest());
    }

    /**
     * Generate nonce for message proof
     */
    generateNonce() {
        return this.toFieldElement(require('crypto').randomBytes(32));
    }

    /**
     * Hash message for message proof
     */
    hashMessage(message) {
        const hash = require('crypto').createHash('sha256');
        hash.update(message);
        return this.toFieldElement(hash.digest());
    }

    /**
     * Derive public key from private key (simplified)
     */
    derivePublicKey(privateKey) {
        const hash = require('crypto').createHash('sha256');
        hash.update(privateKey);
        hash.update('public');
        return this.toFieldElement(hash.digest());
    }
}

// CLI interface for testing
if (require.main === module) {
    const bridge = new ZKBridge();
    
    const command = process.argv[2];
    const params = process.argv[3] ? JSON.parse(process.argv[3]) : {};
    
    async function main() {
        try {
            let result;
            
            switch (command) {
                case 'membership':
                    result = await bridge.generateMembershipProof(params);
                    break;
                case 'reputation':
                    result = await bridge.generateReputationProof(params);
                    break;
                case 'message':
                    result = await bridge.generateMessageAuthProof(params);
                    break;
                case 'verify':
                    result = await bridge.verifyProof(params.proof, params.publicInputs, params.proofType);
                    break;
                default:
                    throw new Error(`Unknown command: ${command}`);
            }
            
            console.log(JSON.stringify(result, null, 2));
        } catch (error) {
            console.error('Error:', error.message);
            process.exit(1);
        }
    }
    
    main();
}

module.exports = ZKBridge;
