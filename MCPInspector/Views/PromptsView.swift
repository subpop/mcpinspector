import SwiftUI

struct PromptsView: View {
    @ObservedObject var session: ServerSession
    @State private var selectedPrompt: MCPPrompt?
    @State private var searchText = ""
    
    // Invocation state
    @State private var argumentValues: [String: String] = [:]
    @State private var isExecuting = false
    @State private var result: PromptCallResult?
    @State private var resultExpanded = true
    
    private var filteredPrompts: [MCPPrompt] {
        if searchText.isEmpty {
            return session.prompts
        }
        return session.prompts.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.description?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var body: some View {
        HSplitView {
            promptsList
                .frame(minWidth: 250, maxWidth: 350)
            
            promptDetail
                .frame(minWidth: 400)
        }
        .onChange(of: selectedPrompt) {
            resetInvocationState()
        }
    }
    
    // MARK: - Prompts List
    
    private var promptsList: some View {
        List(selection: $selectedPrompt) {
            if filteredPrompts.isEmpty {
                if session.prompts.isEmpty {
                    Text("No prompts available")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    Text("No matching prompts")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
            } else {
                ForEach(filteredPrompts) { prompt in
                    PromptRow(prompt: prompt, isSelected: selectedPrompt?.id == prompt.id)
                        .tag(prompt)
                }
            }
        }
        .listStyle(.inset)
        .searchable(text: $searchText, prompt: "Filter prompts...")
    }
    
    // MARK: - Prompt Detail
    
    @ViewBuilder
    private var promptDetail: some View {
        if let prompt = selectedPrompt {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Header
                        VStack(alignment: .leading, spacing: 4) {
                            Text(prompt.name)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .textSelection(.enabled)
                            
                            if let description = prompt.description {
                                Text(description)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Divider()
                        
                        // Arguments section
                        if let arguments = prompt.arguments, !arguments.isEmpty {
                            Text("Arguments")
                                .font(.headline)
                            
                            ForEach(arguments, id: \.name) { arg in
                                argumentField(argument: arg)
                            }
                        } else {
                            Text("This prompt has no arguments.")
                                .foregroundColor(.secondary)
                        }
                        
                        // Result section
                        if let result = result {
                            Divider()
                            resultSection(result)
                        }
                    }
                    .padding()
                }
                
                Divider()
                
                // Footer with Run button
                runFooter
            }
        } else {
            VStack {
                Image(systemName: "text.bubble")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                
                Text("Select a prompt")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    // MARK: - Argument Field
    
    private func argumentField(argument: MCPPromptArgument) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(argument.name)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                
                if argument.required == true {
                    Text("required")
                        .font(.caption)
                        .foregroundColor(.red)
                } else {
                    Text("optional")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let description = argument.description {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            TextField("Enter value", text: argumentBinding(for: argument.name))
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
        }
        .padding(10)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
    
    // MARK: - Run Footer
    
    private var runFooter: some View {
        HStack {
            if result != nil {
                Button("Clear Result") {
                    result = nil
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
            
            Button(action: executePromptGet) {
                HStack(spacing: 6) {
                    if isExecuting {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(isExecuting ? "Running..." : "Run")
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(isExecuting)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
    
    // MARK: - Result Section
    
    private func resultSection(_ result: PromptCallResult) -> some View {
        DisclosureGroup(isExpanded: $resultExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                switch result {
                case .success(let promptResult):
                    if let description = promptResult.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    ForEach(Array(promptResult.messages.enumerated()), id: \.offset) { index, message in
                        promptMessageView(message, index: index)
                    }
                case .error(let message):
                    Text(message)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.red)
                        .textSelection(.enabled)
                }
            }
            .padding(.top, 8)
        } label: {
            HStack(spacing: 8) {
                Text("Result")
                    .font(.headline)
                
                resultBadge(result)
            }
        }
    }
    
    @ViewBuilder
    private func resultBadge(_ result: PromptCallResult) -> some View {
        switch result {
        case .success:
            Label("Success", systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.subheadline)
        case .error:
            Label("Error", systemImage: "xmark.circle.fill")
                .foregroundColor(.red)
                .font(.subheadline)
        }
    }
    
    private func promptMessageView(_ message: MCPPromptMessage, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("[\(index)] \(message.role)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Text(message.content.type)
                    .font(.caption2)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
            }
            
            Text(message.content.displayText)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(6)
    }
    
    // MARK: - Bindings
    
    private func argumentBinding(for name: String) -> Binding<String> {
        Binding(
            get: { argumentValues[name] ?? "" },
            set: { argumentValues[name] = $0 }
        )
    }
    
    // MARK: - Actions
    
    private func resetInvocationState() {
        argumentValues = [:]
        isExecuting = false
        result = nil
        resultExpanded = true
        
        if let prompt = selectedPrompt, let arguments = prompt.arguments {
            for arg in arguments {
                argumentValues[arg.name] = ""
            }
        }
    }
    
    private func executePromptGet() {
        guard let prompt = selectedPrompt else { return }
        isExecuting = true
        result = nil
        
        Task {
            do {
                let args = argumentValues.filter { !$0.value.isEmpty }
                let promptResult = try await session.getPrompt(name: prompt.name, arguments: args)
                result = .success(promptResult)
            } catch {
                result = .error(error.localizedDescription)
            }
            isExecuting = false
            resultExpanded = true
        }
    }
}

// MARK: - Prompt Call Result

enum PromptCallResult {
    case success(MCPPromptGetResult)
    case error(String)
}

// MARK: - Prompt Row

struct PromptRow: View {
    let prompt: MCPPrompt
    let isSelected: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "text.bubble")
                    .foregroundColor(.orange)
                    .font(.caption)
                
                Text(prompt.name)
                    .fontWeight(.medium)
            }
            
            if let description = prompt.description {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            if let args = prompt.arguments, !args.isEmpty {
                Text("\(args.count) argument\(args.count == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    PromptsView(session: ServerSession(configuration: .sample))
}
