import SwiftUI
import Combine

@main
struct MCPInspectorApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(appState)
        }
        .windowStyle(.automatic)
        .defaultSize(width: 800, height: 650)

        Settings {
            SettingsView()
        }
    }
}

/// Global application state shared across views
@MainActor
class AppState: ObservableObject {
    @Published var configurationStore = ConfigurationStore()
    private(set) var sessions: [UUID: ServerSession] = [:]
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        configurationStore.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    /// Get or create a session for the given configuration
    func session(for configuration: ServerConfiguration) -> ServerSession {
        if let existing = sessions[configuration.id] {
            return existing
        }
        let session = ServerSession(configuration: configuration)
        sessions[configuration.id] = session
        
        session.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        return session
    }
    
    /// Start a server session (connect)
    func startSession(for configuration: ServerConfiguration) {
        let session = self.session(for: configuration)
        Task {
            await session.connect()
        }
    }
    
    /// Stop a server session (disconnect)
    func stopSession(for configuration: ServerConfiguration) {
        guard let session = sessions[configuration.id] else { return }
        session.disconnect()
    }
    
    /// Remove a session entirely (e.g. when deleting a server config)
    func removeSession(for configId: UUID) {
        if let session = sessions[configId] {
            session.disconnect()
        }
        objectWillChange.send()
        sessions.removeValue(forKey: configId)
    }
    
    /// Connection state for a given server config
    func connectionState(for configId: UUID) -> ServerSession.ConnectionState {
        sessions[configId]?.connectionState ?? .disconnected
    }
}

struct SettingsView: View {
    var body: some View {
        Form {
            Text("MCP Inspector Settings")
                .font(.headline)
            Text("No settings available yet.")
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 400, height: 200)
    }
}
