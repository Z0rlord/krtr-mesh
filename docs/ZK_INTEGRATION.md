# KRTR Zero-Knowledge Integration

This document describes the integration of Noir zero-knowledge proofs into the KRTR mesh networking project, enabling anonymous authentication, private reputation systems, and selective disclosure.

## 🎯 **Overview**

KRTR now includes advanced zero-knowledge capabilities that provide:

- **Anonymous Authentication** - Prove membership without revealing identity
- **Private Reputation** - Establish trust without exposing interaction history  
- **Selective Disclosure** - Prove message authenticity without revealing content
- **Group Authorization** - Access control with cryptographic privacy

## 🏗️ **Architecture**

### **ZK Service Layer**

```
┌─────────────────────────────────────────────────────────────┐
│                        KRTR App                             │
├─────────────────────────────────────────────────────────────┤
│  ZK Auth Service    │  ZK Service      │  Privacy Service   │
├─────────────────────────────────────────────────────────────┤
│              Bluetooth Mesh Service                         │
├─────────────────────────────────────────────────────────────┤
│  Noir Circuits     │  Encryption      │  Store & Forward   │
├─────────────────────────────────────────────────────────────┤
│                    Binary Protocol                          │
└─────────────────────────────────────────────────────────────┘
```

### **Core Components**

1. **ZKService** (`app/zk/ZKService.js`) - Core ZK proof generation and verification
2. **ZKAuthService** (`app/zk/ZKAuthService.js`) - Anonymous authentication system
3. **Noir Circuits** (`circuits/`) - Zero-knowledge proof circuits
4. **Protocol Extensions** - ZK message types and structures

## 🔐 **Zero-Knowledge Circuits**

### **1. Membership Circuit** (`circuits/membership/`)

Proves membership in an authorized group without revealing which member you are.

**Private Inputs:**

- `secret_key` - User's secret membership key
- `path_elements` - Merkle tree path to prove membership
- `path_indices` - Path directions in the tree

**Public Inputs:**

- `group_root` - Merkle root of authorized members
- `nullifier_hash` - Prevents double-use of proofs
- `signal_hash` - Unique challenge identifier

**Use Cases:**

- Join mesh networks anonymously
- Access private channels without revealing identity
- Participate in governance while maintaining privacy

### **2. Reputation Circuit** (`circuits/reputation/`)

Proves good reputation without revealing interaction history.

**Private Inputs:**

- `message_count` - Total messages sent
- `positive_ratings` - Positive feedback received
- `negative_ratings` - Negative feedback received
- `secret_salt` - Random salt for commitment

**Public Inputs:**

- `reputation_threshold` - Minimum reputation required
- `commitment` - Cryptographic commitment to private data

**Use Cases:**

- Access high-trust channels
- Establish credibility without revealing history
- Moderate content with anonymous authority

### **3. Message Proof Circuit** (`circuits/message_proof/`)

Proves message authenticity without revealing content.

**Private Inputs:**

- `message_content` - Actual message content
- `sender_private_key` - Sender's private key
- `nonce` - Random nonce for uniqueness

**Public Inputs:**

- `message_hash` - Hash of the message
- `sender_public_key` - Sender's public key
- `timestamp` - When message was sent

**Use Cases:**

- Dispute resolution without revealing messages
- Prove delivery without exposing content
- Content moderation with privacy preservation

## 🚀 **Usage Examples**

### **Anonymous Authentication**

```javascript
// Initiate authentication for a peer
const challengeId = await zkAuthService.initiateAuthentication(peerID, 'trusted');

// Peer responds with ZK proof
const authSuccess = await zkAuthService.handleAuthResponse(peerID, challengeId, proofs);

// Check if peer is authorized
const isAuthorized = zkAuthService.isPeerAuthorized(peerID, 'trusted');
```

### **Reputation Proofs**

```javascript
// Check if user can prove required reputation
const canProve = await zkService.canProveReputation(100);

if (canProve) {
  // Generate reputation proof
  const proof = await zkService.generateReputationProof(100);
  
  // Verify proof
  const isValid = await zkService.verifyReputationProof(proof.proof, proof.publicSignals);
}
```

### **Message Authenticity**

```javascript
// Generate proof of message authenticity
const messageProof = await zkService.generateMessageProof(
  "Hello, world!",
  Date.now()
);

// Verify message proof
const isAuthentic = await zkService.verifyMessageProof(
  messageProof.proof,
  messageProof.publicSignals
);
```

## 🛠️ **Setup and Installation**

### **1. Install Noir Toolchain**

```bash
# Install Noir
npm run setup:noir

# Or manually:
curl -L https://raw.githubusercontent.com/noir-lang/noirup/main/install | bash
noirup
```

### **2. Compile Circuits**

```bash
# Build all ZK circuits
npm run build:circuits

# Or manually:
./scripts/build-circuits.sh
```

### **3. Install Dependencies**

```bash
# Install Noir JavaScript packages
npm install
```

### **4. Test ZK Functionality**

```bash
# Run ZK-specific tests
npm run test:zk
```

## 📊 **Performance Characteristics**

### **Proof Generation Times** (estimated on mobile)

- **Membership Proof**: 2-5 seconds
- **Reputation Proof**: 1-3 seconds  
- **Message Proof**: 1-2 seconds

### **Proof Sizes**

- **Membership Proof**: ~2KB
- **Reputation Proof**: ~1.5KB
- **Message Proof**: ~1KB

### **Battery Impact**

- **Performance Mode**: Full ZK features enabled
- **Balanced Mode**: ZK proofs with longer generation times
- **Power Saver**: Limited ZK functionality
- **Ultra Low Power**: ZK features disabled

## 🔒 **Security Model**

### **Privacy Guarantees**

- **Zero-Knowledge**: Proofs reveal nothing beyond the statement being proven
- **Unlinkability**: Multiple proofs from same user cannot be linked
- **Forward Secrecy**: Compromised keys don't affect past proofs
- **Soundness**: Invalid statements cannot be proven

### **Attack Resistance**

- **Replay Attacks**: Prevented by nullifiers and timestamps
- **Sybil Attacks**: Mitigated by reputation requirements
- **Collusion**: Limited by cryptographic assumptions
- **Side-Channel**: Timing randomization and cover traffic

## 🎛️ **Configuration**

### **Group Management**

```javascript
// Add new authorization group
zkAuthService.addGroup('vip', merkleRoot, 100); // Requires 100+ reputation

// Remove group
zkAuthService.removeGroup('old_group');

// List all groups
const groups = zkAuthService.getGroups();
```

### **Reputation Thresholds**

- **Public Group**: 0 reputation (anyone can join)
- **Trusted Group**: 10+ reputation
- **VIP Group**: 100+ reputation
- **Custom Groups**: Configurable thresholds

## 📈 **Monitoring and Statistics**

### **ZK Service Stats**

```javascript
const zkStats = zkService.getStats();
// {
//   proofsGenerated: 42,
//   proofsVerified: 38,
//   averageProofTime: 2500,
//   reputationScore: 85,
//   hasZKIdentity: true,
//   circuitsAvailable: { membership: true, reputation: true, messageProof: true }
// }
```

### **Authentication Stats**

```javascript
const authStats = zkAuthService.getStats();
// {
//   challengesSent: 15,
//   authSuccesses: 12,
//   authorizedPeers: 8,
//   successRate: '80.0%'
// }
```

## 🚨 **Emergency Features**

### **ZK Identity Wipe**

```javascript
// Clear all ZK identity and reputation data
await zkService.emergencyWipe();
await zkAuthService.emergencyWipe();
```

### **Triple-Tap Emergency**

The existing triple-tap logo emergency wipe now also clears:

- ZK identity keys
- Reputation data
- Authorization states
- Generated proofs

## 🔧 **Development**

### **Adding New Circuits**

1. Create circuit in `circuits/new_circuit/src/main.nr`
2. Add `Nargo.toml` configuration
3. Update build script
4. Add JavaScript integration
5. Update ZKService with new proof methods

### **Testing ZK Features**

```bash
# Test circuit compilation
nargo test --package krtr_membership

# Test JavaScript integration
npm run test:zk

# Test on device
npm run ios # or android
```

## 🎯 **Use Cases**

### **Anonymous Mesh Networks**

- Join networks without revealing identity
- Participate in discussions anonymously
- Vote on network policies privately

### **Trust Without Identity**

- Establish reputation without history exposure
- Access privileged channels based on merit
- Moderate content with anonymous authority

### **Privacy-Preserving Disputes**

- Prove message delivery without revealing content
- Resolve conflicts while maintaining privacy
- Audit network behavior anonymously

## 🚀 **Future Enhancements**

### **Advanced Circuits**

- **Range Proofs**: Prove values within ranges without revealing exact amounts
- **Set Membership**: Prove membership in dynamic sets
- **Threshold Signatures**: Collaborative signing with privacy

### **Integration Opportunities**

- **Decentralized Identity**: Integration with DID systems
- **Blockchain Anchoring**: Anchor proofs to public blockchains
- **Cross-Network**: ZK proofs across different mesh networks

---

**The KRTR ZK integration provides unprecedented privacy and anonymity for mesh networking, enabling truly decentralized and private communication systems.**
