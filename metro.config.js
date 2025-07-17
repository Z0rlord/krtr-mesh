const { getDefaultConfig } = require('expo/metro-config');
const path = require('path');

const config = getDefaultConfig(__dirname);

// Specify the entry file for iOS
config.resolver.sourceExts = ['js', 'jsx', 'json', 'ts', 'tsx', 'native.js'];
config.resolver.platforms = ['ios', 'android', 'native', 'web'];

// Set the entry file for iOS to index.native.js
config.resolver.resolverMainFields = ['react-native', 'browser', 'main'];

module.exports = config;
