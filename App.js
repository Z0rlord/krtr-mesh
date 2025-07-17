import React from 'react';
import { View, Text, StyleSheet } from 'react-native';

// Simple component for KRTR Mesh app
function KRTRMeshApp() {
  return (
    <View style={styles.container}>
      <Text style={styles.title}>KRTR Mesh</Text>
      <Text style={styles.subtitle}>Decentralized Mesh Network</Text>
      <Text style={styles.status}>✅ App loaded successfully!</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#1a1a1a',
  },
  title: {
    color: '#00ff88',
    fontSize: 32,
    fontWeight: 'bold',
    marginBottom: 20,
  },
  subtitle: {
    color: '#fff',
    fontSize: 18,
    marginBottom: 10,
  },
  status: {
    color: '#00ff88',
    fontSize: 16,
    fontWeight: '600',
  },
});

export default KRTRMeshApp;
