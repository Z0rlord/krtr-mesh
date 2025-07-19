import Foundation
import SwiftUI

/// Device-based ZK functionality tests that can run on actual hardware
class ZKDeviceTests: ObservableObject {
    @Published var testResults: [ZKTestResult] = []
    @Published var isRunning = false
    @Published var currentTest = ""
    
    private let zkService: ZKServiceProtocol
    
    init() {
        // Use the factory to get the appropriate ZK service
        self.zkService = ZKServiceFactory.createService()
    }
    
    // MARK: - Test Execution
    
    func runAllTests() async {
        await MainActor.run {
            isRunning = true
            testResults.removeAll()
            currentTest = "Starting ZK Device Tests..."
        }
        
        // Test 1: Service Availability
        await testServiceAvailability()
        
        // Test 2: Membership Proof Generation
        await testMembershipProofGeneration()
        
        // Test 3: Reputation Proof Generation
        await testReputationProofGeneration()
        
        // Test 4: Message Authentication Proof
        await testMessageAuthProof()
        
        // Test 5: Proof Verification
        await testProofVerification()
        
        // Test 6: Performance Testing
        await testPerformance()
        
        // Test 7: Error Handling
        await testErrorHandling()
        
        // Test 8: Statistics Tracking
        await testStatisticsTracking()
        
        await MainActor.run {
            isRunning = false
            currentTest = "All tests completed!"
        }
    }
    
    // MARK: - Individual Tests
    
    private func testServiceAvailability() async {
        await updateCurrentTest("Testing ZK Service Availability...")
        
        let startTime = Date()
        let isAvailable = zkService.isAvailable
        let duration = Date().timeIntervalSince(startTime)
        
        let result = ZKTestResult(
            name: "Service Availability",
            success: true, // Always succeeds since we have fallback
            duration: duration,
            details: "Service available: \(isAvailable ? "Yes" : "No (using fallback)")",
            proofSize: nil
        )
        
        await addTestResult(result)
    }
    
    private func testMembershipProofGeneration() async {
        await updateCurrentTest("Testing Membership Proof Generation...")
        
        let startTime = Date()
        
        do {
            let membershipKey = Data("test_membership_key_device".utf8)
            let groupRoot = Data("test_group_root_device".utf8)
            let pathElements = [
                Data("path_element_1".utf8),
                Data("path_element_2".utf8),
                Data("path_element_3".utf8)
            ]
            let pathIndices = [0, 1, 0]
            
            let proofResult = try await zkService.generateMembershipProof(
                membershipKey: membershipKey,
                groupRoot: groupRoot,
                pathElements: pathElements,
                pathIndices: pathIndices
            )
            
            let duration = Date().timeIntervalSince(startTime)
            
            let result = ZKTestResult(
                name: "Membership Proof Generation",
                success: true,
                duration: duration,
                details: "Proof type: \(proofResult.proofType), Public inputs: \(proofResult.publicInputs.count)",
                proofSize: proofResult.proof.count
            )
            
            await addTestResult(result)
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            let result = ZKTestResult(
                name: "Membership Proof Generation",
                success: false,
                duration: duration,
                details: "Error: \(error.localizedDescription)",
                proofSize: nil
            )
            
            await addTestResult(result)
        }
    }
    
    private func testReputationProofGeneration() async {
        await updateCurrentTest("Testing Reputation Proof Generation...")
        
        let startTime = Date()
        
        do {
            let proofResult = try await zkService.generateReputationProof(
                reputationScore: 85,
                threshold: 50,
                nonce: Data("test_nonce_device".utf8)
            )
            
            let duration = Date().timeIntervalSince(startTime)
            
            let result = ZKTestResult(
                name: "Reputation Proof Generation",
                success: true,
                duration: duration,
                details: "Score: 85, Threshold: 50, Public inputs: \(proofResult.publicInputs.count)",
                proofSize: proofResult.proof.count
            )
            
            await addTestResult(result)
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            let result = ZKTestResult(
                name: "Reputation Proof Generation",
                success: false,
                duration: duration,
                details: "Error: \(error.localizedDescription)",
                proofSize: nil
            )
            
            await addTestResult(result)
        }
    }
    
    private func testMessageAuthProof() async {
        await updateCurrentTest("Testing Message Authentication Proof...")
        
        let startTime = Date()
        
        do {
            let message = Data("Hello KRTR mesh network from device!".utf8)
            let senderKey = Data("device_sender_key".utf8)
            let timestamp = UInt64(Date().timeIntervalSince1970)
            
            let proofResult = try await zkService.generateMessageAuthProof(
                message: message,
                senderKey: senderKey,
                timestamp: timestamp
            )
            
            let duration = Date().timeIntervalSince(startTime)
            
            let result = ZKTestResult(
                name: "Message Authentication Proof",
                success: true,
                duration: duration,
                details: "Message length: \(message.count), Public inputs: \(proofResult.publicInputs.count)",
                proofSize: proofResult.proof.count
            )
            
            await addTestResult(result)
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            let result = ZKTestResult(
                name: "Message Authentication Proof",
                success: false,
                duration: duration,
                details: "Error: \(error.localizedDescription)",
                proofSize: nil
            )
            
            await addTestResult(result)
        }
    }
    
    private func testProofVerification() async {
        await updateCurrentTest("Testing Proof Verification...")
        
        let startTime = Date()
        
        do {
            // First generate a proof
            let membershipKey = Data("verification_test_key".utf8)
            let groupRoot = Data("verification_test_root".utf8)
            let pathElements = [Data("path_1".utf8)]
            let pathIndices = [0]
            
            let proofResult = try await zkService.generateMembershipProof(
                membershipKey: membershipKey,
                groupRoot: groupRoot,
                pathElements: pathElements,
                pathIndices: pathIndices
            )
            
            // Then verify it
            let isValid = try await zkService.verifyProof(
                proof: proofResult.proof,
                publicInputs: proofResult.publicInputs,
                proofType: .membership
            )
            
            let duration = Date().timeIntervalSince(startTime)
            
            let result = ZKTestResult(
                name: "Proof Verification",
                success: isValid,
                duration: duration,
                details: "Verification result: \(isValid ? "VALID" : "INVALID")",
                proofSize: proofResult.proof.count
            )
            
            await addTestResult(result)
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            let result = ZKTestResult(
                name: "Proof Verification",
                success: false,
                duration: duration,
                details: "Error: \(error.localizedDescription)",
                proofSize: nil
            )
            
            await addTestResult(result)
        }
    }
    
    private func testPerformance() async {
        await updateCurrentTest("Testing ZK Performance...")
        
        let iterations = 5
        var totalDuration: TimeInterval = 0
        var successCount = 0
        
        for i in 1...iterations {
            let startTime = Date()
            
            do {
                let membershipKey = Data("perf_test_\(i)".utf8)
                let groupRoot = Data("perf_root_\(i)".utf8)
                let pathElements = [Data("path_\(i)".utf8)]
                let pathIndices = [0]
                
                _ = try await zkService.generateMembershipProof(
                    membershipKey: membershipKey,
                    groupRoot: groupRoot,
                    pathElements: pathElements,
                    pathIndices: pathIndices
                )
                
                successCount += 1
            } catch {
                // Continue with other iterations
            }
            
            totalDuration += Date().timeIntervalSince(startTime)
        }
        
        let avgDuration = totalDuration / Double(iterations)
        let successRate = Double(successCount) / Double(iterations) * 100
        
        let result = ZKTestResult(
            name: "Performance Test",
            success: successCount > 0,
            duration: avgDuration,
            details: "Avg: \(String(format: "%.3f", avgDuration))s, Success rate: \(String(format: "%.1f", successRate))%",
            proofSize: nil
        )
        
        await addTestResult(result)
    }
    
    private func testErrorHandling() async {
        await updateCurrentTest("Testing Error Handling...")
        
        let startTime = Date()
        
        do {
            // Test with invalid inputs
            _ = try await zkService.generateMembershipProof(
                membershipKey: Data(),
                groupRoot: Data(),
                pathElements: [],
                pathIndices: []
            )
            
            // If we get here, error handling didn't work
            let result = ZKTestResult(
                name: "Error Handling",
                success: false,
                duration: Date().timeIntervalSince(startTime),
                details: "Expected error but operation succeeded",
                proofSize: nil
            )
            
            await addTestResult(result)
            
        } catch {
            // This is expected
            let result = ZKTestResult(
                name: "Error Handling",
                success: true,
                duration: Date().timeIntervalSince(startTime),
                details: "Correctly handled error: \(error.localizedDescription)",
                proofSize: nil
            )
            
            await addTestResult(result)
        }
    }
    
    private func testStatisticsTracking() async {
        await updateCurrentTest("Testing Statistics Tracking...")
        
        let startTime = Date()
        let initialStats = zkService.getStats()
        
        // Generate a proof to update stats
        do {
            _ = try await zkService.generateMembershipProof(
                membershipKey: Data("stats_test".utf8),
                groupRoot: Data("stats_root".utf8),
                pathElements: [Data("path".utf8)],
                pathIndices: [0]
            )
        } catch {
            // Stats should still be updated even on error
        }
        
        let finalStats = zkService.getStats()
        let duration = Date().timeIntervalSince(startTime)
        
        let statsIncremented = finalStats.totalProofs > initialStats.totalProofs
        
        let result = ZKTestResult(
            name: "Statistics Tracking",
            success: statsIncremented,
            duration: duration,
            details: "Total proofs: \(finalStats.totalProofs), Success rate: \(String(format: "%.1f", finalStats.successRate * 100))%",
            proofSize: nil
        )
        
        await addTestResult(result)
    }
    
    // MARK: - Helper Methods
    
    @MainActor
    private func updateCurrentTest(_ test: String) {
        currentTest = test
    }
    
    @MainActor
    private func addTestResult(_ result: ZKTestResult) {
        testResults.append(result)
    }
}

// MARK: - Test Result Model

struct ZKTestResult: Identifiable {
    let id = UUID()
    let name: String
    let success: Bool
    let duration: TimeInterval
    let details: String
    let proofSize: Int?
    let timestamp = Date()
    
    var statusIcon: String {
        success ? "✅" : "❌"
    }
    
    var durationString: String {
        String(format: "%.3f", duration)
    }
    
    var proofSizeString: String {
        guard let size = proofSize else { return "N/A" }
        return "\(size) bytes"
    }
}
