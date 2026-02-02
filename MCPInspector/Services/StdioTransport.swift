import Foundation

/// Manages communication with an MCP server over stdio (stdin/stdout)
actor StdioTransport {
    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    
    private var responseBuffer = Data()
    private var pendingRequests: [RequestID: CheckedContinuation<JSONRPCResponse, Error>] = [:]
    private var isRunning = false
    
    private let configuration: ServerConfiguration
    
    /// Callback for stderr output
    private let onStderr: (@Sendable (String) -> Void)?
    
    /// Collected stderr output for error reporting
    private var stderrBuffer: String = ""
    
    init(configuration: ServerConfiguration, onStderr: (@Sendable (String) -> Void)? = nil) {
        self.configuration = configuration
        self.onStderr = onStderr
    }
    
    /// Get collected stderr output
    func getStderrOutput() -> String {
        return stderrBuffer
    }
    
    /// Append to stderr buffer
    private func appendStderr(_ text: String) {
        stderrBuffer += text
        // Limit buffer size to prevent memory issues
        if stderrBuffer.count > 10000 {
            stderrBuffer = String(stderrBuffer.suffix(10000))
        }
    }
    
    // MARK: - Lifecycle
    
    func start() throws {
        guard !isRunning else { return }
        
        let process = Process()
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        
        // Resolve the command path
        let command = configuration.command
        
        // Set up process
        if command.hasPrefix("/") {
            // Absolute path
            process.executableURL = URL(fileURLWithPath: command)
            process.arguments = configuration.arguments
        } else {
            // Use shell to resolve PATH
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            let fullCommand = ([command] + configuration.arguments)
                .map { $0.contains(" ") ? "\"\($0)\"" : $0 }
                .joined(separator: " ")
            process.arguments = ["-l", "-c", fullCommand]
        }
        
        // Set environment variables
        var environment = ProcessInfo.processInfo.environment
        for (key, value) in configuration.environmentVariables {
            environment[key] = value
        }
        process.environment = environment
        
        // Set up pipes
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        
        // Handle process termination
        process.terminationHandler = { [weak self] proc in
            Task { [weak self] in
                await self?.handleTermination(exitCode: proc.terminationStatus)
            }
        }
        
        self.process = process
        self.stdinPipe = stdinPipe
        self.stdoutPipe = stdoutPipe
        self.stderrPipe = stderrPipe
        
        // Start reading stdout
        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            Task { [weak self] in
                await self?.handleStdoutData(data)
            }
        }
        
        // Capture stderr
        let stderrHandler = self.onStderr
        stderrPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let text = String(data: data, encoding: .utf8), !text.isEmpty {
                // Accumulate stderr for error reporting
                Task { [weak self] in
                    await self?.appendStderr(text)
                }
                // Call the stderr callback
                stderrHandler?(text)
            }
        }
        
        // Start process
        do {
            try process.run()
            isRunning = true
        } catch {
            throw MCPError.connectionFailed("Failed to start process: \(error.localizedDescription)")
        }
    }
    
    func stop() {
        isRunning = false
        
        // Cancel pending requests
        for (_, continuation) in pendingRequests {
            continuation.resume(throwing: MCPError.notConnected)
        }
        pendingRequests.removeAll()
        
        // Stop reading
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        
        // Terminate process
        if let process = process, process.isRunning {
            process.terminate()
        }
        
        process = nil
        stdinPipe = nil
        stdoutPipe = nil
        stderrPipe = nil
        responseBuffer = Data()
        stderrBuffer = ""
    }
    
    // MARK: - Communication
    
    func send(_ request: JSONRPCRequest) async throws -> JSONRPCResponse {
        guard isRunning, let stdinPipe = stdinPipe else {
            throw MCPError.notConnected
        }
        
        // Encode request
        let requestString = try JSONRPCCodec.encodeRequest(request)
        let messageData = (requestString + "\n").data(using: .utf8)!
        
        // Set up continuation for response
        return try await withCheckedThrowingContinuation { continuation in
            pendingRequests[request.id] = continuation
            
            // Write to stdin
            do {
                try stdinPipe.fileHandleForWriting.write(contentsOf: messageData)
            } catch {
                pendingRequests.removeValue(forKey: request.id)
                continuation.resume(throwing: MCPError.connectionFailed("Write failed: \(error.localizedDescription)"))
            }
        }
    }
    
    func sendNotification(_ notification: JSONRPCNotification) throws {
        guard isRunning, let stdinPipe = stdinPipe else {
            throw MCPError.notConnected
        }
        
        let data = try JSONRPCCodec.encode(notification)
        guard var messageString = String(data: data, encoding: .utf8) else {
            throw MCPError.encodingError("Failed to encode notification")
        }
        messageString += "\n"
        
        let messageData = messageString.data(using: .utf8)!
        try stdinPipe.fileHandleForWriting.write(contentsOf: messageData)
    }
    
    // MARK: - Response Handling
    
    private func handleStdoutData(_ data: Data) {
        responseBuffer.append(data)
        processBuffer()
    }
    
    private func processBuffer() {
        // Process line by line (newline-delimited JSON)
        while let newlineIndex = responseBuffer.firstIndex(of: UInt8(ascii: "\n")) {
            let lineData = responseBuffer[..<newlineIndex]
            responseBuffer = Data(responseBuffer[(newlineIndex + 1)...])
            
            guard !lineData.isEmpty else { continue }
            
            do {
                let response = try JSONRPCCodec.decodeResponse(from: Data(lineData))
                handleResponse(response)
            } catch {
                print("[MCP] Failed to decode response: \(error)")
                // Try to parse as notification or other message type
                if let text = String(data: Data(lineData), encoding: .utf8) {
                    print("[MCP] Raw message: \(text)")
                }
            }
        }
    }
    
    private func handleResponse(_ response: JSONRPCResponse) {
        guard let id = response.id else {
            // This is likely a notification from the server
            print("[MCP] Received notification or message without id")
            return
        }
        
        if let continuation = pendingRequests.removeValue(forKey: id) {
            continuation.resume(returning: response)
        } else {
            print("[MCP] Received response for unknown request id: \(id)")
        }
    }
    
    private func handleTermination(exitCode: Int32) {
        isRunning = false
        
        // Fail all pending requests with stderr context
        let stderrText = stderrBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        let error = MCPError.processTerminated(exitCode, stderr: stderrText.isEmpty ? nil : stderrText)
        for (_, continuation) in pendingRequests {
            continuation.resume(throwing: error)
        }
        pendingRequests.removeAll()
    }
}
