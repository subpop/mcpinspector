import SwiftUI

struct ServerConfigEditView: View {
    enum Mode {
        case add
        case edit(ServerConfiguration)
        
        var title: String {
            switch self {
            case .add: return "Add Server"
            case .edit: return "Edit Server"
            }
        }
        
        var buttonTitle: String {
            switch self {
            case .add: return "Add"
            case .edit: return "Save"
            }
        }
    }
    
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    let mode: Mode
    
    @State private var name: String = ""
    @State private var command: String = ""
    @State private var argumentsText: String = ""
    @State private var envVariables: [EnvironmentVariable] = []
    
    init(mode: Mode) {
        self.mode = mode
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Server Information") {
                    TextField("Name", text: $name, prompt: Text("My MCP Server"))
                    TextField(
                        "Command",
                        text: $command,
                        prompt: Text("npx, python, node, etc.")
                    )
                    .font(.system(.body, design: .monospaced))
                }
                
                Section("Arguments") {
                    TextField("Arguments", text: $argumentsText, prompt: Text("-y @modelcontextprotocol/server-example"))
                        .font(.system(.body, design: .monospaced))
                    
                    Text("Separate arguments with spaces. Use quotes for arguments containing spaces.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Environment Variables") {
                    ForEach($envVariables) { $envVar in
                        HStack {
                            TextField("Key", text: $envVar.key)
                                .frame(maxWidth: 150)
                            Text("=")
                                .foregroundColor(.secondary)
                            TextField("Value", text: $envVar.value)
                            
                            Button(action: { removeEnvVariable(envVar) }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    
                    Button(action: addEnvVariable) {
                        Label("Add Variable", systemImage: "plus")
                    }
                    .buttonStyle(.borderless)
                }
            }
            .formStyle(.grouped)
            
            Divider()
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button(mode.buttonTitle) {
                    save()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(minWidth: 450, minHeight: 400)
        .navigationTitle(mode.title)
        .onAppear {
            loadConfiguration()
        }
    }
    
    // MARK: - Validation
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !command.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    // MARK: - Data Loading
    
    private func loadConfiguration() {
        if case .edit(let config) = mode {
            name = config.name
            command = config.command
            argumentsText = config.arguments.joined(separator: " ")
            envVariables = config.environmentVariables.map { EnvironmentVariable(key: $0.key, value: $0.value) }
        }
    }
    
    // MARK: - Actions
    
    private func addEnvVariable() {
        envVariables.append(EnvironmentVariable())
    }
    
    private func removeEnvVariable(_ variable: EnvironmentVariable) {
        envVariables.removeAll { $0.id == variable.id }
    }
    
    private func save() {
        let arguments = parseArguments(argumentsText)
        let environment = Dictionary(
            uniqueKeysWithValues: envVariables
                .filter { !$0.key.isEmpty }
                .map { ($0.key, $0.value) }
        )
        
        switch mode {
        case .add:
            let config = ServerConfiguration(
                name: name.trimmingCharacters(in: .whitespaces),
                command: command.trimmingCharacters(in: .whitespaces),
                arguments: arguments,
                environmentVariables: environment
            )
            appState.configurationStore.add(config)
            
        case .edit(var config):
            config.name = name.trimmingCharacters(in: .whitespaces)
            config.command = command.trimmingCharacters(in: .whitespaces)
            config.arguments = arguments
            config.environmentVariables = environment
            appState.configurationStore.update(config)
        }
        
        dismiss()
    }
    
    /// Parse arguments string, respecting quoted strings
    private func parseArguments(_ text: String) -> [String] {
        var arguments: [String] = []
        var current = ""
        var inQuotes = false
        var quoteChar: Character = "\""
        
        for char in text {
            if char == "\"" || char == "'" {
                if inQuotes && char == quoteChar {
                    inQuotes = false
                } else if !inQuotes {
                    inQuotes = true
                    quoteChar = char
                } else {
                    current.append(char)
                }
            } else if char == " " && !inQuotes {
                if !current.isEmpty {
                    arguments.append(current)
                    current = ""
                }
            } else {
                current.append(char)
            }
        }
        
        if !current.isEmpty {
            arguments.append(current)
        }
        
        return arguments
    }
}

#Preview("Add") {
    ServerConfigEditView(mode: .add)
        .environmentObject(AppState())
}

#Preview("Edit") {
    ServerConfigEditView(mode: .edit(.sample))
        .environmentObject(AppState())
}
