import Foundation

// MARK: - JSON-RPC 2.0 Protocol Types

/// JSON-RPC 2.0 Request
struct JSONRPCRequest: Codable {
    let jsonrpc: String
    let id: RequestID
    let method: String
    let params: JSONValue?
    
    init(id: Int, method: String, params: JSONValue? = nil) {
        self.jsonrpc = "2.0"
        self.id = .int(id)
        self.method = method
        self.params = params
    }
    
    init(id: String, method: String, params: JSONValue? = nil) {
        self.jsonrpc = "2.0"
        self.id = .string(id)
        self.method = method
        self.params = params
    }
}

/// JSON-RPC 2.0 Response
struct JSONRPCResponse: Codable {
    let jsonrpc: String
    let id: RequestID?
    let result: JSONValue?
    let error: JSONRPCError?
    
    var isSuccess: Bool {
        error == nil
    }
}

/// JSON-RPC 2.0 Error
struct JSONRPCError: Codable, Error, LocalizedError {
    let code: Int
    let message: String
    let data: JSONValue?
    
    var errorDescription: String? {
        "JSON-RPC Error \(code): \(message)"
    }
    
    // Standard JSON-RPC error codes
    static let parseError = -32700
    static let invalidRequest = -32600
    static let methodNotFound = -32601
    static let invalidParams = -32602
    static let internalError = -32603
}

/// JSON-RPC 2.0 Notification (no id field)
struct JSONRPCNotification: Codable {
    let jsonrpc: String
    let method: String
    let params: JSONValue?
    
    init(method: String, params: JSONValue? = nil) {
        self.jsonrpc = "2.0"
        self.method = method
        self.params = params
    }
}

// MARK: - Request ID (can be int or string)

enum RequestID: Codable, Hashable {
    case int(Int)
    case string(String)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else {
            throw DecodingError.typeMismatch(
                RequestID.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected Int or String")
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .int(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        }
    }
}

// MARK: - JSONValue (flexible JSON type)

/// A flexible JSON value type that can represent any JSON data
enum JSONValue: Codable, Equatable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: JSONValue].self) {
            self = .object(object)
        } else {
            throw DecodingError.typeMismatch(
                JSONValue.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON type")
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }
    
    // Convenience initializers
    static func from(_ value: Any?) -> JSONValue {
        guard let value = value else { return .null }
        
        switch value {
        case let bool as Bool:
            return .bool(bool)
        case let int as Int:
            return .int(int)
        case let double as Double:
            return .double(double)
        case let string as String:
            return .string(string)
        case let array as [Any]:
            return .array(array.map { JSONValue.from($0) })
        case let dict as [String: Any]:
            return .object(dict.mapValues { JSONValue.from($0) })
        default:
            return .null
        }
    }
    
    // Convert to native Swift types
    func toAny() -> Any? {
        switch self {
        case .null:
            return nil
        case .bool(let value):
            return value
        case .int(let value):
            return value
        case .double(let value):
            return value
        case .string(let value):
            return value
        case .array(let value):
            return value.map { $0.toAny() }
        case .object(let value):
            return value.mapValues { $0.toAny() }
        }
    }
    
    // Subscript access for objects
    subscript(key: String) -> JSONValue? {
        if case .object(let dict) = self {
            return dict[key]
        }
        return nil
    }
    
    // Subscript access for arrays
    subscript(index: Int) -> JSONValue? {
        if case .array(let arr) = self, index >= 0 && index < arr.count {
            return arr[index]
        }
        return nil
    }
    
    // Type accessors
    var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }
    
    var intValue: Int? {
        if case .int(let i) = self { return i }
        return nil
    }
    
    var doubleValue: Double? {
        if case .double(let d) = self { return d }
        if case .int(let i) = self { return Double(i) }
        return nil
    }
    
    var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }
    
    var arrayValue: [JSONValue]? {
        if case .array(let a) = self { return a }
        return nil
    }
    
    var objectValue: [String: JSONValue]? {
        if case .object(let o) = self { return o }
        return nil
    }
    
    // Pretty print JSON
    func prettyPrinted() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(self),
              let string = String(data: data, encoding: .utf8) else {
            return "\(self)"
        }
        return string
    }
}

// MARK: - JSON Encoding/Decoding Helpers

struct JSONRPCCodec {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = []
        return encoder
    }()
    
    static let decoder = JSONDecoder()
    
    static func encode<T: Encodable>(_ value: T) throws -> Data {
        try encoder.encode(value)
    }
    
    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try decoder.decode(type, from: data)
    }
    
    static func encodeRequest(_ request: JSONRPCRequest) throws -> String {
        let data = try encode(request)
        guard let string = String(data: data, encoding: .utf8) else {
            throw MCPError.encodingError("Failed to encode request to UTF-8 string")
        }
        return string
    }
    
    static func decodeResponse(from data: Data) throws -> JSONRPCResponse {
        try decode(JSONRPCResponse.self, from: data)
    }
}
