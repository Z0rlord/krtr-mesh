#!/bin/bash

# KRTR Expo Setup Script
# Sets up Expo authentication and project configuration

set -e

echo "🚀 KRTR Expo Setup"
echo "=================="

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
    echo "✅ Loaded environment variables from .env"
else
    echo "❌ .env file not found"
    exit 1
fi

# Check if EXPO_TOKEN is set
if [ -z "$EXPO_TOKEN" ]; then
    echo "❌ EXPO_TOKEN not found in .env file"
    exit 1
fi

echo "🔐 Authenticating with Expo..."
export EXPO_TOKEN=$EXPO_TOKEN

# Check authentication
EXPO_USER=$(npx expo whoami 2>/dev/null || echo "not-authenticated")
if [ "$EXPO_USER" = "not-authenticated" ]; then
    echo "❌ Failed to authenticate with Expo"
    exit 1
else
    echo "✅ Authenticated as: $EXPO_USER"
fi

# Check project status
echo "📱 Checking project configuration..."

# Try to get project info
PROJECT_INFO=$(npx expo config --type public 2>/dev/null || echo "")
if [ -n "$PROJECT_INFO" ]; then
    echo "✅ Project configuration loaded"
else
    echo "⚠️  Project configuration may need updates"
fi

echo ""
echo "🎯 Next steps:"
echo "   1. Run 'npm start' to start development server"
echo "   2. Run 'npm run ios' to test on iOS"
echo "   3. Run 'npm run android' to test on Android"
echo "   4. Run 'npm run build:ios' or 'npm run build:android' to build"
echo ""
echo "✨ KRTR Expo setup complete!"
