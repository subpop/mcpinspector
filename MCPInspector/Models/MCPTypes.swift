import Foundation

// Note: The main MCP types (MCPTool, MCPPrompt, MCPResource, MCPServerInfo, etc.)
// are defined in Protocol/MCPMessages.swift as they are closely tied to the
// protocol message definitions.
//
// This file contains additional type aliases and extensions for convenience.

// MARK: - Type Aliases

typealias ToolResult = MCPToolResult

// MARK: - Extensions

extension MCPTool {
    /// Returns the required parameters from the input schema
    var requiredParameters: [String] {
        guard let schema = inputSchema,
              let required = schema["required"]?.arrayValue else {
            return []
        }
        return required.compactMap { $0.stringValue }
    }
    
    /// Returns the properties from the input schema
    var schemaProperties: [String: JSONValue]? {
        inputSchema?["properties"]?.objectValue
    }
    
    /// Checks if the tool has any parameters
    var hasParameters: Bool {
        guard let props = schemaProperties else { return false }
        return !props.isEmpty
    }
}

extension MCPPrompt {
    /// Checks if the prompt has any arguments
    var hasArguments: Bool {
        guard let args = arguments else { return false }
        return !args.isEmpty
    }
    
    /// Returns the required argument names
    var requiredArguments: [String] {
        arguments?.filter { $0.required == true }.map { $0.name } ?? []
    }
}

extension MCPResource {
    /// Returns a shortened display name for the resource
    var shortName: String {
        if let lastComponent = uri.split(separator: "/").last {
            return String(lastComponent)
        }
        return name
    }
    
    /// Returns the file extension from the URI if available
    var fileExtension: String? {
        let url = URL(string: uri)
        let ext = url?.pathExtension
        return ext?.isEmpty == false ? ext : nil
    }
}

extension MCPServerInfo {
    /// Display string combining name and version
    var displayString: String {
        if let version = version {
            return "\(name) v\(version)"
        }
        return name
    }
}

extension MCPContent {
    /// Checks if the content is text-based
    var isText: Bool {
        type == "text"
    }
    
    /// Checks if the content is an image
    var isImage: Bool {
        type == "image"
    }
    
    /// Checks if the content is a resource
    var isResource: Bool {
        type == "resource"
    }
}
