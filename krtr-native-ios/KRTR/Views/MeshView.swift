//
// MeshView.swift
// KRTR
//
// This is free and unencumbered software released into the public domain.
// For more information, see <https://unlicense.org>
//

import SwiftUI

struct MeshView: View {
    @ObservedObject var meshService: BluetoothMeshService
    @State private var showingSettings = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    headerSection
                    
                    // Mesh Status
                    meshStatusSection
                    
                    // Connected Peers
                    connectedPeersSection
                    
                    // Network Statistics
                    networkStatsSection
                }
                .padding()
            }
            .navigationTitle("Mesh Network")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Settings") {
                        showingSettings = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            MeshSettingsView(meshService: meshService)
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "network")
                    .foregroundColor(.blue)
                    .font(.title2)
                Text("KRTR Mesh Network")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            Text("Decentralized mesh networking with zero-knowledge privacy")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var meshStatusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Network Status")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 20) {
                StatusCard(
                    title: "Connection",
                    value: meshService.isConnected ? "Connected" : "Disconnected",
                    color: meshService.isConnected ? .green : .red,
                    icon: meshService.isConnected ? "wifi" : "wifi.slash"
                )
                
                StatusCard(
                    title: "Peers",
                    value: "\(meshService.connectedPeers.count)",
                    color: .blue,
                    icon: "person.3.fill"
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var connectedPeersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Connected Peers")
                .font(.headline)
                .fontWeight(.semibold)
            
            if meshService.connectedPeers.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.3.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    
                    Text("No peers connected")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Make sure Bluetooth is enabled and other KRTR devices are nearby")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(meshService.connectedPeers.enumerated()), id: \.offset) { index, peer in
                        PeerCard(peer: peer, index: index)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var networkStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Network Statistics")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(title: "Messages Sent", value: "0", icon: "arrow.up.circle")
                StatCard(title: "Messages Received", value: "0", icon: "arrow.down.circle")
                StatCard(title: "Relayed Messages", value: "0", icon: "arrow.triangle.2.circlepath")
                StatCard(title: "Network Uptime", value: "0m", icon: "clock")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct StatusCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct PeerCard: View {
    let peer: String
    let index: Int
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Peer \(index + 1)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(peer)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Image(systemName: "antenna.radiowaves.left.and.right")
                .foregroundColor(.blue)
                .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct MeshSettingsView: View {
    @ObservedObject var meshService: BluetoothMeshService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Mesh Settings")
                    .font(.title)
                    .padding()
                
                Text("Settings coming soon...")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    MeshView(meshService: BluetoothMeshService())
}
