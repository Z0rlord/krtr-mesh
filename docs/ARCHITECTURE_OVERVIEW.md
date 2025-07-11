# KRTR Architecture Overview

This document provides a comprehensive overview of the KRTR mesh networking architecture, detailing the core components and their interactions.

## 🏗️ **System Architecture**

KRTR is built as a layered architecture that provides decentralized, encrypted, and privacy-preserving mesh networking capabilities.

```
┌─────────────────────────────────────────────────────────────┐
│                        KRTR App                             │
├─────────────────────────────────────────────────────────────┤
│  ZK Auth Service    │  Privacy Service  │  Battery Optimizer │
├─────────────────────────────────────────────────────────────┤
│              Bluetooth Mesh Service                         │
├─────────────────────────────────────────────────────────────┤
│  ZK Service        │  Encryption       │  Store & Forward   │
├─────────────────────────────────────────────────────────────┤
│  Compression       │  Fragmentation    │  Binary Protocol   │
├─────────────────────────────────────────────────────────────┤
│                  React Native BLE                           │
└─────────────────────────────────────────────────────────────┘
```

## 🔧 **Core Components**

### **1. Mesh Networking Layer**
**BluetoothMeshService** - The foundation of KRTR's networking capabilities

**Key Features:**
- **Dual Role Architecture**: Each device acts as both central (client) and peripheral (server)
- **Automatic Peer Discovery**: BLE service UUID-based discovery with RSSI tracking
- **Multi-hop Routing**: TTL-based message forwarding (max 7 hops) with loop prevention
- **Connection Management**: Handles BLE connection limits and automatic reconnection
- **Message Deduplication**: Prevents circular routing with bloom filters

**Technical Implementation:**
- Service UUID: `6E400001-B5A3-F393-E0A9-E50E24DCCA9E`
- Characteristic UUID: `6E400002-B5A3-F393-E0A9-E50E24DCCA9E`
- Connection limits: 2-20 based on battery state
- Scan duty cycling: Adaptive based on power mode

### **2. Encryption & Security**
**EncryptionService** - End-to-end encryption with forward secrecy

**Cryptographic Stack:**
- **X25519 Key Exchange**: Elliptic curve Diffie-Hellman for secure key agreement
- **AES-256-GCM**: Authenticated encryption for message confidentiality
- **Ed25519 Signatures**: Digital signatures for message authenticity
- **Argon2id**: Password-based key derivation for channels
- **Ephemeral Keys**: New key pairs generated each session

**Security Features:**
- Forward secrecy with session-based keys
- Identity key management for persistent relationships
- Channel encryption for group communications
- Emergency wipe capability

### **3. Zero-Knowledge Privacy**
**ZKService & ZKAuthService** - Anonymous authentication and private reputation

**ZK Capabilities:**
- **Anonymous Authentication**: Prove membership without revealing identity
- **Private Reputation**: Establish trust without exposing interaction history
- **Selective Disclosure**: Prove message authenticity without revealing content
- **Group Authorization**: Access control with cryptographic privacy

**Noir Circuits:**
- **Membership Circuit**: Anonymous group membership proofs
- **Reputation Circuit**: Private reputation verification
- **Message Proof Circuit**: Content authenticity without revelation

### **4. Store-and-Forward System**
**StoreAndForwardService** - Offline message delivery

**Features:**
- **Tiered Retention**: Regular (12hr) vs favorite peer (indefinite) storage
- **Automatic Delivery**: Cached messages sent when peers reconnect
- **Delivery Tracking**: Acknowledgments and read receipts
- **Persistent Storage**: AsyncStorage for message persistence
- **Cache Management**: Intelligent cleanup and size limits

### **5. Privacy Protection**
**PrivacyService** - Traffic analysis resistance

**Privacy Features:**
- **Cover Traffic**: Random dummy messages to prevent traffic analysis
- **Timing Randomization**: 50-500ms delays to prevent correlation attacks
- **Ephemeral Identities**: Random nicknames per session
- **Message Padding**: Uniform message sizes to prevent size analysis

### **6. Performance Optimization**
**Compression & Fragmentation** - Bandwidth and reliability optimization

**Compression (LZ4):**
- 30-70% bandwidth savings for text messages
- Entropy detection to avoid compressing encrypted data
- Adaptive thresholds based on power mode

**Fragmentation:**
- Automatic splitting of large messages (>500 bytes)
- Reliable reassembly with timeout handling
- Fragment deduplication and ordering

### **7. Battery Management**
**BatteryOptimizer** - Adaptive power management

**Power Modes:**
- **Performance** (Charging/>60%): Full features, 20 connections
- **Balanced** (30-60%): Standard operation, 10 connections
- **Power Saver** (10-30%): Reduced scanning, 5 connections
- **Ultra Low Power** (<10%): Minimal operation, 2 connections

**Adaptive Features:**
- Dynamic duty cycling for BLE scanning
- Connection limit adjustment
- Feature enablement based on battery state
- Background mode optimization

## 📊 **Data Flow Architecture**

### **Message Sending Flow**
1. **User Input** → App UI
2. **Privacy Processing** → Timing randomization, padding
3. **Compression** → LZ4 compression if beneficial
4. **Fragmentation** → Split large messages
5. **Encryption** → AES-256-GCM with peer keys
6. **Protocol Encoding** → Binary packet structure
7. **Mesh Routing** → TTL-based forwarding
8. **BLE Transmission** → Bluetooth Low Energy

### **Message Receiving Flow**
1. **BLE Reception** → Bluetooth Low Energy
2. **Protocol Decoding** → Binary packet parsing
3. **Routing Decision** → Local delivery or relay
4. **Decryption** → AES-256-GCM decryption
5. **Reassembly** → Fragment reconstruction
6. **Decompression** → LZ4 decompression
7. **Privacy Filtering** → Cover traffic removal
8. **UI Display** → Message presentation

### **ZK Authentication Flow**
1. **Challenge Generation** → Random challenge with group requirements
2. **Proof Generation** → Noir circuit execution
3. **Proof Transmission** → Encrypted proof delivery
4. **Proof Verification** → Circuit verification
5. **Authorization Grant** → Access permission storage

## 🔐 **Security Model**

### **Threat Model**
KRTR is designed to resist:
- **Passive Surveillance**: Traffic analysis and metadata collection
- **Active Attacks**: Man-in-the-middle and message injection
- **Network Analysis**: Topology discovery and relationship mapping
- **Reputation Attacks**: Sybil attacks and reputation manipulation

### **Security Guarantees**
- **Confidentiality**: Messages encrypted with AES-256-GCM
- **Authenticity**: Ed25519 signatures verify message origin
- **Integrity**: Authenticated encryption prevents tampering
- **Forward Secrecy**: Compromised keys don't affect past communications
- **Anonymity**: Zero-knowledge proofs hide user identities
- **Unlinkability**: Multiple interactions cannot be correlated

### **Privacy Properties**
- **Sender Anonymity**: ZK proofs hide message senders
- **Recipient Privacy**: Encrypted recipient fields
- **Content Privacy**: End-to-end encryption
- **Metadata Privacy**: Cover traffic and timing randomization
- **Relationship Privacy**: No persistent identifiers

## 📈 **Performance Characteristics**

### **Latency**
- **Direct Connection**: 50-200ms message delivery
- **Multi-hop (3 hops)**: 200-800ms message delivery
- **ZK Proof Generation**: 1-5 seconds on mobile
- **Store-and-Forward**: Immediate on peer reconnection

### **Throughput**
- **Text Messages**: 100-500 messages/minute per connection
- **Compressed Data**: 30-70% bandwidth savings
- **Fragmented Messages**: Reliable delivery up to 10KB
- **Concurrent Connections**: 2-20 based on battery state

### **Resource Usage**
- **Battery Impact**: Adaptive based on power mode
- **Memory Usage**: ~50MB for full feature set
- **Storage**: Configurable cache limits (default 100MB)
- **CPU Usage**: Optimized for mobile processors

## 🛠️ **Development Architecture**

### **Modular Design**
Each component is designed as an independent module with clear interfaces:
- **Service Layer**: Core functionality (mesh, crypto, ZK)
- **Protocol Layer**: Message formats and encoding
- **Transport Layer**: Bluetooth Low Energy abstraction
- **Application Layer**: React Native UI and user interaction

### **Extensibility**
The architecture supports easy extension:
- **New Transports**: WiFi Direct, LoRa, etc.
- **Additional Circuits**: New ZK proof types
- **Enhanced Privacy**: Additional anonymity features
- **Protocol Evolution**: Backward-compatible updates

### **Testing Strategy**
- **Unit Tests**: Individual component testing
- **Integration Tests**: Cross-component functionality
- **Network Tests**: Multi-device mesh testing
- **Security Tests**: Cryptographic verification
- **Performance Tests**: Battery and throughput optimization

## 🚀 **Future Architecture Evolution**

### **Planned Enhancements**
- **Multi-Transport**: Simultaneous BLE + WiFi Direct + LoRa
- **Advanced ZK**: Range proofs, set membership, threshold signatures
- **Network Bridging**: Optional internet relay via Nostr protocol
- **Mesh Optimization**: Dynamic routing and topology optimization

### **Scalability Considerations**
- **Network Size**: Designed for 10-100 node local meshes
- **Message Volume**: Optimized for conversational traffic
- **Geographic Distribution**: Local area network focus
- **Bandwidth Efficiency**: Compression and fragmentation optimization

---

**The KRTR architecture provides a robust foundation for decentralized, private, and secure mesh networking, designed by Zorie Barber for the post-platform era.**
