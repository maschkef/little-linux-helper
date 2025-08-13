# Little Linux Helper GUI

A modern web-based GUI for the Little Linux Helper system administration toolkit.

## Features

- **Multi-session management** - Run unlimited concurrent module sessions
- **Advanced session control** - Session dropdown with switching, status indicators, and individual session management
- **Flexible panel system** with hideable module list, terminal panels, help, and documentation areas
- **Panel toggle controls** - Hide/show modules sidebar, terminal panels, help, and docs independently
- **Full-screen reading mode** - Hide all panels except documentation for maximum reading space
- **Real-time terminal output** via WebSockets with session-aware output switching
- **Interactive module execution** with comprehensive input capabilities (Send, Any Key, Stop buttons)
- **Flexible module starting** - Individual "Start" buttons per module plus global "New Session" button
- **Session persistence** - Sessions remain accessible across browser windows and tabs
- **Built-in help system** with module-specific guidance
- **Enhanced documentation system** - Dual-mode documentation with module-bound and independent browser modes
- **Document browser** - Categorized navigation through all documentation with collapsible groups
- **Scrollable documentation interface** - Navigation sidebar can be hidden and scrolls smoothly
- **Configurable networking** - Port and host configuration with security-first defaults
- **Security features** - Localhost-only binding by default with optional network access
- **Responsive design** that works on different screen sizes
- **Preserves CLI functionality** - the original `help_master.sh` continues to work unchanged

## Architecture

- **Backend**: Go + Fiber web framework
- **Frontend**: React with modern JavaScript
- **Communication**: REST API + WebSockets for real-time updates
- **Documentation**: Automatic markdown rendering from `docs/` directory

## Prerequisites

- Go 1.18 or later
- Node.js 16 or later
- npm (comes with Node.js)

## Quick Start

1. **Setup** (run once):
   ```bash
   chmod +x setup.sh
   ./setup.sh
   ```

2. **Development** (starts both backend and frontend):
   ```bash
   chmod +x dev.sh
   ./dev.sh
   ```

3. **Production build**:
   ```bash
   chmod +x build.sh
   ./build.sh
   ./little-linux-helper-gui
   ```

## Development

### Backend Development
The Go backend serves the React build and provides API endpoints:

- `/api/modules` - List available modules
- `/api/modules/:id/docs` - Get module documentation
- `/api/docs` - List all available documentation files with metadata for document browser
- `/api/modules/:id/start` - Start a module session
- `/api/sessions` - List all active sessions
- `/api/sessions/:sessionId/input` - Send input to module
- `/api/sessions/:sessionId` - Stop module session
- `/ws` - WebSocket for real-time communication

### Frontend Development
The React frontend provides a modern interface with:

- **ModuleList**: Sidebar with categorized modules and individual "Start" buttons (hideable)
- **SessionDropdown**: Multi-session management with switching and status indicators
- **Terminal**: Real-time terminal output and input with session awareness (hideable)
- **TerminalInput**: Enhanced input handling with Send, Any Key, and Stop buttons
- **SessionContext**: React context for centralized session state management
- **HelpPanel**: Context-sensitive help for each module (hideable)
- **DocsPanel**: Module-bound markdown documentation viewer (hideable)
- **DocumentBrowser**: Independent documentation browser with categorized navigation and search
- **ResizablePanels**: Flexible panel layout with show/hide controls for all panels

### Project Structure

```
gui/
├── main.go              # Go backend server
├── go.mod              # Go dependencies
├── setup.sh            # Setup script
├── build.sh            # Production build script
├── dev.sh              # Development script
└── web/                # React frontend
    ├── package.json    # Node.js dependencies
    ├── public/         # Static files
    └── src/            # React source code
        ├── App.jsx     # Main application component with panel controls
        ├── index.jsx   # Entry point
        ├── index.css   # Global styles
        ├── components/ # React components
        │   ├── ModuleList.jsx         # Module sidebar (hideable)
        │   ├── Terminal.jsx           # Terminal output (hideable)
        │   ├── TerminalInput.jsx      # Terminal input controls
        │   ├── SessionDropdown.jsx    # Session management
        │   ├── HelpPanel.jsx          # Context help (hideable)
        │   ├── DocsPanel.jsx          # Module-bound docs (hideable)
        │   ├── DocumentBrowser.jsx    # Independent document browser
        │   └── ResizablePanels.jsx    # Panel layout management
        └── contexts/   # React contexts (SessionContext)
```

## Integration with Little Linux Helper

The GUI integrates seamlessly with the existing Little Linux Helper system:

1. **Module Discovery**: Automatically detects and lists all available modules
2. **Documentation Integration**: Reads module documentation from `docs/` directory
3. **Environment Preservation**: Maintains all environment variables and configuration
4. **CLI Compatibility**: Original CLI interface remains fully functional

## Usage

### Basic Workflow
1. **Select a Module**: Click on any module in the sidebar to select it (doesn't start a session)
2. **Start Sessions**: Use either:
   - Individual "Start" buttons that appear when hovering over modules
   - The "+ New Session" button (starts the currently selected module)
3. **Manage Sessions**: Use the session dropdown (top-right) to:
   - Switch between active sessions
   - View session status (running/stopped)
   - Close individual sessions (except the last one)
4. **Control Panel Layout**: Use the panel toggle buttons to:
   - **Hide Modules**: Hide sidebar to expand content area
   - **Hide Terminal**: Hide terminal panels for documentation focus
   - **Hide Help**: Hide help panel when not needed
   - **Show/Hide Docs**: Toggle documentation panel visibility
5. **Monitor Output**: Watch real-time output in the terminal panel (switches with active session)
6. **Send Input**: Use the terminal input area with:
   - **Text Input**: Type responses and click "Send" or press Enter
   - **Any Key**: Click for "press any key" prompts
   - **Stop**: Red button to immediately stop the current session
7. **View Help**: Context-sensitive help appears in the help panel
8. **Browse Documentation**: Choose between:
   - **Module-bound docs**: Traditional documentation tied to selected modules
   - **Document browser**: Independent browsing through all documentation with categories

### Multi-Session Features
- **Unlimited Sessions**: Run as many concurrent modules as needed
- **Session Persistence**: Sessions remain accessible when opening new browser windows
- **Output Preservation**: Each session maintains its own output history
- **Status Tracking**: Visual indicators show which sessions are running or stopped

### Documentation & Reading Features
- **Dual Documentation Modes**:
  - **Module-bound Mode**: Traditional docs that update based on selected module
  - **Document Browser Mode**: Independent browsing through all available documentation
- **Categorized Navigation**: Documents organized into logical groups (System Admin, Backup, Docker, etc.)
- **Collapsible Categories**: Expand/collapse document groups for better organization
- **Hideable Navigation**: Document browser sidebar can be hidden to maximize reading space
- **Scrollable Interface**: Long document lists scroll smoothly within navigation panel
- **Full-Screen Reading**: Hide all panels except documentation for distraction-free reading
- **Flexible Panel Layout**: All panels (modules, terminal, help, docs) can be hidden independently

## Configuration

The GUI respects all existing Little Linux Helper configuration:

- Module paths are automatically detected
- Environment variables are preserved
- Configuration files in `config/` are used
- Logging system integration
- Internationalization support (planned)

### GUI-Specific Configuration

The GUI can be configured via `config/general.conf`:

```bash
# GUI server port (default: 3000)
CFG_LH_GUI_PORT="3000"

# GUI server host binding (default: localhost for security)
# Options: "localhost" (secure) or "0.0.0.0" (network access)
CFG_LH_GUI_HOST="localhost"
```

### Command Line Options

**Via GUI Launcher (Recommended):**
```bash
# Default usage (localhost, auto-detected port)
./gui_launcher.sh

# Enable network access with shorthand
./gui_launcher.sh -n

# Custom port (both short and long forms)
./gui_launcher.sh -p 8080
./gui_launcher.sh --port 8080

# Combined options
./gui_launcher.sh -n -p 80

# Build and run with network access
./gui_launcher.sh -b -n

# Show comprehensive help
./gui_launcher.sh -h
```

**Direct Binary Execution:**
```bash
# Default usage (localhost:3000)
./little-linux-helper-gui

# Custom port (both short and long forms)
./little-linux-helper-gui -p 8080
./little-linux-helper-gui --port 8080

# Enable network access (both short and long forms)
./little-linux-helper-gui -n
./little-linux-helper-gui --network

# Combined options
./little-linux-helper-gui -n -p 80

# Show help (both short and long forms)
./little-linux-helper-gui -h
./little-linux-helper-gui --help
```

**Configuration Priority**: Command line arguments > config file > built-in defaults

## Security Notes

- **Secure by default**: GUI binds to localhost only, preventing network exposure
- **Network mode warnings**: Clear warnings displayed when network access is enabled
- **Firewall considerations**: Network mode requires proper firewall configuration
- **Same security context**: All module executions maintain the same privileges as CLI usage
- **WebSocket security**: Connections are restricted by host binding configuration
- **No sensitive data exposure**: No sensitive information is transmitted unnecessarily

## Troubleshooting

### Common Issues

1. **Port already in use**: 
   - Use `-p 8080` or `--port 8080` flag for a different port
   - Or configure `CFG_LH_GUI_PORT` in `config/general.conf`
2. **Go modules errors**: Run `go mod tidy` to resolve dependencies
3. **React build fails**: Ensure Node.js 16+ is installed
4. **Module not found**: Check that the Little Linux Helper root directory is correctly detected
5. **Sessions not working**: Ensure WebSocket connections are not blocked by firewall
6. **Network access issues**: Use `-n` or `--network` flag if access from other machines is needed

### Logs

- Backend logs are printed to the console
- Frontend development logs appear in the browser console
- Module output is streamed through the WebSocket connection

## Contributing

This GUI is designed to be extended easily:

1. **Add new modules**: They will be automatically detected and categorized
2. **Extend help content**: Update the help content in `HelpPanel.jsx`
3. **Improve documentation**: Add new docs to `docs/` directory - they'll appear in the document browser
4. **Enhance UI**: React components are modular and easy to modify
5. **Add panel features**: Extend panel controls in `App.jsx` and `ResizablePanels.jsx`
6. **Improve document browser**: Extend categories and features in `DocumentBrowser.jsx`
7. **Add API features**: The backend API can be extended for new functionality

## License

Same as Little Linux Helper - MIT License
