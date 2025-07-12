# 📱 KRTR iOS Testing Guide

## 🎯 **Your KRTR Project is Ready!**

**Project:** `@z0rlord/krtr-mesh`  
**Project ID:** `aeeba0cd-2e0e-46aa-99c7-6e63472094b0`  
**Owner:** `z0rlord`  
**Status:** ✅ Synced with Expo.dev

## 🚀 **Testing Options**

### **Option 1: Direct Expo Go Link (Recommended)**

**Open this link in Expo Go:**
```
exp://u.expo.dev/aeeba0cd-2e0e-46aa-99c7-6e63472094b0
```

**Or scan this QR code in Expo Go:**
- Open Expo Go app on your iPhone
- Tap "Scan QR Code"
- Scan the QR code from your development server

### **Option 2: Search in Expo Go**

1. Open **Expo Go** on your iPhone
2. Search for: `@z0rlord/krtr-mesh`
3. Tap to open your KRTR app

### **Option 3: Development Build (In Progress)**

The full development build is being created on Expo's servers. You'll receive a link when it's ready.

## 🧪 **What You Can Test**

### **✅ Zero-Knowledge Features:**
- **Anonymous Authentication** - Test group-based auth without revealing identity
- **Membership Proofs** - Prove you belong to a group without revealing which member
- **Reputation Proofs** - Prove reputation threshold without revealing exact score
- **Message Authenticity** - Prove message authorship without revealing sender

### **✅ Mesh Networking:**
- **Peer Discovery** - Find nearby KRTR devices
- **Bluetooth Mesh** - Connect multiple devices
- **Store-and-Forward** - Offline message routing
- **Encrypted Messaging** - End-to-end encrypted communications

### **✅ Privacy Features:**
- **Face ID/Touch ID** - Biometric authentication
- **Triple-Tap Emergency** - Quick data wipe
- **Selective Disclosure** - Share only necessary information

## 📊 **ZK Circuit Status**

All three Noir circuits are compiled and ready:

1. **✅ Membership Circuit** (`circuits/membership/`)
   - Proves group membership anonymously
   - Tree depth: 20 levels
   - Status: Compiled and tested

2. **✅ Reputation Circuit** (`circuits/reputation/`)
   - Proves reputation threshold privately
   - Supports complex reputation calculations
   - Status: Compiled and tested

3. **✅ Message Proof Circuit** (`circuits/message_proof/`)
   - Proves message authenticity
   - Supports selective disclosure
   - Status: Compiled and tested

## 🔧 **Troubleshooting**

### **If Expo Go Times Out:**
1. Make sure you're connected to the same WiFi network
2. Try the direct link: `exp://u.expo.dev/aeeba0cd-2e0e-46aa-99c7-6e63472094b0`
3. Search for `@z0rlord/krtr-mesh` in Expo Go

### **If App Crashes:**
1. Check that your iPhone supports the required features:
   - iOS 11+ for Face ID integration
   - Bluetooth LE for mesh networking
   - Sufficient storage for ZK circuits

### **For Full iOS Features:**
- Wait for the development build to complete
- Install via TestFlight or direct install
- This gives you full Bluetooth mesh networking

## 🎉 **Success Indicators**

When the app loads successfully, you should see:

1. **✅ KRTR Mesh Logo** - App initialized
2. **✅ "Initializing KRTR Mesh..."** - Services starting
3. **✅ Main Interface** - Ready for testing
4. **✅ ZK Services Active** - Zero-knowledge proofs ready

## 📞 **Next Steps**

1. **Test on iPhone** using Expo Go
2. **Try ZK features** - Generate and verify proofs
3. **Test with multiple devices** - Same QR code works on all devices
4. **Report any issues** - ZK functionality should work perfectly

Your KRTR mesh networking app with full zero-knowledge proof capabilities is ready for testing! 🚀
