import SwiftUI
import UniformTypeIdentifiers

struct ExportSheet: View {
    let configuration: ServerConfiguration
    @Environment(\.dismiss) private var dismiss

    @State private var selectedFormat: ExportFormat = .vscode
    @State private var copied = false

    private var exportedContent: String {
        ServerConfigExporter.export(configuration, format: selectedFormat)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            VStack(spacing: 16) {
                formatPicker
                preview
            }
            .padding()

            Divider()
            footer
        }
        .frame(width: 560, height: 480)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Label("Export Server Config", systemImage: "square.and.arrow.up")
                    .font(.headline)

                Text(configuration.name)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
    }

    // MARK: - Format Picker

    private var formatPicker: some View {
        HStack(spacing: 8) {
            Text("Format")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Picker("", selection: $selectedFormat) {
                ForEach(ExportFormat.allCases) { format in
                    Text(format.rawValue).tag(format)
                }
            }
            .labelsHidden()

            Spacer()
        }
    }

    // MARK: - Preview

    private var preview: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Preview")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Text(selectedFormat.suggestedFilename)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.12))
                    .cornerRadius(4)
            }

            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical]) {
                    Text(exportedContent)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(10)
                        .frame(
                            minWidth: geometry.size.width,
                            minHeight: geometry.size.height,
                            alignment: .topLeading
                        )
                }
            }
            .background(Color(nsColor: .textBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.2))
            )
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.escape)

            Spacer()

            Button {
                copyToClipboard()
            } label: {
                Label(copied ? "Copied!" : "Copy to Clipboard", systemImage: copied ? "checkmark" : "doc.on.doc")
            }
            .buttonStyle(.bordered)

            Button("Save to File…") {
                saveToFile()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - Actions

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(exportedContent, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copied = false
        }
    }

    private func saveToFile() {
        let panel = NSSavePanel()
        panel.title = "Export for \(selectedFormat.rawValue)"
        panel.nameFieldStringValue = selectedFormat.suggestedFilename
        panel.allowedContentTypes = [selectedFormat.contentType]
        panel.canCreateDirectories = true

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try exportedContent.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                let alert = NSAlert(error: error)
                alert.runModal()
            }
        }
    }
}

#Preview {
    ExportSheet(configuration: ServerConfiguration(
        name: "Example Server",
        command: "npx",
        arguments: ["-y", "@modelcontextprotocol/server-everything"],
        environmentVariables: ["API_KEY": "sk-1234"]
    ))
}
