import SwiftUI

struct ResourcesView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedResource: MCPResource?
    @State private var searchText = ""
    
    private var filteredResources: [MCPResource] {
        if searchText.isEmpty {
            return appState.resources
        }
        return appState.resources.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.uri.localizedCaseInsensitiveContains(searchText) ||
            ($0.description?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var body: some View {
        HSplitView {
            // Resources List
            resourcesList
                .frame(minWidth: 250, maxWidth: 350)
            
            // Resource Detail
            resourceDetail
                .frame(minWidth: 400)
        }
        .navigationTitle("Resources")
        .searchable(text: $searchText, prompt: "Search resources...")
    }
    
    // MARK: - Resources List
    
    private var resourcesList: some View {
        List(selection: $selectedResource) {
            if filteredResources.isEmpty {
                if appState.resources.isEmpty {
                    Text("No resources available")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    Text("No matching resources")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
            } else {
                ForEach(filteredResources) { resource in
                    ResourceRow(resource: resource, isSelected: selectedResource?.id == resource.id)
                        .tag(resource)
                }
            }
        }
        .listStyle(.inset)
    }
    
    // MARK: - Resource Detail
    
    @ViewBuilder
    private var resourceDetail: some View {
        if let resource = selectedResource {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(resource.name)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .textSelection(.enabled)
                        
                        if let description = resource.description {
                            Text(description)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    // Resource Details
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Details")
                            .font(.headline)
                        
                        detailRow(label: "URI", value: resource.uri)
                        
                        if let mimeType = resource.mimeType {
                            detailRow(label: "MIME Type", value: mimeType)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
        } else {
            VStack {
                Image(systemName: "doc.text")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                
                Text("Select a resource")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private func detailRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(6)
    }
}

// MARK: - Resource Row

struct ResourceRow: View {
    let resource: MCPResource
    let isSelected: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: iconForResource)
                    .foregroundColor(.purple)
                    .font(.caption)
                
                Text(resource.name)
                    .fontWeight(.medium)
            }
            
            Text(resource.uri)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            if let mimeType = resource.mimeType {
                Text(mimeType)
                    .font(.caption2)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.2))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var iconForResource: String {
        guard let mimeType = resource.mimeType else {
            return "doc"
        }
        
        if mimeType.hasPrefix("text/") {
            return "doc.text"
        } else if mimeType.hasPrefix("image/") {
            return "photo"
        } else if mimeType.hasPrefix("application/json") {
            return "curlybraces"
        } else if mimeType.hasPrefix("application/") {
            return "doc.fill"
        }
        
        return "doc"
    }
}

#Preview {
    ResourcesView()
        .environmentObject(AppState())
}
