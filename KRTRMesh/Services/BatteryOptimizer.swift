/**
 * KRTR Battery Optimizer - Intelligent power management for mesh networking
 * Adapts scanning, advertising, and connection parameters based on battery level
 */

import Foundation
import Combine
import os.log

#if os(macOS)
import IOKit.ps
#else
import UIKit
#endif

// MARK: - Battery Optimizer
class BatteryOptimizer: ObservableObject {
    static let shared = BatteryOptimizer()
    
    @Published var batteryLevel: Float = 1.0
    @Published var currentPowerMode: PowerMode = .balanced
    @Published var isInBackground: Bool = false
    
    private var batteryMonitorTimer: Timer?
    private let monitoringInterval: TimeInterval = 30.0 // Check every 30 seconds
    
    // Scan parameters for different power modes
    var scanParameters: ScanParameters {
        switch currentPowerMode {
        case .performance:
            return ScanParameters(duration: 10.0, pause: 2.0)
        case .balanced:
            return ScanParameters(duration: 5.0, pause: 10.0)
        case .powerSaver:
            return ScanParameters(duration: 3.0, pause: 20.0)
        case .ultraLowPower:
            return ScanParameters(duration: 1.0, pause: 60.0)
        }
    }
    
    private init() {
        setupBatteryMonitoring()
        setupBackgroundNotifications()
        updateBatteryLevel()
        updatePowerMode()
    }
    
    deinit {
        batteryMonitorTimer?.invalidate()
    }
    
    // MARK: - Battery Monitoring
    
    private func setupBatteryMonitoring() {
        batteryMonitorTimer = Timer.scheduledTimer(withTimeInterval: monitoringInterval, repeats: true) { [weak self] _ in
            self?.updateBatteryLevel()
            self?.updatePowerMode()
        }
    }
    
    private func updateBatteryLevel() {
        #if os(macOS)
        batteryLevel = getMacOSBatteryLevel()
        #else
        UIDevice.current.isBatteryMonitoringEnabled = true
        batteryLevel = UIDevice.current.batteryLevel
        #endif
        
        SecurityLogger.log("Battery level updated: \(Int(batteryLevel * 100))%", category: SecurityLogger.mesh, level: .debug)
    }
    
    #if os(macOS)
    private func getMacOSBatteryLevel() -> Float {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array
        
        for source in sources {
            let sourceInfo = IOPSGetPowerSourceDescription(snapshot, source).takeUnretainedValue() as! [String: Any]
            
            if let type = sourceInfo[kIOPSTypeKey] as? String,
               type == kIOPSInternalBatteryType,
               let capacity = sourceInfo[kIOPSCurrentCapacityKey] as? Int,
               let maxCapacity = sourceInfo[kIOPSMaxCapacityKey] as? Int,
               maxCapacity > 0 {
                return Float(capacity) / Float(maxCapacity)
            }
        }
        
        return 1.0 // Default to full battery if not found
    }
    #endif
    
    private func updatePowerMode() {
        let newPowerMode: PowerMode
        
        if isInBackground {
            // More aggressive power saving in background
            if batteryLevel > 0.5 {
                newPowerMode = .powerSaver
            } else {
                newPowerMode = .ultraLowPower
            }
        } else {
            // Normal power management in foreground
            if batteryLevel > 0.8 {
                newPowerMode = .performance
            } else if batteryLevel > 0.5 {
                newPowerMode = .balanced
            } else if batteryLevel > 0.2 {
                newPowerMode = .powerSaver
            } else {
                newPowerMode = .ultraLowPower
            }
        }
        
        if newPowerMode != currentPowerMode {
            SecurityLogger.log("Power mode changed: \(currentPowerMode) -> \(newPowerMode)", category: SecurityLogger.mesh, level: .info)
            currentPowerMode = newPowerMode
        }
    }
    
    // MARK: - Background Notifications
    
    private func setupBackgroundNotifications() {
        #if os(macOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: NSApplication.didHideNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: NSApplication.didUnhideNotification,
            object: nil
        )
        #else
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        #endif
    }
    
    @objc private func appDidEnterBackground() {
        isInBackground = true
        updatePowerMode()
        SecurityLogger.log("App entered background, adjusting power mode", category: SecurityLogger.mesh, level: .info)
    }
    
    @objc private func appWillEnterForeground() {
        isInBackground = false
        updatePowerMode()
        SecurityLogger.log("App entering foreground, adjusting power mode", category: SecurityLogger.mesh, level: .info)
    }
    
    // MARK: - Power Management Recommendations
    
    func shouldReduceConnections() -> Bool {
        return currentPowerMode == .powerSaver || currentPowerMode == .ultraLowPower
    }
    
    func shouldPauseScanning() -> Bool {
        return currentPowerMode == .ultraLowPower && isInBackground
    }
    
    func shouldReduceAdvertising() -> Bool {
        return currentPowerMode == .powerSaver || currentPowerMode == .ultraLowPower
    }
    
    func getRecommendedMaxConnections() -> Int {
        return currentPowerMode.maxConnections
    }
    
    func getRecommendedMessageAggregationWindow() -> TimeInterval {
        return currentPowerMode.messageAggregationWindow
    }
    
    func getRecommendedAdvertisingInterval() -> TimeInterval {
        return currentPowerMode.advertisingInterval
    }
    
    // MARK: - Statistics
    
    func getBatteryStats() -> BatteryStats {
        return BatteryStats(
            currentLevel: batteryLevel,
            powerMode: currentPowerMode,
            isInBackground: isInBackground,
            scanParameters: scanParameters
        )
    }
}

// MARK: - Supporting Structures

struct ScanParameters {
    let duration: TimeInterval
    let pause: TimeInterval
}

struct BatteryStats {
    let currentLevel: Float
    let powerMode: PowerMode
    let isInBackground: Bool
    let scanParameters: ScanParameters
    
    var levelPercentage: Int {
        return Int(currentLevel * 100)
    }
    
    var description: String {
        return "Battery: \(levelPercentage)%, Mode: \(powerMode), Background: \(isInBackground)"
    }
}
