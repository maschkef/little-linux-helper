# Little Linux Helper GUI

A modern web-based GUI for the Little Linux Helper system administration toolkit.

## Features

- **Multi-session management** - Run unlimited concurrent module sessions
- **Advanced session control** - Session dropdown with switching, status indicators, and individual session management
- **Multi-panel interface** with module list, terminal output, help panel, and documentation viewer
- **Real-time terminal output** via WebSockets with session-aware output switching
- **Interactive module execution** with comprehensive input capabilities (Send, Any Key, Stop buttons)
- **Flexible module starting** - Individual "Start" buttons per module plus global "New Session" button
- **Session persistence** - Sessions remain accessible across browser windows and tabs
- **Built-in help system** with module-specific guidance
- **Markdown documentation viewer** for all modules
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

- Go 1.21 or later
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
- `/api/modules/:id/start` - Start a module session
- `/api/sessions` - List all active sessions
- `/api/sessions/:sessionId/input` - Send input to module
- `/api/sessions/:sessionId` - Stop module session
- `/ws` - WebSocket for real-time communication

### Frontend Development
The React frontend provides a modern interface with:

- **ModuleList**: Sidebar with categorized modules and individual "Start" buttons
- **SessionDropdown**: Multi-session management with switching and status indicators
- **Terminal**: Real-time terminal output and input with session awareness
- **TerminalInput**: Enhanced input handling with Send, Any Key, and Stop buttons
- **SessionContext**: React context for centralized session state management
- **HelpPanel**: Context-sensitive help for each module
- **DocsPanel**: Markdown documentation viewer

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
        ├── App.js      # Main application component
        ├── index.js    # Entry point
        ├── index.css   # Global styles
        ├── components/ # React components
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
4. **Monitor Output**: Watch real-time output in the terminal panel (switches with active session)
5. **Send Input**: Use the terminal input area with:
   - **Text Input**: Type responses and click "Send" or press Enter
   - **Any Key**: Click for "press any key" prompts
   - **Stop**: Red button to immediately stop the current session
6. **View Help**: Context-sensitive help appears in the help panel
7. **Read Documentation**: Full module documentation is shown in the docs panel

### Multi-Session Features
- **Unlimited Sessions**: Run as many concurrent modules as needed
- **Session Persistence**: Sessions remain accessible when opening new browser windows
- **Output Preservation**: Each session maintains its own output history
- **Status Tracking**: Visual indicators show which sessions are running or stopped

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

1. **Add new modules**: They will be automatically detected
2. **Extend help content**: Update the help content in `HelpPanel.js`
3. **Improve UI**: React components are modular and easy to modify
4. **Add features**: The API can be extended for new functionality

## License

Same as Little Linux Helper - MIT License
