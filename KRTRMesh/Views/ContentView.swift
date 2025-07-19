/**
 * KRTR Content View - Main SwiftUI interface for mesh chat
 * Provides tabbed interface for chat, peers, and settings
 */

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var chatViewModel: ChatViewModel
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ChatView()
                .tabItem {
                    Image(systemName: "message.fill")
                    Text("Chat")
                }
                .tag(0)
            
            PeersView()
                .tabItem {
                    Image(systemName: "person.3.fill")
                    Text("Peers")
                }
                .tag(1)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear.fill")
                    Text("Settings")
                }
                .tag(2)
        }
        .accentColor(.blue)
    }
}

// MARK: - Chat View
struct ChatView: View {
    @EnvironmentObject var chatViewModel: ChatViewModel
    @State private var messageText = ""
    @State private var showingChannelPicker = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Channel header
                HStack {
                    Button(chatViewModel.currentChannel) {
                        showingChannelPicker = true
                    }
                    .font(.headline)
                    .foregroundColor(.blue)
                    
                    Spacer()
                    
                    // Connection status
                    HStack {
                        Circle()
                            .fill(chatViewModel.isConnected ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text("\(chatViewModel.networkStatus.connectedPeers) peers")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                
                Divider()
                
                // Messages list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(filteredMessages) { message in
                                MessageRow(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .onChange(of: chatViewModel.messages.count) { _ in
                        if let lastMessage = chatViewModel.messages.last {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Message input
                HStack {
                    TextField("Type a message...", text: $messageText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            sendMessage()
                        }
                    
                    Button("Send") {
                        sendMessage()
                    }
                    .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
            }
            .navigationTitle("KRTR Mesh")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingChannelPicker) {
                ChannelPickerView()
            }
        }
    }
    
    private var filteredMessages: [KRTRMessage] {
        return chatViewModel.messages.filter { message in
            if chatViewModel.currentChannel.hasPrefix("#") {
                return message.channel == chatViewModel.currentChannel
            } else {
                return message.isPrivate
            }
        }
    }
    
    private func sendMessage() {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        chatViewModel.sendMessage(trimmed)
        messageText = ""
    }
}

// MARK: - Message Row
struct MessageRow: View {
    let message: KRTRMessage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(message.sender)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                
                if message.isPrivate {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
                
                Spacer()
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text(message.content)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Peers View
struct PeersView: View {
    @EnvironmentObject var chatViewModel: ChatViewModel
    
    var body: some View {
        NavigationView {
            List {
                Section("Connected Peers") {
                    ForEach(connectedPeers) { peer in
                        PeerRow(peer: peer)
                    }
                }
                
                Section("Discovered Peers") {
                    ForEach(discoveredPeers) { peer in
                        PeerRow(peer: peer)
                    }
                }
                
                if chatViewModel.peers.isEmpty {
                    Text("No peers discovered")
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            .navigationTitle("Peers")
            .refreshable {
                // Refresh peer list
            }
        }
    }
    
    private var connectedPeers: [PeerInfo] {
        return chatViewModel.peers.filter { $0.isConnected }
    }
    
    private var discoveredPeers: [PeerInfo] {
        return chatViewModel.peers.filter { !$0.isConnected }
    }
}

// MARK: - Peer Row
struct PeerRow: View {
    let peer: PeerInfo
    @EnvironmentObject var chatViewModel: ChatViewModel
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(peer.nickname)
                    .font(.headline)
                
                Text(peer.id.prefix(8) + "...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                HStack {
                    if peer.isAuthenticated {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                    
                    Circle()
                        .fill(peer.isConnected ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                }
                
                if let rssi = peer.rssi {
                    Text("\(rssi.intValue) dBm")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // TODO: Open private chat with peer
        }
    }
}

// MARK: - Channel Picker View
struct ChannelPickerView: View {
    @EnvironmentObject var chatViewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var newChannelName = ""
    
    private let commonChannels = ["#general", "#random", "#tech", "#privacy"]
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    Section("Common Channels") {
                        ForEach(commonChannels, id: \.self) { channel in
                            Button(channel) {
                                chatViewModel.joinChannel(channel)
                                dismiss()
                            }
                        }
                    }
                }
                
                VStack {
                    TextField("Enter channel name", text: $newChannelName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button("Join Channel") {
                        chatViewModel.joinChannel(newChannelName)
                        dismiss()
                    }
                    .disabled(newChannelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
            }
            .navigationTitle("Select Channel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @EnvironmentObject var chatViewModel: ChatViewModel
    @State private var showingNicknameEditor = false
    @State private var tempNickname = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Profile") {
                    HStack {
                        Text("Nickname")
                        Spacer()
                        Button(chatViewModel.nickname) {
                            tempNickname = chatViewModel.nickname
                            showingNicknameEditor = true
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                Section("Network Status") {
                    HStack {
                        Text("Connected Peers")
                        Spacer()
                        Text("\(chatViewModel.networkStatus.connectedPeers)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Battery Level")
                        Spacer()
                        Text("\(Int(chatViewModel.networkStatus.batteryLevel * 100))%")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Power Mode")
                        Spacer()
                        Text("\(chatViewModel.networkStatus.powerMode)")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Statistics") {
                    HStack {
                        Text("Messages Sent")
                        Spacer()
                        Text("\(chatViewModel.networkStatus.messagesSent)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Messages Received")
                        Spacer()
                        Text("\(chatViewModel.networkStatus.messagesReceived)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
        .alert("Edit Nickname", isPresented: $showingNicknameEditor) {
            TextField("Nickname", text: $tempNickname)
            Button("Save") {
                chatViewModel.setNickname(tempNickname)
            }
            Button("Cancel", role: .cancel) { }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ChatViewModel())
}
