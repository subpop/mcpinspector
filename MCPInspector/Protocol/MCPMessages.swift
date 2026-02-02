import Foundation

// MARK: - MCP Protocol Version

let MCP_PROTOCOL_VERSION = "2024-11-05"

// MARK: - MCP Errors

enum MCPError: Error, LocalizedError {
    case notConnected
    case connectionFailed(String)
    case timeout
    case encodingError(String)
    case decodingError(String)
    case serverError(JSONRPCError)
    case unexpectedResponse(String)
    case processTerminated(Int32, stderr: String?)
    
    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to MCP server"
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"
        case .timeout:
            return "Request timed out"
        case .encodingError(let message):
            return "Encoding error: \(message)"
        case .decodingError(let message):
            return "Decoding error: \(message)"
        case .serverError(let error):
            return error.errorDescription
        case .unexpectedResponse(let message):
            return "Unexpected response: \(message)"
        case .processTerminated(let code, let stderr):
            var message = "MCP server process terminated with code \(code)"
            if let stderr = stderr, !stderr.isEmpty {
                message += "\n\nstderr:\n\(stderr)"
            }
            return message
        }
    }
}

// MARK: - Initialize Request/Response

struct MCPInitializeParams: Codable {
    let protocolVersion: String
    let capabilities: MCPClientCapabilities
    let clientInfo: MCPClientInfo
    
    static func standard() -> MCPInitializeParams {
        MCPInitializeParams(
            protocolVersion: MCP_PROTOCOL_VERSION,
            capabilities: MCPClientCapabilities(),
            clientInfo: MCPClientInfo(name: "MCPInspector", version: "1.0.0")
        )
    }
}

struct MCPClientInfo: Codable {
    let name: String
    let version: String
}

struct MCPClientCapabilities: Codable {
    // Client capabilities - we support receiving from server
    let roots: RootsCapability?
    let sampling: SamplingCapability?
    
    init(roots: RootsCapability? = nil, sampling: SamplingCapability? = nil) {
        self.roots = roots
        self.sampling = sampling
    }
    
    struct RootsCapability: Codable {
        let listChanged: Bool?
    }
    
    struct SamplingCapability: Codable {}
}

struct MCPInitializeResult: Codable {
    let protocolVersion: String
    let capabilities: MCPServerCapabilities
    let serverInfo: MCPServerInfo
    let instructions: String?
}

struct MCPServerInfo: Codable {
    let name: String
    let version: String?
}

struct MCPServerCapabilities: Codable {
    let tools: ToolsCapability?
    let prompts: PromptsCapability?
    let resources: ResourcesCapability?
    let logging: LoggingCapability?
    
    struct ToolsCapability: Codable {
        let listChanged: Bool?
    }
    
    struct PromptsCapability: Codable {
        let listChanged: Bool?
    }
    
    struct ResourcesCapability: Codable {
        let subscribe: Bool?
        let listChanged: Bool?
    }
    
    struct LoggingCapability: Codable {}
}

// MARK: - Tools

struct MCPToolsListResult: Codable {
    let tools: [MCPTool]
}

struct MCPTool: Codable, Identifiable, Hashable {
    let name: String
    let description: String?
    let inputSchema: JSONValue?
    
    var id: String { name }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
    
    static func == (lhs: MCPTool, rhs: MCPTool) -> Bool {
        lhs.name == rhs.name
    }
}

struct MCPToolCallParams: Codable {
    let name: String
    let arguments: JSONValue?
}

struct MCPToolResult: Codable {
    let content: [MCPContent]
    let isError: Bool?
}

// MARK: - Prompts

struct MCPPromptsListResult: Codable {
    let prompts: [MCPPrompt]
}

struct MCPPrompt: Codable, Identifiable, Hashable {
    let name: String
    let description: String?
    let arguments: [MCPPromptArgument]?
    
    var id: String { name }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
    
    static func == (lhs: MCPPrompt, rhs: MCPPrompt) -> Bool {
        lhs.name == rhs.name
    }
}

struct MCPPromptArgument: Codable, Hashable {
    let name: String
    let description: String?
    let required: Bool?
}

// MARK: - Resources

struct MCPResourcesListResult: Codable {
    let resources: [MCPResource]
}

struct MCPResource: Codable, Identifiable, Hashable {
    let uri: String
    let name: String
    let description: String?
    let mimeType: String?
    
    var id: String { uri }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(uri)
    }
    
    static func == (lhs: MCPResource, rhs: MCPResource) -> Bool {
        lhs.uri == rhs.uri
    }
}

// MARK: - Content Types

struct MCPContent: Codable {
    let type: String
    let text: String?
    let data: String?
    let mimeType: String?
    
    var displayText: String {
        if let text = text {
            return text
        } else if let data = data {
            return "[Binary data: \(data.prefix(100))...]"
        }
        return "[Unknown content]"
    }
}

// MARK: - MCP Message Builder

struct MCPMessageBuilder {
    private var nextId = 1
    
    mutating func buildInitialize() -> JSONRPCRequest {
        let params = MCPInitializeParams.standard()
        let id = nextId
        nextId += 1
        
        return JSONRPCRequest(
            id: id,
            method: "initialize",
            params: encodeParams(params)
        )
    }
    
    mutating func buildInitialized() -> JSONRPCNotification {
        JSONRPCNotification(method: "notifications/initialized")
    }
    
    mutating func buildToolsList() -> JSONRPCRequest {
        let id = nextId
        nextId += 1
        return JSONRPCRequest(id: id, method: "tools/list")
    }
    
    mutating func buildPromptsList() -> JSONRPCRequest {
        let id = nextId
        nextId += 1
        return JSONRPCRequest(id: id, method: "prompts/list")
    }
    
    mutating func buildResourcesList() -> JSONRPCRequest {
        let id = nextId
        nextId += 1
        return JSONRPCRequest(id: id, method: "resources/list")
    }
    
    mutating func buildToolCall(name: String, arguments: [String: Any]) -> JSONRPCRequest {
        let id = nextId
        nextId += 1
        
        let params = MCPToolCallParams(
            name: name,
            arguments: JSONValue.from(arguments)
        )
        
        return JSONRPCRequest(
            id: id,
            method: "tools/call",
            params: encodeParams(params)
        )
    }
    
    private func encodeParams<T: Encodable>(_ params: T) -> JSONValue {
        guard let data = try? JSONEncoder().encode(params),
              let value = try? JSONDecoder().decode(JSONValue.self, from: data) else {
            return .null
        }
        return value
    }
}
