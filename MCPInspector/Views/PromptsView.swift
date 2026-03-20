import SwiftUI

struct PromptsView: View {
    @ObservedObject var session: ServerSession
    @State private var selectedPrompt: MCPPrompt?
    @State private var searchText = ""
    
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
                .frame(width: 280)

            promptDetail
                .frame(minWidth: 280)
        }
    }
    
    // MARK: - Prompts List
    
    private var promptsList: some View {
        List(selection: $selectedPrompt) {
            ForEach(filteredPrompts) { prompt in
                PromptRow(prompt: prompt, isSelected: selectedPrompt?.id == prompt.id)
                    .tag(prompt)
            }
        }
        .listStyle(.inset)
        .searchable(text: $searchText, prompt: "Filter prompts...")
        .overlay {
            if filteredPrompts.isEmpty {
                ContentUnavailableView(
                    session.prompts.isEmpty ? "No prompts available" : "No matching prompts",
                    systemImage: "text.bubble"
                )
            }
        }
    }
    
    // MARK: - Prompt Detail
    
    @ViewBuilder
    private var promptDetail: some View {
        if let prompt = selectedPrompt {
            PromptDetailView(prompt: prompt) { name, arguments in
                try await session.getPrompt(name: name, arguments: arguments)
            }
        } else {
            ContentUnavailableView("Select a prompt",
                                   systemImage: "text.bubble")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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

#Preview("Prompts") {
    PromptsView(session: ServerSession(configuration: .sample))
        .frame(width: 800, height: 500)
}
