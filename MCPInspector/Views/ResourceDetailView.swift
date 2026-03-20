import SwiftUI

/// A detail view for inspecting and reading an MCP resource.
///
/// Displays the resource's name, description, URI, MIME type, a "Read" button,
/// and the read result. Designed to be used standalone (e.g. in a `#Preview`)
/// or embedded inside `ResourcesView`.
struct ResourceDetailView: View {
    let resource: MCPResource

    /// Called when the user taps "Read". Returns the resource contents asynchronously.
    var onReadResource: (_ uri: String) async throws -> MCPResourceReadResult

    // MARK: - State

    @State private var isReading = false
    @State private var result: ResourceReadResult?
    @State private var resultExpanded = true

    // MARK: - Body

    var body: some View {
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
        .onChange(of: resource) {
            resetReadState()
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

            Button {
                executeResourceRead()
            } label: {
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
        isReading = true
        result = nil

        Task {
            do {
                let readResult = try await onReadResource(resource.uri)
                result = .success(readResult)
            } catch {
                result = .error(error.localizedDescription)
            }
            isReading = false
            resultExpanded = true
        }
    }
}

// MARK: - Previews

#Preview("Resource with text content") {
    ResourceDetailView(
        resource: MCPResource(
            uri: "file:///projects/app/README.md",
            name: "README.md",
            description: "Project readme with setup instructions and documentation.",
            mimeType: "text/markdown"
        ),
        onReadResource: { _ in
            MCPResourceReadResult(
                contents: [
                    MCPResourceContent(
                        uri: "file:///projects/app/README.md",
                        mimeType: "text/markdown",
                        text: "# My App\n\nA sample application.\n\n## Getting Started\n\nRun `swift build` to compile.",
                        blob: nil
                    ),
                ]
            )
        }
    )
    .frame(width: 500, height: 500)
}

#Preview("Resource without description") {
    ResourceDetailView(
        resource: MCPResource(
            uri: "db://users/schema",
            name: "users table schema",
            description: nil,
            mimeType: "application/json"
        ),
        onReadResource: { _ in
            MCPResourceReadResult(
                contents: [
                    MCPResourceContent(
                        uri: "db://users/schema",
                        mimeType: "application/json",
                        text: "{\n  \"columns\": [\"id\", \"name\", \"email\"],\n  \"primary_key\": \"id\"\n}",
                        blob: nil
                    ),
                ]
            )
        }
    )
    .frame(width: 500, height: 450)
}
