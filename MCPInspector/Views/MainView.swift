import SwiftUI

struct MainView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedSection: SidebarSection? = .servers
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    enum SidebarSection: String, CaseIterable, Identifiable {
        case servers = "Servers"
        case connection = "Connection"
        case tools = "Tools"
        case prompts = "Prompts"
        case resources = "Resources"
        case logs = "Logs"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .servers: return "server.rack"
            case .connection: return "network"
            case .tools: return "wrench.and.screwdriver"
            case .prompts: return "text.bubble"
            case .resources: return "doc.text"
            case .logs: return "list.bullet.rectangle"
            }
        }
        
        var requiresConnection: Bool {
            switch self {
            case .servers, .connection, .logs:
                return false
            case .tools, .prompts, .resources:
                return true
            }
        }
    }
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } detail: {
            detailView
        }
        .navigationSplitViewStyle(.balanced)
    }
    
    // MARK: - Sidebar
    
    private var sidebar: some View {
        VStack(spacing: 0) {
            List(selection: $selectedSection) {
                Section("Configuration") {
                    NavigationLink(value: SidebarSection.servers) {
                        Label("Servers", systemImage: SidebarSection.servers.icon)
                    }
                }
                
                Section("Inspector") {
                    ForEach([SidebarSection.connection, .tools, .prompts, .resources], id: \.self) { section in
                        NavigationLink(value: section) {
                            Label(section.rawValue, systemImage: section.icon)
                        }
                        .disabled(section.requiresConnection && !isConnected)
                    }
                }
                
                Section("Debug") {
                    NavigationLink(value: SidebarSection.logs) {
                        Label("Logs", systemImage: SidebarSection.logs.icon)
                            .badge(appState.logStore.entries.count)
                    }
                }
            }
            .listStyle(.sidebar)
            
            Divider()
            
            // Status bar at bottom of sidebar
            connectionStatusBadge
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.bar)
        }
        .navigationTitle("MCP Inspector")
        .frame(minWidth: 200)
    }
    
    // MARK: - Detail View
    
    @ViewBuilder
    private var detailView: some View {
        switch selectedSection {
        case .servers:
            ServerConfigListView()
        case .connection:
            ConnectionView()
        case .tools:
            if isConnected {
                ToolsView()
            } else {
                notConnectedView
            }
        case .prompts:
            if isConnected {
                PromptsView()
            } else {
                notConnectedView
            }
        case .resources:
            if isConnected {
                ResourcesView()
            } else {
                notConnectedView
            }
        case .logs:
            LogView()
        case .none:
            welcomeView
        }
    }
    
    // MARK: - Helper Views
    
    private var isConnected: Bool {
        appState.connectionState == .connected
    }
    
    private var connectionStatusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(connectionStatusColor)
                .frame(width: 8, height: 8)
            Text(connectionStatusText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var connectionStatusColor: Color {
        switch appState.connectionState {
        case .connected:
            return .green
        case .connecting:
            return .orange
        case .disconnected:
            return .gray
        case .error:
            return .red
        }
    }
    
    private var connectionStatusText: String {
        switch appState.connectionState {
        case .connected:
            return appState.selectedServer?.name ?? "Connected"
        case .connecting:
            return "Connecting..."
        case .disconnected:
            return "Disconnected"
        case .error(let message):
            return "Error: \(message.prefix(20))..."
        }
    }
    
    private var welcomeView: some View {
        VStack(spacing: 16) {
            Image(systemName: "network")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("MCP Inspector")
                .font(.largeTitle)
                .fontWeight(.semibold)
            
            Text("Select a section from the sidebar to get started.")
                .foregroundColor(.secondary)
            
            if appState.configurationStore.configurations.isEmpty {
                Divider()
                    .frame(width: 200)
                    .padding(.vertical)
                
                Text("No servers configured yet.")
                    .foregroundColor(.secondary)
                
                Button("Add Server") {
                    selectedSection = .servers
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var notConnectedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "network.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("Not Connected")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Connect to an MCP server to view this section.")
                .foregroundColor(.secondary)
            
            Button("Go to Connection") {
                selectedSection = .connection
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    MainView()
        .environmentObject(AppState())
}
