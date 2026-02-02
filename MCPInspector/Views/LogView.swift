import SwiftUI
import UniformTypeIdentifiers

struct LogView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedEntry: LogEntry?
    @State private var filterDirection: LogEntry.Direction?
    @State private var filterText = ""
    @State private var showErrorsOnly = false
    
    private var filteredEntries: [LogEntry] {
        var entries = appState.logStore.entries
        
        if let direction = filterDirection {
            entries = entries.filter { $0.direction == direction }
        }
        
        if showErrorsOnly {
            entries = entries.filter { $0.isError }
        }
        
        if !filterText.isEmpty {
            entries = entries.filter {
                $0.method.localizedCaseInsensitiveContains(filterText) ||
                $0.content.localizedCaseInsensitiveContains(filterText)
            }
        }
        
        return entries.reversed() // Most recent first
    }
    
    var body: some View {
        HSplitView {
            // Log List
            logList
                .frame(minWidth: 300, maxWidth: 450)
            
            // Log Detail
            logDetail
                .frame(minWidth: 400)
        }
        .navigationTitle("Logs")
        .toolbar {
            ToolbarItemGroup {
                filterMenu
                
                Button(action: saveLogs) {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .disabled(appState.logStore.entries.isEmpty)
                
                Button(action: { appState.logStore.clear() }) {
                    Label("Clear", systemImage: "trash")
                }
                .disabled(appState.logStore.entries.isEmpty)
            }
        }
    }
    
    // MARK: - Log List
    
    private var logList: some View {
        VStack(spacing: 0) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Filter logs...", text: $filterText)
                    .textFieldStyle(.plain)
                
                if !filterText.isEmpty {
                    Button(action: { filterText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1))
            
            Divider()
            
            if filteredEntries.isEmpty {
                emptyState
            } else {
                List(selection: $selectedEntry) {
                    ForEach(filteredEntries) { entry in
                        LogEntryRow(entry: entry)
                            .tag(entry)
                    }
                }
                .listStyle(.inset)
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            
            if appState.logStore.entries.isEmpty {
                Text("No logs yet")
                    .foregroundColor(.secondary)
                
                Text("Connect to a server and perform actions to see logs here.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("No matching logs")
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Log Detail
    
    @ViewBuilder
    private var logDetail: some View {
        if let entry = selectedEntry {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack {
                        directionBadge(entry.direction)
                        
                        Text(entry.method)
                            .font(.headline)
                        
                        if entry.isError {
                            Label("Error", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        
                        Spacer()
                        
                        Text(entry.formattedTimestamp)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    // Content
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Content")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Button(action: { copyToClipboard(entry.content) }) {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                            .buttonStyle(.borderless)
                            .font(.caption)
                        }
                        
                        jsonContentView(entry.content)
                    }
                }
                .padding()
            }
        } else {
            VStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                
                Text("Select a log entry")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private func jsonContentView(_ content: String) -> some View {
        ScrollView([.horizontal, .vertical], showsIndicators: true) {
            Text(content)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .padding(12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
    
    // MARK: - Filter Menu
    
    private var filterMenu: some View {
        Menu {
            Button(action: { filterDirection = nil }) {
                Label("All Messages", systemImage: filterDirection == nil ? "checkmark" : "")
            }
            
            Divider()
            
            Button(action: { filterDirection = .outgoing }) {
                Label("Requests Only", systemImage: filterDirection == .outgoing ? "checkmark" : "")
            }
            
            Button(action: { filterDirection = .incoming }) {
                Label("Responses Only", systemImage: filterDirection == .incoming ? "checkmark" : "")
            }
            
            Button(action: { filterDirection = .stderr }) {
                Label("stderr Only", systemImage: filterDirection == .stderr ? "checkmark" : "")
            }
            
            Divider()
            
            Toggle("Errors Only", isOn: $showErrorsOnly)
        } label: {
            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
        }
    }
    
    // MARK: - Helper Views
    
    private func directionBadge(_ direction: LogEntry.Direction) -> some View {
        HStack(spacing: 4) {
            Text(direction.symbol)
            Text(direction.label)
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(directionColor(direction).opacity(0.2))
        .foregroundColor(directionColor(direction))
        .cornerRadius(4)
    }
    
    private func directionColor(_ direction: LogEntry.Direction) -> Color {
        switch direction {
        case .outgoing: return .blue
        case .incoming: return .green
        case .stderr: return .orange
        }
    }
    
    // MARK: - Actions
    
    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
    
    private func saveLogs() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "mcp-logs-\(formattedDateForFilename()).json"
        savePanel.title = "Save Logs"
        savePanel.message = "Choose a location to save the logs as JSON"
        
        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }
            
            do {
                let data = try appState.logStore.exportToJSON()
                try data.write(to: url)
            } catch {
                // Show error alert
                let alert = NSAlert()
                alert.messageText = "Failed to Save Logs"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.runModal()
            }
        }
    }
    
    private func formattedDateForFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: Date())
    }
}

// MARK: - Log Entry Row

struct LogEntryRow: View {
    let entry: LogEntry
    
    private var directionColor: Color {
        switch entry.direction {
        case .outgoing: return .blue
        case .incoming: return .green
        case .stderr: return .orange
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Direction indicator
            Text(entry.direction.symbol)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(directionColor)
                .frame(width: 16)
            
            // Timestamp
            Text(entry.formattedTimestamp)
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            // Method
            Text(entry.method)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.medium)
                .lineLimit(1)
            
            Spacer()
            
            // Error indicator
            if entry.isError {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    LogView()
        .environmentObject(AppState())
}
