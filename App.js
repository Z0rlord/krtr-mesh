/**
 * KRTR Mesh - Main Application
 * Decentralized, encrypted, offline-first messaging
 * Integrating components adapted from bitchat
 */

import React, { useState, useEffect, useRef } from 'react';
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  ScrollView,
  StyleSheet,
  Alert,
  StatusBar,
  SafeAreaView,
  KeyboardAvoidingView,
  Platform
} from 'react-native';

// KRTR Services
import { BluetoothMeshService } from './app/mesh/BluetoothMeshService';
import { EncryptionService } from './app/crypto/EncryptionService';
import { StoreAndForwardService } from './app/mesh/StoreAndForwardService';
import { BatteryOptimizer } from './app/mesh/BatteryOptimizer';
import { PrivacyService } from './app/privacy/PrivacyService';
import { MessageCompression, MessageFragmentation } from './app/protocols/MessageCompression';
import { ZKService } from './app/zk/ZKService';
import { ZKAuthService } from './app/zk/ZKAuthService';

export default function App() {
  // State management
  const [messages, setMessages] = useState([]);
  const [inputText, setInputText] = useState('');
  const [connectedPeers, setConnectedPeers] = useState([]);
  const [nickname, setNickname] = useState('');
  const [isInitialized, setIsInitialized] = useState(false);
  const [stats, setStats] = useState({});
  const [powerMode, setPowerMode] = useState('balanced');

  // Service references
  const meshService = useRef(null);
  const encryptionService = useRef(null);
  const storeAndForward = useRef(null);
  const batteryOptimizer = useRef(null);
  const privacyService = useRef(null);
  const compression = useRef(null);
  const fragmentation = useRef(null);
  const zkService = useRef(null);
  const zkAuthService = useRef(null);

  // UI references
  const scrollViewRef = useRef(null);
  const tapCount = useRef(0);
  const tapTimer = useRef(null);

  useEffect(() => {
    initializeServices();
    return () => {
      cleanup();
    };
  }, []);

  const initializeServices = async () => {
    try {
      console.log('[KRTR App] Initializing services...');

      // Initialize core services
      encryptionService.current = new EncryptionService();
      await encryptionService.current.initialize();

      storeAndForward.current = new StoreAndForwardService();
      batteryOptimizer.current = new BatteryOptimizer();

      compression.current = new MessageCompression();
      fragmentation.current = new MessageFragmentation();

      // Initialize ZK services
      zkService.current = new ZKService();
      await zkService.current.initialize();

      // Initialize mesh service with delegate
      meshService.current = new BluetoothMeshService({
        didReceiveMessage: handleMessageReceived,
        didConnectToPeer: handlePeerConnected,
        didDisconnectFromPeer: handlePeerDisconnected,
        didUpdatePeerList: handlePeerListUpdated,
        didReceiveDeliveryAck: handleDeliveryAck
      });

      // Initialize privacy service
      privacyService.current = new PrivacyService(
        meshService.current,
        batteryOptimizer.current
      );

      // Initialize ZK authentication service
      zkAuthService.current = new ZKAuthService(
        zkService.current,
        meshService.current
      );

      // Set up battery optimization callbacks
      batteryOptimizer.current.onPowerModeChanged = (mode, config) => {
        setPowerMode(mode);
        updateServicesForPowerMode(mode);
      };

      // Generate initial nickname
      const identity = privacyService.current.generateEphemeralIdentity();
      setNickname(identity.nickname);

      // Update stats periodically
      setInterval(updateStats, 5000);

      setIsInitialized(true);
      console.log('[KRTR App] Services initialized successfully');

    } catch (error) {
      console.error('[KRTR App] Initialization error:', error);
      Alert.alert('Initialization Error', 'Failed to initialize KRTR services');
    }
  };

  const updateServicesForPowerMode = (mode) => {
    compression.current?.updateForPowerMode(mode);
    fragmentation.current?.updateForPowerMode(mode);
    console.log(`[KRTR App] Updated services for power mode: ${mode}`);
  };

  const handleMessageReceived = (message) => {
    // Filter out cover traffic
    if (privacyService.current?.shouldDisplayMessage(message)) {
      setMessages(prev => [...prev, {
        ...message,
        id: message.id || Date.now().toString(),
        timestamp: message.timestamp || new Date(),
        isOwn: false
      }]);

      // Auto-scroll to bottom
      setTimeout(() => {
        scrollViewRef.current?.scrollToEnd({ animated: true });
      }, 100);
    }
  };

  const handlePeerConnected = (peerID) => {
    console.log(`[KRTR App] Peer connected: ${peerID}`);

    // Deliver cached messages
    storeAndForward.current?.deliverCachedMessages(peerID, meshService.current);
  };

  const handlePeerDisconnected = (peerID) => {
    console.log(`[KRTR App] Peer disconnected: ${peerID}`);
  };

  const handlePeerListUpdated = (peers) => {
    setConnectedPeers(peers);
  };

  const handleDeliveryAck = (ack) => {
    console.log(`[KRTR App] Delivery ack received:`, ack);
  };

  const sendMessage = async () => {
    if (!inputText.trim() || !isInitialized) return;

    try {
      const messageContent = inputText.trim();
      const messageId = Date.now().toString();

      // Add to local messages immediately
      const localMessage = {
        id: messageId,
        sender: nickname,
        content: messageContent,
        timestamp: new Date(),
        isOwn: true,
        deliveryStatus: 'sending'
      };

      setMessages(prev => [...prev, localMessage]);
      setInputText('');

      // Send through privacy service (with timing randomization)
      await privacyService.current.sendMessageWithPrivacy(messageContent);

      // Update message status
      setMessages(prev => prev.map(msg =>
        msg.id === messageId ? { ...msg, deliveryStatus: 'sent' } : msg
      ));

      // Auto-scroll to bottom
      setTimeout(() => {
        scrollViewRef.current?.scrollToEnd({ animated: true });
      }, 100);

    } catch (error) {
      console.error('[KRTR App] Send message error:', error);
      Alert.alert('Send Error', 'Failed to send message');
    }
  };

  const updateStats = () => {
    if (!isInitialized) return;

    const meshStats = meshService.current?.getStats() || {};
    const encryptionStats = encryptionService.current?.getStats() || {};
    const storeForwardStats = storeAndForward.current?.getStats() || {};
    const batteryStats = batteryOptimizer.current?.getStats() || {};
    const privacyStats = privacyService.current?.getStats() || {};
    const compressionStats = compression.current?.getStats() || {};
    const zkStats = zkService.current?.getStats() || {};
    const zkAuthStats = zkAuthService.current?.getStats() || {};

    setStats({
      mesh: meshStats,
      encryption: encryptionStats,
      storeForward: storeForwardStats,
      battery: batteryStats,
      privacy: privacyStats,
      compression: compressionStats,
      zk: zkStats,
      zkAuth: zkAuthStats
    });
  };

  const handleLogoTap = () => {
    tapCount.current++;

    if (tapTimer.current) {
      clearTimeout(tapTimer.current);
    }

    tapTimer.current = setTimeout(() => {
      if (tapCount.current >= 3) {
        // Triple tap detected - emergency wipe
        Alert.alert(
          'Emergency Wipe',
          'This will clear all data and reset the app. Continue?',
          [
            { text: 'Cancel', style: 'cancel' },
            { text: 'Wipe', style: 'destructive', onPress: performEmergencyWipe }
          ]
        );
      }
      tapCount.current = 0;
    }, 1000);
  };

  const performEmergencyWipe = async () => {
    try {
      await encryptionService.current?.emergencyWipe();
      await privacyService.current?.emergencyWipe();
      await storeAndForward.current?.clearCache();
      await zkService.current?.emergencyWipe();
      await zkAuthService.current?.emergencyWipe();

      setMessages([]);
      setConnectedPeers([]);

      // Generate new identity
      const identity = privacyService.current?.generateEphemeralIdentity();
      setNickname(identity?.nickname || 'Anonymous');

      Alert.alert('Emergency Wipe', 'All data has been cleared');
    } catch (error) {
      console.error('[KRTR App] Emergency wipe error:', error);
    }
  };

  const cleanup = async () => {
    try {
      await meshService.current?.disconnect();
      privacyService.current?.destroy();
      batteryOptimizer.current?.destroy();
    } catch (error) {
      console.error('[KRTR App] Cleanup error:', error);
    }
  };

  const formatTimestamp = (timestamp) => {
    return new Date(timestamp).toLocaleTimeString([], {
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  const getPowerModeColor = (mode) => {
    const colors = {
      performance: '#4CAF50',
      balanced: '#2196F3',
      powerSaver: '#FF9800',
      ultraLowPower: '#F44336'
    };
    return colors[mode] || '#2196F3';
  };

  if (!isInitialized) {
    return (
      <SafeAreaView style={styles.container}>
        <View style={styles.loadingContainer}>
          <Text style={styles.loadingText}>Initializing KRTR Mesh...</Text>
          <Text style={styles.loadingSubtext}>Setting up encryption and mesh networking</Text>
        </View>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.container}>
      <StatusBar barStyle="light-content" backgroundColor="#1a1a1a" />

      {/* Header */}
      <View style={styles.header}>
        <TouchableOpacity onPress={handleLogoTap}>
          <Text style={styles.logo}>KRTR</Text>
        </TouchableOpacity>
        <View style={styles.headerInfo}>
          <Text style={styles.nickname}>{nickname}</Text>
          <View style={[styles.powerIndicator, { backgroundColor: getPowerModeColor(powerMode) }]}>
            <Text style={styles.powerText}>{powerMode.toUpperCase()}</Text>
          </View>
        </View>
      </View>

      {/* Status Bar */}
      <View style={styles.statusBar}>
        <Text style={styles.statusText}>
          Peers: {connectedPeers.length} |
          Messages: {stats.mesh?.messagesReceived || 0} |
          Battery: {stats.battery?.batteryLevel || 0}% |
          ZK: {stats.zk?.proofsGenerated || 0} proofs
        </Text>
      </View>

      {/* Messages */}
      <ScrollView
        ref={scrollViewRef}
        style={styles.messagesContainer}
        contentContainerStyle={styles.messagesContent}
      >
        {messages.map((message) => (
          <View
            key={message.id}
            style={[
              styles.messageContainer,
              message.isOwn ? styles.ownMessage : styles.otherMessage
            ]}
          >
            <View style={styles.messageHeader}>
              <Text style={styles.messageSender}>{message.sender}</Text>
              <Text style={styles.messageTime}>
                {formatTimestamp(message.timestamp)}
              </Text>
            </View>
            <Text style={styles.messageContent}>{message.content}</Text>
            {message.deliveryStatus && (
              <Text style={styles.deliveryStatus}>{message.deliveryStatus}</Text>
            )}
          </View>
        ))}
      </ScrollView>

      {/* Input */}
      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
        style={styles.inputContainer}
      >
        <TextInput
          style={styles.textInput}
          value={inputText}
          onChangeText={setInputText}
          placeholder="Type a message..."
          placeholderTextColor="#666"
          multiline
          maxLength={1000}
        />
        <TouchableOpacity
          style={[styles.sendButton, !inputText.trim() && styles.sendButtonDisabled]}
          onPress={sendMessage}
          disabled={!inputText.trim()}
        >
          <Text style={styles.sendButtonText}>Send</Text>
        </TouchableOpacity>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#1a1a1a',
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#1a1a1a',
  },
  loadingText: {
    color: '#fff',
    fontSize: 18,
    fontWeight: 'bold',
    marginBottom: 10,
  },
  loadingSubtext: {
    color: '#888',
    fontSize: 14,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingVertical: 15,
    backgroundColor: '#2a2a2a',
    borderBottomWidth: 1,
    borderBottomColor: '#333',
  },
  logo: {
    color: '#00ff88',
    fontSize: 24,
    fontWeight: 'bold',
    fontFamily: Platform.OS === 'ios' ? 'Courier' : 'monospace',
  },
  headerInfo: {
    alignItems: 'flex-end',
  },
  nickname: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
    marginBottom: 4,
  },
  powerIndicator: {
    paddingHorizontal: 8,
    paddingVertical: 2,
    borderRadius: 10,
  },
  powerText: {
    color: '#fff',
    fontSize: 10,
    fontWeight: 'bold',
  },
  statusBar: {
    backgroundColor: '#333',
    paddingHorizontal: 20,
    paddingVertical: 8,
  },
  statusText: {
    color: '#888',
    fontSize: 12,
    fontFamily: Platform.OS === 'ios' ? 'Courier' : 'monospace',
  },
  messagesContainer: {
    flex: 1,
    backgroundColor: '#1a1a1a',
  },
  messagesContent: {
    padding: 20,
  },
  messageContainer: {
    marginBottom: 15,
    padding: 12,
    borderRadius: 12,
    maxWidth: '80%',
  },
  ownMessage: {
    alignSelf: 'flex-end',
    backgroundColor: '#00ff88',
  },
  otherMessage: {
    alignSelf: 'flex-start',
    backgroundColor: '#2a2a2a',
  },
  messageHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 4,
  },
  messageSender: {
    fontSize: 12,
    fontWeight: 'bold',
    color: '#666',
  },
  messageTime: {
    fontSize: 10,
    color: '#666',
  },
  messageContent: {
    fontSize: 16,
    color: '#fff',
    lineHeight: 20,
  },
  deliveryStatus: {
    fontSize: 10,
    color: '#888',
    marginTop: 4,
    fontStyle: 'italic',
  },
  inputContainer: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    paddingHorizontal: 20,
    paddingVertical: 15,
    backgroundColor: '#2a2a2a',
    borderTopWidth: 1,
    borderTopColor: '#333',
  },
  textInput: {
    flex: 1,
    backgroundColor: '#1a1a1a',
    color: '#fff',
    borderRadius: 20,
    paddingHorizontal: 15,
    paddingVertical: 10,
    marginRight: 10,
    maxHeight: 100,
    fontSize: 16,
  },
  sendButton: {
    backgroundColor: '#00ff88',
    paddingHorizontal: 20,
    paddingVertical: 10,
    borderRadius: 20,
  },
  sendButtonDisabled: {
    backgroundColor: '#333',
  },
  sendButtonText: {
    color: '#1a1a1a',
    fontWeight: 'bold',
    fontSize: 16,
  },
});
