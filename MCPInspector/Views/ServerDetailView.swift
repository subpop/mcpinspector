import SwiftUI

struct ServerDetailView: View {
    @ObservedObject var session: ServerSession
    let onEdit: () -> Void
    
    @State private var selectedTab: DetailTab = .overview
    
    enum DetailTab: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case tools = "Tools"
        case prompts = "Prompts"
        case resources = "Resources"
        case logs = "Logs"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .overview: return "info.circle"
            case .tools: return "wrench.and.screwdriver"
            case .prompts: return "text.bubble"
            case .resources: return "doc.text"
            case .logs: return "list.bullet.rectangle"
            }
        }
    }
    
    var body: some View {
        Group {
            switch session.connectionState {
            case .disconnected:
                disconnectedView
            case .connecting:
                connectingView
            case .connected:
                connectedView
            case .error(let message):
                errorView(message: message)
            }
        }
        .navigationTitle(session.configuration.name)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                toolbarButtons
            }
        }
    }
    
    // MARK: - Toolbar
    
    @ViewBuilder
    private var toolbarButtons: some View {
        switch session.connectionState {
        case .connected:
            Button(action: { session.disconnect() }) {
                Label("Stop", systemImage: "stop.fill")
            }
            .help("Stop server")
        case .connecting:
            ProgressView()
                .controlSize(.small)
                .padding(.leading, 8)
            Button(action: { session.disconnect() }) {
                Label("Stop", systemImage: "stop.fill")
            }
            .help("Cancel connection")
        case .disconnected, .error:
            Button(action: { onEdit() }) {
                Label("Edit", systemImage: "pencil")
            }
            .help("Edit configuration")
            
            Button(action: { Task { await session.connect() } }) {
                Label("Start", systemImage: "play.fill")
            }
            .help("Start server")
        }
    }
    
    // MARK: - Disconnected View
    
    private var disconnectedView: some View {
        ScrollView {
            VStack(spacing: 24) {
                configurationCard
                
                Button(action: { Task { await session.connect() } }) {
                    Label("Start Server", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    // MARK: - Connecting View
    
    private var connectingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            
            Text("Connecting to \(session.configuration.name)...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Error View
    
    private func errorView(message: String) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                configurationCard
                
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Connection Error", systemImage: "exclamationmark.triangle.fill")
                            .font(.headline)
                            .foregroundColor(.red)
                        
                        Divider()
                        
                        Text(message)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(4)
                }
                
                HStack {
                    Button("Retry") {
                        Task { await session.connect() }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Edit Configuration") {
                        onEdit()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    // MARK: - Connected View (tabbed)
    
    private var connectedView: some View {
        VStack(spacing: 0) {
            tabBar
            
            Divider()
            
            tabContent
        }
    }
    
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(DetailTab.allCases) { tab in
                let badgeCount = badgeCount(for: tab)
                
                Button(action: { selectedTab = tab }) {
                    HStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.caption)
                        Text(tab.rawValue)
                            .font(.subheadline)
                        if badgeCount > 0 {
                            Text("\(badgeCount)")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(selectedTab == tab ? Color.white.opacity(0.3) : Color.secondary.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(selectedTab == tab ? Color.accentColor : Color.clear)
                    .foregroundColor(selectedTab == tab ? .white : .primary)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }
    
    private func badgeCount(for tab: DetailTab) -> Int {
        switch tab {
        case .overview: return 0
        case .tools: return session.tools.count
        case .prompts: return session.prompts.count
        case .resources: return session.resources.count
        case .logs: return session.logStore.entries.count
        }
    }
    
    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .overview:
            overviewTab
        case .tools:
            ToolsView(session: session)
        case .prompts:
            PromptsView(session: session)
        case .resources:
            ResourcesView(session: session)
        case .logs:
            LogView(session: session)
        }
    }
    
    // MARK: - Overview Tab
    
    private var overviewTab: some View {
        ScrollView {
            VStack(spacing: 24) {
                serverInfoCard
                capabilitiesCard
                
                if let instructions = session.serverInstructions, !instructions.isEmpty {
                    instructionsCard(instructions)
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    // MARK: - Configuration Card
    
    private var configurationCard: some View {
        DetailCard(title: "Configuration", icon: "gearshape") {
            infoRow(label: "Name", value: session.configuration.name)
            configurationDetails
        }
    }
    
    // MARK: - Server Info Card
    
    private var serverInfoCard: some View {
        DetailCard(title: "Server Information", icon: "info.circle") {
            if let serverInfo = session.serverInfo {
                infoRow(label: "Name", value: serverInfo.name)
                
                if let version = serverInfo.version {
                    infoRow(label: "Version", value: version)
                }
            }
            configurationDetails
        } trailing: {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 10, height: 10)
                Text("Connected")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.green.opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Configuration Details (shared rows)
    
    @ViewBuilder
    private var configurationDetails: some View {
        infoRow(label: "Command", value: session.configuration.command)
        
        if !session.configuration.arguments.isEmpty {
            infoRow(label: "Arguments", value: session.configuration.arguments.joined(separator: " "))
        }
        
        if !session.configuration.environmentVariables.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("Environment")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .leading)
                
                ForEach(Array(session.configuration.environmentVariables.keys.sorted()), id: \.self) { key in
                    if let value = session.configuration.environmentVariables[key] {
                        Text("\(key)=\(value)")
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }
    
    // MARK: - Capabilities Card
    
    private var capabilitiesCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label("Capabilities", systemImage: "checklist")
                    .font(.headline)
                
                Divider()
                
                HStack(spacing: 24) {
                    capabilityBadge(
                        name: "Tools",
                        count: session.tools.count,
                        icon: "wrench.and.screwdriver",
                        available: !session.tools.isEmpty
                    )
                    
                    capabilityBadge(
                        name: "Prompts",
                        count: session.prompts.count,
                        icon: "text.bubble",
                        available: !session.prompts.isEmpty
                    )
                    
                    capabilityBadge(
                        name: "Resources",
                        count: session.resources.count,
                        icon: "doc.text",
                        available: !session.resources.isEmpty
                    )
                }
            }
            .padding(4)
        }
    }
    
    // MARK: - Instructions Card
    
    private func instructionsCard(_ instructions: String) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Label("Instructions", systemImage: "doc.plaintext")
                    .font(.headline)
                
                Divider()
                
                Text(instructions)
                    .font(.subheadline)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)
            }
            .padding(4)
        }
    }
    
    // MARK: - Helpers
    
    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(.system(.subheadline, design: .monospaced))
                .textSelection(.enabled)
            
            Spacer()
        }
    }
    
    private func capabilityBadge(name: String, count: Int, icon: String, available: Bool) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(available ? .accentColor : .secondary)
            
            Text(name)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("\(count)")
                .font(.headline)
                .foregroundColor(available ? .primary : .secondary)
        }
        .frame(minWidth: 80)
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

private struct DetailCard<Content: View, Trailing: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    @ViewBuilder let trailing: Trailing
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.icon = icon
        self.content = content()
        self.trailing = trailing()
    }
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(title, systemImage: icon)
                        .font(.headline)
                    Spacer()
                    trailing
                }
                
                Divider()
                
                content
            }
            .padding(4)
        }
    }
}

#Preview {
    let session = ServerSession(configuration: .sample)
    return ServerDetailView(session: session, onEdit: {})
        .environmentObject(AppState())
}
