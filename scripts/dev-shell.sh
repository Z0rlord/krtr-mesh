#!/bin/bash

# KRTR Mesh Development Shell Startup Script
# Source this in your ~/.zshrc or run manually: source scripts/dev-shell.sh

echo "🚀 KRTR Mesh Development Environment"
echo "===================================="

# Project-specific environment variables
export KRTR_PROJECT_ROOT="$(pwd)"
export KRTR_SERVICE_UUID="6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
export KRTR_CHARACTERISTIC_UUID="6E400002-B5A3-F393-E0A9-E50E24DCCA9E"

# Development flags
export DEBUG_MESH_NETWORKING=true
export DEBUG_ENCRYPTION=false
export DEBUG_PRIVACY=false
export EXPO_DEVTOOLS_LISTEN_ADDRESS=0.0.0.0

# Node.js optimization for React Native
export NODE_OPTIONS="--max-old-space-size=8192"
export WATCHMAN_MAX_FILES=100000

# iOS Development
export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
export FASTLANE_SKIP_UPDATE_CHECK=1

# Useful aliases for KRTR development
alias krtr-start="npm start"
alias krtr-ios="npm run ios"
alias krtr-android="npm run android"
alias krtr-build-ios="npm run build:ios"
alias krtr-build-android="npm run build:android"
alias krtr-test="npm test"
alias krtr-test-zk="npm run test:zk"
alias krtr-test-mesh="npm run test:mesh"
alias krtr-circuits="npm run build:circuits"
alias krtr-setup="npm run setup:expo"
alias krtr-clean="rm -rf node_modules && npm install"
alias krtr-reset="npx expo r -c"
alias krtr-doctor="npx expo doctor"

# Git aliases for mesh development
alias gst="git status"
alias gco="git checkout"
alias gcb="git checkout -b"
alias gp="git push"
alias gl="git pull"
alias glog="git log --oneline --graph --decorate"

# Quick project navigation
alias cdkrtr="cd $KRTR_PROJECT_ROOT"
alias cdapp="cd $KRTR_PROJECT_ROOT/app"
alias cdscripts="cd $KRTR_PROJECT_ROOT/scripts"
alias cddocs="cd $KRTR_PROJECT_ROOT/docs"

# Development utilities
krtr-status() {
    echo "📊 KRTR Mesh Project Status"
    echo "=========================="
    echo "📁 Project: $(basename $PWD)"
    echo "🌿 Branch: $(git branch --show-current 2>/dev/null || echo 'Not a git repo')"
    echo "📦 Node: $(node --version)"
    echo "⚛️  Expo: $(npx expo --version 2>/dev/null || echo 'Not installed')"
    echo "📱 iOS Ready: $([ -f ios/Podfile.lock ] && echo '✅ Yes' || echo '❌ No')"
    echo "🤖 Android Ready: $([ -d android ] && echo '✅ Yes' || echo '❌ No')"
    echo "🔧 Circuits: $([ -d app/zk/circuits ] && echo '✅ Built' || echo '❌ Not built')"
    echo ""
}

krtr-quick-test() {
    echo "🧪 Quick KRTR Test Suite"
    echo "======================="
    npm run test:zk --silent && echo "✅ ZK tests passed" || echo "❌ ZK tests failed"
    npm run test:mesh --silent && echo "✅ Mesh tests passed" || echo "❌ Mesh tests failed"
    npx expo doctor --fix-dependencies --non-interactive 2>/dev/null && echo "✅ Expo health check passed" || echo "⚠️  Expo issues detected"
}

krtr-dev-setup() {
    echo "🔧 KRTR Development Setup"
    echo "========================"
    
    # Fix file watchers
    ulimit -n 65536
    echo "✅ File descriptor limit: $(ulimit -n)"
    
    # Check dependencies
    if [ ! -d "node_modules" ]; then
        echo "📦 Installing dependencies..."
        npm install
    fi
    
    # Build circuits if needed
    if [ ! -d "app/zk/circuits" ]; then
        echo "🔧 Building ZK circuits..."
        npm run build:circuits 2>/dev/null || echo "⚠️  Circuit build failed (Noir may not be installed)"
    fi
    
    # iOS setup
    if [ -d "ios" ] && [ ! -f "ios/Podfile.lock" ]; then
        echo "📱 Setting up iOS dependencies..."
        cd ios && pod install && cd ..
    fi
    
    echo "✅ Development environment ready!"
    krtr-status
}

# Auto-setup when entering KRTR directory
if [[ "$(basename $PWD)" == *"krtr"* ]]; then
    echo "📡 KRTR Mesh project detected"
    echo "💡 Run 'krtr-dev-setup' for full environment setup"
    echo "💡 Run 'krtr-status' to check project health"
    echo "💡 Run 'krtr-quick-test' for rapid testing"
    echo ""
fi

# Show available commands
krtr-help() {
    echo "🚀 KRTR Mesh Development Commands"
    echo "================================"
    echo ""
    echo "🏃 Quick Start:"
    echo "  krtr-dev-setup    - Full development environment setup"
    echo "  krtr-start        - Start development server"
    echo "  krtr-ios          - Run on iOS simulator"
    echo "  krtr-android      - Run on Android emulator"
    echo ""
    echo "🧪 Testing:"
    echo "  krtr-test         - Run all tests"
    echo "  krtr-test-zk      - Test zero-knowledge functionality"
    echo "  krtr-test-mesh    - Test mesh networking"
    echo "  krtr-quick-test   - Rapid test suite"
    echo ""
    echo "🔧 Build & Deploy:"
    echo "  krtr-build-ios    - Build iOS app"
    echo "  krtr-build-android- Build Android app"
    echo "  krtr-circuits     - Compile ZK circuits"
    echo ""
    echo "🛠️  Utilities:"
    echo "  krtr-status       - Show project status"
    echo "  krtr-clean        - Clean and reinstall dependencies"
    echo "  krtr-reset        - Reset Expo cache"
    echo "  krtr-doctor       - Run Expo diagnostics"
    echo ""
}

echo "✅ KRTR development environment loaded"
echo "💡 Type 'krtr-help' to see available commands"