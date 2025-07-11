const { getDefaultConfig } = require('expo/metro-config');

const config = getDefaultConfig(__dirname);

// Add support for Noir circuits and ZK proof files
config.resolver.assetExts.push('json', 'nr', 'toml');

// Support for larger JavaScript bundles (needed for ZK libraries)
config.transformer.minifierConfig = {
  keep_fnames: true,
  mangle: {
    keep_fnames: true,
  },
};

// Increase bundle size limits for ZK proof libraries
config.transformer.maxWorkers = 2;

module.exports = config;
