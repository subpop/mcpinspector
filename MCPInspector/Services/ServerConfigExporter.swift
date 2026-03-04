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

    var supportsCLI: Bool {
        switch self {
        case .claudeCode, .codex, .geminiCLI: return true
        default: return false
        }
    }
}

// MARK: - Server Configuration Export

extension ServerConfiguration {

    /// Export this server configuration as a string in the specified format
    func exported(as format: ExportFormat) -> String {
        switch format {
        case .vscode:
            return exportedAsVSCode()
        case .cursor:
            return exportedAsCursor()
        case .claudeCode:
            return exportedAsClaudeCode()
        case .codex:
            return exportedAsCodex()
        case .geminiCLI:
            return exportedAsGeminiCLI()
        case .genericJSON:
            return exportedAsGenericJSON()
        }
    }

    /// Generate a CLI command to add the server, if the format supports it
    func cliCommand(for format: ExportFormat) -> String? {
        switch format {
        case .claudeCode:
            return claudeCodeCLICommand()
        case .codex:
            return codexCLICommand()
        case .geminiCLI:
            return geminiCLICommand()
        default:
            return nil
        }
    }

    // MARK: - VS Code

    /// VS Code uses `"servers"` as the top-level key with an explicit `"type": "stdio"` field.
    /// File: `.vscode/mcp.json`
    private func exportedAsVSCode() -> String {
        var server: OrderedDict = [
            ("type", .string("stdio")),
            ("command", .string(command)),
        ]
        if !arguments.isEmpty {
            server.append(("args", .array(arguments.map { .string($0) })))
        }
        if !environmentVariables.isEmpty {
            server.append(("env", .object(environmentVariables.sorted(by: { $0.key < $1.key }).map { ($0.key, JSONValue.string($0.value)) })))
        }

        let root: OrderedDict = [
            ("servers", .object([
                (name, .object(server))
            ]))
        ]
        return renderJSON(root)
    }

    // MARK: - Cursor

    /// Cursor uses `"mcpServers"` as the top-level key, no explicit type needed.
    /// File: `.cursor/mcp.json`
    private func exportedAsCursor() -> String {
        var server: OrderedDict = [
            ("command", .string(command)),
        ]
        if !arguments.isEmpty {
            server.append(("args", .array(arguments.map { .string($0) })))
        }
        if !environmentVariables.isEmpty {
            server.append(("env", .object(environmentVariables.sorted(by: { $0.key < $1.key }).map { ($0.key, JSONValue.string($0.value)) })))
        }

        let root: OrderedDict = [
            ("mcpServers", .object([
                (name, .object(server))
            ]))
        ]
        return renderJSON(root)
    }

    // MARK: - Claude Code

    /// Claude Code uses `"mcpServers"` with `"type": "stdio"`.
    /// File: `.mcp.json`
    private func exportedAsClaudeCode() -> String {
        var server: OrderedDict = [
            ("type", .string("stdio")),
            ("command", .string(command)),
        ]
        if !arguments.isEmpty {
            server.append(("args", .array(arguments.map { .string($0) })))
        }
        if !environmentVariables.isEmpty {
            server.append(("env", .object(environmentVariables.sorted(by: { $0.key < $1.key }).map { ($0.key, JSONValue.string($0.value)) })))
        }

        let root: OrderedDict = [
            ("mcpServers", .object([
                (name, .object(server))
            ]))
        ]
        return renderJSON(root)
    }

    // MARK: - Codex (TOML)

    /// Codex uses TOML format with `[mcp_servers.<name>]` sections.
    /// File: `.codex/config.toml`
    private func exportedAsCodex() -> String {
        var lines: [String] = []
        let sanitizedName = name.replacingOccurrences(of: " ", with: "-").lowercased()
        lines.append("[mcp_servers.\(sanitizedName)]")
        lines.append("command = \(tomlQuote(command))")

        if !arguments.isEmpty {
            let args = arguments.map { tomlQuote($0) }.joined(separator: ", ")
            lines.append("args = [\(args)]")
        }

        if !environmentVariables.isEmpty {
            let pairs = environmentVariables.sorted(by: { $0.key < $1.key }).map { "\($0.key) = \(tomlQuote($0.value))" }.joined(separator: ", ")
            lines.append("env = { \(pairs) }")
        }

        lines.append("")
        return lines.joined(separator: "\n")
    }

    // MARK: - Gemini CLI

    /// Gemini CLI uses `"mcpServers"` inside `settings.json`, no explicit type needed.
    /// File: `.gemini/settings.json`
    private func exportedAsGeminiCLI() -> String {
        var server: OrderedDict = [
            ("command", .string(command)),
        ]
        if !arguments.isEmpty {
            server.append(("args", .array(arguments.map { .string($0) })))
        }
        if !environmentVariables.isEmpty {
            server.append(("env", .object(environmentVariables.sorted(by: { $0.key < $1.key }).map { ($0.key, JSONValue.string($0.value)) })))
        }

        let root: OrderedDict = [
            ("mcpServers", .object([
                (name, .object(server))
            ]))
        ]
        return renderJSON(root)
    }

    // MARK: - Generic JSON

    /// A generic format with all fields.
    private func exportedAsGenericJSON() -> String {
        var server: OrderedDict = [
            ("command", .string(command)),
        ]
        if !arguments.isEmpty {
            server.append(("args", .array(arguments.map { .string($0) })))
        }
        if !environmentVariables.isEmpty {
            server.append(("env", .object(environmentVariables.sorted(by: { $0.key < $1.key }).map { ($0.key, JSONValue.string($0.value)) })))
        }

        let root: OrderedDict = [
            (name, .object(server))
        ]
        return renderJSON(root)
    }

    // MARK: - CLI Commands

    /// `claude mcp add <name> [-e KEY=VAL ...] -- <command> [args...]`
    private func claudeCodeCLICommand() -> String {
        var parts = ["claude", "mcp", "add", shellEscape(name)]

        for (key, value) in environmentVariables.sorted(by: { $0.key < $1.key }) {
            parts.append("-e")
            parts.append(shellEscape("\(key)=\(value)"))
        }

        parts.append("--")
        parts.append(shellEscape(command))

        for arg in arguments {
            parts.append(shellEscape(arg))
        }

        return parts.joined(separator: " ")
    }

    /// `codex mcp add <name> [--env KEY=VAL...] -- <command> [args...]`
    private func codexCLICommand() -> String {
        var parts = ["codex", "mcp", "add", shellEscape(name)]

        for (key, value) in environmentVariables.sorted(by: { $0.key < $1.key }) {
            parts.append("--env")
            parts.append(shellEscape("\(key)=\(value)"))
        }

        parts.append("--")
        parts.append(shellEscape(command))

        for arg in arguments {
            parts.append(shellEscape(arg))
        }

        return parts.joined(separator: " ")
    }

    /// `gemini mcp add <name <command>`
    private func geminiCLICommand() -> String {
        var parts = ["gemini", "mcp", "add", shellEscape(name)]

        parts.append(shellEscape(command))

        for arg in arguments {
            parts.append(shellEscape(arg))
        }

        return parts.joined(separator: " ")
    }

    // MARK: - Shell Helpers

    private func shellEscape(_ s: String) -> String {
        if s.isEmpty { return "''" }
        let safeChars = CharacterSet.alphanumerics
            .union(CharacterSet(charactersIn: "-_./=@:,+"))
        if s.unicodeScalars.allSatisfy({ safeChars.contains($0) }) {
            return s
        }
        return "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    // MARK: - TOML Helpers

    private func tomlQuote(_ s: String) -> String {
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

    private func renderJSON(_ value: OrderedDict, indent: Int = 0) -> String {
        renderValue(.object(value), indent: indent)
    }

    private func renderValue(_ value: JSONValue, indent: Int) -> String {
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

    private func escapeJSON(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
         .replacingOccurrences(of: "\n", with: "\\n")
         .replacingOccurrences(of: "\r", with: "\\r")
         .replacingOccurrences(of: "\t", with: "\\t")
    }
}
