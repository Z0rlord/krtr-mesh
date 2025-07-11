# KRTR Expo Development Guide

This guide covers using Expo for KRTR mesh networking development, testing, and deployment.

## 🚀 **Why Expo for KRTR**

### **Perfect for Mesh Testing**
- **Multi-Device Testing**: Deploy to multiple devices instantly for mesh network testing
- **Hot Reload**: Real-time code changes while testing peer connections
- **Tunnel Mode**: Test mesh networking across different networks
- **Easy Distribution**: Share builds with testers via QR codes

### **Production Ready**
- **App Store Deployment**: Seamless iOS and Android store submission
- **Over-the-Air Updates**: Push mesh protocol updates without app store approval
- **Background Processing**: Full support for Bluetooth mesh networking
- **Native Modules**: Complete access to BLE, crypto, and ZK libraries

## 🛠️ **Setup Instructions**

### **1. Install Expo CLI**
```bash
# Install Expo CLI globally
npm install -g @expo/cli

# Install EAS CLI for builds
npm install -g eas-cli
```

### **2. Initialize Expo Project**
```bash
# Already configured! Just install dependencies
npm install

# Login to Expo (optional, for builds)
expo login
```

### **3. Development Workflow**

#### **Local Development**
```bash
# Start development server
npm start

# Start with tunnel (for testing across networks)
npm run start:tunnel

# Start development client (for custom native modules)
npm run start:dev
```

#### **Device Testing**
```bash
# Run on iOS simulator
npm run ios

# Run on Android emulator
npm run android

# Scan QR code with Expo Go app for physical device testing
```

### **4. Mesh Network Testing**

#### **Multi-Device Setup**
1. **Install Expo Go** on multiple physical devices
2. **Connect to same network** or use tunnel mode
3. **Scan QR code** on all devices
4. **Test mesh connectivity** between devices

#### **Bluetooth Testing**
```bash
# Enable development build for BLE testing
expo install expo-dev-client
npm run start:dev
```

**Note**: Bluetooth LE requires physical devices - simulators don't support BLE.

## 🏗️ **Building & Distribution**

### **Development Builds**
```bash
# Build development version with custom native modules
npm run build:android
npm run build:ios

# Install on device for testing
# iOS: Use TestFlight or direct install
# Android: Install APK directly
```

### **Preview Builds**
```bash
# Build preview version for testing
eas build --profile preview

# Share with testers
eas build:list
```

### **Production Builds**
```bash
# Build for app stores
npm run build:all

# Submit to stores
npm run submit:ios
npm run submit:android
```

## 📱 **Over-the-Air Updates**

### **Update Mesh Protocol**
```bash
# Push updates without app store approval
npm run update

# Update specific channel
eas update --channel production --message "Mesh protocol improvements"
```

### **Update Channels**
- **Development**: Latest features and experiments
- **Preview**: Beta testing with testers
- **Production**: Stable releases for app store users

## 🔧 **Configuration**

### **App Configuration** (`app.json`)
Key settings for KRTR:

```json
{
  "expo": {
    "name": "KRTR Mesh",
    "slug": "krtr-mesh",
    "scheme": "krtr",
    "ios": {
      "bundleIdentifier": "com.krtr.mesh",
      "infoPlist": {
        "NSBluetoothAlwaysUsageDescription": "KRTR needs Bluetooth for mesh networking",
        "UIBackgroundModes": ["bluetooth-central", "bluetooth-peripheral"]
      }
    },
    "android": {
      "package": "com.krtr.mesh",
      "permissions": [
        "android.permission.BLUETOOTH",
        "android.permission.BLUETOOTH_SCAN",
        "android.permission.BLUETOOTH_ADVERTISE",
        "android.permission.BLUETOOTH_CONNECT"
      ]
    }
  }
}
```

### **Build Configuration** (`eas.json`)
Optimized for mesh networking:

```json
{
  "build": {
    "development": {
      "developmentClient": true,
      "distribution": "internal"
    },
    "preview": {
      "distribution": "internal"
    },
    "production": {}
  }
}
```

## 🧪 **Testing Strategies**

### **Mesh Network Testing**
1. **Single Device**: Test UI and basic functionality
2. **Two Devices**: Test peer discovery and basic messaging
3. **Multiple Devices**: Test multi-hop routing and store-and-forward
4. **Network Stress**: Test with many peers and high message volume

### **ZK Proof Testing**
```bash
# Test ZK functionality specifically
npm run test:zk

# Test on device with development build
# ZK proofs require actual device performance testing
```

### **Battery Testing**
```bash
# Test battery optimization
# Monitor battery usage during mesh networking
# Test different power modes
```

## 📊 **Performance Monitoring**

### **Expo Analytics**
- **Crash Reporting**: Automatic crash detection and reporting
- **Performance Metrics**: App startup time, memory usage
- **Update Success**: OTA update installation rates

### **Custom Metrics**
```javascript
// Track mesh networking performance
import { Analytics } from 'expo-analytics';

// Track mesh events
Analytics.track('mesh_peer_connected', {
  peerCount: connectedPeers.length,
  batteryLevel: batteryLevel
});
```

## 🚀 **Deployment Workflow**

### **Development Cycle**
1. **Code Changes** → Hot reload testing
2. **Device Testing** → Multi-device mesh testing
3. **Preview Build** → Beta tester distribution
4. **Production Build** → App store submission
5. **OTA Updates** → Protocol improvements

### **Release Strategy**
- **Major Updates**: App store releases for new features
- **Protocol Updates**: OTA updates for mesh improvements
- **Security Patches**: Immediate OTA deployment
- **ZK Circuit Updates**: Development builds for testing

## 🔒 **Security Considerations**

### **Code Signing**
```bash
# Set up code signing for iOS
eas credentials

# Configure Android signing
# Upload keystore to EAS
```

### **Environment Variables**
```bash
# Set production secrets
eas secret:create --scope project --name API_KEY --value "your-secret"

# Use in app.json
"extra": {
  "apiKey": "$API_KEY"
}
```

## 🎯 **Best Practices**

### **Development**
- **Use Development Builds** for BLE and ZK testing
- **Test on Physical Devices** for accurate mesh performance
- **Use Tunnel Mode** for cross-network testing
- **Monitor Performance** with Expo analytics

### **Distribution**
- **Preview Builds** for beta testing mesh features
- **OTA Updates** for protocol improvements
- **App Store Builds** for major feature releases
- **TestFlight** for iOS beta distribution

### **Mesh Testing**
- **Start Small**: Test with 2-3 devices first
- **Scale Gradually**: Add more devices to test limits
- **Test Edge Cases**: Network disconnections, battery drain
- **Real-World Testing**: Different environments and distances

---

**Expo provides the perfect development and distribution platform for KRTR's mesh networking capabilities, enabling rapid iteration and seamless deployment across iOS and Android.**
