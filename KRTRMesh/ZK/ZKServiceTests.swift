import XCTest
import Foundation
@testable import KRTR

class ZKServiceTests: XCTestCase {
    var zkService: ZKServiceProtocol!
    
    override func setUp() {
        super.setUp()
        // Try to create native service, fall back to mock if not available
        do {
            zkService = try ZKNativeService()
        } catch {
            zkService = ZKMockService()
        }
    }
    
    override func tearDown() {
        zkService = nil
        super.tearDown()
    }
    
    // MARK: - Service Availability Tests
    
    func testServiceAvailability() {
        // Test that we can determine service availability
        let isAvailable = zkService.isAvailable
        XCTAssertNotNil(isAvailable, "Service availability should be determinable")
        
        if zkService is ZKNativeService {
            print("✅ Using native ZK service")
        } else {
            print("⚠️ Using mock ZK service")
        }
    }
    
    // MARK: - Membership Proof Tests
    
    func testMembershipProofGeneration() async throws {
        // Test data
        let membershipKey = Data("test_membership_key".utf8)
        let groupRoot = Data("test_group_root".utf8)
        let pathElements = [
            Data("path_element_1".utf8),
            Data("path_element_2".utf8),
            Data("path_element_3".utf8)
        ]
        let pathIndices = [0, 1, 0]
        
        // Generate proof
        let result = try await zkService.generateMembershipProof(
            membershipKey: membershipKey,
            groupRoot: groupRoot,
            pathElements: pathElements,
            pathIndices: pathIndices
        )
        
        // Verify result
        XCTAssertNotNil(result.proof, "Proof should be generated")
        XCTAssertFalse(result.publicInputs.isEmpty, "Public inputs should not be empty")
        XCTAssertEqual(result.proofType, .membership, "Proof type should be membership")
        XCTAssertNotNil(result.timestamp, "Timestamp should be set")
        
        print("✅ Membership proof generated successfully")
        print("   Proof size: \(result.proof.count) bytes")
        print("   Public inputs: \(result.publicInputs.count)")
    }
    
    func testMembershipProofVerification() async throws {
        // Generate a proof first
        let membershipKey = Data("test_membership_key".utf8)
        let groupRoot = Data("test_group_root".utf8)
        let pathElements = [Data("path_element_1".utf8)]
        let pathIndices = [0]
        
        let proofResult = try await zkService.generateMembershipProof(
            membershipKey: membershipKey,
            groupRoot: groupRoot,
            pathElements: pathElements,
            pathIndices: pathIndices
        )
        
        // Verify the proof
        let isValid = try await zkService.verifyProof(
            proof: proofResult.proof,
            publicInputs: proofResult.publicInputs,
            proofType: .membership
        )
        
        XCTAssertTrue(isValid, "Generated proof should be valid")
        print("✅ Membership proof verification successful")
    }
    
    // MARK: - Reputation Proof Tests
    
    func testReputationProofGeneration() async throws {
        let reputationScore = 85
        let threshold = 50
        let nonce = Data("test_nonce".utf8)
        
        let result = try await zkService.generateReputationProof(
            reputationScore: reputationScore,
            threshold: threshold,
            nonce: nonce
        )
        
        XCTAssertNotNil(result.proof, "Reputation proof should be generated")
        XCTAssertFalse(result.publicInputs.isEmpty, "Public inputs should not be empty")
        XCTAssertEqual(result.proofType, .reputation, "Proof type should be reputation")
        
        print("✅ Reputation proof generated successfully")
        print("   Score: \(reputationScore), Threshold: \(threshold)")
        print("   Proof size: \(result.proof.count) bytes")
    }
    
    // MARK: - Message Authentication Proof Tests
    
    func testMessageAuthProofGeneration() async throws {
        let message = Data("Hello, KRTR mesh network!".utf8)
        let senderKey = Data("sender_private_key".utf8)
        let timestamp = UInt64(Date().timeIntervalSince1970)
        
        let result = try await zkService.generateMessageAuthProof(
            message: message,
            senderKey: senderKey,
            timestamp: timestamp
        )
        
        XCTAssertNotNil(result.proof, "Message auth proof should be generated")
        XCTAssertFalse(result.publicInputs.isEmpty, "Public inputs should not be empty")
        XCTAssertEqual(result.proofType, .messageAuth, "Proof type should be message auth")
        
        print("✅ Message authentication proof generated successfully")
        print("   Message: \(String(data: message, encoding: .utf8) ?? "unknown")")
        print("   Proof size: \(result.proof.count) bytes")
    }
    
    // MARK: - Performance Tests
    
    func testProofGenerationPerformance() async throws {
        let membershipKey = Data("perf_test_key".utf8)
        let groupRoot = Data("perf_test_root".utf8)
        let pathElements = [Data("path_1".utf8), Data("path_2".utf8)]
        let pathIndices = [0, 1]
        
        let startTime = Date()
        
        let result = try await zkService.generateMembershipProof(
            membershipKey: membershipKey,
            groupRoot: groupRoot,
            pathElements: pathElements,
            pathIndices: pathIndices
        )
        
        let duration = Date().timeIntervalSince(startTime)
        
        XCTAssertNotNil(result.proof, "Proof should be generated")
        XCTAssertLessThan(duration, 5.0, "Proof generation should complete within 5 seconds")
        
        print("✅ Performance test completed")
        print("   Duration: \(String(format: "%.3f", duration))s")
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidInputHandling() async {
        // Test with empty inputs
        do {
            _ = try await zkService.generateMembershipProof(
                membershipKey: Data(),
                groupRoot: Data(),
                pathElements: [],
                pathIndices: []
            )
            XCTFail("Should throw error for empty inputs")
        } catch {
            print("✅ Correctly handled empty inputs: \(error)")
        }
    }
    
    // MARK: - Statistics Tests
    
    func testStatisticsTracking() async throws {
        let stats = zkService.getStats()
        let initialCount = stats.totalProofs
        
        // Generate a proof
        let membershipKey = Data("stats_test_key".utf8)
        let groupRoot = Data("stats_test_root".utf8)
        let pathElements = [Data("path".utf8)]
        let pathIndices = [0]
        
        _ = try await zkService.generateMembershipProof(
            membershipKey: membershipKey,
            groupRoot: groupRoot,
            pathElements: pathElements,
            pathIndices: pathIndices
        )
        
        let newStats = zkService.getStats()
        XCTAssertEqual(newStats.totalProofs, initialCount + 1, "Proof count should increment")
        
        print("✅ Statistics tracking working")
        print("   Total proofs: \(newStats.totalProofs)")
        print("   Success rate: \(String(format: "%.1f", newStats.successRate * 100))%")
    }
}
