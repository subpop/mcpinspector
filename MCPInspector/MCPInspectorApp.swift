import SwiftUI
import Combine

@main
struct MCPInspectorApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(appState)
        }
        .windowStyle(.automatic)
        .defaultSize(width: 800, height: 600)

        Settings {
            SettingsView()
        }
    }
}

/// Global application state shared across views
@MainActor
class AppState: ObservableObject {
    @Published var configurationStore = ConfigurationStore()
    @Published var mcpClient: MCPClient?
    @Published var logStore = LogStore()
    @Published var selectedServer: ServerConfiguration?
    @Published var connectionState: ConnectionState = .disconnected
    
    // Server capabilities (populated after connection)
    @Published var serverInfo: MCPServerInfo?
    @Published var serverInstructions: String?
    @Published var tools: [MCPTool] = []
    @Published var prompts: [MCPPrompt] = []
    @Published var resources: [MCPResource] = []
    
    private var cancellables = Set<AnyCancellable>()
    
    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
        case error(String)
    }
    
    init() {
        // Forward objectWillChange from nested ObservableObjects to trigger view updates
        configurationStore.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        logStore.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    func connect(to server: ServerConfiguration) async {
        connectionState = .connecting
        selectedServer = server
        
        // Reset state
        serverInfo = nil
        serverInstructions = nil
        tools = []
        prompts = []
        resources = []
        
        do {
            let client = MCPClient(configuration: server, logStore: logStore)
            mcpClient = client
            
            // Initialize connection
            let initResult = try await client.initialize()
            serverInfo = initResult.serverInfo
            serverInstructions = initResult.instructions
            
            // Fetch capabilities
            if initResult.capabilities.tools != nil {
                tools = try await client.listTools()
            }
            if initResult.capabilities.prompts != nil {
                prompts = try await client.listPrompts()
            }
            if initResult.capabilities.resources != nil {
                resources = try await client.listResources()
            }
            
            connectionState = .connected
        } catch {
            connectionState = .error(error.localizedDescription)
            mcpClient = nil
        }
    }
    
    func disconnect() {
        mcpClient?.disconnect()
        mcpClient = nil
        connectionState = .disconnected
        serverInfo = nil
        serverInstructions = nil
        tools = []
        prompts = []
        resources = []
    }
    
    func callTool(name: String, arguments: [String: Any]) async throws -> MCPToolResult {
        guard let client = mcpClient else {
            throw MCPError.notConnected
        }
        return try await client.callTool(name: name, arguments: arguments)
    }
}

struct SettingsView: View {
    var body: some View {
        Form {
            Text("MCP Inspector Settings")
                .font(.headline)
            Text("No settings available yet.")
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 400, height: 200)
    }
}
