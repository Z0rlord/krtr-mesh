import SwiftUI

struct ZKGroupJoinView: View {
    let zkMeshProtocol: ZKMeshProtocol
    @Environment(\.dismiss) private var dismiss
    
    @State private var groupId = ""
    @State private var membershipKey = ""
    @State private var isJoining = false
    @State private var joinResult: String?
    @State private var showingResult = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Group Information") {
                    TextField("Group ID", text: $groupId)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("Membership Key", text: $membershipKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                Section("Anonymous Group Join") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Join a mesh group anonymously using zero-knowledge proof of membership.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("• Your identity remains private")
                        Text("• Only proves you have valid membership")
                        Text("• No personal information shared")
                        
                        Button(action: joinGroup) {
                            HStack {
                                if isJoining {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "person.3.fill")
                                }
                                
                                Text(isJoining ? "Joining..." : "Join Group Anonymously")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canJoin ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(!canJoin || isJoining)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                if let result = joinResult {
                    Section("Result") {
                        Text(result)
                            .foregroundColor(result.contains("Success") ? .green : .red)
                    }
                }
            }
            .navigationTitle("Anonymous Group Join")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var canJoin: Bool {
        !groupId.isEmpty && !membershipKey.isEmpty
    }
    
    private func joinGroup() {
        guard canJoin else { return }
        
        isJoining = true
        joinResult = nil
        
        Task {
            do {
                // Generate mock group data for demonstration
                let membershipKeyData = Data(membershipKey.utf8)
                let groupRoot = Data("group_root_\(groupId)".utf8)
                let pathElements = [
                    Data("path_element_1".utf8),
                    Data("path_element_2".utf8)
                ]
                let pathIndices = [0, 1]
                
                try await zkMeshProtocol.joinGroupAnonymously(
                    groupId: groupId,
                    membershipKey: membershipKeyData,
                    groupRoot: groupRoot,
                    pathElements: pathElements,
                    pathIndices: pathIndices
                )
                
                await MainActor.run {
                    joinResult = "✅ Successfully joined group '\(groupId)' anonymously!"
                    isJoining = false
                }
                
            } catch {
                await MainActor.run {
                    joinResult = "❌ Failed to join group: \(error.localizedDescription)"
                    isJoining = false
                }
            }
        }
    }
}

struct ZKReputationProofView: View {
    let zkMeshProtocol: ZKMeshProtocol
    @Environment(\.dismiss) private var dismiss
    
    @State private var reputationScore = 75
    @State private var threshold = 50
    @State private var isGenerating = false
    @State private var proofResult: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section("Reputation Settings") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Reputation Score: \(reputationScore)")
                            .font(.headline)
                        
                        Slider(value: Binding(
                            get: { Double(reputationScore) },
                            set: { reputationScore = Int($0) }
                        ), in: 0...100, step: 1)
                        
                        Text("Threshold to Prove: \(threshold)")
                            .font(.subheadline)
                        
                        Slider(value: Binding(
                            get: { Double(threshold) },
                            set: { threshold = Int($0) }
                        ), in: 0...100, step: 1)
                    }
                }
                
                Section("Zero-Knowledge Reputation Proof") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Generate a proof that your reputation exceeds the threshold without revealing your exact score.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("• Proves reputation ≥ \(threshold)")
                        Text("• Actual score (\(reputationScore)) remains private")
                        Text("• Cryptographically verifiable")
                        
                        Button(action: generateProof) {
                            HStack {
                                if isGenerating {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "star.circle.fill")
                                }
                                
                                Text(isGenerating ? "Generating..." : "Generate Reputation Proof")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canGenerate ? Color.orange : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(!canGenerate || isGenerating)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                if let result = proofResult {
                    Section("Result") {
                        Text(result)
                            .foregroundColor(result.contains("Success") ? .green : .red)
                    }
                }
            }
            .navigationTitle("Reputation Proof")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var canGenerate: Bool {
        reputationScore >= threshold
    }
    
    private func generateProof() {
        guard canGenerate else { return }
        
        isGenerating = true
        proofResult = nil
        
        Task {
            do {
                let nonce = Data("reputation_nonce_\(Date().timeIntervalSince1970)".utf8)
                
                try await zkMeshProtocol.shareReputationProof(
                    reputationScore: reputationScore,
                    threshold: threshold,
                    nonce: nonce
                )
                
                await MainActor.run {
                    proofResult = "✅ Successfully generated and shared reputation proof!"
                    isGenerating = false
                }
                
            } catch {
                await MainActor.run {
                    proofResult = "❌ Failed to generate proof: \(error.localizedDescription)"
                    isGenerating = false
                }
            }
        }
    }
}

struct ZKMessageAuthView: View {
    let zkMeshProtocol: ZKMeshProtocol
    @Environment(\.dismiss) private var dismiss
    
    @State private var message = ""
    @State private var senderKey = ""
    @State private var isSending = false
    @State private var sendResult: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section("Message") {
                    TextField("Enter your message", text: $message, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3...6)
                    
                    TextField("Sender Key", text: $senderKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                Section("Anonymous Message Authentication") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Send an authenticated message anonymously using zero-knowledge proof.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("• Message authenticity verified")
                        Text("• Sender identity remains private")
                        Text("• Prevents message tampering")
                        
                        Button(action: sendMessage) {
                            HStack {
                                if isSending {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "message.badge.circle.fill")
                                }
                                
                                Text(isSending ? "Sending..." : "Send Authenticated Message")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canSend ? Color.purple : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(!canSend || isSending)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                if let result = sendResult {
                    Section("Result") {
                        Text(result)
                            .foregroundColor(result.contains("Success") ? .green : .red)
                    }
                }
            }
            .navigationTitle("Message Authentication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var canSend: Bool {
        !message.isEmpty && !senderKey.isEmpty
    }
    
    private func sendMessage() {
        guard canSend else { return }
        
        isSending = true
        sendResult = nil
        
        Task {
            do {
                let messageData = Data(message.utf8)
                let senderKeyData = Data(senderKey.utf8)
                
                try await zkMeshProtocol.sendAuthenticatedMessage(
                    message: messageData,
                    senderKey: senderKeyData
                )
                
                await MainActor.run {
                    sendResult = "✅ Successfully sent authenticated message!"
                    isSending = false
                }
                
            } catch {
                await MainActor.run {
                    sendResult = "❌ Failed to send message: \(error.localizedDescription)"
                    isSending = false
                }
            }
        }
    }
}

#Preview {
    ZKGroupJoinView(zkMeshProtocol: ZKMeshProtocol(
        zkService: ZKServiceFactory.createService(),
        meshService: BluetoothMeshService()
    ))
}
