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

- macOS 26.0 (Sonoma) or later
- Xcode 26.0 or later

### Build Steps

1. Clone the repository:
   ```bash
   git clone https://github.com/subpop/MCPInspector.git
   cd MCPInspector
   ```

2. Open the project in Xcode:
   ```bash
   open "MCP Inspector.xcodeproj"
   ```

3. Select your development team in the project settings (Signing & Capabilities)

4. Build and run with **⌘R** or **Product → Run**

## Usage

### Adding a Server

1. Click the **+** button in the sidebar toolbar
2. Enter a name, the command to run, any arguments, and optional environment variables
3. Click **Add**

Example configuration for the MCP "everything" test server:
- **Name:** Everything Server
- **Command:** `npx`
- **Arguments:** `-y @modelcontextprotocol/server-everything`

You can also right-click a server in the sidebar to edit or delete it.

### Starting a Server

1. Select a server from the sidebar
2. Click the **Start** (play) button in the toolbar, or click **Start Server** in the detail view

Once connected, the detail view shows the server name, version, and available capabilities in the **Overview** tab. Multiple servers can run simultaneously — the bottom of the sidebar shows a count of running servers.

To stop a server, click the **Stop** button in the toolbar or right-click the server in the sidebar and choose **Stop**.

### Inspecting Tools, Prompts, and Resources

Once a server is running, use the tab bar at the top of the detail view to switch between **Tools**, **Prompts**, **Resources**, and **Logs**. Each tab shows a badge with the number of available items.

### Calling a Tool

1. Switch to the **Tools** tab
2. Select a tool from the list (use the filter field to search)
3. Click **Call Tool**
4. Fill in the parameters using the form or switch to **Raw JSON** mode
5. Click **Execute** to invoke the tool and view the result

### Viewing Logs

The **Logs** tab shows all JSON-RPC traffic between the app and the server. Use the filter menu to show only requests, responses, or stderr output. You can search logs by method name or content and export them to a JSON file for further analysis.

## License

MIT

---

Made with ❤️. Fueled by ☕️ and 🤖.
