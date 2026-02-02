import SwiftUI
import AppKit

/// A plain text editor that disables smart quotes and other text substitutions
struct PlainTextEditor: NSViewRepresentable {
    @Binding var text: String
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        
        // Disable smart quotes and other substitutions
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        
        // Configure for code/JSON editing
        textView.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.isRichText = false
        textView.allowsUndo = true
        
        textView.delegate = context.coordinator
        textView.string = text
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let textView = nsView.documentView as! NSTextView
        if textView.string != text {
            textView.string = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: PlainTextEditor
        
        init(_ parent: PlainTextEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

struct ToolInvocationSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    let tool: MCPTool
    
    @State private var parameterValues: [String: ParameterValue] = [:]
    @State private var isExecuting = false
    @State private var result: ToolCallResult?
    @State private var rawJSON = ""
    @State private var useRawJSON = false
    
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
    
    enum ToolCallResult {
        case success(MCPToolResult)
        case error(String)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if tool.hasParameters {
                        inputModeToggle
                        
                        if useRawJSON {
                            rawJSONEditor
                        } else {
                            parameterForm
                        }
                    } else {
                        Text("This tool has no parameters.")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                    
                    if let result = result {
                        resultView(result)
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Footer
            footer
        }
        .frame(minWidth: 500, minHeight: 400, maxHeight: 700)
        .onAppear {
            initializeParameters()
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Call Tool")
                    .font(.headline)
                
                Text(tool.name)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
    
    // MARK: - Input Mode Toggle
    
    private var inputModeToggle: some View {
        Picker("Input Mode", selection: $useRawJSON) {
            Text("Form").tag(false)
            Text("Raw JSON").tag(true)
        }
        .pickerStyle(.segmented)
        .frame(width: 200)
    }
    
    // MARK: - Parameter Form
    
    private var parameterForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let properties = tool.schemaProperties {
                ForEach(Array(properties.keys.sorted()), id: \.self) { key in
                    if let prop = properties[key] {
                        parameterField(name: key, property: prop)
                    }
                }
            }
        }
    }
    
    private func parameterField(name: String, property: JSONValue) -> some View {
        let type = property["type"]?.stringValue ?? "string"
        let description = property["description"]?.stringValue
        let isRequired = tool.requiredParameters.contains(name)
        
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                
                if isRequired {
                    Text("*")
                        .foregroundColor(.red)
                }
                
                Text(type)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(4)
            }
            
            if let desc = description {
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            inputField(for: name, type: type, property: property)
        }
        .padding(8)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(6)
    }
    
    @ViewBuilder
    private func inputField(for name: String, type: String, property: JSONValue) -> some View {
        switch type {
        case "boolean":
            Toggle("", isOn: boolBinding(for: name))
                .labelsHidden()
            
        case "number", "integer":
            TextField("Enter value", text: stringBinding(for: name, type: .number("")))
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
            
        case "object", "array":
            PlainTextEditor(text: jsonBinding(for: name, type: type))
                .frame(height: 80)
                .border(Color.secondary.opacity(0.3))
            
        default: // string
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
            
            Text("Enter a valid JSON object with the tool arguments.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Result View
    
    private func resultView(_ result: ToolCallResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            
            HStack {
                Text("Result")
                    .font(.headline)
                
                Spacer()
                
                switch result {
                case .success(let r):
                    if r.isError == true {
                        Label("Error", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                    } else {
                        Label("Success", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                case .error:
                    Label("Error", systemImage: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    switch result {
                    case .success(let toolResult):
                        ForEach(Array(toolResult.content.enumerated()), id: \.offset) { index, content in
                            contentView(content, index: index)
                        }
                    case .error(let message):
                        Text(message)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.red)
                            .textSelection(.enabled)
                    }
                }
            }
            .frame(maxHeight: 200)
            .padding(8)
            .background(Color.secondary.opacity(0.05))
            .cornerRadius(6)
        }
    }
    
    private func contentView(_ content: MCPContent, index: Int) -> some View {
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
    
    // MARK: - Footer
    
    private var footer: some View {
        HStack {
            if result != nil {
                Button("Clear Result") {
                    result = nil
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
            
            Button("Close") {
                dismiss()
            }
            .keyboardShortcut(.escape)
            
            Button("Execute") {
                executeToolCall()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return)
            .disabled(isExecuting)
        }
        .padding()
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
    
    private func initializeParameters() {
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
        
        // Initialize raw JSON with empty object
        rawJSON = "{}"
    }
    
    private func executeToolCall() {
        isExecuting = true
        result = nil
        
        Task {
            do {
                let arguments = buildArguments()
                let toolResult = try await appState.callTool(name: tool.name, arguments: arguments)
                result = .success(toolResult)
            } catch {
                result = .error(error.localizedDescription)
            }
            isExecuting = false
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

#Preview {
    let sampleTool = MCPTool(
        name: "get_weather",
        description: "Get the current weather for a location",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "location": .object([
                    "type": .string("string"),
                    "description": .string("The city and state, e.g. San Francisco, CA")
                ]),
                "unit": .object([
                    "type": .string("string"),
                    "enum": .array([.string("celsius"), .string("fahrenheit")])
                ])
            ]),
            "required": .array([.string("location")])
        ])
    )
    
    return ToolInvocationSheet(tool: sampleTool)
        .environmentObject(AppState())
}
