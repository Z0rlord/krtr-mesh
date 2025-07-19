//
// ZKEnhancedComponents.swift
// KRTR
//
// This is free and unencumbered software released into the public domain.
// For more information, see <https://unlicense.org>
//

import SwiftUI
import Foundation

// MARK: - Supporting Data Structures

struct AttendanceProof {
    let id: UUID
    let location: String
    let attendanceCount: Int
    let requiredCount: Int
    let timeWindow: String
    let isComplete: Bool
    let proofHash: String?
    let generatedAt: Date?
}

struct ReputationGating {
    let messageRelayCount: Int
    let lightningTips: Int
    let isEligibleForHighValue: Bool
    let lastProofGenerated: Date?
    
    init(messageRelayCount: Int = 0, lightningTips: Int = 0, isEligibleForHighValue: Bool = false, lastProofGenerated: Date? = nil) {
        self.messageRelayCount = messageRelayCount
        self.lightningTips = lightningTips
        self.isEligibleForHighValue = isEligibleForHighValue
        self.lastProofGenerated = lastProofGenerated
    }
}

// MARK: - UI Components

struct ChannelCard: View {
    let channel: ChannelAccess
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: channel.isUnlocked ? "lock.open.fill" : "lock.fill")
                    .foregroundColor(channel.isUnlocked ? .green : .orange)
                    .font(.title3)
                
                Spacer()
                
                if channel.isUnlocked {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                }
            }
            
            Text(channel.channelName)
                .font(.headline)
                .fontWeight(.semibold)
                .lineLimit(2)
            
            Text(requirementDescription(channel.requirement))
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(3)
            
            if channel.isUnlocked, let unlockedAt = channel.unlockedAt {
                Text("Unlocked \(timeAgoString(unlockedAt))")
                    .font(.caption2)
                    .foregroundColor(.green)
            }
            
            Button(action: onTap) {
                HStack {
                    Image(systemName: channel.isUnlocked ? "arrow.right.circle" : "shield.checkered")
                    Text(channel.isUnlocked ? "Enter" : "Generate Proof")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(channel.isUnlocked ? Color.blue : Color.orange)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func requirementDescription(_ requirement: ChannelAccessRequirement) -> String {
        switch requirement {
        case .reputationThreshold(let threshold):
            return "Requires reputation ≥ \(threshold)"
        case .proximityAttestations(let count):
            return "Requires \(count) proximity attestations"
        case .messageRelay(let count):
            return "Requires \(count) message relays"
        case .lightningPayment:
            return "Requires Lightning payment verification"
        }
    }
    
    private func timeAgoString(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct AttendanceProofCard: View {
    let proof: AttendanceProof
    let onGenerate: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(.blue)
                    .font(.title3)
                
                Text(proof.location)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if proof.isComplete {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.title3)
                }
            }
            
            HStack {
                Text("Progress:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("\(proof.attendanceCount)/\(proof.requiredCount)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(proof.isComplete ? .green : .orange)
                
                Spacer()
                
                Text(proof.timeWindow)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: Double(proof.attendanceCount), total: Double(proof.requiredCount))
                .progressViewStyle(LinearProgressViewStyle(tint: proof.isComplete ? .green : .orange))
            
            if proof.isComplete, let generatedAt = proof.generatedAt {
                HStack {
                    Image(systemName: "shield.checkered")
                        .foregroundColor(.green)
                    Text("Proof generated \(timeAgoString(generatedAt))")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            Button(action: onGenerate) {
                HStack {
                    Image(systemName: proof.isComplete ? "arrow.up.circle" : "clock.arrow.circlepath")
                    Text(proof.isComplete ? "Generate Proof" : "Check In")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(proof.isComplete ? Color.green : Color.blue)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func timeAgoString(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct ReputationGatingCard: View {
    let gating: ReputationGating
    let onTest: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundColor(gating.isEligibleForHighValue ? .green : .orange)
                    .font(.title2)
                
                VStack(alignment: .leading) {
                    Text("Reputation Status")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(gating.isEligibleForHighValue ? "Eligible for High-Value Messages" : "Building Reputation")
                        .font(.subheadline)
                        .foregroundColor(gating.isEligibleForHighValue ? .green : .orange)
                }
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(.blue)
                    Text("Message Relays: \(gating.messageRelayCount)")
                        .font(.subheadline)
                    Spacer()
                    if gating.messageRelayCount >= 5 {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                
                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.yellow)
                    Text("Lightning Tips: \(gating.lightningTips)")
                        .font(.subheadline)
                    Spacer()
                    if gating.lightningTips >= 1 {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            if let lastProof = gating.lastProofGenerated {
                Text("Last proof: \(timeAgoString(lastProof))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button(action: onTest) {
                HStack {
                    Image(systemName: "testtube.2")
                    Text("Test Reputation Gating")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.purple)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func timeAgoString(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct CodeSnippetView: View {
    let title: String
    let code: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
            
            Text(code)
                .font(.system(.caption, design: .monospaced))
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
    }
}

struct ZKProofGenerationView: View {
    let zkService: MockZKService
    let onProofGenerated: (ZKProofWithMetadata) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isGenerating = false
    @State private var progress: Double = 0.0
    @State private var currentStep = "Initializing..."
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()
                
                Image(systemName: "shield.checkered")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Generating ZK Proof")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(currentStep)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .frame(maxWidth: 200)
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .font(.headline)
                .foregroundColor(.red)
            }
            .padding()
            .navigationTitle("ZK Proof")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            generateProof()
        }
    }
    
    private func generateProof() {
        isGenerating = true
        
        Task {
            let steps = [
                "Preparing circuit parameters...",
                "Generating witness...",
                "Computing proof...",
                "Verifying proof...",
                "Finalizing..."
            ]
            
            for (index, step) in steps.enumerated() {
                await MainActor.run {
                    currentStep = step
                    progress = Double(index) / Double(steps.count - 1)
                }
                
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
            
            // Generate actual proof
            let context = ZKProofContext(
                reputationScore: 75,
                threshold: 50,
                nonce: Data("test_nonce".utf8)
            )
            
            do {
                let proof = try await zkService.generateZKProof(for: .reputation, context: context)
                
                await MainActor.run {
                    onProofGenerated(proof)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    dismiss()
                }
            }
        }
    }
}
