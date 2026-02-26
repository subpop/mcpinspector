import SwiftUI

struct MainView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedServerId: UUID?
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly
    @State private var showingAddSheet = false
    @State private var editingConfiguration: ServerConfiguration?
    
    private var hasServers: Bool {
        !appState.configurationStore.configurations.isEmpty
    }
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } detail: {
            detailView
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: hasServers) { _, newValue in
            columnVisibility = newValue ? .all : .detailOnly
        }
        .onAppear {
            if hasServers {
                columnVisibility = .all
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            ServerConfigEditView(mode: .add)
        }
        .sheet(item: $editingConfiguration) { config in
            ServerConfigEditView(mode: .edit(config))
        }
    }
    
    // MARK: - Sidebar
    
    private var sidebar: some View {
        VStack(spacing: 0) {
            if appState.configurationStore.configurations.isEmpty {
                emptyServerList
            } else {
                serverList
            }
            
            Divider()
            
            runningServersSummary
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.bar)
        }
        .navigationTitle("MCP Inspector")
        .frame(minWidth: 220)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddSheet = true }) {
                    Label("Add Server", systemImage: "plus")
                }
            }
        }
    }
    
    private var serverList: some View {
        List(selection: $selectedServerId) {
            ForEach(appState.configurationStore.configurations) { config in
                ServerSidebarRow(
                    configuration: config,
                    connectionState: appState.connectionState(for: config.id)
                )
                .tag(config.id)
                .contextMenu {
                    serverContextMenu(for: config)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        deleteServer(config)
                    } label: {
                        Label("", systemImage: "trash")
                    }
                }
            }
            .onDelete(perform: deleteConfigurations)
        }
        .listStyle(.sidebar)
    }
    
    private var emptyServerList: some View {
        VStack(spacing: 16) {
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private func serverContextMenu(for config: ServerConfiguration) -> some View {
        let state = appState.connectionState(for: config.id)
        
        if state == .connected {
            Button("Stop") {
                appState.stopSession(for: config)
            }
        } else if state == .connecting {
            Button("Stop") {
                appState.stopSession(for: config)
            }
        } else {
            Button("Start") {
                appState.startSession(for: config)
            }
        }
        
        Divider()
        
        Button("Edit...") {
            editingConfiguration = config
        }
        
        Button("Delete", role: .destructive) {
            deleteServer(config)
        }
    }
    
    // MARK: - Detail View
    
    @ViewBuilder
    private var detailView: some View {
        if let serverId = selectedServerId,
           let config = appState.configurationStore.configuration(withId: serverId) {
            let session = appState.session(for: config)
            ServerDetailView(session: session, onEdit: {
                editingConfiguration = config
            })
        } else {
            welcomeView
        }
    }
    
    // MARK: - Running Servers Summary
    
    private var runningServersSummary: some View {
        let runningCount = appState.sessions.values.filter { $0.isConnected }.count
        return HStack(spacing: 4) {
            Circle()
                .fill(runningCount > 0 ? .green : .gray)
                .frame(width: 8, height: 8)
            Text(runningCount > 0 ? "\(runningCount) running" : "No servers running")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Welcome View
    
    private var welcomeView: some View {
        VStack(spacing: 16) {
            Image(systemName: "server.rack")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("MCP Inspector")
                .font(.largeTitle)
                .fontWeight(.semibold)
            
            Text("Select a server from the sidebar to get started.")
                .foregroundColor(.secondary)
            
            if appState.configurationStore.configurations.isEmpty {
                Divider()
                    .frame(width: 200)
                    .padding(.vertical)
                
                Text("No servers configured yet.")
                    .foregroundColor(.secondary)
                
                Button("Add Server", systemImage: "plus") {
                    showingAddSheet = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Actions
    
    private func deleteConfigurations(at offsets: IndexSet) {
        for index in offsets {
            let config = appState.configurationStore.configurations[index]
            appState.removeSession(for: config.id)
        }
        appState.configurationStore.delete(at: offsets)
    }
    
    private func deleteServer(_ config: ServerConfiguration) {
        if selectedServerId == config.id {
            selectedServerId = nil
        }
        appState.removeSession(for: config.id)
        appState.configurationStore.delete(config)
    }
}

// MARK: - Server Sidebar Row

struct ServerSidebarRow: View {
    let configuration: ServerConfiguration
    let connectionState: ServerSession.ConnectionState
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(configuration.name)
                    .font(.body)
                    .lineLimit(1)
                
                Text(configuration.commandDisplay)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
    
    private var statusColor: Color {
        switch connectionState {
        case .connected: return .green
        case .connecting: return .orange
        case .disconnected: return .gray
        case .error: return .red
        }
    }
}

#Preview {
    MainView()
        .environmentObject(AppState())
}
