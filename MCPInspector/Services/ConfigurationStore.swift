import Foundation

/// Manages persistence of server configurations using UserDefaults
@MainActor
class ConfigurationStore: ObservableObject {
    @Published private(set) var configurations: [ServerConfiguration] = []
    
    private let userDefaultsKey = "MCPInspector.ServerConfigurations"
    
    init() {
        loadConfigurations()
    }
    
    // MARK: - CRUD Operations
    
    func add(_ configuration: ServerConfiguration) {
        configurations.append(configuration)
        saveConfigurations()
    }
    
    func update(_ configuration: ServerConfiguration) {
        if let index = configurations.firstIndex(where: { $0.id == configuration.id }) {
            configurations[index] = configuration
            saveConfigurations()
        }
    }
    
    func delete(_ configuration: ServerConfiguration) {
        configurations.removeAll { $0.id == configuration.id }
        saveConfigurations()
    }
    
    func delete(at offsets: IndexSet) {
        configurations.remove(atOffsets: offsets)
        saveConfigurations()
    }
    
    func move(from source: IndexSet, to destination: Int) {
        configurations.move(fromOffsets: source, toOffset: destination)
        saveConfigurations()
    }
    
    // MARK: - Persistence
    
    private func loadConfigurations() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            // No saved configurations, start with empty list
            return
        }
        
        do {
            let decoded = try JSONDecoder().decode([ServerConfiguration].self, from: data)
            configurations = decoded
        } catch {
            print("Failed to load configurations: \(error)")
            configurations = []
        }
    }
    
    private func saveConfigurations() {
        do {
            let data = try JSONEncoder().encode(configurations)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            print("Failed to save configurations: \(error)")
        }
    }
    
    // MARK: - Lookup
    
    func configuration(withId id: UUID) -> ServerConfiguration? {
        configurations.first { $0.id == id }
    }
    
    func configuration(named name: String) -> ServerConfiguration? {
        configurations.first { $0.name == name }
    }
    
    // MARK: - Import/Export
    
    func exportToJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(configurations)
    }
    
    func importFromJSON(_ data: Data) throws {
        let decoded = try JSONDecoder().decode([ServerConfiguration].self, from: data)
        configurations = decoded
        saveConfigurations()
    }
}
