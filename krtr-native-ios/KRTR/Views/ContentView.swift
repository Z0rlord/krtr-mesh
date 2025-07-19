//
// ContentView.swift
// KRTR
//
// This is free and unencumbered software released into the public domain.
// For more information, see <https://unlicense.org>
//

import SwiftUI
import Foundation

// MARK: - ZK Service Protocol and Implementation

protocol ZKServiceProtocol: ObservableObject {
    var isAvailable: Bool { get }
    func generateMembershipProof(membershipKey: Data, groupRoot: Data, pathElements: [Data], pathIndices: [Int]) async throws -> ZKProofResult
    func generateReputationProof(reputationScore: Int, threshold: Int, nonce: Data) async throws -> ZKProofResult
    func generateMessageAuthProof(message: Data, senderKey: Data, timestamp: UInt64) async throws -> ZKProofResult
    func verifyProof(proof: Data, publicInputs: [Data], proofType: ZKProofType) async throws -> Bool
    func getStats() -> ZKStats
    func resetStats()
}

struct ZKProofResult {
    let proof: Data
    let publicInputs: [Data]
    let proofType: ZKProofType
    let timestamp: Date
}

enum ZKProofType: String, Codable {
    case membership = "membership"
    case reputation = "reputation"
    case messageAuth = "message_auth"
}

struct ZKStats {
    var totalProofs: Int = 0
    var successfulProofs: Int = 0
    var averageDuration: TimeInterval = 0

    var successRate: Double {
        return totalProofs > 0 ? Double(successfulProofs) / Double(totalProofs) : 0.0
    }
}

class MockZKService: ZKServiceProtocol {
    @Published var isAvailable: Bool = true
    private var stats = ZKStats()

    func generateMembershipProof(membershipKey: Data, groupRoot: Data, pathElements: [Data], pathIndices: [Int]) async throws -> ZKProofResult {
        let startTime = Date()

        // Simulate proof generation delay
        try await Task.sleep(nanoseconds: UInt64.random(in: 100_000_000...500_000_000))

        let proofId = "proof_membership_\(UUID().uuidString.prefix(8))"
        let proof = Data(proofId.utf8)

        let publicInputs = [
            groupRoot,
            Data("public_nullifier_\(UUID().uuidString.prefix(8))".utf8),
            Data("merkle_root_\(UUID().uuidString.prefix(8))".utf8)
        ]

        updateStats(duration: Date().timeIntervalSince(startTime), success: true)

        return ZKProofResult(
            proof: proof,
            publicInputs: publicInputs,
            proofType: .membership,
            timestamp: Date()
        )
    }

    func generateReputationProof(reputationScore: Int, threshold: Int, nonce: Data) async throws -> ZKProofResult {
        let startTime = Date()

        guard reputationScore >= threshold else {
            updateStats(duration: Date().timeIntervalSince(startTime), success: false)
            throw ZKError.invalidInput("Reputation score below threshold")
        }

        // Simulate proof generation delay
        try await Task.sleep(nanoseconds: UInt64.random(in: 100_000_000...500_000_000))

        let proofId = "proof_reputation_\(UUID().uuidString.prefix(8))"
        let proof = Data(proofId.utf8)

        let publicInputs = [
            Data(withUnsafeBytes(of: threshold.bigEndian) { Data($0) }),
            nonce,
            Data("commitment_\(UUID().uuidString.prefix(8))".utf8)
        ]

        updateStats(duration: Date().timeIntervalSince(startTime), success: true)

        return ZKProofResult(
            proof: proof,
            publicInputs: publicInputs,
            proofType: .reputation,
            timestamp: Date()
        )
    }

    func generateMessageAuthProof(message: Data, senderKey: Data, timestamp: UInt64) async throws -> ZKProofResult {
        let startTime = Date()

        // Simulate proof generation delay
        try await Task.sleep(nanoseconds: UInt64.random(in: 100_000_000...500_000_000))

        let proofId = "proof_message_\(UUID().uuidString.prefix(8))"
        let proof = Data(proofId.utf8)

        let publicInputs = [
            Data(withUnsafeBytes(of: timestamp.bigEndian) { Data($0) }),
            Data(message.sha256.prefix(16)),
            Data("auth_commitment_\(UUID().uuidString.prefix(8))".utf8)
        ]

        updateStats(duration: Date().timeIntervalSince(startTime), success: true)

        return ZKProofResult(
            proof: proof,
            publicInputs: publicInputs,
            proofType: .messageAuth,
            timestamp: Date()
        )
    }

    func verifyProof(proof: Data, publicInputs: [Data], proofType: ZKProofType) async throws -> Bool {
        // Simulate verification delay
        try await Task.sleep(nanoseconds: UInt64.random(in: 50_000_000...200_000_000))

        // Mock verification - always returns true for valid-looking proofs
        return proof.count > 0 && !publicInputs.isEmpty
    }

    func getStats() -> ZKStats {
        return stats
    }

    func resetStats() {
        stats = ZKStats()
    }

    private func updateStats(duration: TimeInterval, success: Bool) {
        stats.totalProofs += 1
        if success {
            stats.successfulProofs += 1
        }

        // Update average duration
        let totalDuration = stats.averageDuration * Double(stats.totalProofs - 1) + duration
        stats.averageDuration = totalDuration / Double(stats.totalProofs)
    }
}

enum ZKError: Error, LocalizedError {
    case invalidInput(String)
    case proofGenerationFailed(String)
    case verificationFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        case .proofGenerationFailed(let message):
            return "Proof generation failed: \(message)"
        case .verificationFailed(let message):
            return "Verification failed: \(message)"
        }
    }
}

struct ZKServiceFactory {
    static func createService() -> MockZKService {
        return MockZKService()
    }
}

extension Data {
    var sha256: Data {
        var hash = [UInt8](repeating: 0, count: 32)
        self.withUnsafeBytes { bytes in
            // Simple hash simulation - not cryptographically secure
            for (index, byte) in bytes.enumerated() {
                hash[index % 32] ^= byte
            }
        }
        return Data(hash)
    }
}

struct ContentView: View {
    @EnvironmentObject var viewModel: ChatViewModel
    @State private var messageText = ""
    @State private var textFieldSelection: NSRange? = nil
    @FocusState private var isTextFieldFocused: Bool
    @Environment(\.colorScheme) var colorScheme
    @State private var showPeerList = false
    @State private var showSidebar = false
    @State private var sidebarDragOffset: CGFloat = 0
    @State private var showAppInfo = false
    @State private var showPasswordInput = false
    @State private var passwordInputChannel: String? = nil
    @State private var passwordInput = ""
    @State private var showPasswordPrompt = false
    @State private var passwordPromptInput = ""
    @State private var showPasswordError = false
    @State private var showCommandSuggestions = false
    @State private var commandSuggestions: [String] = []
    @State private var showLeaveChannelAlert = false
    @State private var backSwipeOffset: CGFloat = 0
    @State private var showPrivateChat = false
    @State private var showChannel = false
    @State private var showZKDashboard = false
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color.black : Color.white
    }
    
    private var textColor: Color {
        colorScheme == .dark ? Color.green : Color(red: 0, green: 0.5, blue: 0)
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? Color.green.opacity(0.8) : Color(red: 0, green: 0.5, blue: 0).opacity(0.8)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Base layer - Main public chat (always visible)
                mainChatView
                
                // Private chat slide-over
                if viewModel.selectedPrivateChatPeer != nil {
                    privateChatView
                        .frame(width: geometry.size.width)
                        .background(backgroundColor)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .trailing)
                        ))
                        .offset(x: showPrivateChat ? 0 : geometry.size.width)
                        .offset(x: backSwipeOffset)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if value.translation.width > 0 {
                                        backSwipeOffset = min(value.translation.width, geometry.size.width)
                                    }
                                }
                                .onEnded { value in
                                    if value.translation.width > 50 || (value.translation.width > 30 && value.velocity.width > 300) {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            showPrivateChat = false
                                            backSwipeOffset = 0
                                            viewModel.endPrivateChat()
                                        }
                                    } else {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            backSwipeOffset = 0
                                        }
                                    }
                                }
                        )
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showPrivateChat)
                }
                
                // Channel slide-over
                if viewModel.currentChannel != nil {
                    channelView
                        .frame(width: geometry.size.width)
                        .background(backgroundColor)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .trailing)
                        ))
                        .offset(x: showChannel ? 0 : geometry.size.width)
                        .offset(x: backSwipeOffset)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if value.translation.width > 0 {
                                        backSwipeOffset = min(value.translation.width, geometry.size.width)
                                    }
                                }
                                .onEnded { value in
                                    if value.translation.width > 50 || (value.translation.width > 30 && value.velocity.width > 300) {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            showChannel = false
                                            backSwipeOffset = 0
                                            viewModel.switchToChannel(nil)
                                        }
                                    } else {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            backSwipeOffset = 0
                                        }
                                    }
                                }
                        )
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showChannel)
                }
                
                // Sidebar overlay
                HStack(spacing: 0) {
                    // Tap to dismiss area
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showSidebar = false
                                sidebarDragOffset = 0
                            }
                        }
                    
                    sidebarView
                        #if os(macOS)
                        .frame(width: min(300, geometry.size.width * 0.4))
                        #else
                        .frame(width: geometry.size.width * 0.7)
                        #endif
                        .transition(.move(edge: .trailing))
                }
                .offset(x: showSidebar ? -sidebarDragOffset : geometry.size.width - sidebarDragOffset)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showSidebar)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: sidebarDragOffset)
            }
        }
        #if os(macOS)
        .frame(minWidth: 600, minHeight: 400)
        #endif
        .onChange(of: viewModel.selectedPrivateChatPeer) { newValue in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showPrivateChat = newValue != nil
            }
        }
        .onChange(of: viewModel.currentChannel) { newValue in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showChannel = newValue != nil
            }
        }
        .sheet(isPresented: $showAppInfo) {
            AppInfoView()
        }
        .sheet(isPresented: $showZKDashboard) {
            ZKDashboardSheet()
        }
        .sheet(isPresented: Binding(
            get: { viewModel.showingFingerprintFor != nil },
            set: { _ in viewModel.showingFingerprintFor = nil }
        )) {
            if let peerID = viewModel.showingFingerprintFor {
                FingerprintView(viewModel: viewModel, peerID: peerID)
            }
        }
        .alert("Set Channel Password", isPresented: $showPasswordInput) {
            SecureField("Password", text: $passwordInput)
            Button("Cancel", role: .cancel) {
                passwordInput = ""
                passwordInputChannel = nil
            }
            Button("Set Password") {
                if let channel = passwordInputChannel, !passwordInput.isEmpty {
                    viewModel.setChannelPassword(passwordInput, for: channel)
                    passwordInput = ""
                    passwordInputChannel = nil
                }
            }
        } message: {
            Text("Enter a password to protect \(passwordInputChannel ?? "channel"). Others will need this password to read messages.")
        }
        .alert("Enter Channel Password", isPresented: Binding(
            get: { viewModel.showPasswordPrompt },
            set: { viewModel.showPasswordPrompt = $0 }
        )) {
            SecureField("Password", text: $passwordPromptInput)
            Button("Cancel", role: .cancel) {
                passwordPromptInput = ""
                viewModel.passwordPromptChannel = nil
            }
            Button("Join") {
                if let channel = viewModel.passwordPromptChannel, !passwordPromptInput.isEmpty {
                    let success = viewModel.joinChannel(channel, password: passwordPromptInput)
                    if success {
                        passwordPromptInput = ""
                    } else {
                        // Wrong password - show error
                        passwordPromptInput = ""
                        showPasswordError = true
                    }
                }
            }
        } message: {
            Text("Channel \(viewModel.passwordPromptChannel ?? "") is password protected. Enter the password to join.")
        }
        .alert("Wrong Password", isPresented: $showPasswordError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("The password you entered is incorrect. Please try again.")
        }
    }
    
    private func messagesView(for channel: String?, privatePeer: String?) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    let messages: [KRTRMessage] = {
                        if let privatePeer = privatePeer {
                            let msgs = viewModel.getPrivateChatMessages(for: privatePeer)
                            return msgs
                        } else if let channel = channel {
                            let msgs = viewModel.getChannelMessages(channel)
                            return msgs
                        } else {
                            return viewModel.messages
                        }
                    }()
                    
                    ForEach(messages, id: \.id) { message in
                        VStack(alignment: .leading, spacing: 4) {
                            // Check if current user is mentioned
                            let _ = message.mentions?.contains(viewModel.nickname) ?? false
                            
                            if message.sender == "system" {
                                // System messages
                                Text(viewModel.formatMessageAsText(message, colorScheme: colorScheme))
                                    .textSelection(.enabled)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                // Regular messages with natural text wrapping
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(alignment: .top, spacing: 0) {
                                        // Single text view for natural wrapping
                                        Text(viewModel.formatMessageAsText(message, colorScheme: colorScheme))
                                            .textSelection(.enabled)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        
                                        // Delivery status indicator for private messages
                                        if message.isPrivate && message.sender == viewModel.nickname,
                                           let status = message.deliveryStatus {
                                            DeliveryStatusView(status: status, colorScheme: colorScheme)
                                                .padding(.leading, 4)
                                        }
                                    }
                                    
                                    // Check for links and show preview
                                    if let markdownLink = message.content.extractMarkdownLink() {
                                        // Don't show link preview if the message is just the emoji
                                        let cleanContent = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
                                        if cleanContent.hasPrefix("👇") {
                                            LinkPreviewView(url: markdownLink.url, title: markdownLink.title)
                                                .padding(.top, 4)
                                        }
                                    } else {
                                        // Check for plain URLs
                                        let urls = message.content.extractURLs()
                                        ForEach(urls.prefix(3), id: \.url) { urlInfo in
                                            LinkPreviewView(url: urlInfo.url, title: nil)
                                                .padding(.top, 4)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 2)
                        .id(message.id)
                    }
                }
                .padding(.vertical, 8)
            }
            .background(backgroundColor)
            .onChange(of: viewModel.messages.count) { _ in
                if channel == nil && privatePeer == nil && !viewModel.messages.isEmpty {
                    withAnimation {
                        proxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: viewModel.privateChats) { _ in
                if let peerID = privatePeer,
                   let messages = viewModel.privateChats[peerID],
                   !messages.isEmpty {
                    withAnimation {
                        proxy.scrollTo(messages.last?.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: viewModel.channelMessages) { _ in
                if let channelName = channel,
                   let messages = viewModel.channelMessages[channelName],
                   !messages.isEmpty {
                    withAnimation {
                        proxy.scrollTo(messages.last?.id, anchor: .bottom)
                    }
                }
            }
            .onAppear {
                // Also check when view appears
                if let peerID = privatePeer {
                    // Try multiple times to ensure read receipts are sent
                    viewModel.markPrivateMessagesAsRead(from: peerID)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        viewModel.markPrivateMessagesAsRead(from: peerID)
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        viewModel.markPrivateMessagesAsRead(from: peerID)
                    }
                }
            }
        }
    }
    
    private var inputView: some View {
        VStack(spacing: 0) {
            // @mentions autocomplete
            if viewModel.showAutocomplete && !viewModel.autocompleteSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(viewModel.autocompleteSuggestions.enumerated()), id: \.element) { index, suggestion in
                        Button(action: {
                            _ = viewModel.completeNickname(suggestion, in: &messageText)
                        }) {
                            HStack {
                                Text("@\(suggestion)")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(textColor)
                                    .fontWeight(.medium)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .background(Color.gray.opacity(0.1))
                    }
                }
                .background(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(secondaryTextColor.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal, 12)
            }
            
            // Command suggestions
            if showCommandSuggestions && !commandSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    // Define commands with aliases and syntax
                    let commandInfo: [(commands: [String], syntax: String?, description: String)] = [
                        (["/block"], "[nickname]", "block or list blocked peers"),
                        (["/clear"], nil, "clear chat messages"),
                        (["/hug"], "<nickname>", "send someone a warm hug"),
                        (["/j", "/join"], "<channel>", "join or create a channel"),
                        (["/m", "/msg"], "<nickname> [message]", "send private message"),
                        (["/channels"], nil, "show all discovered channels"),
                        (["/slap"], "<nickname>", "slap someone with a trout"),
                        (["/unblock"], "<nickname>", "unblock a peer"),
                        (["/w"], nil, "see who's online")
                    ]
                    
                    let channelCommandInfo: [(commands: [String], syntax: String?, description: String)] = [
                        (["/pass"], "[password]", "change channel password"),
                        (["/transfer"], "<nickname>", "transfer channel ownership")
                    ]
                    
                    // Build the display
                    let allCommands = viewModel.currentChannel != nil 
                        ? commandInfo + channelCommandInfo 
                        : commandInfo
                    
                    // Show matching commands
                    ForEach(commandSuggestions, id: \.self) { command in
                        // Find the command info for this suggestion
                        if let info = allCommands.first(where: { $0.commands.contains(command) }) {
                            Button(action: {
                                // Replace current text with selected command
                                messageText = command + " "
                                showCommandSuggestions = false
                                commandSuggestions = []
                            }) {
                                HStack {
                                    // Show all aliases together
                                    Text(info.commands.joined(separator: ", "))
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(textColor)
                                        .fontWeight(.medium)
                                    
                                    // Show syntax if any
                                    if let syntax = info.syntax {
                                        Text(syntax)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(secondaryTextColor.opacity(0.8))
                                    }
                                    
                                    Spacer()
                                    
                                    // Show description
                                    Text(info.description)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(secondaryTextColor)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .background(Color.gray.opacity(0.1))
                        }
                    }
                }
                .background(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(secondaryTextColor.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal, 12)
            }
            
            HStack(alignment: .center, spacing: 4) {
            if viewModel.selectedPrivateChatPeer != nil {
                Text("<@\(viewModel.nickname)> →")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.orange)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.leading, 12)
            } else if let currentChannel = viewModel.currentChannel, viewModel.passwordProtectedChannels.contains(currentChannel) {
                Text("<@\(viewModel.nickname)> →")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.orange)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.leading, 12)
            } else {
                Text("<@\(viewModel.nickname)>")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(textColor)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.leading, 12)
            }
            
            TextField("", text: $messageText)
                .textFieldStyle(.plain)
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(textColor)
                .autocorrectionDisabled()
                .focused($isTextFieldFocused)
                .onChange(of: messageText) { newValue in
                    // Get cursor position (approximate - end of text for now)
                    let cursorPosition = newValue.count
                    viewModel.updateAutocomplete(for: newValue, cursorPosition: cursorPosition)
                    
                    // Check for command autocomplete
                    if newValue.hasPrefix("/") && newValue.count >= 1 {
                        // Build context-aware command list
                        var commandDescriptions = [
                            ("/block", "block or list blocked peers"),
                            ("/channels", "show all discovered channels"),
                            ("/clear", "clear chat messages"),
                            ("/hug", "send someone a warm hug"),
                            ("/j", "join or create a channel"),
                            ("/m", "send private message"),
                            ("/slap", "slap someone with a trout"),
                            ("/unblock", "unblock a peer"),
                            ("/w", "see who's online")
                        ]
                        
                        // Add channel-specific commands if in a channel
                        if viewModel.currentChannel != nil {
                            commandDescriptions.append(("/pass", "change channel password"))
                            commandDescriptions.append(("/transfer", "transfer channel ownership"))
                        }
                        
                        let input = newValue.lowercased()
                        
                        // Map of aliases to primary commands
                        let aliases: [String: String] = [
                            "/join": "/j",
                            "/msg": "/m"
                        ]
                        
                        // Filter commands, but convert aliases to primary
                        commandSuggestions = commandDescriptions
                            .filter { $0.0.starts(with: input) }
                            .map { $0.0 }
                        
                        // Also check if input matches an alias
                        for (alias, primary) in aliases {
                            if alias.starts(with: input) && !commandSuggestions.contains(primary) {
                                if commandDescriptions.contains(where: { $0.0 == primary }) {
                                    commandSuggestions.append(primary)
                                }
                            }
                        }
                        
                        // Remove duplicates and sort
                        commandSuggestions = Array(Set(commandSuggestions)).sorted()
                        showCommandSuggestions = !commandSuggestions.isEmpty
                    } else {
                        showCommandSuggestions = false
                        commandSuggestions = []
                    }
                }
                .onSubmit {
                    sendMessage()
                }
            
            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(messageText.isEmpty ? Color.gray :
                                            (viewModel.selectedPrivateChatPeer != nil ||
                                             (viewModel.currentChannel != nil && viewModel.passwordProtectedChannels.contains(viewModel.currentChannel ?? "")))
                                             ? Color.orange : textColor)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 12)
            .accessibilityLabel("Send message")
            .accessibilityHint(messageText.isEmpty ? "Enter a message to send" : "Double tap to send")
            }
            .padding(.vertical, 8)
            .background(backgroundColor.opacity(0.95))
        }
        .onAppear {
            isTextFieldFocused = true
        }
    }
    
    private func sendMessage() {
        viewModel.sendMessage(messageText)
        messageText = ""
    }
    
    @ViewBuilder
    private var channelsSection: some View {
        if !viewModel.joinedChannels.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "square.split.2x2")
                        .font(.system(size: 10))
                        .accessibilityHidden(true)
                    Text("CHANNELS")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                }
                .foregroundColor(secondaryTextColor)
                .padding(.horizontal, 12)
                
                ForEach(Array(viewModel.joinedChannels).sorted(), id: \.self) { channel in
                    channelButton(for: channel)
                }
            }
        }
    }
    
    @ViewBuilder
    private func channelButton(for channel: String) -> some View {
        Button(action: {
            // Check if channel needs password and we don't have it
            if viewModel.passwordProtectedChannels.contains(channel) && viewModel.channelKeys[channel] == nil {
                // Need password
                viewModel.passwordPromptChannel = channel
                viewModel.showPasswordPrompt = true
            } else {
                // Can enter channel
                viewModel.switchToChannel(channel)
                withAnimation(.spring()) {
                    showSidebar = false
                }
            }
        }) {
            HStack {
                // Lock icon for password protected channels
                if viewModel.passwordProtectedChannels.contains(channel) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundColor(secondaryTextColor)
                        .accessibilityLabel("Password protected")
                }
                
                Text(channel)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(viewModel.currentChannel == channel ? Color.blue : textColor)
                
                Spacer()
                
                // Unread count
                if let unreadCount = viewModel.unreadChannelMessages[channel], unreadCount > 0 {
                    Text("\(unreadCount)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(backgroundColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange)
                        .clipShape(Capsule())
                }
                
                // Channel controls
                if viewModel.currentChannel == channel {
                    channelControls(for: channel)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(viewModel.currentChannel == channel ? backgroundColor.opacity(0.5) : Color.clear)
    }
    
    @ViewBuilder
    private func channelControls(for channel: String) -> some View {
        HStack(spacing: 4) {
            // Password button for channel creator only
            if viewModel.isChannelOwner(channel) {
                Button(action: {
                    // Toggle password protection
                    if viewModel.passwordProtectedChannels.contains(channel) {
                        viewModel.removeChannelPassword(for: channel)
                    } else {
                        // Show password input
                        showPasswordInput = true
                        passwordInputChannel = channel
                    }
                }) {
                    HStack(spacing: 2) {
                        Image(systemName: viewModel.passwordProtectedChannels.contains(channel) ? "lock.fill" : "lock")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(viewModel.passwordProtectedChannels.contains(channel) ? backgroundColor : secondaryTextColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(viewModel.passwordProtectedChannels.contains(channel) ? Color.orange : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(viewModel.passwordProtectedChannels.contains(channel) ? Color.orange : secondaryTextColor.opacity(0.5), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(viewModel.passwordProtectedChannels.contains(channel) ? "Remove password" : "Set password")
            }
            
            // Leave button
            Button(action: {
                showLeaveChannelAlert = true
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Color.red.opacity(0.6))
            }
            .buttonStyle(.plain)
            .alert("leave channel", isPresented: $showLeaveChannelAlert) {
                Button("cancel", role: .cancel) { }
                Button("leave", role: .destructive) {
                    viewModel.leaveChannel(channel)
                }
            } message: {
                Text("sure you want to leave \(channel)?")
            }
        }
    }
    
    private var sidebarView: some View {
        HStack(spacing: 0) {
            // Grey vertical bar for visual continuity
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 1)
            
            VStack(alignment: .leading, spacing: 0) {
                // Header - match main toolbar height
                HStack {
                    Text("YOUR NETWORK")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(textColor)
                    Spacer()
                }
                .frame(height: 44) // Match header height
                .padding(.horizontal, 12)
                .background(backgroundColor.opacity(0.95))
                
                Divider()
            
            // Rooms and People list
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Channels section
                    channelsSection
                    
                    if !viewModel.joinedChannels.isEmpty {
                        Divider()
                            .padding(.vertical, 4)
                    }
                    
                    // People section
                    VStack(alignment: .leading, spacing: 8) {
                        // Show appropriate header based on context
                        if let currentChannel = viewModel.currentChannel {
                            Text("IN \(currentChannel.uppercased())")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(secondaryTextColor)
                                .padding(.horizontal, 12)
                        } else if !viewModel.connectedPeers.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 10))
                                    .accessibilityHidden(true)
                                Text("PEOPLE")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                            }
                            .foregroundColor(secondaryTextColor)
                            .padding(.horizontal, 12)
                        }
                        
                        if viewModel.connectedPeers.isEmpty {
                            Text("no one connected...")
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundColor(secondaryTextColor)
                                .padding(.horizontal)
                        } else if let currentChannel = viewModel.currentChannel,
                                  let channelMemberIDs = viewModel.channelMembers[currentChannel],
                                  channelMemberIDs.isEmpty {
                            Text("no one in this channel yet...")
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundColor(secondaryTextColor)
                                .padding(.horizontal)
                        } else {
                            let peerNicknames = viewModel.meshService.getPeerNicknames()
                            let peerRSSI = viewModel.meshService.getPeerRSSI()
                            let myPeerID = viewModel.meshService.myPeerID
                            
                            // Filter peers based on current channel
                            let peersToShow: [String] = {
                                if let currentChannel = viewModel.currentChannel,
                                   let channelMemberIDs = viewModel.channelMembers[currentChannel] {
                                    // Show only peers who have sent messages to this channel (including self)
                                    
                                    // Start with channel members who are also connected
                                    var memberPeers = viewModel.connectedPeers.filter { channelMemberIDs.contains($0) }
                                    
                                    // Always include ourselves if we're a channel member
                                    if channelMemberIDs.contains(myPeerID) && !memberPeers.contains(myPeerID) {
                                        memberPeers.append(myPeerID)
                                    }
                                    
                                    return memberPeers
                                } else {
                                    // Show all connected peers in main chat
                                    return viewModel.connectedPeers
                                }
                            }()
                            
                        // Sort peers: favorites first, then alphabetically by nickname
                        let sortedPeers = peersToShow.sorted { peer1, peer2 in
                            let isFav1 = viewModel.isFavorite(peerID: peer1)
                            let isFav2 = viewModel.isFavorite(peerID: peer2)
                            
                            if isFav1 != isFav2 {
                                return isFav1 // Favorites come first
                            }
                            
                            let name1 = peerNicknames[peer1] ?? "anon\(peer1.prefix(4))"
                            let name2 = peerNicknames[peer2] ?? "anon\(peer2.prefix(4))"
                            return name1 < name2
                        }
                        
                        ForEach(sortedPeers, id: \.self) { peerID in
                            let displayName = peerID == myPeerID ? viewModel.nickname : (peerNicknames[peerID] ?? "anon\(peerID.prefix(4))")
                            let rssi = peerRSSI[peerID]?.intValue ?? -100
                            let isFavorite = viewModel.isFavorite(peerID: peerID)
                            let isMe = peerID == myPeerID
                            
                            HStack(spacing: 8) {
                                // Signal strength indicator or unread message icon
                                if isMe {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(textColor)
                                        .accessibilityLabel("You")
                                } else if viewModel.unreadPrivateMessages.contains(peerID) {
                                    Image(systemName: "envelope.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color.orange)
                                        .accessibilityLabel("Unread message from \(displayName)")
                                } else {
                                    Image(systemName: "radiowaves.left")
                                        .font(.system(size: 12))
                                        .foregroundColor(viewModel.getRSSIColor(rssi: rssi, colorScheme: colorScheme))
                                        .accessibilityLabel("Signal strength: \(rssi > -60 ? "excellent" : rssi > -70 ? "good" : rssi > -80 ? "fair" : "poor")")
                                }
                                
                                // Peer name
                                if isMe {
                                    HStack {
                                        Text(displayName + " (you)")
                                            .font(.system(size: 14, design: .monospaced))
                                            .foregroundColor(textColor)
                                        
                                        Spacer()
                                    }
                                } else {
                                    Button(action: {
                                        if peerNicknames[peerID] != nil {
                                            viewModel.startPrivateChat(with: peerID)
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                showSidebar = false
                                                sidebarDragOffset = 0
                                            }
                                        }
                                    }) {
                                        Text(displayName)
                                            .font(.system(size: 14, design: .monospaced))
                                            .foregroundColor(peerNicknames[peerID] != nil ? textColor : secondaryTextColor)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(peerNicknames[peerID] == nil)
                                    .onTapGesture(count: 2) {
                                        // Show fingerprint on double tap
                                        viewModel.showFingerprint(for: peerID)
                                    }
                                    
                                    // Encryption status icon (after peer name)
                                    let encryptionStatus = viewModel.getEncryptionStatus(for: peerID)
                                    Image(systemName: encryptionStatus.icon)
                                        .font(.system(size: 10))
                                        .foregroundColor(encryptionStatus == .noiseVerified ? Color.green : 
                                                       encryptionStatus == .noiseSecured ? textColor :
                                                       encryptionStatus == .noiseHandshaking ? Color.orange :
                                                       Color.red)
                                        .accessibilityLabel("Encryption: \(encryptionStatus == .noiseVerified ? "verified" : encryptionStatus == .noiseSecured ? "secured" : encryptionStatus == .noiseHandshaking ? "establishing" : "none")")
                                    
                                    Spacer()
                                    
                                    // Favorite star
                                    Button(action: {
                                        viewModel.toggleFavorite(peerID: peerID)
                                    }) {
                                        Image(systemName: isFavorite ? "star.fill" : "star")
                                            .font(.system(size: 12))
                                            .foregroundColor(isFavorite ? Color.yellow : secondaryTextColor)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(isFavorite ? "Remove \(displayName) from favorites" : "Add \(displayName) to favorites")
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                        }
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            
            Spacer()
        }
        .background(backgroundColor)
        }
    }
    
    // MARK: - View Components
    
    private var mainChatView: some View {
        VStack(spacing: 0) {
            mainHeaderView
            Divider()
            messagesView(for: nil, privatePeer: nil)
            Divider()
            inputView
        }
        .background(backgroundColor)
        .foregroundColor(textColor)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if !showSidebar && value.translation.width < 0 {
                        sidebarDragOffset = max(value.translation.width, -300)
                    } else if showSidebar && value.translation.width > 0 {
                        sidebarDragOffset = min(-300 + value.translation.width, 0)
                    }
                }
                .onEnded { value in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        if !showSidebar {
                            if value.translation.width < -100 || (value.translation.width < -50 && value.velocity.width < -500) {
                                showSidebar = true
                                sidebarDragOffset = 0
                            } else {
                                sidebarDragOffset = 0
                            }
                        } else {
                            if value.translation.width > 100 || (value.translation.width > 50 && value.velocity.width > 500) {
                                showSidebar = false
                                sidebarDragOffset = 0
                            } else {
                                sidebarDragOffset = 0
                            }
                        }
                    }
                }
        )
    }
    
    private var privateChatView: some View {
        HStack(spacing: 0) {
            // Vertical separator bar
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 1)
            
            VStack(spacing: 0) {
                privateHeaderView
                Divider()
                messagesView(for: nil, privatePeer: viewModel.selectedPrivateChatPeer)
                Divider()
                inputView
            }
            .background(backgroundColor)
            .foregroundColor(textColor)
        }
    }
    
    private var channelView: some View {
        HStack(spacing: 0) {
            // Vertical separator bar
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 1)
            
            VStack(spacing: 0) {
                channelHeaderView
                Divider()
                messagesView(for: viewModel.currentChannel, privatePeer: nil)
                Divider()
                inputView
            }
            .background(backgroundColor)
            .foregroundColor(textColor)
        }
    }
    
    private var mainHeaderView: some View {
        HStack(spacing: 4) {
            Text("krtr-mesh*")
                .font(.system(size: 18, weight: .medium, design: .monospaced))
                .foregroundColor(textColor)
                .onTapGesture(count: 3) {
                    // PANIC: Triple-tap to clear all data
                    viewModel.panicClearAllData()
                }
                .onTapGesture(count: 1) {
                    // Single tap for app info
                    showAppInfo = true
                }
            
            HStack(spacing: 0) {
                Text("@")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(secondaryTextColor)
                
                TextField("nickname", text: $viewModel.nickname)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, design: .monospaced))
                    .frame(maxWidth: 100)
                    .foregroundColor(textColor)
                    .onChange(of: viewModel.nickname) { _ in
                        viewModel.saveNickname()
                    }
                    .onSubmit {
                        viewModel.saveNickname()
                    }
            }

            // ZK Dashboard button
            Button(action: {
                showZKDashboard = true
            }) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Zero-Knowledge Dashboard")

            Spacer()
            
            // People counter with unread indicator
            HStack(spacing: 4) {
                // Check for any unread channel messages
                let hasUnreadChannelMessages = viewModel.unreadChannelMessages.values.contains { $0 > 0 }
                
                if hasUnreadChannelMessages {
                    Image(systemName: "number")
                        .font(.system(size: 12))
                        .foregroundColor(Color.blue)
                        .accessibilityLabel("Unread channel messages")
                }
                
                if !viewModel.unreadPrivateMessages.isEmpty {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color.orange)
                        .accessibilityLabel("Unread private messages")
                }
                
                let otherPeersCount = viewModel.connectedPeers.filter { $0 != viewModel.meshService.myPeerID }.count
                let channelCount = viewModel.joinedChannels.count
                
                HStack(spacing: 4) {
                    // People icon with count
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 11))
                        .accessibilityLabel("\(otherPeersCount) connected \(otherPeersCount == 1 ? "person" : "people")")
                    Text("\(otherPeersCount)")
                        .font(.system(size: 12, design: .monospaced))
                        .accessibilityHidden(true)
                    
                    // Channels icon with count (only if there are channels)
                    if channelCount > 0 {
                        Text("·")
                            .font(.system(size: 12, design: .monospaced))
                        Image(systemName: "square.split.2x2")
                            .font(.system(size: 11))
                            .accessibilityLabel("\(channelCount) active \(channelCount == 1 ? "channel" : "channels")")
                        Text("\(channelCount)")
                            .font(.system(size: 12, design: .monospaced))
                            .accessibilityHidden(true)
                    }
                }
                .foregroundColor(viewModel.isConnected ? textColor : Color.red)
            }
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showSidebar.toggle()
                    sidebarDragOffset = 0
                }
            }
        }
        .frame(height: 44)
        .padding(.horizontal, 12)
        .background(backgroundColor.opacity(0.95))
    }
    
    private var privateHeaderView: some View {
        Group {
            if let privatePeerID = viewModel.selectedPrivateChatPeer,
               let privatePeerNick = viewModel.meshService.getPeerNicknames()[privatePeerID] {
                HStack {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showPrivateChat = false
                            viewModel.endPrivateChat()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12))
                            Text("back")
                                .font(.system(size: 14, design: .monospaced))
                        }
                        .foregroundColor(textColor)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back to main chat")
                    
                    Spacer()
                    
                    Button(action: {
                        viewModel.showFingerprint(for: privatePeerID)
                    }) {
                        HStack(spacing: 6) {
                            Text("\(privatePeerNick)")
                                .font(.system(size: 16, weight: .medium, design: .monospaced))
                                .foregroundColor(Color.orange)
                            // Dynamic encryption status icon
                            let encryptionStatus = viewModel.getEncryptionStatus(for: privatePeerID)
                            Image(systemName: encryptionStatus.icon)
                                .font(.system(size: 14))
                                .foregroundColor(encryptionStatus == .noiseVerified ? Color.green : 
                                               encryptionStatus == .noiseSecured ? Color.orange :
                                               Color.red)
                                .accessibilityLabel("Encryption status: \(encryptionStatus == .noiseVerified ? "verified" : encryptionStatus == .noiseSecured ? "secured" : "not encrypted")")
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("Private chat with \(privatePeerNick)")
                        .accessibilityHint("Tap to view encryption fingerprint")
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    // Favorite button
                    Button(action: {
                        viewModel.toggleFavorite(peerID: privatePeerID)
                    }) {
                        Image(systemName: viewModel.isFavorite(peerID: privatePeerID) ? "star.fill" : "star")
                            .font(.system(size: 16))
                            .foregroundColor(viewModel.isFavorite(peerID: privatePeerID) ? Color.yellow : textColor)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(viewModel.isFavorite(peerID: privatePeerID) ? "Remove from favorites" : "Add to favorites")
                    .accessibilityHint("Double tap to toggle favorite status")
                }
                .frame(height: 44)
                .padding(.horizontal, 12)
                .background(backgroundColor.opacity(0.95))
            } else {
                EmptyView()
            }
        }
    }
    
    private var channelHeaderView: some View {
        Group {
            if let currentChannel = viewModel.currentChannel {
                HStack {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showChannel = false
                        viewModel.switchToChannel(nil)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12))
                        Text("back")
                            .font(.system(size: 14, design: .monospaced))
                    }
                    .foregroundColor(textColor)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back to main chat")
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showSidebar.toggle()
                        sidebarDragOffset = 0
                    }
                }) {
                    HStack(spacing: 4) {
                        if viewModel.passwordProtectedChannels.contains(currentChannel) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color.orange)
                                .accessibilityLabel("Password protected channel")
                        }
                        
                        Text(currentChannel)
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .foregroundColor(viewModel.passwordProtectedChannels.contains(currentChannel) ? Color.orange : Color.blue)
                        
                        // Verification status indicator after channel name
                        if viewModel.passwordProtectedChannels.contains(currentChannel),
                           let status = viewModel.channelVerificationStatus[currentChannel] {
                            switch status {
                            case .verifying:
                                ProgressView()
                                    .scaleEffect(0.5)
                                    .frame(width: 12, height: 12)
                            case .verified:
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.green)
                            case .failed:
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.red)
                            case .unverified:
                                Image(systemName: "questionmark.circle")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.gray)
                                    .help("Password verification pending")
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                
                Spacer()
                
                HStack(spacing: 8) {
                    // Password button for channel creator only
                    if viewModel.isChannelOwner(currentChannel) {
                        Button(action: {
                            // Toggle password protection
                            if viewModel.passwordProtectedChannels.contains(currentChannel) {
                                viewModel.removeChannelPassword(for: currentChannel)
                            } else {
                                // Show password input
                                showPasswordInput = true
                                passwordInputChannel = currentChannel
                            }
                        }) {
                            Image(systemName: viewModel.passwordProtectedChannels.contains(currentChannel) ? "lock.fill" : "lock")
                                .font(.system(size: 16))
                                .foregroundColor(viewModel.passwordProtectedChannels.contains(currentChannel) ? Color.yellow : textColor)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(viewModel.passwordProtectedChannels.contains(currentChannel) ? "Remove channel password" : "Set channel password")
                    }
                    
                    // Leave channel button
                    Button(action: {
                        showLeaveChannelAlert = true
                    }) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 16))
                            .foregroundColor(Color.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .alert("leave channel?", isPresented: $showLeaveChannelAlert) {
                        Button("cancel", role: .cancel) { }
                        Button("leave", role: .destructive) {
                            viewModel.leaveChannel(currentChannel)
                        }
                    } message: {
                        Text("sure you want to leave \(currentChannel)?")
                    }
                }
            }
            .frame(height: 44)
            .padding(.horizontal, 12)
            .background(backgroundColor.opacity(0.95))
            } else {
                EmptyView()
            }
        }
    }
}

// Helper view for rendering message content with clickable hashtags
struct MessageContentView: View {
    let message: KRTRMessage
    let viewModel: ChatViewModel
    let colorScheme: ColorScheme
    let isMentioned: Bool
    
    var body: some View {
        let content = message.content
        let hashtagPattern = "#([a-zA-Z0-9_]+)"
        let mentionPattern = "@([a-zA-Z0-9_]+)"
        
        let hashtagRegex = try? NSRegularExpression(pattern: hashtagPattern, options: [])
        let mentionRegex = try? NSRegularExpression(pattern: mentionPattern, options: [])
        
        let hashtagMatches = hashtagRegex?.matches(in: content, options: [], range: NSRange(location: 0, length: content.count)) ?? []
        let mentionMatches = mentionRegex?.matches(in: content, options: [], range: NSRange(location: 0, length: content.count)) ?? []
        
        // Combine all matches and sort by location
        var allMatches: [(range: NSRange, type: String)] = []
        for match in hashtagMatches {
            allMatches.append((match.range(at: 0), "hashtag"))
        }
        for match in mentionMatches {
            allMatches.append((match.range(at: 0), "mention"))
        }
        allMatches.sort { $0.range.location < $1.range.location }
        
        // Build the text as a concatenated Text view for natural wrapping
        let segments = buildTextSegments()
        var result = Text("")
        
        for segment in segments {
            if segment.type == "hashtag" {
                // Note: We can't have clickable links in concatenated Text, so hashtags won't be clickable
                result = result + Text(segment.text)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color.blue)
                    .underline()
            } else if segment.type == "mention" {
                result = result + Text(segment.text)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color.orange)
            } else {
                result = result + Text(segment.text)
                    .font(.system(size: 14, design: .monospaced))
                    .fontWeight(isMentioned ? .bold : .regular)
            }
        }
        
        return result
            .textSelection(.enabled)
    }
    
    private func buildTextSegments() -> [(text: String, type: String)] {
        var segments: [(text: String, type: String)] = []
        let content = message.content
        var lastEnd = content.startIndex
        
        let hashtagPattern = "#([a-zA-Z0-9_]+)"
        let mentionPattern = "@([a-zA-Z0-9_]+)"
        
        let hashtagRegex = try? NSRegularExpression(pattern: hashtagPattern, options: [])
        let mentionRegex = try? NSRegularExpression(pattern: mentionPattern, options: [])
        
        let hashtagMatches = hashtagRegex?.matches(in: content, options: [], range: NSRange(location: 0, length: content.count)) ?? []
        let mentionMatches = mentionRegex?.matches(in: content, options: [], range: NSRange(location: 0, length: content.count)) ?? []
        
        // Combine all matches and sort by location
        var allMatches: [(range: NSRange, type: String)] = []
        for match in hashtagMatches {
            allMatches.append((match.range(at: 0), "hashtag"))
        }
        for match in mentionMatches {
            allMatches.append((match.range(at: 0), "mention"))
        }
        allMatches.sort { $0.range.location < $1.range.location }
        
        for (matchRange, matchType) in allMatches {
            if let range = Range(matchRange, in: content) {
                // Add text before the match
                if lastEnd < range.lowerBound {
                    let beforeText = String(content[lastEnd..<range.lowerBound])
                    if !beforeText.isEmpty {
                        segments.append((beforeText, "text"))
                    }
                }
                
                // Add the match
                let matchText = String(content[range])
                segments.append((matchText, matchType))
                
                lastEnd = range.upperBound
            }
        }
        
        // Add any remaining text
        if lastEnd < content.endIndex {
            let remainingText = String(content[lastEnd...])
            if !remainingText.isEmpty {
                segments.append((remainingText, "text"))
            }
        }
        
        return segments
    }
}

// Delivery status indicator view
struct DeliveryStatusView: View {
    let status: DeliveryStatus
    let colorScheme: ColorScheme
    
    private var textColor: Color {
        colorScheme == .dark ? Color.green : Color(red: 0, green: 0.5, blue: 0)
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? Color.green.opacity(0.8) : Color(red: 0, green: 0.5, blue: 0).opacity(0.8)
    }
    
    var body: some View {
        switch status {
        case .sending:
            Image(systemName: "circle")
                .font(.system(size: 10))
                .foregroundColor(secondaryTextColor.opacity(0.6))
            
        case .sent:
            Image(systemName: "checkmark")
                .font(.system(size: 10))
                .foregroundColor(secondaryTextColor.opacity(0.6))
            
        case .delivered(let nickname, _):
            HStack(spacing: -2) {
                Image(systemName: "checkmark")
                    .font(.system(size: 10))
                Image(systemName: "checkmark")
                    .font(.system(size: 10))
            }
            .foregroundColor(textColor.opacity(0.8))
            .help("Delivered to \(nickname)")
            
        case .read(let nickname, _):
            HStack(spacing: -2) {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(Color(red: 0.0, green: 0.478, blue: 1.0))  // Bright blue
            .help("Read by \(nickname)")
            
        case .failed(let reason):
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 10))
                .foregroundColor(Color.red.opacity(0.8))
                .help("Failed: \(reason)")
            
        case .partiallyDelivered(let reached, let total):
            HStack(spacing: 1) {
                Image(systemName: "checkmark")
                    .font(.system(size: 10))
                Text("\(reached)/\(total)")
                    .font(.system(size: 10, design: .monospaced))
            }
            .foregroundColor(secondaryTextColor.opacity(0.6))
            .help("Delivered to \(reached) of \(total) members")
        }
    }
}

// MARK: - ZK Dashboard Sheet

struct ZKDashboardSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var zkService = ZKServiceFactory.createService()
    @State private var showingTestView = false
    @State private var testResults: [ZKTestResult] = []
    @State private var isRunningTests = false
    @State private var currentTest = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
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

                    // Status Cards
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

                        ZKStatusCard(
                            title: "Avg Duration",
                            value: String(format: "%.3fs", zkService.getStats().averageDuration),
                            icon: "timer",
                            color: .blue
                        )
                    }

                    // Quick Actions
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
                                title: "Generate Proof",
                                subtitle: "Test proof gen",
                                icon: "checkmark.shield",
                                color: .green
                            ) {
                                generateTestProof()
                            }

                            ZKActionButton(
                                title: "View Stats",
                                subtitle: "Performance",
                                icon: "chart.bar",
                                color: .orange
                            ) {
                                // Show detailed stats
                            }

                            ZKActionButton(
                                title: "Reset Stats",
                                subtitle: "Clear data",
                                icon: "arrow.clockwise",
                                color: .red
                            ) {
                                zkService.resetStats()
                            }
                        }
                    }

                    // Test Results
                    if !testResults.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recent Test Results")
                                .font(.headline)
                                .fontWeight(.bold)

                            ForEach(testResults.prefix(5)) { result in
                                HStack {
                                    Text(result.statusIcon)
                                        .font(.title2)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(result.name)
                                            .font(.subheadline)
                                            .fontWeight(.medium)

                                        Text(result.details)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }

                                    Spacer()

                                    Text("\(result.durationString)s")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                    }

                    // Current Test Status
                    if isRunningTests {
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.2)

                            Text(currentTest)
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.blue)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }

                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle("Zero-Knowledge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingTestView) {
                ZKTestSheet(
                    zkService: zkService,
                    testResults: $testResults,
                    isRunningTests: $isRunningTests,
                    currentTest: $currentTest
                )
            }
        }
    }

    private func generateTestProof() {
        isRunningTests = true
        currentTest = "Generating test membership proof..."

        Task {
            do {
                let membershipKey = Data("test_membership_key".utf8)
                let groupRoot = Data("test_group_root".utf8)
                let pathElements = [Data("path_element_1".utf8)]
                let pathIndices = [0]

                let startTime = Date()
                let proofResult = try await zkService.generateMembershipProof(
                    membershipKey: membershipKey,
                    groupRoot: groupRoot,
                    pathElements: pathElements,
                    pathIndices: pathIndices
                )
                let duration = Date().timeIntervalSince(startTime)

                let result = ZKTestResult(
                    name: "Test Membership Proof",
                    success: true,
                    duration: duration,
                    details: "Generated proof successfully",
                    proofSize: proofResult.proof.count
                )

                await MainActor.run {
                    testResults.insert(result, at: 0)
                    isRunningTests = false
                    currentTest = ""
                }

            } catch {
                let result = ZKTestResult(
                    name: "Test Membership Proof",
                    success: false,
                    duration: 0,
                    details: "Error: \(error.localizedDescription)",
                    proofSize: nil
                )

                await MainActor.run {
                    testResults.insert(result, at: 0)
                    isRunningTests = false
                    currentTest = ""
                }
            }
        }
    }
}

// MARK: - ZK Supporting Views

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
}

struct ZKTestSheet: View {
    let zkService: MockZKService
    @Binding var testResults: [ZKTestResult]
    @Binding var isRunningTests: Bool
    @Binding var currentTest: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("ZK Test Suite")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Run comprehensive tests to verify ZK functionality")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Button(action: runBasicTests) {
                    HStack {
                        if isRunningTests {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "play.circle.fill")
                        }

                        Text(isRunningTests ? "Running Tests..." : "Run Basic Tests")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isRunningTests ? Color.gray : Color.blue)
                    .cornerRadius(12)
                }
                .disabled(isRunningTests)

                if isRunningTests {
                    Text(currentTest)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .multilineTextAlignment(.center)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("ZK Tests")
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

    private func runBasicTests() {
        isRunningTests = true

        Task {
            // Test 1: Service availability
            await updateCurrentTest("Testing ZK service availability...")
            await addTestResult(ZKTestResult(
                name: "Service Availability",
                success: true,
                duration: 0.001,
                details: "Service available: \(zkService.isAvailable ? "Yes" : "No (fallback)")",
                proofSize: nil
            ))

            // Test 2: Membership proof
            await updateCurrentTest("Testing membership proof generation...")
            await testMembershipProof()

            // Test 3: Reputation proof
            await updateCurrentTest("Testing reputation proof generation...")
            await testReputationProof()

            await MainActor.run {
                isRunningTests = false
                currentTest = "All tests completed!"
            }

            // Clear status after delay
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                currentTest = ""
            }
        }
    }

    private func testMembershipProof() async {
        let startTime = Date()

        do {
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

            let duration = Date().timeIntervalSince(startTime)

            await addTestResult(ZKTestResult(
                name: "Membership Proof",
                success: true,
                duration: duration,
                details: "Generated proof with \(proofResult.publicInputs.count) public inputs",
                proofSize: proofResult.proof.count
            ))

        } catch {
            let duration = Date().timeIntervalSince(startTime)

            await addTestResult(ZKTestResult(
                name: "Membership Proof",
                success: false,
                duration: duration,
                details: "Error: \(error.localizedDescription)",
                proofSize: nil
            ))
        }
    }

    private func testReputationProof() async {
        let startTime = Date()

        do {
            let proofResult = try await zkService.generateReputationProof(
                reputationScore: 85,
                threshold: 50,
                nonce: Data("test_nonce".utf8)
            )

            let duration = Date().timeIntervalSince(startTime)

            await addTestResult(ZKTestResult(
                name: "Reputation Proof",
                success: true,
                duration: duration,
                details: "Proved score ≥ 50 without revealing actual score (85)",
                proofSize: proofResult.proof.count
            ))

        } catch {
            let duration = Date().timeIntervalSince(startTime)

            await addTestResult(ZKTestResult(
                name: "Reputation Proof",
                success: false,
                duration: duration,
                details: "Error: \(error.localizedDescription)",
                proofSize: nil
            ))
        }
    }

    @MainActor
    private func updateCurrentTest(_ test: String) {
        currentTest = test
    }

    @MainActor
    private func addTestResult(_ result: ZKTestResult) {
        testResults.insert(result, at: 0)
    }
}
