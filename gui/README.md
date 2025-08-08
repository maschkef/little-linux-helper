# Little Linux Helper GUI

A modern web-based GUI for the Little Linux Helper system administration toolkit.

## Features

- **Multi-panel interface** with module list, terminal output, help panel, and documentation viewer
- **Real-time terminal output** via WebSockets
- **Interactive module execution** with input capabilities
- **Built-in help system** with module-specific guidance
- **Markdown documentation viewer** for all modules
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
- `/api/sessions/:sessionId/input` - Send input to module
- `/api/sessions/:sessionId` - Stop module session
- `/ws` - WebSocket for real-time communication

### Frontend Development
The React frontend provides a modern interface with:

- **ModuleList**: Sidebar with categorized modules
- **Terminal**: Real-time terminal output and input
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
        └── components/ # React components
```

## Integration with Little Linux Helper

The GUI integrates seamlessly with the existing Little Linux Helper system:

1. **Module Discovery**: Automatically detects and lists all available modules
2. **Documentation Integration**: Reads module documentation from `docs/` directory
3. **Environment Preservation**: Maintains all environment variables and configuration
4. **CLI Compatibility**: Original CLI interface remains fully functional

## Usage

1. **Select a Module**: Click on any module in the sidebar to start it
2. **Monitor Output**: Watch real-time output in the terminal panel
3. **Send Input**: Type responses in the terminal input field
4. **View Help**: Context-sensitive help appears in the help panel
5. **Read Documentation**: Full module documentation is shown in the docs panel
6. **Stop Module**: Use the stop button to terminate a running module

## Configuration

The GUI respects all existing Little Linux Helper configuration:

- Module paths are automatically detected
- Environment variables are preserved
- Configuration files in `config/` are used
- Logging system integration
- Internationalization support (planned)

## Security Notes

- The GUI runs locally and does not expose external network access by default
- All module executions maintain the same security context as CLI usage
- WebSocket connections are local-only
- No sensitive data is transmitted over the network

## Troubleshooting

### Common Issues

1. **Port already in use**: Change the port in `main.go` if 3000 is occupied
2. **Go modules errors**: Run `go mod tidy` to resolve dependencies
3. **React build fails**: Ensure Node.js 16+ is installed
4. **Module not found**: Check that the Little Linux Helper root directory is correctly detected

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
