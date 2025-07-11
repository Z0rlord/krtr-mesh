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
- [ ] AES-256 end-to-end encrypted messaging
- [ ] Biometric-based message decryption (FaceID / fingerprint)
- [ ] Minimal UI chat prototype
- [ ] No backend dependencies

---

## ⚙️ Tech Stack

- **React Native (Expo)** – cross-platform mobile base
- **react-native-ble-plx** – for Bluetooth LE mesh
- **libsodium / crypto.subtle** – for cryptographic layer
- **expo-local-authentication** – biometric unlock

_Note: Native implementations (MultipeerConnectivity, Nearby Connections API) can be swapped in._

---

## 🧱 Project Structure

| Folder       | Purpose                                   |
|--------------|-------------------------------------------|
| `app/`       | Core logic (mesh networking, crypto, UI)  |
| `docs/`      | Whitepaper, architecture docs             |
| `android/`   | Native Android bindings                   |
| `ios/`       | Native iOS bindings                       |

---

## 🔐 Encryption Overview

- Session key negotiated via Bluetooth handshake
- Messages encrypted using AES-256-GCM
- Optional: biometric unlock required to decrypt payload
- Long-term identity stored locally or ZK-derived

Detailed spec in [`docs/WHITEPAPER.md`](docs/WHITEPAPER.md)

---

## 📆 Roadmap

### Phase 1 – Proof of Concept (4–6 weeks)
- Bluetooth chat mesh
- Encrypted payloads
- Biometric decryption
- Local UI only

### Phase 2 – Optional Extensions
- Trust graph / identity layer
- Burn-after-read + stealth modes
- Crypto wallet hooks (ZK / MPC / UTXO opt-in)

---

## 👤 Team

- 🧠 [Your Name] — Vision, product, crypto architecture
- 🛠️ (TBD) — Mesh developer
- 🎨 (TBD) — Frontend / UX

---

## 📜 License

MIT or TBD

---

## 🕳️ We build from the edge.

> "Jack Dorsey and I have the same birthday. He’s building his version now. This is mine."