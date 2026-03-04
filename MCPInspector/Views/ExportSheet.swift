import SwiftUI
import UniformTypeIdentifiers

struct ExportSheet: View {
    let configuration: ServerConfiguration
    @Environment(\.dismiss) private var dismiss

    @State private var selectedFormat: ExportFormat = .vscode
    @State private var copied = false
    @State private var cliCopied = false

    private var exportedContent: String {
        configuration.exported(as: selectedFormat)
    }

    private var cliCommand: String? {
        configuration.cliCommand(for: selectedFormat)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            VStack(spacing: 16) {
                formatPicker
                preview
                if let cliCommand {
                    cliSection(command: cliCommand)
                }
            }
            .padding()

            Divider()
            footer
        }
        .frame(width: 560, height: 560)
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
                Text("Configuration")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Button {
                    copyToClipboard()
                } label: {
                    Label(copied ? "Copied!" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
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

            Button("Save to File…") {
                saveToFile()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - CLI Command

    private func cliSection(command: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Command", systemImage: "terminal")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Button {
                    copyCLIToClipboard(command)
                } label: {
                    Label(cliCopied ? "Copied!" : "Copy", systemImage: cliCopied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                Text(command)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .textBackgroundColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.2))
            )
        }
    }

    // MARK: - Actions

    private func copyCLIToClipboard(_ command: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
        cliCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            cliCopied = false
        }
    }

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
        panel.isExtensionHidden = false
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
