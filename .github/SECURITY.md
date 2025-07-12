# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub issues.**

### For Security Issues

If you discover a security vulnerability in KRTR Mesh, please report it privately:

1. **Email**: Send details to [your-security-email@domain.com]
2. **Subject**: "KRTR Security Vulnerability Report"
3. **Include**:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

### Response Timeline

- **Initial Response**: Within 48 hours
- **Status Update**: Within 7 days
- **Resolution**: Varies by severity (1-30 days)

### Security Scope

**In Scope:**
- Cryptographic implementations
- Zero-knowledge proof circuits
- Mesh networking protocols
- Authentication and authorization
- Data storage and privacy
- Bluetooth LE security

**Out of Scope:**
- Social engineering attacks
- Physical device access
- Third-party dependencies (report to upstream)
- Denial of service via resource exhaustion

### Responsible Disclosure

We follow responsible disclosure practices:

1. **Private Report** → Investigation → **Fix Development** → **Testing** → **Release** → **Public Disclosure**

### Security Features

KRTR Mesh implements multiple security layers:

- **End-to-End Encryption**: AES-256-GCM with X25519 key exchange
- **Forward Secrecy**: Ephemeral keys regenerated each session
- **Zero-Knowledge Privacy**: Anonymous authentication and reputation
- **Message Authentication**: Ed25519 digital signatures
- **Traffic Analysis Resistance**: Cover traffic and timing randomization
- **Emergency Wipe**: Triple-tap data destruction

### Security Considerations

**Threat Model:**
- Passive network surveillance
- Active man-in-the-middle attacks
- Traffic analysis and metadata collection
- Device compromise and key extraction
- Reputation system manipulation

**Assumptions:**
- Devices are not physically compromised
- Bluetooth LE implementation is secure
- Cryptographic libraries are correctly implemented
- Users follow operational security practices

### Bug Bounty

Currently, KRTR Mesh does not have a formal bug bounty program. However, we appreciate security research and will acknowledge researchers who responsibly disclose vulnerabilities.

### Contact

For security-related questions or concerns:
- **Project Lead**: Zorie Barber
- **Security Email**: [your-security-email@domain.com]
- **PGP Key**: [Optional - provide PGP key for encrypted communication]

---

**Thank you for helping keep KRTR Mesh secure!**
