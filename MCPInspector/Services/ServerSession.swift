import Foundation
import Combine

/// Encapsulates all per-server connection state: client, logs, tools, prompts, resources.
/// Multiple ServerSession instances can exist simultaneously for concurrent server connections.
@MainActor
class ServerSession: ObservableObject, Identifiable {
    let configuration: ServerConfiguration
    
    var id: UUID { configuration.id }
    
    @Published var connectionState: ConnectionState = .disconnected
    @Published private(set) var mcpClient: MCPClient?
    @Published var logStore = LogStore()
    
    @Published var serverInfo: MCPServerInfo?
    @Published var serverInstructions: String?
    @Published var tools: [MCPTool] = []
    @Published var prompts: [MCPPrompt] = []
    @Published var resources: [MCPResource] = []
    
    @Published var pendingElicitation: PendingElicitation?
    
    private var cancellables = Set<AnyCancellable>()
    
    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
        case error(String)
    }
    
    init(configuration: ServerConfiguration) {
        self.configuration = configuration
        
        logStore.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    var isConnected: Bool {
        connectionState == .connected
    }
    
    // MARK: - Connection Lifecycle
    
    func connect() async {
        connectionState = .connecting
        
        serverInfo = nil
        serverInstructions = nil
        tools = []
        prompts = []
        resources = []
        
        do {
            let client = MCPClient(configuration: configuration, logStore: logStore)
            mcpClient = client
            
            client.onElicitation = { [weak self] elicitation in
                self?.pendingElicitation = elicitation
            }
            
            let initResult = try await client.initialize()
            serverInfo = initResult.serverInfo
            serverInstructions = initResult.instructions
            
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
    
    // MARK: - Tool Invocation
    
    func callTool(name: String, arguments: [String: Any]) async throws -> MCPToolResult {
        guard let client = mcpClient else {
            throw MCPError.notConnected
        }
        return try await client.callTool(name: name, arguments: arguments)
    }
    
    // MARK: - Elicitation
    
    func respondToElicitation(action: MCPElicitationResult.ElicitationAction, content: [String: Any]? = nil) async {
        guard let elicitation = pendingElicitation,
              let client = mcpClient else {
            return
        }
        
        let result: MCPElicitationResult
        switch action {
        case .accept:
            result = .accept(content: content ?? [:])
        case .decline:
            result = .decline()
        case .cancel:
            result = MCPElicitationResult(action: .cancel, content: nil)
        }
        
        do {
            try await client.respondToElicitation(requestId: elicitation.requestId, result: result)
        } catch {
            logStore.addEntry(LogEntry(
                direction: .outgoing,
                method: "elicitation/create (error)",
                content: "Failed to send elicitation response: \(error.localizedDescription)",
                isError: true
            ))
        }
        
        pendingElicitation = nil
    }
}
