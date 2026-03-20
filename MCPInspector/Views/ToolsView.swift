import SwiftUI

struct ToolsView: View {
    @ObservedObject var session: ServerSession
    @State private var selectedTool: MCPTool?
    @State private var searchText = ""
    
    private var filteredTools: [MCPTool] {
        if searchText.isEmpty {
            return session.tools
        }
        return session.tools.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.description?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var body: some View {
        HSplitView {
            toolsList
                .frame(width: 280)

            toolDetail
                .frame(minWidth: 280)
        }
        .sheet(item: $session.pendingElicitation) { elicitation in
            ElicitationSheet(session: session, elicitation: elicitation)
        }
    }
    
    // MARK: - Tools List
    
    private var toolsList: some View {
        List(selection: $selectedTool) {
            ForEach(filteredTools) { tool in
                ToolRow(tool: tool, isSelected: selectedTool?.id == tool.id)
                    .tag(tool)
            }
        }
        .listStyle(.inset)
        .searchable(text: $searchText, prompt: "Filter tools...")
        .overlay {
            if filteredTools.isEmpty {
                ContentUnavailableView(
                    session.tools.isEmpty ? "No tools available" : "No matching tools",
                    systemImage: "wrench.and.screwdriver"
                )
            }
        }
    }
    
    // MARK: - Tool Detail
    
    @ViewBuilder
    private var toolDetail: some View {
        if let tool = selectedTool {
            ToolDetailView(tool: tool) { name, arguments in
                try await session.callTool(name: name, arguments: arguments)
            }
        } else {
            ContentUnavailableView("Select a tool",
                                   systemImage: "wrench.and.screwdriver")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Parameter Value

enum ParameterValue {
    case string(String)
    case number(String)
    case boolean(Bool)
    case json(String)
    
    var asAny: Any? {
        switch self {
        case .string(let s):
            return s.isEmpty ? nil : s
        case .number(let s):
            if let int = Int(s) { return int }
            if let double = Double(s) { return double }
            return nil
        case .boolean(let b):
            return b
        case .json(let s):
            guard let data = s.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) else {
                return nil
            }
            return obj
        }
    }
}

// MARK: - Tool Call Result

enum ToolCallResult {
    case success(MCPToolResult)
    case error(String)
}

// MARK: - Tool Row

struct ToolRow: View {
    let tool: MCPTool
    let isSelected: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "wrench.and.screwdriver")
                    .foregroundColor(.accentColor)
                    .font(.caption)
                
                Text(tool.name)
                    .fontWeight(.medium)
            }
            
            if let description = tool.description {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

// Note: Populating sample tools in the preview causes a SwiftUI crash
// in OutlineListCoordinator (rdar://FB...). Run the app to test with data.
#Preview("Tools") {
    ToolsView(session: ServerSession(configuration: .sample))
        .frame(width: 800, height: 500)
}
