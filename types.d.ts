declare module '*.png';
declare module '*.jpg';
declare module '*.jpeg';
declare module '*.gif';
declare module '*.svg';
declare module '*.webp';
declare module '*.bmp';

// React Native specific declarations
declare module 'react-native-ble-plx';
declare module 'react-native-wifi-reborn';
declare module 'react-native-keychain';
declare module 'react-native-uuid';

// Environment variables
declare module '@env' {
  export const DEBUG: string;
  export const ZK_PROOF_TIMEOUT: string;
  export const ZK_CIRCUIT_CACHE: string;
  export const MESH_DISCOVERY_TIMEOUT: string;
  export const MESH_CONNECTION_TIMEOUT: string;
  export const MESH_MAX_PEERS: string;
  export const ENCRYPTION_KEY_SIZE: string;
  export const SIGNATURE_ALGORITHM: string;
  export const LOG_LEVEL: string;
  export const LOG_ZK_PROOFS: string;
  export const LOG_MESH_ACTIVITY: string;
  export const EXPO_TOKEN: string;
}
