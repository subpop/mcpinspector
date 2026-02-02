# MCP Inspector

A native macOS application for inspecting and debugging [Model Context Protocol (MCP)](https://modelcontextprotocol.io) servers.

## Features

- **Server Management** — Configure multiple MCP servers with custom commands, arguments, and environment variables
- **Connection Status** — Real-time connection status with server information and capabilities overview
- **Tools Browser** — View all available tools, their input schemas, and invoke them directly with a form-based UI or raw JSON
- **Prompts Browser** — Explore prompts exposed by the server and their arguments
- **Resources Browser** — Browse resources with URI and MIME type information
- **JSON-RPC Logs** — Full visibility into all messages sent and received, with filtering by direction (requests/responses/stderr) and search
- **Log Export** — Save logs to JSON for offline analysis

## Installation

MCP Inspector is currently available by compiling from source.

### Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later

### Build Steps

1. Clone the repository:
   ```bash
   git clone https://github.com/subpop/MCPInspector.git
   cd MCPInspector
   ```

2. Open the project in Xcode:
   ```bash
   open MCPInspector.xcodeproj
   ```

3. Select your development team in the project settings (Signing & Capabilities)

4. Build and run with **⌘R** or **Product → Run**

## Usage

### Adding a Server

1. Open the **Servers** section from the sidebar
2. Click the **+** button to add a new server configuration
3. Enter a name, the command to run, any arguments, and optional environment variables
4. Click **Add**

Example configuration for the MCP "everything" test server:
- **Name:** Everything Server
- **Command:** `npx`
- **Arguments:** `-y @modelcontextprotocol/server-everything`

### Connecting

1. Go to the **Connection** section
2. Select a configured server from the dropdown
3. Click **Connect**

Once connected, the app displays the server name, version, and available capabilities.

### Inspecting Tools, Prompts, and Resources

After connecting, navigate to **Tools**, **Prompts**, or **Resources** in the sidebar to browse what the server exposes. Select any item to view its details.

### Calling a Tool

1. Select a tool from the **Tools** list
2. Click **Call Tool**
3. Fill in the parameters using the form or switch to **Raw JSON** mode
4. Click **Execute** to invoke the tool and view the result

### Viewing Logs

The **Logs** section shows all JSON-RPC traffic between the app and the server. Use the filter menu to show only requests, responses, or stderr output. You can search logs by method name or content and export them to a JSON file for further analysis.

## License

MIT

---

Made with ❤️. Fueled by ☕️ and 🤖.
