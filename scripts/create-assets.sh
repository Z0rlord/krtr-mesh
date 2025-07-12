#!/bin/bash

# KRTR Asset Creation Script
# Creates required Expo assets with proper dimensions

set -e

echo "🎨 Creating KRTR Expo Assets"
echo "============================"

# Create assets directory if it doesn't exist
mkdir -p assets

# Check if ImageMagick is available
if ! command -v convert &> /dev/null; then
    echo "❌ ImageMagick not found. Installing via Homebrew..."
    if command -v brew &> /dev/null; then
        brew install imagemagick
    else
        echo "❌ Homebrew not found. Please install ImageMagick manually:"
        echo "   brew install imagemagick"
        echo "   or visit: https://imagemagick.org/script/download.php"
        exit 1
    fi
fi

echo "✅ ImageMagick available"

# Create a simple KRTR logo using ImageMagick
echo "🎯 Creating app icon (1024x1024)..."
convert -size 1024x1024 xc:'#1a1a1a' \
    -fill '#00ff88' \
    -font Arial-Bold -pointsize 200 \
    -gravity center \
    -annotate +0+0 'KRTR' \
    -fill '#ffffff' \
    -font Arial -pointsize 80 \
    -gravity center \
    -annotate +0+120 'MESH' \
    assets/icon.png

echo "✅ Created assets/icon.png"

# Create adaptive icon (foreground)
echo "🎯 Creating adaptive icon (1024x1024)..."
convert -size 1024x1024 xc:transparent \
    -fill '#00ff88' \
    -font Arial-Bold -pointsize 180 \
    -gravity center \
    -annotate +0-40 'KRTR' \
    -fill '#ffffff' \
    -font Arial -pointsize 70 \
    -gravity center \
    -annotate +0+80 'MESH' \
    assets/adaptive-icon.png

echo "✅ Created assets/adaptive-icon.png"

# Create splash screen
echo "🎯 Creating splash screen (1284x2778)..."
convert -size 1284x2778 xc:'#1a1a1a' \
    -fill '#00ff88' \
    -font Arial-Bold -pointsize 120 \
    -gravity center \
    -annotate +0-100 'KRTR' \
    -fill '#ffffff' \
    -font Arial -pointsize 60 \
    -gravity center \
    -annotate +0-20 'MESH' \
    -fill '#888888' \
    -font Arial -pointsize 40 \
    -gravity center \
    -annotate +0+60 'Decentralized Messaging' \
    -fill '#666666' \
    -font Arial -pointsize 30 \
    -gravity center \
    -annotate +0+120 'Secure • Private • Offline-First' \
    assets/splash.png

echo "✅ Created assets/splash.png"

# Create favicon for web
echo "🎯 Creating favicon (48x48)..."
convert assets/icon.png -resize 48x48 assets/favicon.png
echo "✅ Created assets/favicon.png"

echo ""
echo "🎉 All assets created successfully!"
echo ""
echo "📁 Created files:"
echo "   assets/icon.png (1024x1024) - App icon"
echo "   assets/adaptive-icon.png (1024x1024) - Android adaptive icon"
echo "   assets/splash.png (1284x2778) - Splash screen"
echo "   assets/favicon.png (48x48) - Web favicon"
echo ""
echo "✨ Ready for Expo!"
