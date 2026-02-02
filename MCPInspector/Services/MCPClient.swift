import Foundation

/// MCP Client that communicates with an MCP server over stdio
@MainActor
class MCPClient: ObservableObject {
    private let configuration: ServerConfiguration
    private let transport: StdioTransport
    private let logStore: LogStore
    private var messageBuilder = MCPMessageBuilder()
    
    @Published private(set) var isConnected = false
    
    init(configuration: ServerConfiguration, logStore: LogStore) {
        self.configuration = configuration
        self.logStore = logStore
        
        // Create transport with stderr callback for logging
        self.transport = StdioTransport(configuration: configuration) { [weak logStore] stderrText in
            // Log stderr output on main actor
            Task { @MainActor in
                logStore?.addEntry(LogEntry(
                    direction: .stderr,
                    method: "stderr",
                    content: stderrText.trimmingCharacters(in: .whitespacesAndNewlines),
                    isError: true
                ))
            }
        }
    }
    
    // MARK: - Connection Lifecycle
    
    func initialize() async throws -> MCPInitializeResult {
        // Start the transport
        try await transport.start()
        
        // Send initialize request
        let request = messageBuilder.buildInitialize()
        logRequest(method: "initialize", request: request)
        
        let response = try await transport.send(request)
        logResponse(method: "initialize", response: response)
        
        if let error = response.error {
            throw MCPError.serverError(error)
        }
        
        guard let result = response.result else {
            throw MCPError.unexpectedResponse("No result in initialize response")
        }
        
        // Decode the result
        let resultData = try JSONEncoder().encode(result)
        let initResult = try JSONDecoder().decode(MCPInitializeResult.self, from: resultData)
        
        // Send initialized notification
        let notification = messageBuilder.buildInitialized()
        try await transport.sendNotification(notification)
        logNotification(method: "notifications/initialized")
        
        isConnected = true
        return initResult
    }
    
    func disconnect() {
        Task {
            await transport.stop()
        }
        isConnected = false
    }
    
    // MARK: - List Methods
    
    func listTools() async throws -> [MCPTool] {
        let request = messageBuilder.buildToolsList()
        logRequest(method: "tools/list", request: request)
        
        let response = try await transport.send(request)
        logResponse(method: "tools/list", response: response)
        
        if let error = response.error {
            throw MCPError.serverError(error)
        }
        
        guard let result = response.result else {
            throw MCPError.unexpectedResponse("No result in tools/list response")
        }
        
        let resultData = try JSONEncoder().encode(result)
        let toolsResult = try JSONDecoder().decode(MCPToolsListResult.self, from: resultData)
        
        return toolsResult.tools
    }
    
    func listPrompts() async throws -> [MCPPrompt] {
        let request = messageBuilder.buildPromptsList()
        logRequest(method: "prompts/list", request: request)
        
        let response = try await transport.send(request)
        logResponse(method: "prompts/list", response: response)
        
        if let error = response.error {
            throw MCPError.serverError(error)
        }
        
        guard let result = response.result else {
            throw MCPError.unexpectedResponse("No result in prompts/list response")
        }
        
        let resultData = try JSONEncoder().encode(result)
        let promptsResult = try JSONDecoder().decode(MCPPromptsListResult.self, from: resultData)
        
        return promptsResult.prompts
    }
    
    func listResources() async throws -> [MCPResource] {
        let request = messageBuilder.buildResourcesList()
        logRequest(method: "resources/list", request: request)
        
        let response = try await transport.send(request)
        logResponse(method: "resources/list", response: response)
        
        if let error = response.error {
            throw MCPError.serverError(error)
        }
        
        guard let result = response.result else {
            throw MCPError.unexpectedResponse("No result in resources/list response")
        }
        
        let resultData = try JSONEncoder().encode(result)
        let resourcesResult = try JSONDecoder().decode(MCPResourcesListResult.self, from: resultData)
        
        return resourcesResult.resources
    }
    
    // MARK: - Tool Invocation
    
    func callTool(name: String, arguments: [String: Any]) async throws -> MCPToolResult {
        let request = messageBuilder.buildToolCall(name: name, arguments: arguments)
        logRequest(method: "tools/call (\(name))", request: request)
        
        let response = try await transport.send(request)
        logResponse(method: "tools/call (\(name))", response: response)
        
        if let error = response.error {
            throw MCPError.serverError(error)
        }
        
        guard let result = response.result else {
            throw MCPError.unexpectedResponse("No result in tools/call response")
        }
        
        let resultData = try JSONEncoder().encode(result)
        let toolResult = try JSONDecoder().decode(MCPToolResult.self, from: resultData)
        
        return toolResult
    }
    
    // MARK: - Logging
    
    private func logRequest(method: String, request: JSONRPCRequest) {
        let json = formatJSON(request)
        logStore.addEntry(LogEntry(
            direction: .outgoing,
            method: method,
            content: json
        ))
    }
    
    private func logResponse(method: String, response: JSONRPCResponse) {
        let json = formatJSON(response)
        logStore.addEntry(LogEntry(
            direction: .incoming,
            method: method,
            content: json,
            isError: response.error != nil
        ))
    }
    
    private func logNotification(method: String) {
        logStore.addEntry(LogEntry(
            direction: .outgoing,
            method: method,
            content: "{\"jsonrpc\":\"2.0\",\"method\":\"\(method)\"}"
        ))
    }
    
    private func formatJSON<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(value),
              let string = String(data: data, encoding: .utf8) else {
            return "Unable to encode"
        }
        return string
    }
}
