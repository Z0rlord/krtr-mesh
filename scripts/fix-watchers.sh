#!/bin/bash

# KRTR File Watcher Fix Script
# Increases file descriptor limits for macOS development

echo "🔧 Fixing file watcher limits for KRTR development..."

# Check current limits
echo "Current file descriptor limits:"
echo "  Soft limit: $(ulimit -n)"
echo "  Hard limit: $(ulimit -Hn)"

# Increase limits for current session
ulimit -n 65536

echo "✅ Increased file descriptor limit to 65536"

# Create launchctl plist for permanent fix
PLIST_FILE="$HOME/Library/LaunchAgents/limit.maxfiles.plist"

if [ ! -f "$PLIST_FILE" ]; then
    echo "📝 Creating permanent file limit configuration..."
    
    cat > "$PLIST_FILE" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>limit.maxfiles</string>
    <key>ProgramArguments</key>
    <array>
      <string>launchctl</string>
      <string>limit</string>
      <string>maxfiles</string>
      <string>65536</string>
      <string>200000</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>ServiceIPC</key>
    <false/>
  </dict>
</plist>
EOF

    # Load the plist
    launchctl load "$PLIST_FILE" 2>/dev/null || echo "⚠️  Could not load plist (may require restart)"
    
    echo "✅ Created permanent file limit configuration"
    echo "   You may need to restart your terminal or computer for full effect"
else
    echo "✅ Permanent file limit configuration already exists"
fi

echo ""
echo "🎯 Now you can run:"
echo "   npm start    # Start development server"
echo "   npm run ios  # Test on iOS (requires Xcode)"
echo ""
echo "📱 Alternative: Use Expo Go app to scan QR code for testing"
