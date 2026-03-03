import Foundation
import Testing
@testable import MCP_Inspector

struct ServerConfigExporterTests {
    
    // A full config with command, args, and env vars
    private let fullConfig = ServerConfiguration(
        name: "test-server",
        command: "npx",
        arguments: ["-y", "@modelcontextprotocol/server-everything"],
        environmentVariables: ["API_KEY": "abc123", "DEBUG": "true"]
    )
    
    // A minimal config with only command, no args or env
    private let minimalConfig = ServerConfiguration(
        name: "minimal",
        command: "/usr/bin/my-server",
        arguments: [],
        environmentVariables: [:]
    )
    
    // MARK: - VS Code
    
    @Test func vsCodeExportUsesServersKey() {
        let output = ServerConfigExporter.export(fullConfig, format: .vscode)
        let json = try! JSONSerialization.jsonObject(with: Data(output.utf8)) as! [String: Any]
        
        #expect(json["servers"] != nil)
        #expect(json["mcpServers"] == nil)
    }
    
    @Test func vsCodeExportIncludesTypeStdio() {
        let output = ServerConfigExporter.export(fullConfig, format: .vscode)
        let json = try! JSONSerialization.jsonObject(with: Data(output.utf8)) as! [String: Any]
        let servers = json["servers"] as! [String: Any]
        let server = servers["test-server"] as! [String: Any]
        
        #expect(server["type"] as? String == "stdio")
    }
    
    @Test func vsCodeExportFullConfig() {
        let output = ServerConfigExporter.export(fullConfig, format: .vscode)
        let json = try! JSONSerialization.jsonObject(with: Data(output.utf8)) as! [String: Any]
        let servers = json["servers"] as! [String: Any]
        let server = servers["test-server"] as! [String: Any]
        
        #expect(server["command"] as? String == "npx")
        #expect(server["args"] as? [String] == ["-y", "@modelcontextprotocol/server-everything"])
        
        let env = server["env"] as! [String: String]
        #expect(env["API_KEY"] == "abc123")
        #expect(env["DEBUG"] == "true")
    }
    
    @Test func vsCodeExportMinimalConfig() {
        let output = ServerConfigExporter.export(minimalConfig, format: .vscode)
        let json = try! JSONSerialization.jsonObject(with: Data(output.utf8)) as! [String: Any]
        let servers = json["servers"] as! [String: Any]
        let server = servers["minimal"] as! [String: Any]
        
        #expect(server["command"] as? String == "/usr/bin/my-server")
        #expect(server["args"] == nil)
        #expect(server["env"] == nil)
    }
    
    // MARK: - Cursor
    
    @Test func cursorExportUsesMcpServersKey() {
        let output = ServerConfigExporter.export(fullConfig, format: .cursor)
        let json = try! JSONSerialization.jsonObject(with: Data(output.utf8)) as! [String: Any]
        
        #expect(json["mcpServers"] != nil)
        #expect(json["servers"] == nil)
    }
    
    @Test func cursorExportOmitsType() {
        let output = ServerConfigExporter.export(fullConfig, format: .cursor)
        let json = try! JSONSerialization.jsonObject(with: Data(output.utf8)) as! [String: Any]
        let mcpServers = json["mcpServers"] as! [String: Any]
        let server = mcpServers["test-server"] as! [String: Any]
        
        #expect(server["type"] == nil)
    }
    
    @Test func cursorExportFullConfig() {
        let output = ServerConfigExporter.export(fullConfig, format: .cursor)
        let json = try! JSONSerialization.jsonObject(with: Data(output.utf8)) as! [String: Any]
        let mcpServers = json["mcpServers"] as! [String: Any]
        let server = mcpServers["test-server"] as! [String: Any]
        
        #expect(server["command"] as? String == "npx")
        #expect(server["args"] as? [String] == ["-y", "@modelcontextprotocol/server-everything"])
        
        let env = server["env"] as! [String: String]
        #expect(env["API_KEY"] == "abc123")
        #expect(env["DEBUG"] == "true")
    }
    
    // MARK: - Claude Code
    
    @Test func claudeCodeExportUsesMcpServersKey() {
        let output = ServerConfigExporter.export(fullConfig, format: .claudeCode)
        let json = try! JSONSerialization.jsonObject(with: Data(output.utf8)) as! [String: Any]
        
        #expect(json["mcpServers"] != nil)
    }
    
    @Test func claudeCodeExportIncludesTypeStdio() {
        let output = ServerConfigExporter.export(fullConfig, format: .claudeCode)
        let json = try! JSONSerialization.jsonObject(with: Data(output.utf8)) as! [String: Any]
        let mcpServers = json["mcpServers"] as! [String: Any]
        let server = mcpServers["test-server"] as! [String: Any]
        
        #expect(server["type"] as? String == "stdio")
    }
    
    @Test func claudeCodeExportFullConfig() {
        let output = ServerConfigExporter.export(fullConfig, format: .claudeCode)
        let json = try! JSONSerialization.jsonObject(with: Data(output.utf8)) as! [String: Any]
        let mcpServers = json["mcpServers"] as! [String: Any]
        let server = mcpServers["test-server"] as! [String: Any]
        
        #expect(server["command"] as? String == "npx")
        #expect(server["args"] as? [String] == ["-y", "@modelcontextprotocol/server-everything"])
        
        let env = server["env"] as! [String: String]
        #expect(env["API_KEY"] == "abc123")
    }
    
    // MARK: - Codex (TOML)
    
    @Test func codexExportIsTOML() {
        let output = ServerConfigExporter.export(fullConfig, format: .codex)
        
        #expect(output.contains("[mcp_servers.test-server]"))
        #expect(output.contains("command = \"npx\""))
    }
    
    @Test func codexExportIncludesArgs() {
        let output = ServerConfigExporter.export(fullConfig, format: .codex)
        
        #expect(output.contains("args = [\"-y\", \"@modelcontextprotocol/server-everything\"]"))
    }
    
    @Test func codexExportIncludesEnv() {
        let output = ServerConfigExporter.export(fullConfig, format: .codex)
        
        #expect(output.contains("env = {"))
        #expect(output.contains("API_KEY = \"abc123\""))
        #expect(output.contains("DEBUG = \"true\""))
    }
    
    @Test func codexExportSanitizesNameWithSpaces() {
        let config = ServerConfiguration(
            name: "My Test Server",
            command: "node",
            arguments: ["server.js"],
            environmentVariables: [:]
        )
        let output = ServerConfigExporter.export(config, format: .codex)
        
        #expect(output.contains("[mcp_servers.my-test-server]"))
    }
    
    @Test func codexExportMinimalConfig() {
        let output = ServerConfigExporter.export(minimalConfig, format: .codex)
        
        #expect(output.contains("[mcp_servers.minimal]"))
        #expect(output.contains("command = \"/usr/bin/my-server\""))
        #expect(!output.contains("args"))
        #expect(!output.contains("env"))
    }
    
    // MARK: - Gemini CLI
    
    @Test func geminiCLIExportUsesMcpServersKey() {
        let output = ServerConfigExporter.export(fullConfig, format: .geminiCLI)
        let json = try! JSONSerialization.jsonObject(with: Data(output.utf8)) as! [String: Any]
        
        #expect(json["mcpServers"] != nil)
    }
    
    @Test func geminiCLIExportOmitsType() {
        let output = ServerConfigExporter.export(fullConfig, format: .geminiCLI)
        let json = try! JSONSerialization.jsonObject(with: Data(output.utf8)) as! [String: Any]
        let mcpServers = json["mcpServers"] as! [String: Any]
        let server = mcpServers["test-server"] as! [String: Any]
        
        #expect(server["type"] == nil)
    }
    
    @Test func geminiCLIExportFullConfig() {
        let output = ServerConfigExporter.export(fullConfig, format: .geminiCLI)
        let json = try! JSONSerialization.jsonObject(with: Data(output.utf8)) as! [String: Any]
        let mcpServers = json["mcpServers"] as! [String: Any]
        let server = mcpServers["test-server"] as! [String: Any]
        
        #expect(server["command"] as? String == "npx")
        #expect(server["args"] as? [String] == ["-y", "@modelcontextprotocol/server-everything"])
        
        let env = server["env"] as! [String: String]
        #expect(env["API_KEY"] == "abc123")
        #expect(env["DEBUG"] == "true")
    }
    
    // MARK: - Generic JSON
    
    @Test func genericJSONExportUsesServerNameAsKey() {
        let output = ServerConfigExporter.export(fullConfig, format: .genericJSON)
        let json = try! JSONSerialization.jsonObject(with: Data(output.utf8)) as! [String: Any]
        
        #expect(json["test-server"] != nil)
        #expect(json["mcpServers"] == nil)
        #expect(json["servers"] == nil)
    }
    
    @Test func genericJSONExportOmitsType() {
        let output = ServerConfigExporter.export(fullConfig, format: .genericJSON)
        let json = try! JSONSerialization.jsonObject(with: Data(output.utf8)) as! [String: Any]
        let server = json["test-server"] as! [String: Any]
        
        #expect(server["type"] == nil)
    }
    
    @Test func genericJSONExportFullConfig() {
        let output = ServerConfigExporter.export(fullConfig, format: .genericJSON)
        let json = try! JSONSerialization.jsonObject(with: Data(output.utf8)) as! [String: Any]
        let server = json["test-server"] as! [String: Any]
        
        #expect(server["command"] as? String == "npx")
        #expect(server["args"] as? [String] == ["-y", "@modelcontextprotocol/server-everything"])
        
        let env = server["env"] as! [String: String]
        #expect(env["API_KEY"] == "abc123")
        #expect(env["DEBUG"] == "true")
    }
    
    @Test func genericJSONExportMinimalConfig() {
        let output = ServerConfigExporter.export(minimalConfig, format: .genericJSON)
        let json = try! JSONSerialization.jsonObject(with: Data(output.utf8)) as! [String: Any]
        let server = json["minimal"] as! [String: Any]
        
        #expect(server["command"] as? String == "/usr/bin/my-server")
        #expect(server["args"] == nil)
        #expect(server["env"] == nil)
    }
    
    // MARK: - JSON Escaping
    
    @Test func jsonExportEscapesSpecialCharacters() {
        let config = ServerConfiguration(
            name: "test",
            command: "node",
            arguments: [],
            environmentVariables: ["PROMPT": "say \"hello\"\nworld"]
        )
        let output = ServerConfigExporter.export(config, format: .genericJSON)
        
        // Should be valid JSON even with special characters
        let json = try! JSONSerialization.jsonObject(with: Data(output.utf8)) as! [String: Any]
        let server = json["test"] as! [String: Any]
        let env = server["env"] as! [String: String]
        #expect(env["PROMPT"] == "say \"hello\"\nworld")
    }
    
    // MARK: - ExportFormat Properties
    
    @Test func exportFormatFileExtensions() {
        #expect(ExportFormat.vscode.fileExtension == "json")
        #expect(ExportFormat.cursor.fileExtension == "json")
        #expect(ExportFormat.claudeCode.fileExtension == "json")
        #expect(ExportFormat.codex.fileExtension == "toml")
        #expect(ExportFormat.geminiCLI.fileExtension == "json")
        #expect(ExportFormat.genericJSON.fileExtension == "json")
    }
    
    @Test func exportFormatSuggestedFilenames() {
        #expect(ExportFormat.vscode.suggestedFilename == "mcp.json")
        #expect(ExportFormat.cursor.suggestedFilename == "mcp.json")
        #expect(ExportFormat.claudeCode.suggestedFilename == ".mcp.json")
        #expect(ExportFormat.codex.suggestedFilename == "config.toml")
        #expect(ExportFormat.geminiCLI.suggestedFilename == "settings.json")
        #expect(ExportFormat.genericJSON.suggestedFilename == "mcp-servers.json")
    }
    
    @Test func allFormatsProduceNonEmptyOutput() {
        for format in ExportFormat.allCases {
            let output = ServerConfigExporter.export(fullConfig, format: format)
            #expect(!output.isEmpty, "Export for \(format.rawValue) should not be empty")
        }
    }
    
    @Test func allJSONFormatsProduceValidJSON() {
        let jsonFormats = ExportFormat.allCases.filter { $0 != .codex }
        for format in jsonFormats {
            let output = ServerConfigExporter.export(fullConfig, format: format)
            let parsed = try? JSONSerialization.jsonObject(with: Data(output.utf8))
            #expect(parsed != nil, "Export for \(format.rawValue) should produce valid JSON")
        }
    }
}
