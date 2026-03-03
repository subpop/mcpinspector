import Foundation
import UniformTypeIdentifiers

/// Export formats for MCP server configurations
enum ExportFormat: String, CaseIterable, Identifiable {
    case vscode = "VS Code"
    case cursor = "Cursor"
    case claudeCode = "Claude Code"
    case codex = "Codex"
    case geminiCLI = "Gemini CLI"
    case genericJSON = "Generic JSON"

    var id: String { rawValue }

    var fileExtension: String {
        switch self {
        case .codex: return "toml"
        default: return "json"
        }
    }

    var contentType: UTType {
        switch self {
        case .codex: return .init(filenameExtension: "toml") ?? .plainText
        default: return .json
        }
    }

    var suggestedFilename: String {
        switch self {
        case .vscode: return "mcp.json"
        case .cursor: return "mcp.json"
        case .claudeCode: return ".mcp.json"
        case .codex: return "config.toml"
        case .geminiCLI: return "settings.json"
        case .genericJSON: return "mcp-servers.json"
        }
    }
}

/// Exports MCP server configurations in various tool-specific formats
struct ServerConfigExporter {

    /// Export a single server configuration in the specified format
    static func export(_ config: ServerConfiguration, format: ExportFormat) -> String {
        switch format {
        case .vscode:
            return exportVSCode(config)
        case .cursor:
            return exportCursor(config)
        case .claudeCode:
            return exportClaudeCode(config)
        case .codex:
            return exportCodex(config)
        case .geminiCLI:
            return exportGeminiCLI(config)
        case .genericJSON:
            return exportGenericJSON(config)
        }
    }

    // MARK: - VS Code

    /// VS Code uses `"servers"` as the top-level key with an explicit `"type": "stdio"` field.
    /// File: `.vscode/mcp.json`
    private static func exportVSCode(_ config: ServerConfiguration) -> String {
        var server: OrderedDict = [
            ("type", .string("stdio")),
            ("command", .string(config.command)),
        ]
        if !config.arguments.isEmpty {
            server.append(("args", .array(config.arguments.map { .string($0) })))
        }
        if !config.environmentVariables.isEmpty {
            server.append(("env", .object(config.environmentVariables.sorted(by: { $0.key < $1.key }).map { ($0.key, JSONValue.string($0.value)) })))
        }

        let root: OrderedDict = [
            ("servers", .object([
                (config.name, .object(server))
            ]))
        ]
        return renderJSON(root)
    }

    // MARK: - Cursor

    /// Cursor uses `"mcpServers"` as the top-level key, no explicit type needed.
    /// File: `.cursor/mcp.json`
    private static func exportCursor(_ config: ServerConfiguration) -> String {
        var server: OrderedDict = [
            ("command", .string(config.command)),
        ]
        if !config.arguments.isEmpty {
            server.append(("args", .array(config.arguments.map { .string($0) })))
        }
        if !config.environmentVariables.isEmpty {
            server.append(("env", .object(config.environmentVariables.sorted(by: { $0.key < $1.key }).map { ($0.key, JSONValue.string($0.value)) })))
        }

        let root: OrderedDict = [
            ("mcpServers", .object([
                (config.name, .object(server))
            ]))
        ]
        return renderJSON(root)
    }

    // MARK: - Claude Code

    /// Claude Code uses `"mcpServers"` with `"type": "stdio"`.
    /// File: `.mcp.json`
    private static func exportClaudeCode(_ config: ServerConfiguration) -> String {
        var server: OrderedDict = [
            ("type", .string("stdio")),
            ("command", .string(config.command)),
        ]
        if !config.arguments.isEmpty {
            server.append(("args", .array(config.arguments.map { .string($0) })))
        }
        if !config.environmentVariables.isEmpty {
            server.append(("env", .object(config.environmentVariables.sorted(by: { $0.key < $1.key }).map { ($0.key, JSONValue.string($0.value)) })))
        }

        let root: OrderedDict = [
            ("mcpServers", .object([
                (config.name, .object(server))
            ]))
        ]
        return renderJSON(root)
    }

    // MARK: - Codex (TOML)

    /// Codex uses TOML format with `[mcp_servers.<name>]` sections.
    /// File: `.codex/config.toml`
    private static func exportCodex(_ config: ServerConfiguration) -> String {
        var lines: [String] = []
        let sanitizedName = config.name.replacingOccurrences(of: " ", with: "-").lowercased()
        lines.append("[mcp_servers.\(sanitizedName)]")
        lines.append("command = \(tomlQuote(config.command))")

        if !config.arguments.isEmpty {
            let args = config.arguments.map { tomlQuote($0) }.joined(separator: ", ")
            lines.append("args = [\(args)]")
        }

        if !config.environmentVariables.isEmpty {
            let pairs = config.environmentVariables.sorted(by: { $0.key < $1.key }).map { "\($0.key) = \(tomlQuote($0.value))" }.joined(separator: ", ")
            lines.append("env = { \(pairs) }")
        }

        lines.append("")
        return lines.joined(separator: "\n")
    }

    // MARK: - Gemini CLI

    /// Gemini CLI uses `"mcpServers"` inside `settings.json`, no explicit type needed.
    /// File: `.gemini/settings.json`
    private static func exportGeminiCLI(_ config: ServerConfiguration) -> String {
        var server: OrderedDict = [
            ("command", .string(config.command)),
        ]
        if !config.arguments.isEmpty {
            server.append(("args", .array(config.arguments.map { .string($0) })))
        }
        if !config.environmentVariables.isEmpty {
            server.append(("env", .object(config.environmentVariables.sorted(by: { $0.key < $1.key }).map { ($0.key, JSONValue.string($0.value)) })))
        }

        let root: OrderedDict = [
            ("mcpServers", .object([
                (config.name, .object(server))
            ]))
        ]
        return renderJSON(root)
    }

    // MARK: - Generic JSON

    /// A generic format with all fields.
    private static func exportGenericJSON(_ config: ServerConfiguration) -> String {
        var server: OrderedDict = [
            ("command", .string(config.command)),
        ]
        if !config.arguments.isEmpty {
            server.append(("args", .array(config.arguments.map { .string($0) })))
        }
        if !config.environmentVariables.isEmpty {
            server.append(("env", .object(config.environmentVariables.sorted(by: { $0.key < $1.key }).map { ($0.key, JSONValue.string($0.value)) })))
        }

        let root: OrderedDict = [
            (config.name, .object(server))
        ]
        return renderJSON(root)
    }

    // MARK: - TOML Helpers

    private static func tomlQuote(_ s: String) -> String {
        let escaped = s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    // MARK: - Ordered JSON Rendering

    /// A simple value type for building JSON with key ordering preserved.
    private enum JSONValue {
        case string(String)
        case array([JSONValue])
        case object(OrderedDict)
    }

    private typealias OrderedDict = [(String, JSONValue)]

    private static func renderJSON(_ value: OrderedDict, indent: Int = 0) -> String {
        renderValue(.object(value), indent: indent)
    }

    private static func renderValue(_ value: JSONValue, indent: Int) -> String {
        let pad = String(repeating: "  ", count: indent)
        let innerPad = String(repeating: "  ", count: indent + 1)

        switch value {
        case .string(let s):
            return "\"\(escapeJSON(s))\""

        case .array(let items):
            if items.isEmpty { return "[]" }
            let rendered = items.map { "\(innerPad)\(renderValue($0, indent: indent + 1))" }
            return "[\n\(rendered.joined(separator: ",\n"))\n\(pad)]"

        case .object(let pairs):
            if pairs.isEmpty { return "{}" }
            let rendered = pairs.map { key, val in
                "\(innerPad)\"\(escapeJSON(key))\": \(renderValue(val, indent: indent + 1))"
            }
            return "{\n\(rendered.joined(separator: ",\n"))\n\(pad)}"
        }
    }

    private static func escapeJSON(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
         .replacingOccurrences(of: "\n", with: "\\n")
         .replacingOccurrences(of: "\r", with: "\\r")
         .replacingOccurrences(of: "\t", with: "\\t")
    }
}
