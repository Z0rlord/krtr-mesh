import SwiftUI

struct ZKDashboardView: View {
    @StateObject private var zkMeshProtocol: ZKMeshProtocol
    @StateObject private var zkService = ZKServiceFactory.createService()
    @State private var showingTestView = false
    @State private var showingGroupJoin = false
    @State private var showingReputationProof = false
    @State private var showingMessageAuth = false
    
    init(meshService: BluetoothMeshService) {
        let zkService = ZKServiceFactory.createService()
        self._zkMeshProtocol = StateObject(wrappedValue: ZKMeshProtocol(zkService: zkService, meshService: meshService))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    ZKHeaderView()
                    
                    // Status Cards
                    ZKStatusCardsView(
                        zkService: zkService,
                        zkMeshProtocol: zkMeshProtocol
                    )
                    
                    // Quick Actions
                    ZKQuickActionsView(
                        showingTestView: $showingTestView,
                        showingGroupJoin: $showingGroupJoin,
                        showingReputationProof: $showingReputationProof,
                        showingMessageAuth: $showingMessageAuth
                    )
                    
                    // Statistics
                    ZKStatisticsView(
                        zkService: zkService,
                        zkMeshProtocol: zkMeshProtocol
                    )
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle("Zero-Knowledge")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingTestView) {
                ZKTestView()
            }
            .sheet(isPresented: $showingGroupJoin) {
                ZKGroupJoinView(zkMeshProtocol: zkMeshProtocol)
            }
            .sheet(isPresented: $showingReputationProof) {
                ZKReputationProofView(zkMeshProtocol: zkMeshProtocol)
            }
            .sheet(isPresented: $showingMessageAuth) {
                ZKMessageAuthView(zkMeshProtocol: zkMeshProtocol)
            }
        }
    }
}

struct ZKHeaderView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 50))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("Zero-Knowledge Privacy")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Anonymous authentication and privacy-preserving mesh networking")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct ZKStatusCardsView: View {
    let zkService: ZKServiceProtocol
    let zkMeshProtocol: ZKMeshProtocol
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            ZKStatusCard(
                title: "ZK Service",
                value: zkService.isAvailable ? "Active" : "Fallback",
                icon: "cpu",
                color: zkService.isAvailable ? .green : .orange
            )
            
            ZKStatusCard(
                title: "Mesh Integration",
                value: "Ready",
                icon: "network",
                color: .blue
            )
            
            ZKStatusCard(
                title: "Proofs Generated",
                value: "\(zkService.getStats().totalProofs)",
                icon: "checkmark.shield",
                color: .purple
            )
            
            ZKStatusCard(
                title: "Success Rate",
                value: String(format: "%.1f%%", zkService.getStats().successRate * 100),
                icon: "chart.line.uptrend.xyaxis",
                color: .green
            )
        }
    }
}

struct ZKStatusCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ZKQuickActionsView: View {
    @Binding var showingTestView: Bool
    @Binding var showingGroupJoin: Bool
    @Binding var showingReputationProof: Bool
    @Binding var showingMessageAuth: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.headline)
                .fontWeight(.bold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ZKActionButton(
                    title: "Test ZK",
                    subtitle: "Run tests",
                    icon: "testtube.2",
                    color: .blue
                ) {
                    showingTestView = true
                }
                
                ZKActionButton(
                    title: "Join Group",
                    subtitle: "Anonymous join",
                    icon: "person.3",
                    color: .green
                ) {
                    showingGroupJoin = true
                }
                
                ZKActionButton(
                    title: "Prove Reputation",
                    subtitle: "Share proof",
                    icon: "star.circle",
                    color: .orange
                ) {
                    showingReputationProof = true
                }
                
                ZKActionButton(
                    title: "Auth Message",
                    subtitle: "Anonymous auth",
                    icon: "message.badge.circle",
                    color: .purple
                ) {
                    showingMessageAuth = true
                }
            }
        }
    }
}

struct ZKActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ZKStatisticsView: View {
    let zkService: ZKServiceProtocol
    let zkMeshProtocol: ZKMeshProtocol
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Statistics")
                .font(.headline)
                .fontWeight(.bold)
            
            VStack(spacing: 12) {
                let zkStats = zkService.getStats()
                let meshStats = zkMeshProtocol.getZKMeshStats()
                
                ZKStatRow(label: "Total Proofs", value: "\(zkStats.totalProofs)")
                ZKStatRow(label: "Average Duration", value: String(format: "%.3fs", zkStats.averageDuration))
                ZKStatRow(label: "Mesh Messages Sent", value: "\(meshStats.totalZKMessagesSent)")
                ZKStatRow(label: "Mesh Messages Received", value: "\(meshStats.totalZKMessagesReceived)")
                ZKStatRow(label: "Groups Joined", value: "\(meshStats.groupsJoined)")
                ZKStatRow(label: "Reputation Proofs", value: "\(meshStats.reputationProofsShared)")
                ZKStatRow(label: "Verification Success Rate", value: String(format: "%.1f%%", meshStats.successRate * 100))
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

struct ZKStatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    ZKDashboardView(meshService: BluetoothMeshService())
}
