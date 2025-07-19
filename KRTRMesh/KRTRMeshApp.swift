/**
 * KRTR Mesh - Swift Native Implementation
 * Decentralized, encrypted, offline-first messaging
 * Advanced mesh networking with zero-knowledge privacy
 */

import SwiftUI
import os.log

#if os(macOS)
import AppKit
#else
import UIKit
#endif

@main
struct KRTRMeshApp: App {
    @StateObject private var chatViewModel = ChatViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(chatViewModel)
                .onAppear {
                    setupApp()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                    cleanup()
                }
        }
    }
    
    private func setupApp() {
        // Configure logging
        setupLogging()
        
        // Start mesh services
        chatViewModel.startServices()
        
        // Log app startup
        SecurityLogger.log("KRTR Mesh started", category: SecurityLogger.app, level: .info)
    }
    
    private func cleanup() {
        // Cleanup on app termination
        chatViewModel.cleanup()
        SecurityLogger.log("KRTR Mesh terminated", category: SecurityLogger.app, level: .info)
    }
    
    private func setupLogging() {
        // Configure security logging
        SecurityLogger.configure()
    }
}

// MARK: - Security Logger
class SecurityLogger {
    static let app = OSLog(subsystem: "com.krtr.mesh", category: "app")
    static let mesh = OSLog(subsystem: "com.krtr.mesh", category: "mesh")
    static let encryption = OSLog(subsystem: "com.krtr.mesh", category: "encryption")
    static let noise = OSLog(subsystem: "com.krtr.mesh", category: "noise")
    static let session = OSLog(subsystem: "com.krtr.mesh", category: "session")
    static let zk = OSLog(subsystem: "com.krtr.mesh", category: "zk")
    
    static func configure() {
        // Configure logging levels based on build configuration
        #if DEBUG
        // Debug builds: verbose logging
        #else
        // Release builds: minimal logging for security
        #endif
    }
    
    static func log(_ message: String, category: OSLog, level: OSLogType = .default) {
        os_log("%{public}@", log: category, type: level, message)
    }
    
    static func logError(_ error: Error, context: String, category: OSLog) {
        os_log("Error in %{public}@: %{public}@", log: category, type: .error, context, error.localizedDescription)
    }
    
    static func logSecurityEvent(_ event: SecurityEvent) {
        switch event {
        case .handshakeCompleted(let peerID):
            log("Handshake completed with peer: \(peerID)", category: noise, level: .info)
        case .sessionEstablished(let peerID):
            log("Session established with peer: \(peerID)", category: session, level: .info)
        case .unauthorizedAccess(let context):
            log("Unauthorized access attempt: \(context)", category: encryption, level: .error)
        }
    }
}

// MARK: - Security Events
enum SecurityEvent {
    case handshakeCompleted(peerID: String)
    case sessionEstablished(peerID: String)
    case unauthorizedAccess(context: String)
}
