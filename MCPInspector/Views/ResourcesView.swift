// Copyright (c) 2026 Link Dupont
// SPDX-License-Identifier: MIT

import SwiftUI

struct ResourcesView: View {
    @ObservedObject var session: ServerSession
    @State private var selectedResource: MCPResource?
    @State private var searchText = ""
    
    private var filteredResources: [MCPResource] {
        if searchText.isEmpty {
            return session.resources
        }
        return session.resources.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.uri.localizedCaseInsensitiveContains(searchText) ||
            ($0.description?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var body: some View {
        HSplitView {
            resourcesList
                .frame(width: 280)

            resourceDetail
                .frame(minWidth: 280)
        }
    }
    
    // MARK: - Resources List
    
    private var resourcesList: some View {
        List(selection: $selectedResource) {
            ForEach(filteredResources) { resource in
                ResourceRow(resource: resource, isSelected: selectedResource?.id == resource.id)
                    .tag(resource)
            }
        }
        .listStyle(.inset)
        .searchable(text: $searchText, prompt: "Filter resources...")
        .overlay {
            if filteredResources.isEmpty {
                ContentUnavailableView(
                    session.resources.isEmpty ? "No resources available" : "No matching resources",
                    systemImage: "doc.text"
                )
            }
        }
    }
    
    // MARK: - Resource Detail
    
    @ViewBuilder
    private var resourceDetail: some View {
        if let resource = selectedResource {
            ResourceDetailView(resource: resource) { uri in
                try await session.readResource(uri: uri)
            }
        } else {
            ContentUnavailableView("Select a resource",
                                   systemImage: "doc.text")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Resource Read Result

enum ResourceReadResult {
    case success(MCPResourceReadResult)
    case error(String)
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

#Preview("Resources") {
    ResourcesView(session: ServerSession(configuration: .sample))
        .frame(width: 800, height: 500)
}
