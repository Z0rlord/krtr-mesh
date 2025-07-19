import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var chatViewModel: ChatViewModel
    @StateObject private var meshService = BluetoothMeshService()
    
    var body: some View {
        TabView {
            // Mesh Tab
            MeshView(meshService: meshService)
                .tabItem {
                    Image(systemName: "network")
                    Text("Mesh")
                }

            // Chat Tab
            ContentView()
                .environmentObject(chatViewModel)
                .tabItem {
                    Image(systemName: "message.circle.fill")
                    Text("Chat")
                }

            // ZK Dashboard Tab
            ZKDashboardView(meshService: meshService)
                .tabItem {
                    Image(systemName: "lock.shield.fill")
                    Text("ZK Dashboard")
                }

            // ZK Enhanced Features Tab
            ZKEnhancedFeaturesView()
                .tabItem {
                    Image(systemName: "shield.checkered")
                    Text("ZK Features")
                }

            // Settings/Info Tab
            AppInfoView()
                .tabItem {
                    Image(systemName: "info.circle.fill")
                    Text("Info")
                }
        }
        .accentColor(.blue)
    }
}

#Preview {
    MainTabView()
        .environmentObject(ChatViewModel())
}
