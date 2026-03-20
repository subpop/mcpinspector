import SwiftUI

struct ResourcesView: View {
    @ObservedObject var session: ServerSession
    @State private var selectedResource: MCPResource?
    @State private var searchText = ""
    
    // Read state
    @State private var isReading = false
    @State private var result: ResourceReadResult?
    @State private var resultExpanded = true
    
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
                .frame(minWidth: 250, maxWidth: 350)
            
            resourceDetail
                .frame(minWidth: 400)
        }
        .onChange(of: selectedResource) {
            resetReadState()
        }
    }
    
    // MARK: - Resources List
    
    private var resourcesList: some View {
        List(selection: $selectedResource) {
            if filteredResources.isEmpty {
                if session.resources.isEmpty {
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
        .searchable(text: $searchText, prompt: "Filter resources...")
    }
    
    // MARK: - Resource Detail
    
    @ViewBuilder
    private var resourceDetail: some View {
        if let resource = selectedResource {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
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
                        
                        // Details section
                        Text("Details")
                            .font(.headline)
                        
                        detailRow(label: "URI", value: resource.uri)
                        
                        if let mimeType = resource.mimeType {
                            detailRow(label: "MIME Type", value: mimeType)
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
                
                // Footer with Read button
                readFooter
            }
        } else {
            ContentUnavailableView("Select a resource",
                                   systemImage: "doc.text")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    // MARK: - Detail Row
    
    private func detailRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
    
    // MARK: - Read Footer
    
    private var readFooter: some View {
        HStack {
            if result != nil {
                Button("Clear Result") {
                    result = nil
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
            
            Button(action: executeResourceRead) {
                HStack(spacing: 6) {
                    if isReading {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(isReading ? "Reading..." : "Read")
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(isReading)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
    
    // MARK: - Result Section
    
    private func resultSection(_ result: ResourceReadResult) -> some View {
        DisclosureGroup(isExpanded: $resultExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                switch result {
                case .success(let readResult):
                    ForEach(Array(readResult.contents.enumerated()), id: \.offset) { index, content in
                        resourceContentView(content, index: index)
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
    private func resultBadge(_ result: ResourceReadResult) -> some View {
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
    
    private func resourceContentView(_ content: MCPResourceContent, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("[\(index)]")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Text(content.uri)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                if let mimeType = content.mimeType {
                    Text(mimeType)
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            
            Text(content.displayText)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(6)
    }
    
    // MARK: - Actions
    
    private func resetReadState() {
        isReading = false
        result = nil
        resultExpanded = true
    }
    
    private func executeResourceRead() {
        guard let resource = selectedResource else { return }
        isReading = true
        result = nil
        
        Task {
            do {
                let readResult = try await session.readResource(uri: resource.uri)
                result = .success(readResult)
            } catch {
                result = .error(error.localizedDescription)
            }
            isReading = false
            resultExpanded = true
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

#Preview {
    ResourcesView(session: ServerSession(configuration: .sample))
}
