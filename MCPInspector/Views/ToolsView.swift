import SwiftUI

struct ToolsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTool: MCPTool?
    @State private var showingInvocationSheet = false
    @State private var searchText = ""
    
    private var filteredTools: [MCPTool] {
        if searchText.isEmpty {
            return appState.tools
        }
        return appState.tools.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.description?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var body: some View {
        HSplitView {
            // Tools List
            toolsList
                .frame(minWidth: 250, maxWidth: 350)
            
            // Tool Detail
            toolDetail
                .frame(minWidth: 400)
        }
        .navigationTitle("Tools")
        .searchable(text: $searchText, prompt: "Search tools...")
        .sheet(isPresented: $showingInvocationSheet) {
            if let tool = selectedTool {
                ToolInvocationSheet(tool: tool)
            }
        }
    }
    
    // MARK: - Tools List
    
    private var toolsList: some View {
        List(selection: $selectedTool) {
            if filteredTools.isEmpty {
                if appState.tools.isEmpty {
                    Text("No tools available")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    Text("No matching tools")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
            } else {
                ForEach(filteredTools) { tool in
                    ToolRow(tool: tool, isSelected: selectedTool?.id == tool.id)
                        .tag(tool)
                }
            }
        }
        .listStyle(.inset)
    }
    
    // MARK: - Tool Detail
    
    @ViewBuilder
    private var toolDetail: some View {
        if let tool = selectedTool {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(tool.name)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .textSelection(.enabled)
                            
                            if let description = tool.description {
                                Text(description)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Button("Call Tool") {
                            showingInvocationSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    Divider()
                    
                    // Input Schema
                    if let schema = tool.inputSchema {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Input Schema")
                                .font(.headline)
                            
                            SchemaView(schema: schema, required: tool.requiredParameters)
                        }
                    } else {
                        Text("No parameters required")
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding()
            }
        } else {
            VStack {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                
                Text("Select a tool")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
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

// MARK: - Schema View

struct SchemaView: View {
    let schema: JSONValue
    let required: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let properties = schema["properties"]?.objectValue {
                ForEach(Array(properties.keys.sorted()), id: \.self) { key in
                    if let prop = properties[key] {
                        PropertyRow(
                            name: key,
                            property: prop,
                            isRequired: required.contains(key)
                        )
                    }
                }
            }
            
            // Raw schema view
            DisclosureGroup("Raw Schema") {
                ScrollView(.horizontal, showsIndicators: true) {
                    Text(schema.prettyPrinted())
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(8)
                }
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)
            }
            .font(.subheadline)
        }
    }
}

struct PropertyRow: View {
    let name: String
    let property: JSONValue
    let isRequired: Bool
    
    private var type: String {
        property["type"]?.stringValue ?? "any"
    }
    
    private var description: String? {
        property["description"]?.stringValue
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                
                Text(type)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(4)
                
                if isRequired {
                    Text("required")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            if let desc = description {
                Text(desc)
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
    ToolsView()
        .environmentObject(AppState())
}
