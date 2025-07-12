/**
 * KRTR Battery Optimizer - Adaptive power management for mesh networking
 * Advanced battery optimization with 4-tier power management
 */

import { DeviceEventEmitter, NativeModules } from 'react-native';

// Power modes for different battery levels
export const PowerMode = {
  PERFORMANCE: 'performance', // Charging or >60% battery
  BALANCED: 'balanced', // 30-60% battery
  POWER_SAVER: 'powerSaver', // 10-30% battery
  ULTRA_LOW_POWER: 'ultraLowPower', // <10% battery
};

export class BatteryOptimizer {
  constructor() {
    this.currentPowerMode = PowerMode.BALANCED;
    this.batteryLevel = 1.0; // 100%
    this.isCharging = false;
    this.isBackgrounded = false;

    // Callbacks
    this.onPowerModeChanged = null;
    this.onBatteryLevelChanged = null;

    // Power mode configurations
    this.powerModeConfigs = {
      [PowerMode.PERFORMANCE]: {
        scanDuration: 3000, // 3 seconds
        pauseDuration: 2000, // 2 seconds
        advertisingInterval: 100, // 100ms
        maxConnections: 20,
        messageAggregationWindow: 100, // 100ms
        enableCoverTraffic: true,
        compressionThreshold: 100, // bytes
      },
      [PowerMode.BALANCED]: {
        scanDuration: 2000, // 2 seconds
        pauseDuration: 3000, // 3 seconds
        advertisingInterval: 500, // 500ms
        maxConnections: 10,
        messageAggregationWindow: 250, // 250ms
        enableCoverTraffic: true,
        compressionThreshold: 100, // bytes
      },
      [PowerMode.POWER_SAVER]: {
        scanDuration: 1000, // 1 second
        pauseDuration: 8000, // 8 seconds
        advertisingInterval: 1500, // 1.5s
        maxConnections: 5,
        messageAggregationWindow: 500, // 500ms
        enableCoverTraffic: false,
        compressionThreshold: 50, // bytes
      },
      [PowerMode.ULTRA_LOW_POWER]: {
        scanDuration: 500, // 0.5 seconds
        pauseDuration: 20000, // 20 seconds
        advertisingInterval: 3000, // 3s
        maxConnections: 2,
        messageAggregationWindow: 1000, // 1s
        enableCoverTraffic: false,
        compressionThreshold: 50, // bytes
      },
    };

    this.initialize();
  }

  async initialize() {
    try {
      // Get initial battery state
      await this.updateBatteryState();

      // Set up battery monitoring
      this.setupBatteryMonitoring();

      // Set up app state monitoring
      this.setupAppStateMonitoring();

      // Initial power mode calculation
      this.updatePowerMode();

      console.log('[KRTR Battery] Battery optimizer initialized');
    } catch (error) {
      console.error('[KRTR Battery] Initialization error:', error);
    }
  }

  async updateBatteryState() {
    try {
      // Try to get battery info from native modules
      if (NativeModules.BatteryManager) {
        const batteryInfo = await NativeModules.BatteryManager.getBatteryInfo();
        this.batteryLevel = batteryInfo.level;
        this.isCharging = batteryInfo.isCharging;
      } else {
        // Fallback: simulate battery monitoring
        console.warn(
          '[KRTR Battery] Native battery module not available, using simulation'
        );
        this.simulateBatteryMonitoring();
      }
    } catch (error) {
      console.error('[KRTR Battery] Battery state update error:', error);
      // Use default values
      this.batteryLevel = 0.8; // 80%
      this.isCharging = false;
    }
  }

  setupBatteryMonitoring() {
    // Listen for battery level changes
    const batterySubscription = DeviceEventEmitter.addListener(
      'BatteryLevelChanged',
      batteryInfo => {
        const oldLevel = this.batteryLevel;
        const oldCharging = this.isCharging;

        this.batteryLevel = batteryInfo.level;
        this.isCharging = batteryInfo.isCharging;

        // Check if power mode should change
        if (this.shouldUpdatePowerMode(oldLevel, oldCharging)) {
          this.updatePowerMode();
        }

        // Notify callback
        this.onBatteryLevelChanged?.(this.batteryLevel, this.isCharging);
      }
    );

    // Check battery periodically as fallback
    this.batteryCheckInterval = setInterval(() => {
      this.updateBatteryState();
    }, 30 * 1000); // Every 30 seconds
  }

  setupAppStateMonitoring() {
    // Listen for app state changes
    const appStateSubscription = DeviceEventEmitter.addListener(
      'AppStateChanged',
      appState => {
        const wasBackgrounded = this.isBackgrounded;
        this.isBackgrounded = appState === 'background';

        if (wasBackgrounded !== this.isBackgrounded) {
          this.updatePowerMode();
        }
      }
    );
  }

  shouldUpdatePowerMode(oldLevel, oldCharging) {
    // Check if we've crossed battery thresholds
    const oldMode = this.calculatePowerMode(
      oldLevel,
      oldCharging,
      this.isBackgrounded
    );
    const newMode = this.calculatePowerMode(
      this.batteryLevel,
      this.isCharging,
      this.isBackgrounded
    );

    return oldMode !== newMode;
  }

  calculatePowerMode(batteryLevel, isCharging, isBackgrounded) {
    // If charging or high battery, use performance mode
    if (isCharging || batteryLevel > 0.6) {
      return isBackgrounded ? PowerMode.BALANCED : PowerMode.PERFORMANCE;
    }

    // If backgrounded, always use power saver
    if (isBackgrounded) {
      return batteryLevel > 0.3
        ? PowerMode.POWER_SAVER
        : PowerMode.ULTRA_LOW_POWER;
    }

    // Battery-based power modes
    if (batteryLevel > 0.3) {
      return PowerMode.BALANCED;
    } else if (batteryLevel > 0.1) {
      return PowerMode.POWER_SAVER;
    } else {
      return PowerMode.ULTRA_LOW_POWER;
    }
  }

  updatePowerMode() {
    const newMode = this.calculatePowerMode(
      this.batteryLevel,
      this.isCharging,
      this.isBackgrounded
    );

    if (newMode !== this.currentPowerMode) {
      const oldMode = this.currentPowerMode;
      this.currentPowerMode = newMode;

      console.log(
        `[KRTR Battery] Power mode changed: ${oldMode} -> ${newMode} (battery: ${Math.round(
          this.batteryLevel * 100
        )}%, charging: ${this.isCharging}, background: ${this.isBackgrounded})`
      );

      // Notify callback
      this.onPowerModeChanged?.(newMode, this.getPowerModeConfig(newMode));
    }
  }

  simulateBatteryMonitoring() {
    // Simulate gradual battery drain for testing
    let simulatedLevel = 0.8;
    let simulatedCharging = false;

    setInterval(() => {
      if (!simulatedCharging) {
        simulatedLevel -= 0.01; // 1% per interval
        if (simulatedLevel <= 0.1) {
          simulatedCharging = true; // Start charging when low
        }
      } else {
        simulatedLevel += 0.02; // 2% per interval when charging
        if (simulatedLevel >= 1.0) {
          simulatedLevel = 1.0;
          simulatedCharging = false; // Stop charging when full
        }
      }

      const oldLevel = this.batteryLevel;
      const oldCharging = this.isCharging;

      this.batteryLevel = simulatedLevel;
      this.isCharging = simulatedCharging;

      if (this.shouldUpdatePowerMode(oldLevel, oldCharging)) {
        this.updatePowerMode();
      }
    }, 60 * 1000); // Every minute
  }

  // Public API
  getCurrentPowerMode() {
    return this.currentPowerMode;
  }

  getPowerModeConfig(mode = null) {
    const targetMode = mode || this.currentPowerMode;
    return { ...this.powerModeConfigs[targetMode] };
  }

  getBatteryLevel() {
    return this.batteryLevel;
  }

  isChargingNow() {
    return this.isCharging;
  }

  isInBackgroundMode() {
    return this.isBackgrounded;
  }

  // Get optimized settings for specific operations
  getScanSettings() {
    const config = this.getPowerModeConfig();
    return {
      scanDuration: config.scanDuration,
      pauseDuration: config.pauseDuration,
      dutyCycle:
        config.scanDuration / (config.scanDuration + config.pauseDuration),
    };
  }

  getAdvertisingSettings() {
    const config = this.getPowerModeConfig();
    return {
      interval: config.advertisingInterval,
      txPowerLevel:
        this.currentPowerMode === PowerMode.ULTRA_LOW_POWER ? 'low' : 'medium',
    };
  }

  getConnectionSettings() {
    const config = this.getPowerModeConfig();
    return {
      maxConnections: config.maxConnections,
      connectionTimeout:
        this.currentPowerMode === PowerMode.ULTRA_LOW_POWER ? 10000 : 5000,
    };
  }

  getMessageSettings() {
    const config = this.getPowerModeConfig();
    return {
      aggregationWindow: config.messageAggregationWindow,
      enableCoverTraffic: config.enableCoverTraffic,
      compressionThreshold: config.compressionThreshold,
    };
  }

  // Force power mode (for testing or manual override)
  forcePowerMode(mode) {
    if (Object.values(PowerMode).includes(mode)) {
      this.currentPowerMode = mode;
      this.onPowerModeChanged?.(mode, this.getPowerModeConfig(mode));
      console.log(`[KRTR Battery] Forced power mode: ${mode}`);
    }
  }

  // Get battery statistics
  getStats() {
    return {
      batteryLevel: Math.round(this.batteryLevel * 100),
      isCharging: this.isCharging,
      isBackgrounded: this.isBackgrounded,
      currentPowerMode: this.currentPowerMode,
      powerModeConfig: this.getPowerModeConfig(),
    };
  }

  // Cleanup
  destroy() {
    if (this.batteryCheckInterval) {
      clearInterval(this.batteryCheckInterval);
    }

    // Remove event listeners
    DeviceEventEmitter.removeAllListeners('BatteryLevelChanged');
    DeviceEventEmitter.removeAllListeners('AppStateChanged');

    console.log('[KRTR Battery] Battery optimizer destroyed');
  }
}
