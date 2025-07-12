const { getDefaultConfig } = require('expo/metro-config');

const config = getDefaultConfig(__dirname);

// Enable TypeScript support
config.resolver.sourceExts.push('ts', 'tsx');

// Add TypeScript transformer
config.transformer.babelTransformerPath = require.resolve('@expo/metro-config/babel-transformer');

module.exports = config;
