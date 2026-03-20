import SwiftUI

/// A detail view for inspecting and invoking an MCP tool.
///
/// This view displays the tool's name, description, parameter form (or raw JSON editor),
/// a "Run" button, and the invocation result. It is designed to be used standalone
/// (e.g. in a `#Preview`) or embedded inside `ToolsView`.
struct ToolDetailView: View {
    let tool: MCPTool

    /// Called when the user taps "Run". Returns the tool result asynchronously.
    var onRunTool: @MainActor (_ name: String, _ arguments: [String: Any]) async throws -> MCPToolResult

    /// Optional pre-populated result used by previews.
    var initialResult: ToolCallResult? = nil

    // MARK: - State

    @State private var parameterValues: [String: ParameterValue] = [:]
    @State private var isExecuting = false
    @State private var result: ToolCallResult?
    @State private var rawJSON = "{}"
    @State private var useRawJSON = false
    @State private var resultExpanded = true
    @State private var resultViewMode: ResultViewMode = .content

    /// Controls which view is shown in the result section when structured output is available.
    private enum ResultViewMode: String, CaseIterable {
        case content = "Content"
        case structured = "Structured"
        case raw = "Raw JSON"

        var imageName: String {
            switch self {
            case .content: "doc.text"
            case .structured: "list.bullet.indent"
            case .raw: "curlybraces"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
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

                    Divider()

                    // Input section
                    if tool.hasParameters {
                        inputModeToggle

                        if useRawJSON {
                            rawJSONEditor
                        } else {
                            parameterForm(tool: tool)
                        }

                        // Raw schema reference
                        if let schema = tool.inputSchema {
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
                            .foregroundColor(.secondary)
                        }
                    } else {
                        Text("This tool has no parameters.")
                            .foregroundColor(.secondary)
                    }

                    // Output schema reference
                    if let outputSchema = tool.outputSchema {
                        DisclosureGroup("Output Schema") {
                            ScrollView(.horizontal, showsIndicators: true) {
                                Text(outputSchema.prettyPrinted())
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                                    .padding(8)
                            }
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(6)
                        }
                        .font(.subheadline)
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
            initializeParameters(for: tool)
            if let initial = initialResult {
                result = initial
                if case .success(let r) = initial, r.structuredContent != nil {
                    resultViewMode = .structured
                }
            }
        }
        .onChange(of: tool) {
            resetInvocationState()
        }
    }

    // MARK: - Input Mode Toggle

    private var inputModeToggle: some View {
        HStack {
            Text("Input Schema")
                .font(.headline)

            Spacer()


            Picker("", selection: $useRawJSON) {
                Image(systemName: "list.bullet.rectangle").tag(false)
                Image(systemName: "curlybraces").tag(true)
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Parameter Form

    private func parameterForm(tool: MCPTool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let properties = tool.schemaProperties {
                ForEach(Array(properties.keys.sorted()), id: \.self) { key in
                    if let prop = properties[key] {
                        parameterField(name: key, property: prop, tool: tool)
                    }
                }
            }
        }
    }

    private func parameterField(name: String, property: JSONValue, tool: MCPTool) -> some View {
        let type = property["type"]?.stringValue ?? "string"
        let description = property["description"]?.stringValue
        let isRequired = tool.requiredParameters.contains(name)

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
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

            inputField(for: name, type: type, property: property)
        }
        .padding(10)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }

    @ViewBuilder
    private func inputField(for name: String, type: String, property: JSONValue) -> some View {
        switch type {
        case "boolean":
            Toggle("", isOn: boolBinding(for: name))
                .labelsHidden()

        case "number", "integer":
            TextField("Enter \(type) value", text: stringBinding(for: name, type: .number("")))
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))

        case "object", "array":
            PlainTextEditor(text: jsonBinding(for: name, type: type))
                .frame(height: 80)
                .border(Color.secondary.opacity(0.3))
                .cornerRadius(4)

        default:
            if let enumValues = property["enum"]?.arrayValue {
                Picker("", selection: stringBinding(for: name, type: .string(""))) {
                    Text("Select...").tag("")
                    ForEach(enumValues.compactMap { $0.stringValue }, id: \.self) { value in
                        Text(value).tag(value)
                    }
                }
                .labelsHidden()
            } else {
                TextField("Enter value", text: stringBinding(for: name, type: .string("")))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
            }
        }
    }

    // MARK: - Raw JSON Editor

    private var rawJSONEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Arguments (JSON)")
                .font(.subheadline)
                .fontWeight(.medium)

            PlainTextEditor(text: $rawJSON)
                .frame(minHeight: 150)
                .border(Color.secondary.opacity(0.3))
                .cornerRadius(4)

            Text("Enter a valid JSON object with the tool arguments.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Run Footer

    private var runFooter: some View {
        ActionFooter(
            actionLabel: "Run",
            activeLabel: "Running...",
            isActive: isExecuting,
            hasResult: result != nil,
            onAction: executeToolCall,
            onClear: { result = nil }
        )
    }

    // MARK: - Result Section

    private func resultSection(_ result: ToolCallResult) -> some View {
        DisclosureGroup(isExpanded: $resultExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                switch result {
                case .success(let toolResult):
                    resultViewModePicker(toolResult)
                    resultBody(toolResult)
                case .error(let message):
                    Text(message)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.red)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
        } label: {
            HStack(spacing: 8) {
                Text("Result")
                    .font(.headline)

                resultBadge(result)
            }
        }
    }

    /// Shows a segmented picker to switch between Content / Structured / Raw JSON views.
    /// Only displayed when the result contains structured content.
    @ViewBuilder
    private func resultViewModePicker(_ toolResult: MCPToolResult) -> some View {
        if toolResult.structuredContent != nil {
            Picker("", selection: $resultViewMode) {
                ForEach(ResultViewMode.allCases, id: \.self) { mode in
                    Image(systemName: mode.imageName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    /// Renders the appropriate result body based on the selected view mode.
    @ViewBuilder
    private func resultBody(_ toolResult: MCPToolResult) -> some View {
        let hasStructured = toolResult.structuredContent != nil

        switch hasStructured ? resultViewMode : .content {
        case .content:
            ForEach(Array(toolResult.content.enumerated()), id: \.offset) { index, content in
                resultContentView(content, index: index)
            }

        case .structured:
            if let structured = toolResult.structuredContent {
                structuredContentSection(structured)
            }

        case .raw:
            if let structured = toolResult.structuredContent {
                rawJSONResultView(structured)
            }
        }
    }

    @ViewBuilder
    private func resultBadge(_ result: ToolCallResult) -> some View {
        switch result {
        case .success(let r):
            if r.isError == true {
                Label("Error", systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.subheadline)
            } else {
                Label("Success", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.subheadline)
            }
        case .error:
            Label("Error", systemImage: "xmark.circle.fill")
                .foregroundColor(.red)
                .font(.subheadline)
        }
    }

    // MARK: - Content View (text/image/resource items)

    private func resultContentView(_ content: MCPContent, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("[\(index)] \(content.type)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

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
    }

    // MARK: - Structured Content View

    private func structuredContentSection(_ value: JSONValue) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label("Structured Output", systemImage: "tree")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }

            StructuredContentView(value)
                .padding(8)
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(6)
        }
    }

    // MARK: - Raw JSON Result View

    private func rawJSONResultView(_ value: JSONValue) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label("Raw JSON", systemImage: "curlybraces")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: true) {
                Text(value.prettyPrinted())
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(8)
            }
            .background(Color.secondary.opacity(0.05))
            .cornerRadius(6)
        }
    }

    // MARK: - Bindings

    private func stringBinding(for name: String, type: ParameterValue) -> Binding<String> {
        Binding(
            get: {
                switch parameterValues[name] {
                case .string(let s): return s
                case .number(let s): return s
                default: return ""
                }
            },
            set: { newValue in
                switch type {
                case .number:
                    parameterValues[name] = .number(newValue)
                default:
                    parameterValues[name] = .string(newValue)
                }
            }
        )
    }

    private func boolBinding(for name: String) -> Binding<Bool> {
        Binding(
            get: {
                if case .boolean(let b) = parameterValues[name] {
                    return b
                }
                return false
            },
            set: { newValue in
                parameterValues[name] = .boolean(newValue)
            }
        )
    }

    private func jsonBinding(for name: String, type: String) -> Binding<String> {
        Binding(
            get: {
                if case .json(let s) = parameterValues[name] {
                    return s
                }
                return type == "array" ? "[]" : "{}"
            },
            set: { newValue in
                parameterValues[name] = .json(newValue)
            }
        )
    }

    // MARK: - Actions

    private func resetInvocationState() {
        parameterValues = [:]
        rawJSON = "{}"
        useRawJSON = false
        isExecuting = false
        result = nil
        resultExpanded = true
        resultViewMode = .content
        initializeParameters(for: tool)
    }

    private func initializeParameters(for tool: MCPTool) {
        guard let properties = tool.schemaProperties else { return }

        for (key, prop) in properties {
            let type = prop["type"]?.stringValue ?? "string"

            switch type {
            case "boolean":
                parameterValues[key] = .boolean(false)
            case "number", "integer":
                parameterValues[key] = .number("")
            case "object":
                parameterValues[key] = .json("{}")
            case "array":
                parameterValues[key] = .json("[]")
            default:
                parameterValues[key] = .string("")
            }
        }
    }

    private func executeToolCall() {
        isExecuting = true
        result = nil

        Task {
            do {
                let arguments = buildArguments()
                let toolResult = try await onRunTool(tool.name, arguments)
                result = .success(toolResult)
                // Default to structured view when structured output is present
                resultViewMode = toolResult.structuredContent != nil ? .structured : .content
            } catch {
                result = .error(error.localizedDescription)
            }
            isExecuting = false
            resultExpanded = true
        }
    }

    private func buildArguments() -> [String: Any] {
        if useRawJSON {
            guard let data = rawJSON.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return [:]
            }
            return json
        }

        var args: [String: Any] = [:]
        for (key, value) in parameterValues {
            if let v = value.asAny {
                args[key] = v
            }
        }
        return args
    }
}

// MARK: - Preview

private let sampleWeatherSchema: JSONValue = .object([
    "type": .string("object"),
    "properties": .object([
        "location": .object([
            "type": .string("string"),
            "description": .string("City name or coordinates")
        ]),
        "units": .object([
            "type": .string("string"),
            "description": .string("Temperature units"),
            "enum": .array([.string("celsius"), .string("fahrenheit")])
        ]),
        "detailed": .object([
            "type": .string("boolean"),
            "description": .string("Include extended forecast")
        ])
    ]),
    "required": .array([.string("location")])
])

#Preview("Tool with parameters") {
    ToolDetailView(
        tool: MCPTool(
            name: "get_weather",
            description: "Get the current weather for a given location.",
            inputSchema: sampleWeatherSchema,
            outputSchema: nil
        ),
        onRunTool: { _, _ in
            MCPToolResult(
                content: [MCPContent(type: "text", text: "72\u{00B0}F, sunny", data: nil, mimeType: nil)],
                structuredContent: nil,
                isError: nil
            )
        }
    )
    .frame(width: 500, height: 600)
}

#Preview("Tool without parameters") {
    ToolDetailView(
        tool: MCPTool(
            name: "list_files",
            description: "List all files in the current working directory.",
            inputSchema: nil,
            outputSchema: nil
        ),
        onRunTool: { _, _ in
            MCPToolResult(
                content: [MCPContent(type: "text", text: "file1.txt\nfile2.txt\nfile3.txt", data: nil, mimeType: nil)],
                structuredContent: nil,
                isError: nil
            )
        }
    )
    .frame(width: 500, height: 400)
}

private let sampleOutputSchema: JSONValue = .object([
    "type": .string("object"),
    "properties": .object([
        "temperature": .object(["type": .string("number")]),
        "unit": .object(["type": .string("string")]),
        "conditions": .object(["type": .string("string")]),
        "forecast": .object([
            "type": .string("array"),
            "items": .object(["type": .string("object")])
        ])
    ])
])

private let sampleMondayForecast: JSONValue = .object([
    "day": .string("Monday"),
    "high": .int(75),
    "low": .int(58),
    "conditions": .string("partly cloudy")
])

private let sampleTuesdayForecast: JSONValue = .object([
    "day": .string("Tuesday"),
    "high": .int(68),
    "low": .int(55),
    "conditions": .string("rain")
])

private let sampleStructuredContent: JSONValue = .object([
    "temperature": .double(72.0),
    "unit": .string("fahrenheit"),
    "conditions": .string("sunny"),
    "forecast": .array([sampleMondayForecast, sampleTuesdayForecast])
])

private let sampleStructuredResult = MCPToolResult(
    content: [MCPContent(type: "text", text: "72F, sunny", data: nil, mimeType: nil)],
    structuredContent: sampleStructuredContent,
    isError: nil
)

#Preview("Tool with structured output") {
    ToolDetailView(
        tool: MCPTool(
            name: "get_weather_structured",
            description: "Get weather with structured output.",
            inputSchema: sampleWeatherSchema,
            outputSchema: sampleOutputSchema
        ),
        onRunTool: { _, _ in sampleStructuredResult },
        initialResult: .success(sampleStructuredResult)
    )
    .frame(width: 500, height: 700)
}
