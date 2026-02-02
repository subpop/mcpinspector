import Foundation

/// A log entry representing a message sent to or received from the MCP server
struct LogEntry: Identifiable, Equatable, Hashable, Codable {
    let id: UUID
    let timestamp: Date
    let direction: Direction
    let method: String
    let content: String
    let isError: Bool
    
    enum Direction: String, Codable {
        case incoming
        case outgoing
        case stderr
        
        var symbol: String {
            switch self {
            case .incoming: return "←"
            case .outgoing: return "→"
            case .stderr: return "⚠"
            }
        }
        
        var label: String {
            switch self {
            case .incoming: return "Response"
            case .outgoing: return "Request"
            case .stderr: return "stderr"
            }
        }
    }
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        direction: Direction,
        method: String,
        content: String,
        isError: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.direction = direction
        self.method = method
        self.content = content
        self.isError = isError
    }
    
    /// Formatted timestamp for display
    var formattedTimestamp: String {
        Self.timestampFormatter.string(from: timestamp)
    }
    
    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}

/// Store for log entries
@MainActor
class LogStore: ObservableObject {
    @Published private(set) var entries: [LogEntry] = []
    
    /// Maximum number of entries to keep
    private let maxEntries = 1000
    
    func addEntry(_ entry: LogEntry) {
        entries.append(entry)
        
        // Trim old entries if needed
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }
    
    func clear() {
        entries.removeAll()
    }
    
    /// Filter entries by direction
    func entries(direction: LogEntry.Direction) -> [LogEntry] {
        entries.filter { $0.direction == direction }
    }
    
    /// Filter entries by method
    func entries(method: String) -> [LogEntry] {
        entries.filter { $0.method.contains(method) }
    }
    
    /// Get only error entries
    var errorEntries: [LogEntry] {
        entries.filter { $0.isError }
    }
    
    /// Export entries to JSON data
    func exportToJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(entries)
    }
}
