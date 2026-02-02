import SwiftUI

struct ConnectionView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedServerId: UUID?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                connectionCard
                
                if appState.connectionState == .connected {
                    serverInfoCard
                    capabilitiesCard
                }
            }
            .padding()
        }
        .navigationTitle("Connection")
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    // MARK: - Connection Card
    
    private var connectionCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("Connection Status", systemImage: "network")
                        .font(.headline)
                    
                    Spacer()
                    
                    statusBadge
                }
                
                Divider()
                
                if appState.configurationStore.configurations.isEmpty {
                    HStack {
                        Text("No servers configured")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    serverPicker
                }
                
                HStack {
                    Spacer()
                    
                    if appState.connectionState == .connecting {
                        ProgressView()
                            .scaleEffect(0.8)
                            .padding(.trailing, 8)
                    }
                    
                    if appState.connectionState == .connected {
                        Button("Disconnect") {
                            appState.disconnect()
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button("Connect") {
                            connect()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(selectedServerId == nil || appState.connectionState == .connecting)
                    }
                }
            }
            .padding(4)
        }
    }
    
    // MARK: - Server Picker
    
    private var serverPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select Server")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Picker("Server", selection: $selectedServerId) {
                Text("Choose a server...").tag(nil as UUID?)
                ForEach(appState.configurationStore.configurations) { config in
                    Text(config.name).tag(config.id as UUID?)
                }
            }
            .labelsHidden()
            .disabled(appState.connectionState == .connected || appState.connectionState == .connecting)
        }
        .onAppear {
            // Pre-select the connected server or first available
            if let selected = appState.selectedServer {
                selectedServerId = selected.id
            } else if selectedServerId == nil {
                selectedServerId = appState.configurationStore.configurations.first?.id
            }
        }
    }
    
    // MARK: - Status Badge
    
    private var statusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            
            Text(statusText)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var statusColor: Color {
        switch appState.connectionState {
        case .connected: return .green
        case .connecting: return .orange
        case .disconnected: return .gray
        case .error: return .red
        }
    }
    
    private var statusText: String {
        switch appState.connectionState {
        case .connected: return "Connected"
        case .connecting: return "Connecting..."
        case .disconnected: return "Disconnected"
        case .error(let msg): return "Error: \(msg.prefix(30))"
        }
    }
    
    // MARK: - Server Info Card
    
    private var serverInfoCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label("Server Information", systemImage: "info.circle")
                    .font(.headline)
                
                Divider()
                
                if let serverInfo = appState.serverInfo {
                    infoRow(label: "Name", value: serverInfo.name)
                    
                    if let version = serverInfo.version {
                        infoRow(label: "Version", value: version)
                    }
                }
                
                if let server = appState.selectedServer {
                    infoRow(label: "Command", value: server.command)
                    
                    if !server.arguments.isEmpty {
                        infoRow(label: "Arguments", value: server.arguments.joined(separator: " "))
                    }
                }
                
                if let instructions = appState.serverInstructions, !instructions.isEmpty {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Instructions")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(instructions)
                            .font(.subheadline)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(6)
                    }
                }
            }
            .padding(4)
        }
    }
    
    // MARK: - Capabilities Card
    
    private var capabilitiesCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label("Capabilities", systemImage: "checklist")
                    .font(.headline)
                
                Divider()
                
                HStack(spacing: 24) {
                    capabilityBadge(
                        name: "Tools",
                        count: appState.tools.count,
                        icon: "wrench.and.screwdriver",
                        available: !appState.tools.isEmpty
                    )
                    
                    capabilityBadge(
                        name: "Prompts",
                        count: appState.prompts.count,
                        icon: "text.bubble",
                        available: !appState.prompts.isEmpty
                    )
                    
                    capabilityBadge(
                        name: "Resources",
                        count: appState.resources.count,
                        icon: "doc.text",
                        available: !appState.resources.isEmpty
                    )
                }
            }
            .padding(4)
        }
    }
    
    // MARK: - Helper Views
    
    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(.system(.subheadline, design: .monospaced))
                .textSelection(.enabled)
            
            Spacer()
        }
    }
    
    private func capabilityBadge(name: String, count: Int, icon: String, available: Bool) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(available ? .accentColor : .secondary)
            
            Text(name)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("\(count)")
                .font(.headline)
                .foregroundColor(available ? .primary : .secondary)
        }
        .frame(minWidth: 80)
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Actions
    
    private func connect() {
        guard let serverId = selectedServerId,
              let config = appState.configurationStore.configuration(withId: serverId) else {
            return
        }
        
        Task {
            await appState.connect(to: config)
        }
    }
}

#Preview {
    ConnectionView()
        .environmentObject(AppState())
}
