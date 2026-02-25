import Foundation

/// MCP Client that communicates with an MCP server over stdio
@MainActor
class MCPClient: ObservableObject {
    private let configuration: ServerConfiguration
    private let transport: StdioTransport
    private let logStore: LogStore
    private var messageBuilder = MCPMessageBuilder()
    
    @Published private(set) var isConnected = false
    
    /// Callback invoked when the server sends an elicitation request
    var onElicitation: ((PendingElicitation) -> Void)?
    
    init(configuration: ServerConfiguration, logStore: LogStore) {
        self.configuration = configuration
        self.logStore = logStore
        
        self.transport = StdioTransport(
            configuration: configuration,
            onStderr: { [weak logStore] stderrText in
                Task { @MainActor in
                    logStore?.addEntry(LogEntry(
                        direction: .stderr,
                        method: "stderr",
                        content: stderrText.trimmingCharacters(in: .whitespacesAndNewlines),
                        isError: true
                    ))
                }
            },
            onServerRequest: nil
        )
        
        // Wire up server request routing through the transport after init
        Task {
            await transport.setServerRequestHandler { [weak self] method, requestId, params in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    let paramsJSON = params?.prettyPrinted() ?? "{}"
                    self.logStore.addEntry(LogEntry(
                        direction: .incoming,
                        method: method,
                        content: paramsJSON
                    ))
                    self.handleServerRequest(method: method, requestId: requestId, params: params)
                }
            }
        }
    }
    
    // MARK: - Server Request Handling
    
    private func handleServerRequest(method: String, requestId: RequestID, params: JSONValue?) {
        switch method {
        case "elicitation/create":
            handleElicitationRequest(requestId: requestId, params: params)
        default:
            print("[MCP] Unhandled server request method: \(method)")
            Task {
                try? await transport.sendResponse(JSONRPCResponse(
                    id: requestId,
                    error: JSONRPCError(
                        code: JSONRPCError.methodNotFound,
                        message: "Method not supported: \(method)",
                        data: nil
                    )
                ))
            }
        }
    }
    
    private func handleElicitationRequest(requestId: RequestID, params: JSONValue?) {
        guard let params = params,
              let message = params["message"]?.stringValue,
              let requestedSchema = params["requestedSchema"] else {
            Task {
                try? await transport.sendResponse(JSONRPCResponse(
                    id: requestId,
                    error: JSONRPCError(
                        code: JSONRPCError.invalidParams,
                        message: "Invalid elicitation parameters",
                        data: nil
                    )
                ))
            }
            return
        }
        
        let elicitation = PendingElicitation(
            id: UUID().uuidString,
            requestId: requestId,
            message: message,
            requestedSchema: requestedSchema
        )
        
        onElicitation?(elicitation)
    }
    
    /// Send the user's response to an elicitation request back to the server
    func respondToElicitation(requestId: RequestID, result: MCPElicitationResult) async throws {
        let resultData = try JSONEncoder().encode(result)
        let resultValue = try JSONDecoder().decode(JSONValue.self, from: resultData)
        
        let response = JSONRPCResponse(id: requestId, result: resultValue)
        try await transport.sendResponse(response)
        
        logStore.addEntry(LogEntry(
            direction: .outgoing,
            method: "elicitation/create (response)",
            content: resultValue.prettyPrinted()
        ))
    }
    
    // MARK: - Connection Lifecycle
    
    func initialize() async throws -> MCPInitializeResult {
        try await transport.start()
        
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
        
        let resultData = try JSONEncoder().encode(result)
        let initResult = try JSONDecoder().decode(MCPInitializeResult.self, from: resultData)
        
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
