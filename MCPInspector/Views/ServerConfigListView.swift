import SwiftUI

struct ServerConfigListView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showingAddSheet = false
    @State private var editingConfiguration: ServerConfiguration?
    @State private var selectedConfigId: UUID?
    
    var body: some View {
        VStack(spacing: 0) {
            if appState.configurationStore.configurations.isEmpty {
                emptyStateView
            } else {
                serverList
            }
        }
        .navigationTitle("Server Configurations")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 8) {
                    if let selectedConfig = selectedConfiguration {
                        if isConnected(to: selectedConfig) {
                            Button(action: { appState.disconnect() }) {
                                Label("Stop", systemImage: "stop.fill")
                            }
                            .help("Stop \(selectedConfig.name)")
                        } else {
                            Button(action: { connectTo(selectedConfig) }) {
                                Label("Start", systemImage: "play.fill")
                            }
                            .help("Start \(selectedConfig.name)")
                        }
                    } else {
                        Button(action: {}) {
                            Label("Start", systemImage: "play.fill")
                        }
                        .disabled(true)
                        .help("Select a server to start")
                    }
                    
                    Button(action: { showingAddSheet = true }) {
                        Label("Add Server", systemImage: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            ServerConfigEditView(mode: .add)
        }
        .sheet(item: $editingConfiguration) { config in
            ServerConfigEditView(mode: .edit(config))
        }
    }
    
    private var selectedConfiguration: ServerConfiguration? {
        guard let id = selectedConfigId else { return nil }
        return appState.configurationStore.configurations.first { $0.id == id }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "server.rack")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("No Server Configurations")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Add a server configuration to connect to an MCP server.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: { showingAddSheet = true }) {
                Label("Add Server", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Server List
    
    private var serverList: some View {
        List(selection: $selectedConfigId) {
            ForEach(appState.configurationStore.configurations) { config in
                ServerConfigRow(
                    configuration: config,
                    isConnected: isConnected(to: config),
                    onEdit: { editingConfiguration = config }
                )
                .tag(config.id)
            }
            .onDelete(perform: deleteConfigurations)
        }
        .listStyle(.inset)
    }
    
    // MARK: - Actions
    
    private func isConnected(to config: ServerConfiguration) -> Bool {
        appState.selectedServer?.id == config.id && appState.connectionState == .connected
    }
    
    private func connectTo(_ config: ServerConfiguration) {
        Task {
            await appState.connect(to: config)
        }
    }
    
    private func deleteConfigurations(at offsets: IndexSet) {
        // Disconnect if we're deleting the connected server
        for index in offsets {
            let config = appState.configurationStore.configurations[index]
            if appState.selectedServer?.id == config.id {
                appState.disconnect()
            }
        }
        appState.configurationStore.delete(at: offsets)
    }
}

// MARK: - Server Config Row

struct ServerConfigRow: View {
    let configuration: ServerConfiguration
    let isConnected: Bool
    let onEdit: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(configuration.name)
                        .font(.headline)
                    
                    if isConnected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
                
                Text(configuration.commandDisplay)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button(action: onEdit) {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            .help("Edit configuration")
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ServerConfigListView()
        .environmentObject(AppState())
}
