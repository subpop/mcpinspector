import SwiftUI

/// A sheet that presents a form for an elicitation request from the server.
/// The form fields are dynamically generated from the JSON Schema provided
/// in the `requestedSchema` of the elicitation params.
struct ElicitationSheet: View {
    @ObservedObject var session: ServerSession
    @Environment(\.dismiss) private var dismiss
    
    let elicitation: PendingElicitation
    
    @State private var fieldValues: [String: FieldValue] = [:]
    @State private var validationErrors: [String: String] = [:]
    @State private var isSubmitting = false
    
    // MARK: - Field Value Type
    
    enum FieldValue {
        case string(String)
        case number(String)
        case boolean(Bool)
        
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
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    messageSection
                    
                    Divider()
                    
                    formFields
                }
                .padding()
            }
            
            Divider()
            footer
        }
        .frame(minWidth: 480, idealWidth: 520, minHeight: 300, maxHeight: 700)
        .onAppear {
            initializeFields()
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Label("Elicitation Request", systemImage: "questionmark.circle.fill")
                    .font(.headline)
                
                Text("The server is requesting information")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Message
    
    private var messageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Message")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(elicitation.message)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color.blue.opacity(0.08))
                .cornerRadius(8)
        }
    }
    
    // MARK: - Form Fields
    
    private var formFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let properties = elicitation.properties {
                let sortedKeys = properties.keys.sorted()
                ForEach(sortedKeys, id: \.self) { key in
                    if let prop = properties[key] {
                        fieldView(name: key, property: prop)
                    }
                }
            } else {
                Text("No fields in the requested schema.")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func fieldView(name: String, property: JSONValue) -> some View {
        let type = property["type"]?.stringValue ?? "string"
        let title = property["title"]?.stringValue ?? name
        let description = property["description"]?.stringValue
        let isRequired = elicitation.requiredFields.contains(name)
        
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(title)
                    .fontWeight(.medium)
                
                if isRequired {
                    Text("*")
                        .foregroundColor(.red)
                        .fontWeight(.bold)
                }
                
                Text(type)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.15))
                    .cornerRadius(4)
                    .foregroundColor(.blue)
            }
            
            if let desc = description {
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            fieldInput(name: name, type: type, property: property)
            
            if let error = validationErrors[name] {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
    
    @ViewBuilder
    private func fieldInput(name: String, type: String, property: JSONValue) -> some View {
        switch type {
        case "boolean":
            Toggle("", isOn: boolBinding(for: name))
                .labelsHidden()
            
        case "number", "integer":
            let placeholder = numberPlaceholder(property: property, type: type)
            TextField(placeholder, text: stringBinding(for: name, type: .number("")))
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
            
        default: // "string"
            if let enumValues = property["enum"]?.arrayValue {
                let enumNames = property["enumNames"]?.arrayValue?.compactMap { $0.stringValue }
                Picker("", selection: stringBinding(for: name, type: .string(""))) {
                    Text("Select...").tag("")
                    ForEach(Array(enumValues.compactMap { $0.stringValue }.enumerated()), id: \.element) { index, value in
                        let displayName = enumNames != nil && index < enumNames!.count ? enumNames![index] : value
                        Text(displayName).tag(value)
                    }
                }
                .labelsHidden()
            } else if property["format"]?.stringValue == "date" || property["format"]?.stringValue == "date-time" {
                TextField("YYYY-MM-DD", text: stringBinding(for: name, type: .string("")))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
            } else {
                let maxLength = property["maxLength"]?.intValue
                let isLong = maxLength == nil || maxLength! > 200
                
                if isLong && property["enum"] == nil {
                    TextField("Enter value...", text: stringBinding(for: name, type: .string("")), axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...5)
                } else {
                    TextField("Enter value...", text: stringBinding(for: name, type: .string("")))
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
    }
    
    private func numberPlaceholder(property: JSONValue, type: String) -> String {
        var parts: [String] = []
        if let min = property["minimum"]?.doubleValue {
            parts.append("min: \(type == "integer" ? "\(Int(min))" : "\(min)")")
        }
        if let max = property["maximum"]?.doubleValue {
            parts.append("max: \(type == "integer" ? "\(Int(max))" : "\(max)")")
        }
        return parts.isEmpty ? "Enter \(type)..." : parts.joined(separator: ", ")
    }
    
    // MARK: - Footer
    
    private var footer: some View {
        HStack {
            Button("Decline") {
                declineElicitation()
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.escape)
            
            Spacer()
            
            Button("Submit") {
                submitElicitation()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return)
            .disabled(isSubmitting)
        }
        .padding()
    }
    
    // MARK: - Bindings
    
    private func stringBinding(for name: String, type: FieldValue) -> Binding<String> {
        Binding(
            get: {
                switch fieldValues[name] {
                case .string(let s): return s
                case .number(let s): return s
                default: return ""
                }
            },
            set: { newValue in
                validationErrors[name] = nil
                switch type {
                case .number:
                    fieldValues[name] = .number(newValue)
                default:
                    fieldValues[name] = .string(newValue)
                }
            }
        )
    }
    
    private func boolBinding(for name: String) -> Binding<Bool> {
        Binding(
            get: {
                if case .boolean(let b) = fieldValues[name] { return b }
                return false
            },
            set: { newValue in
                validationErrors[name] = nil
                fieldValues[name] = .boolean(newValue)
            }
        )
    }
    
    // MARK: - Initialization
    
    private func initializeFields() {
        guard let properties = elicitation.properties else { return }
        
        for (key, prop) in properties {
            let type = prop["type"]?.stringValue ?? "string"
            
            switch type {
            case "boolean":
                let defaultValue = prop["default"]?.boolValue ?? false
                fieldValues[key] = .boolean(defaultValue)
            case "number", "integer":
                if let defaultValue = prop["default"]?.doubleValue {
                    fieldValues[key] = .number(type == "integer" ? "\(Int(defaultValue))" : "\(defaultValue)")
                } else {
                    fieldValues[key] = .number("")
                }
            default:
                let defaultValue = prop["default"]?.stringValue ?? ""
                fieldValues[key] = .string(defaultValue)
            }
        }
    }
    
    // MARK: - Validation
    
    private func validate() -> Bool {
        validationErrors.removeAll()
        var isValid = true
        
        guard let properties = elicitation.properties else { return true }
        
        for key in elicitation.requiredFields {
            guard let prop = properties[key] else { continue }
            let type = prop["type"]?.stringValue ?? "string"
            
            switch type {
            case "boolean":
                break
            case "number", "integer":
                if case .number(let s) = fieldValues[key], !s.isEmpty {
                    if type == "integer" && Int(s) == nil {
                        validationErrors[key] = "Must be a whole number"
                        isValid = false
                    } else if Double(s) == nil {
                        validationErrors[key] = "Must be a valid number"
                        isValid = false
                    }
                } else {
                    validationErrors[key] = "This field is required"
                    isValid = false
                }
            default:
                if case .string(let s) = fieldValues[key], !s.isEmpty {
                    if let minLength = prop["minLength"]?.intValue, s.count < minLength {
                        validationErrors[key] = "Must be at least \(minLength) characters"
                        isValid = false
                    }
                } else {
                    validationErrors[key] = "This field is required"
                    isValid = false
                }
            }
        }
        
        for (key, value) in fieldValues {
            guard validationErrors[key] == nil,
                  let prop = properties[key] else { continue }
            let type = prop["type"]?.stringValue ?? "string"
            
            switch type {
            case "number":
                if case .number(let s) = value, !s.isEmpty, Double(s) == nil {
                    validationErrors[key] = "Must be a valid number"
                    isValid = false
                }
            case "integer":
                if case .number(let s) = value, !s.isEmpty, Int(s) == nil {
                    validationErrors[key] = "Must be a whole number"
                    isValid = false
                }
            case "string":
                if case .string(let s) = value, !s.isEmpty {
                    if let maxLength = prop["maxLength"]?.intValue, s.count > maxLength {
                        validationErrors[key] = "Must be at most \(maxLength) characters"
                        isValid = false
                    }
                    if let pattern = prop["pattern"]?.stringValue {
                        if let regex = try? NSRegularExpression(pattern: pattern),
                           regex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) == nil {
                            validationErrors[key] = "Does not match required format"
                            isValid = false
                        }
                    }
                }
            default:
                break
            }
        }
        
        return isValid
    }
    
    // MARK: - Actions
    
    private func submitElicitation() {
        guard validate() else { return }
        
        isSubmitting = true
        
        var content: [String: Any] = [:]
        for (key, value) in fieldValues {
            if let v = value.asAny {
                content[key] = v
            }
        }
        
        Task {
            await session.respondToElicitation(action: .accept, content: content)
            dismiss()
        }
    }
    
    private func declineElicitation() {
        Task {
            await session.respondToElicitation(action: .decline)
            dismiss()
        }
    }
}

#Preview {
    let elicitation = PendingElicitation(
        id: "preview",
        requestId: .int(1),
        message: "Please provide your API credentials to continue with the deployment.",
        requestedSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "api_key": .object([
                    "type": .string("string"),
                    "title": .string("API Key"),
                    "description": .string("Your API key for authentication")
                ]),
                "environment": .object([
                    "type": .string("string"),
                    "title": .string("Environment"),
                    "description": .string("Target deployment environment"),
                    "enum": .array([.string("staging"), .string("production")])
                ]),
                "notify": .object([
                    "type": .string("boolean"),
                    "title": .string("Send Notifications"),
                    "description": .string("Whether to send deployment notifications")
                ]),
                "replicas": .object([
                    "type": .string("integer"),
                    "title": .string("Replica Count"),
                    "description": .string("Number of replicas to deploy"),
                    "minimum": .int(1),
                    "maximum": .int(10)
                ])
            ]),
            "required": .array([.string("api_key"), .string("environment")])
        ])
    )
    
    return ElicitationSheet(session: ServerSession(configuration: .sample), elicitation: elicitation)
}
