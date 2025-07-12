#!/bin/bash

# KRTR iOS Testing Script
# Comprehensive iOS testing setup and deployment

set -e

echo "📱 KRTR iOS Testing Setup"
echo "========================"

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
    echo "✅ Loaded environment variables"
else
    echo "❌ .env file not found"
    exit 1
fi

# Check Expo authentication
echo "🔐 Checking Expo authentication..."
EXPO_USER=$(npx expo whoami 2>/dev/null || echo "not-authenticated")
if [ "$EXPO_USER" = "not-authenticated" ]; then
    echo "❌ Not authenticated with Expo"
    echo "   Run: export EXPO_TOKEN=$EXPO_TOKEN"
    exit 1
else
    echo "✅ Authenticated as: $EXPO_USER"
fi

# Check for Xcode
echo "🔨 Checking development environment..."
if command -v xcodebuild &> /dev/null; then
    XCODE_VERSION=$(xcodebuild -version | head -n 1)
    echo "✅ $XCODE_VERSION found"
    HAS_XCODE=true
else
    echo "⚠️  Xcode not found - will use Expo Go instead"
    HAS_XCODE=false
fi

# Fix file watcher limits
echo "🔧 Setting file descriptor limits..."
ulimit -n 65536
echo "✅ File descriptor limit set to $(ulimit -n)"

# Test ZK functionality first
echo "🧪 Testing ZK functionality..."
if npm run test:zk --silent; then
    echo "✅ ZK tests passed"
else
    echo "⚠️  Some ZK tests failed - check implementation"
fi

echo ""
echo "🚀 Choose your testing method:"
echo ""

if [ "$HAS_XCODE" = true ]; then
    echo "Option 1: iOS Simulator (Recommended)"
    echo "   Command: npm run ios"
    echo ""
    echo "Option 2: Development Build"
    echo "   Command: npx eas build --platform ios --profile development"
    echo ""
fi

echo "Option 3: Expo Go (Works without Xcode)"
echo "   1. Install Expo Go from App Store"
echo "   2. Run: npm start"
echo "   3. Scan QR code with iPhone camera"
echo ""

echo "Option 4: Web Testing (Quick validation)"
echo "   Command: npm run web"
echo ""

# Provide specific commands based on environment
if [ "$HAS_XCODE" = true ]; then
    echo "🎯 Starting iOS Simulator..."
    echo "   Running: npm run ios"
    echo ""
    
    # Try to start iOS
    npm run ios
else
    echo "🎯 Starting Expo Go development server..."
    echo "   Running: npm start"
    echo ""
    echo "📱 Instructions:"
    echo "   1. Install Expo Go on your iPhone"
    echo "   2. Scan the QR code that appears"
    echo "   3. Test ZK features on your device"
    echo ""
    
    # Start development server
    npm start
fi
