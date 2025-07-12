# KRTR EAS Workflows

This directory contains automated workflows for building, updating, and deploying the KRTR mesh networking app.

## 🚀 Available Workflows

### Build Workflows

#### `build-ios-preview.yml`
- **Purpose**: Creates iOS builds compatible with Expo Go
- **Triggers**: Push to `main` branch
- **Profile**: `preview` (internal distribution, simulator compatible)
- **Usage**: Perfect for testing with Expo Go on iOS

#### `build-android-preview.yml`
- **Purpose**: Creates Android builds compatible with Expo Go
- **Triggers**: Push to `main` branch
- **Profile**: `preview` (APK format for easy distribution)
- **Usage**: Perfect for testing with Expo Go on Android

#### `build-both-platforms.yml`
- **Purpose**: Builds both iOS and Android simultaneously
- **Triggers**: Manual dispatch only
- **Profile**: `preview` for both platforms
- **Usage**: For comprehensive testing

### Update Workflows

#### `publish-update.yml`
- **Purpose**: Publishes over-the-air updates
- **Triggers**: Push to `main` branch
- **Usage**: Deploy updates without app store approval

## 🛠️ Manual Workflow Execution

You can run any workflow manually using the EAS CLI:

```bash
# Build iOS preview (Expo Go compatible)
eas workflow:run build-ios-preview.yml

# Build Android preview
eas workflow:run build-android-preview.yml

# Build all platforms
eas workflow:run build-all-platforms.yml

# Publish OTA update
eas workflow:run publish-update.yml

# Development build
eas workflow:run development-build.yml
```

## 📱 Expo Go Compatibility

The `preview` profile builds are specifically configured for Expo Go compatibility:

- **iOS**: Builds for simulator and device testing
- **Android**: Creates APK files for easy installation
- **Distribution**: Internal distribution for team testing

## 🔗 GitHub Integration

To enable automatic workflow triggers:

1. Go to your [EAS project GitHub settings](https://expo.dev/accounts/z0rlord/projects/krtr-mesh/github)
2. Install the GitHub app if not already installed
3. Connect this repository (`Z0rlord/krtr-mesh`)
4. Workflows will automatically trigger on pushes to specified branches

## 🎯 Workflow Triggers

- **Main branch**: Triggers production-ready builds and updates
- **Develop branch**: Triggers preview builds and development builds
- **Feature branches**: Triggers development builds only
- **Manual dispatch**: All workflows can be triggered manually

## 📊 Monitoring

Monitor your workflows at:
- [EAS Dashboard](https://expo.dev/accounts/z0rlord/projects/krtr-mesh)
- [GitHub Actions](https://github.com/Z0rlord/krtr-mesh/actions) (if using GitHub integration)

## 🔧 Customization

You can customize workflows by:
- Editing the YAML files in this directory
- Modifying build profiles in `eas.json`
- Adding environment variables in EAS project settings
- Configuring different triggers and conditions
