const path = require('path');
const { getDefaultConfig, mergeConfig } = require('@react-native/metro-config');

// The library's React Native sources are one folder up (ReactNative/src): Metro watches that folder.
const library = path.resolve(__dirname, '..');

module.exports = mergeConfig(getDefaultConfig(__dirname), {
  watchFolders: [library],
  resolver: { nodeModulesPaths: [path.join(__dirname, 'node_modules')] },
});
