# KRTR Mesh Setup Guide

This guide will help you set up and run the KRTR mesh networking application.

## 📋 Prerequisites

### Development Environment
- **Node.js** 16+ and npm/yarn
- **React Native CLI** or **Expo CLI**
- **Android Studio** (for Android development)
- **Xcode** (for iOS development, macOS only)

### Platform Requirements
- **iOS**: iOS 13.0+ (for Bluetooth LE support)
- **Android**: Android 6.0+ (API level 23+) with Bluetooth LE

## 🚀 Quick Start

### 1. Install Dependencies
```bash
# Clone the repository
git clone <your-repo-url>
cd krtr-mesh

# Install dependencies
npm install
# or
yarn install
```

### 2. Platform Setup

#### iOS Setup
```bash
cd ios
pod install
cd ..
```

Add Bluetooth permissions to `ios/krtr-mesh/Info.plist`:
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>KRTR needs Bluetooth to connect with nearby devices for mesh networking</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>KRTR needs Bluetooth to advertise to nearby devices for mesh networking</string>
```

#### Android Setup
Add permissions to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
```

### 3. Run the Application

#### Using Expo (Recommended for development)
```bash
npx expo start
```

#### Using React Native CLI
```bash
# For iOS
npx react-native run-ios

# For Android
npx react-native run-android
```

## 🔧 Configuration

### Environment Variables
Create a `.env` file in the root directory:
```env
# KRTR Configuration
KRTR_SERVICE_UUID=6E400001-B5A3-F393-E0A9-E50E24DCCA9E
KRTR_CHARACTERISTIC_UUID=6E400002-B5A3-F393-E0A9-E50E24DCCA9E

# Debug settings
DEBUG_MESH_NETWORKING=true
DEBUG_ENCRYPTION=false
DEBUG_PRIVACY=false
```

### Power Mode Settings
The app automatically adjusts based on battery level, but you can force specific modes:

- **Performance**: Full features, maximum connections
- **Balanced**: Standard operation (default)
- **Power Saver**: Reduced scanning, fewer connections
- **Ultra Low Power**: Minimal operation for emergency use

## 📱 Usage

### Basic Operation
1. **Launch the app** - Services initialize automatically
2. **Set nickname** - Generated automatically or customize
3. **Connect to peers** - Automatic discovery and connection
4. **Send messages** - Type and send to all connected peers

### Advanced Features

#### Private Messages
```
/msg @username Your private message here
```

#### Channel Commands
```
/join #channelname          # Join or create channel
/leave #channelname         # Leave channel
/channels                   # List available channels
```

#### System Commands
```
/who                        # List connected peers
/stats                      # Show network statistics
/clear                      # Clear message history
```

#### Emergency Features
- **Triple-tap logo** - Emergency wipe of all data
- **Background mode** - Automatic power optimization

## 🔐 Security Features

### Encryption
- **X25519 key exchange** - Secure key agreement
- **AES-256-GCM** - Authenticated encryption
- **Ed25519 signatures** - Message authenticity
- **Forward secrecy** - New keys each session

### Privacy
- **Cover traffic** - Dummy messages prevent analysis
- **Timing randomization** - Prevents correlation attacks
- **Ephemeral identities** - No persistent tracking
- **Emergency wipe** - Instant data destruction

## 🔍 Troubleshooting

### Common Issues

#### Bluetooth Not Working
1. Check device Bluetooth is enabled
2. Verify app has Bluetooth permissions
3. Restart the app
4. Check platform-specific requirements

#### No Peers Found
1. Ensure other devices are running KRTR
2. Check devices are within Bluetooth range (~30m)
3. Verify same app version/protocol
4. Check for interference from other devices

#### Messages Not Sending
1. Verify peer connections in status bar
2. Check battery optimization settings
3. Ensure app is in foreground
4. Try restarting mesh service

#### High Battery Usage
1. App automatically optimizes for battery level
2. Force power saver mode if needed
3. Reduce number of connections
4. Disable cover traffic in settings

### Debug Information

#### Enable Debug Logging
Set environment variables:
```env
DEBUG_MESH_NETWORKING=true
DEBUG_ENCRYPTION=true
DEBUG_PRIVACY=true
```

#### View Statistics
Tap the status bar to view detailed network statistics:
- Connected peers
- Messages sent/received
- Battery optimization status
- Compression efficiency
- Privacy feature status

## 🛠 Development

### Project Structure
```
krtr-mesh/
├── App.js                 # Main application
├── app/
│   ├── mesh/             # Mesh networking services
│   ├── crypto/           # Encryption services
│   ├── privacy/          # Privacy features
│   └── protocols/        # Protocol definitions
├── docs/                 # Documentation
└── ios/android/          # Platform-specific code
```

### Adding Features
1. **New message types** - Add to `KrtrProtocol.js`
2. **Encryption methods** - Extend `EncryptionService.js`
3. **Privacy features** - Modify `PrivacyService.js`
4. **UI components** - Add to `App.js` or create new components

### Testing
```bash
# Run tests
npm test

# Run linting
npm run lint

# Format code
npm run format
```

## 📚 Additional Resources

- [React Native BLE Documentation](https://github.com/dotintent/react-native-ble-plx)
- [libsodium Crypto Library](https://libsodium.gitbook.io/doc/)
- [Bluetooth LE Specifications](https://www.bluetooth.com/specifications/bluetooth-core-specification/)
- [bitchat Original Project](https://github.com/permissionlesstech/bitchat)

## 🆘 Support

### Getting Help
1. Check this documentation
2. Review troubleshooting section
3. Check GitHub issues
4. Create new issue with debug logs

### Contributing
1. Fork the repository
2. Create feature branch
3. Make changes with tests
4. Submit pull request

**Project Lead**: Zorie Barber

## 🔒 Security Considerations

### Production Deployment
- Review all cryptographic implementations
- Conduct security audit
- Test emergency wipe functionality
- Verify no data leakage

### Privacy Best Practices
- Use ephemeral identities
- Enable cover traffic
- Regular emergency wipes
- Avoid persistent identifiers

---

**Note**: KRTR is experimental software. Use at your own risk and conduct thorough testing before production use.
