import SwiftUI

/// A detail view for inspecting and invoking an MCP prompt.
///
/// Displays the prompt's name, description, argument fields, a "Run" button,
/// and the invocation result. Designed to be used standalone (e.g. in a
/// `#Preview`) or embedded inside `PromptsView`.
struct PromptDetailView: View {
    let prompt: MCPPrompt

    /// Called when the user taps "Run". Returns the prompt result asynchronously.
    var onGetPrompt: (_ name: String, _ arguments: [String: String]) async throws -> MCPPromptGetResult

    // MARK: - State

    @State private var argumentValues: [String: String] = [:]
    @State private var isExecuting = false
    @State private var result: PromptCallResult?
    @State private var resultExpanded = true

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
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

                    // Arguments section
                    if let arguments = prompt.arguments, !arguments.isEmpty {
                        Text("Arguments")
                            .font(.headline)

                        ForEach(arguments, id: \.name) { arg in
                            argumentField(argument: arg)
                        }
                    } else {
                        Text("This prompt has no arguments.")
                            .foregroundColor(.secondary)
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

            // Footer with Run button
            runFooter
        }
        .onAppear {
            initializeArguments()
        }
        .onChange(of: prompt) {
            resetInvocationState()
        }
    }

    // MARK: - Argument Field

    private func argumentField(argument: MCPPromptArgument) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
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

            TextField("Enter value", text: argumentBinding(for: argument.name))
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
        }
        .padding(10)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }

    // MARK: - Run Footer

    private var runFooter: some View {
        ActionFooter(
            actionLabel: "Run",
            activeLabel: "Running...",
            isActive: isExecuting,
            hasResult: result != nil,
            onAction: executePromptGet,
            onClear: { result = nil }
        )
    }

    // MARK: - Result Section

    private func resultSection(_ result: PromptCallResult) -> some View {
        DisclosureGroup(isExpanded: $resultExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                switch result {
                case .success(let promptResult):
                    if let description = promptResult.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    ForEach(Array(promptResult.messages.enumerated()), id: \.offset) { index, message in
                        promptMessageView(message, index: index)
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
    private func resultBadge(_ result: PromptCallResult) -> some View {
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

    private func promptMessageView(_ message: MCPPromptMessage, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("[\(index)] \(message.role)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                Text(message.content.type)
                    .font(.caption2)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
            }

            Text(message.content.displayText)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(6)
    }

    // MARK: - Bindings

    private func argumentBinding(for name: String) -> Binding<String> {
        Binding(
            get: { argumentValues[name] ?? "" },
            set: { argumentValues[name] = $0 }
        )
    }

    // MARK: - Actions

    private func initializeArguments() {
        guard let arguments = prompt.arguments else { return }
        for arg in arguments {
            argumentValues[arg.name] = ""
        }
    }

    private func resetInvocationState() {
        argumentValues = [:]
        isExecuting = false
        result = nil
        resultExpanded = true
        initializeArguments()
    }

    private func executePromptGet() {
        isExecuting = true
        result = nil

        Task {
            do {
                let args = argumentValues.filter { !$0.value.isEmpty }
                let promptResult = try await onGetPrompt(prompt.name, args)
                result = .success(promptResult)
            } catch {
                result = .error(error.localizedDescription)
            }
            isExecuting = false
            resultExpanded = true
        }
    }
}

// MARK: - Previews

#Preview("Prompt with arguments") {
    PromptDetailView(
        prompt: MCPPrompt(
            name: "code_review",
            description: "Review code and provide feedback on quality, style, and potential bugs.",
            arguments: [
                MCPPromptArgument(name: "code", description: "The source code to review", required: true),
                MCPPromptArgument(name: "language", description: "Programming language", required: false),
            ]
        ),
        onGetPrompt: { _, _ in
            MCPPromptGetResult(
                description: "Code review result",
                messages: [
                    MCPPromptMessage(
                        role: "user",
                        content: MCPContent(type: "text", text: "Please review the following code...", data: nil, mimeType: nil)
                    ),
                    MCPPromptMessage(
                        role: "assistant",
                        content: MCPContent(type: "text", text: "Here are my findings:\n1. Good use of guard statements\n2. Consider extracting the loop body into a separate function", data: nil, mimeType: nil)
                    ),
                ]
            )
        }
    )
    .frame(width: 500, height: 600)
}

#Preview("Prompt without arguments") {
    PromptDetailView(
        prompt: MCPPrompt(
            name: "summarize",
            description: "Summarize the current conversation context.",
            arguments: nil
        ),
        onGetPrompt: { _, _ in
            MCPPromptGetResult(
                description: nil,
                messages: [
                    MCPPromptMessage(
                        role: "user",
                        content: MCPContent(type: "text", text: "Please provide a summary.", data: nil, mimeType: nil)
                    ),
                ]
            )
        }
    )
    .frame(width: 500, height: 400)
}
