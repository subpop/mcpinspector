import Foundation

/// Configuration for an MCP server
struct ServerConfiguration: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var command: String
    var arguments: [String]
    var environmentVariables: [String: String]
    
    init(
        id: UUID = UUID(),
        name: String = "",
        command: String = "",
        arguments: [String] = [],
        environmentVariables: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.command = command
        self.arguments = arguments
        self.environmentVariables = environmentVariables
    }
    
    /// Creates a sample configuration for testing
    static var sample: ServerConfiguration {
        ServerConfiguration(
            name: "Example Server",
            command: "npx",
            arguments: ["-y", "@modelcontextprotocol/server-everything"],
            environmentVariables: [:]
        )
    }
    
    /// Validates the configuration
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !command.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    /// Display string for the command
    var commandDisplay: String {
        if arguments.isEmpty {
            return command
        }
        return "\(command) \(arguments.joined(separator: " "))"
    }
}

/// Environment variable entry for editing
struct EnvironmentVariable: Identifiable, Hashable {
    var id = UUID()
    var key: String
    var value: String
    
    init(key: String = "", value: String = "") {
        self.key = key
        self.value = value
    }
}
