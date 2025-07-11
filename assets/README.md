# KRTR Assets

This directory contains the app icons and splash screens for KRTR Mesh.

## Required Assets

### App Icons
- `icon.png` - 1024x1024px app icon
- `adaptive-icon.png` - 1024x1024px Android adaptive icon foreground
- `favicon.png` - 32x32px web favicon

### Splash Screen
- `splash.png` - 1284x2778px splash screen image

## Design Guidelines

### Colors
- **Primary**: #00ff88 (KRTR Green)
- **Background**: #1a1a1a (Dark)
- **Secondary**: #2a2a2a (Dark Gray)

### Style
- Minimalist design
- Monospace/terminal aesthetic
- Dark theme optimized
- High contrast for accessibility

## Generating Assets

You can use Expo's asset generation tools:

```bash
# Generate all required sizes
npx expo install expo-asset-utils
npx expo-asset-utils generate-icons icon.png
```

## Placeholder Assets

Until custom assets are created, you can use Expo's default assets or create simple placeholder images with the KRTR branding.
