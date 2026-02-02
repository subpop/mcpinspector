import SwiftUI

struct PromptsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedPrompt: MCPPrompt?
    @State private var searchText = ""
    
    private var filteredPrompts: [MCPPrompt] {
        if searchText.isEmpty {
            return appState.prompts
        }
        return appState.prompts.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.description?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var body: some View {
        HSplitView {
            // Prompts List
            promptsList
                .frame(minWidth: 250, maxWidth: 350)
            
            // Prompt Detail
            promptDetail
                .frame(minWidth: 400)
        }
        .navigationTitle("Prompts")
        .searchable(text: $searchText, prompt: "Search prompts...")
    }
    
    // MARK: - Prompts List
    
    private var promptsList: some View {
        List(selection: $selectedPrompt) {
            if filteredPrompts.isEmpty {
                if appState.prompts.isEmpty {
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
    }
    
    // MARK: - Prompt Detail
    
    @ViewBuilder
    private var promptDetail: some View {
        if let prompt = selectedPrompt {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
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
                    
                    // Arguments
                    if let arguments = prompt.arguments, !arguments.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Arguments")
                                .font(.headline)
                            
                            ForEach(arguments, id: \.name) { arg in
                                PromptArgumentRow(argument: arg)
                            }
                        }
                    } else {
                        Text("No arguments")
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding()
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

// MARK: - Prompt Argument Row

struct PromptArgumentRow: View {
    let argument: MCPPromptArgument
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
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
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(6)
    }
}

#Preview {
    PromptsView()
        .environmentObject(AppState())
}
