import SwiftUI

struct ZKTestView: View {
    @StateObject private var testRunner = ZKDeviceTests()
    @State private var showingDetails = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                    
                    Text("Zero-Knowledge Tests")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Verify ZK proof generation on device")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                // Current Test Status
                if testRunner.isRunning {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        
                        Text(testRunner.currentTest)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.blue)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
                
                // Test Results
                if !testRunner.testResults.isEmpty {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(testRunner.testResults) { result in
                                ZKTestResultRow(result: result)
                            }
                        }
                        .padding(.horizontal)
                    }
                } else if !testRunner.isRunning {
                    VStack(spacing: 16) {
                        Image(systemName: "testtube.2")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No tests run yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Tap 'Run Tests' to verify ZK functionality")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        Task {
                            await testRunner.runAllTests()
                        }
                    }) {
                        HStack {
                            Image(systemName: "play.circle.fill")
                            Text("Run ZK Tests")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(testRunner.isRunning ? Color.gray : Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(testRunner.isRunning)
                    
                    if !testRunner.testResults.isEmpty {
                        Button(action: {
                            showingDetails = true
                        }) {
                            HStack {
                                Image(systemName: "info.circle")
                                Text("View Details")
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("ZK Tests")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingDetails) {
                ZKTestDetailsView(results: testRunner.testResults)
            }
        }
    }
}

struct ZKTestResultRow: View {
    let result: ZKTestResult
    
    var body: some View {
        HStack {
            // Status Icon
            Text(result.statusIcon)
                .font(.title2)
            
            // Test Info
            VStack(alignment: .leading, spacing: 4) {
                Text(result.name)
                    .font(.headline)
                    .foregroundColor(result.success ? .primary : .red)
                
                Text(result.details)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Metrics
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(result.durationString)s")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                
                if let _ = result.proofSize {
                    Text(result.proofSizeString)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct ZKTestDetailsView: View {
    let results: [ZKTestResult]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Test Summary") {
                    let successCount = results.filter { $0.success }.count
                    let totalCount = results.count
                    let avgDuration = results.map { $0.duration }.reduce(0, +) / Double(max(totalCount, 1))
                    
                    HStack {
                        Text("Success Rate")
                        Spacer()
                        Text("\(successCount)/\(totalCount)")
                            .foregroundColor(successCount == totalCount ? .green : .orange)
                    }
                    
                    HStack {
                        Text("Average Duration")
                        Spacer()
                        Text(String(format: "%.3fs", avgDuration))
                            .foregroundColor(.blue)
                    }
                    
                    HStack {
                        Text("Total Tests")
                        Spacer()
                        Text("\(totalCount)")
                    }
                }
                
                Section("Test Results") {
                    ForEach(results) { result in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(result.statusIcon)
                                Text(result.name)
                                    .fontWeight(.medium)
                                Spacer()
                                Text(result.durationString + "s")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            
                            Text(result.details)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if let proofSize = result.proofSize {
                                Text("Proof size: \(proofSize) bytes")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text("Completed: \(result.timestamp.formatted(date: .omitted, time: .standard))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Test Details")
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
    ZKTestView()
}
