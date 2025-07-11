# Krtr Mesh

**Decentralized, encrypted, offline-first messaging for the post-platform era.**

> Built from the blackout. Inspired by the streets. Whispered across devices.

---

## 🔥 Why Krtr?

After witnessing the collapse of communications post-Hurricane Maria, and watching centralized platforms fail the privacy test again and again, Krtr Mesh is a protocol built to enable:

- Peer-to-peer messaging over Bluetooth and WiFi Direct
- End-to-end encryption with biometric unlock
- No servers. No surveillance. No internet required

Think: AirDrop meets Signal — offline.

---

## 💡 MVP Features (Phase 1)

- [x] Device discovery via Bluetooth / WiFi mesh
- [x] Ephemeral session key generation
- [x] AES-256 end-to-end encrypted messaging
- [x] Store-and-forward for offline peers
- [x] Battery optimization with adaptive power modes
- [x] Privacy features: cover traffic, timing randomization
- [x] Message compression and fragmentation
- [x] Emergency wipe capability

---

## ⚙️ Tech Stack

- **React Native (Expo)** – cross-platform mobile base
- **react-native-ble-plx** – for Bluetooth LE mesh
- **react-native-sodium** – for cryptographic layer
- **LZ4 compression** – bandwidth optimization
- **AsyncStorage** – persistent message caching

_Note: Native implementations (MultipeerConnectivity, Nearby Connections API) can be swapped in._

---

## 🧱 Project Structure

| Folder       | Purpose                                   |
|--------------|-------------------------------------------|
| `app/mesh/`  | Bluetooth mesh networking services       |
| `app/crypto/`| Encryption and key management            |
| `app/privacy/`| Privacy features and cover traffic      |
| `app/protocols/`| Binary protocol and compression       |
| `docs/`      | Documentation and setup guides          |

---

## 🔐 Encryption Overview

- **X25519 key exchange** – Secure key agreement with forward secrecy
- **AES-256-GCM** – Authenticated encryption for messages
- **Ed25519 signatures** – Message authenticity verification
- **Argon2id** – Password-based key derivation for channels
- **Ephemeral keys** – New key pairs generated each session

Detailed architecture in [`docs/INTEGRATION_SUMMARY.md`](docs/INTEGRATION_SUMMARY.md)

---

## 🚀 Features

### Mesh Networking
- **Multi-hop routing** with TTL-based forwarding (max 7 hops)
- **Store-and-forward** for offline message delivery
- **Automatic peer discovery** via BLE advertising
- **Connection management** with adaptive limits (2-20 connections)

### Privacy & Security
- **Cover traffic** generation to prevent traffic analysis
- **Timing randomization** (50-500ms delays) to prevent correlation
- **Ephemeral identities** with no persistent tracking
- **Emergency wipe** via triple-tap logo activation

### Performance
- **LZ4 compression** with 30-70% bandwidth savings
- **Message fragmentation** for large payloads (>500 bytes)
- **Battery optimization** with 4-tier power management
- **Binary protocol** for efficient transmission

---

## 📆 Roadmap

### Phase 1 – Core Implementation ✅
- Bluetooth mesh networking
- End-to-end encryption
- Store-and-forward messaging
- Battery optimization
- Privacy features

### Phase 2 – Advanced Features
- Channel management with IRC-style commands
- WiFi Direct transport for high bandwidth
- File sharing capabilities
- Network topology visualization

### Phase 3 – Ecosystem Integration
- Nostr protocol bridging for internet relay
- Multi-transport bonding (BLE + WiFi + LoRa)
- Integration with crypto wallets
- Decentralized identity systems

---

## 👤 Team

- 🧠 **Zorie Barber** — Vision, product, crypto architecture
- 🛠️ (TBD) — Mesh developer
- 🎨 (TBD) — Frontend / UX

---

## 📜 License

MIT

---

## 🕳️ We build from the edge.

> "Decentralized by design. Privacy by default. Built for the people."
