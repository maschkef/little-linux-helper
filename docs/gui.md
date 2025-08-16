<!--
File: docs/gui.md
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
-->

## GUI Interface: `gui/` - Web-Based Graphical Interface

**1. Purpose:**
The GUI provides a modern, web-based interface for the Little Linux Helper system administration toolkit. It transforms the command-line experience into an accessible graphical interface while preserving all functionality of the original modules. The GUI serves as an alternative entry point that maintains full compatibility with the existing CLI system.

**2. Architecture & Components:**
*   **Backend Technology:** Go server using Fiber web framework for high-performance HTTP and WebSocket handling.
*   **Frontend Technology:** React-based single-page application with modern JavaScript and responsive design.
*   **Communication Protocol:** RESTful API endpoints combined with WebSockets for real-time terminal output streaming.
*   **Process Management:** Advanced PTY (pseudo-terminal) integration for authentic terminal experience with color support and interactive input handling.
*   **Documentation Integration:** Automatic markdown rendering from the `docs/` directory with real-time display.

**3. Core Components:**

*   **Backend Server (`main.go`):**
    *   **Purpose:** Serves the React frontend and provides API endpoints for module execution and management.
    *   **Key Features:**
        *   Module discovery and execution via PTY processes
        *   Real-time output streaming through WebSockets
        *   Interactive input handling for module prompts
        *   Session management for concurrent module executions
        *   Documentation serving from `docs/` directory
    *   **API Endpoints:**
        *   `GET /api/modules` - List all available modules with metadata
    *   `GET /api/health` - Health/status info (uptime, active sessions)
        *   `GET /api/modules/:id/docs` - Retrieve module documentation (supports both main and related module docs)
        *   `GET /api/docs` - List all available documentation files with metadata for document browser
        *   `POST /api/modules/:id/start` - Start module execution session
        *   `GET /api/sessions` - List all active sessions with metadata
        *   `POST /api/sessions/:sessionId/input` - Send input to running module
        *   `DELETE /api/sessions/:sessionId` - Stop module session
        *   `WS /ws` - WebSocket for real-time communication
    *   **Dependencies (system):** `go`, `github.com/gofiber/fiber/v2`, `github.com/gofiber/websocket/v2`, `github.com/creack/pty`.

*   **Frontend Application (`web/`):**
    *   **Purpose:** Provides intuitive graphical interface with multi-panel layout for comprehensive module interaction.
    *   **Key Components:**
        *   `ModuleList.jsx` - Categorized sidebar navigation with module hierarchy and individual start buttons
        *   `Terminal.jsx` - Real-time terminal output display with ANSI color support and session management
        *   `TerminalInput.jsx` - Interactive input handling with "Send" and "Stop" buttons, click-to-focus functionality
        *   `SessionDropdown.jsx` - Multi-session management with session switching and status indicators
        *   `SessionContext.jsx` - React context for centralized session state management
        *   `HelpPanel.jsx` - Context-sensitive help with user-friendly descriptions and practical guidance
        *   `DocsPanel.jsx` - Module-bound documentation viewer with related documentation links and navigation
    *   `DocumentBrowser.jsx` - Independent documentation browser with categorized navigation
        *   `ResizablePanels.jsx` - Flexible panel layout management with hide/show panel controls
    *   **Dependencies (system):** `node.js` (18+), `npm`, React ecosystem.

**4. Module Integration & Discovery:**

*   **Automatic Module Detection:**
    *   Scans standard module directories (`modules/`, `modules/backup/`)
    *   Categorizes modules by type (System Diagnosis, Backup & Recovery, Docker & Containers, etc.)
    *   Supports hierarchical module relationships (parent/child modules)
    *   Dynamic documentation mapping to `docs/` files

*   **Module Categories:**
    *   **Recovery & Restarts:** Services and desktop restart utilities
    *   **System Diagnosis & Analysis:** System information, disk tools, log analysis
    *   **Maintenance & Security:** Package management, security checks, energy management
    *   **Docker & Containers:** Docker management, security, and setup modules
    *   **Backup & Recovery:** BTRFS, TAR, and RSYNC backup/restore operations

*   **Execution Environment:**
    *   Preserves all environment variables from the original CLI system
    *   Maintains `LH_ROOT_DIR` and other critical project variables
    *   Sets `LH_GUI_MODE=true` environment variable for GUI-aware module behavior
    *   Uses PTY for authentic terminal behavior with color support
    *   Handles interactive prompts and menu selections seamlessly
    *   Automatic "Any Key" prompt handling via module behavior when `LH_GUI_MODE=true`

**5. Setup & Deployment:**

*   **Development Setup (`setup.sh`):**
    *   **Purpose:** Initializes the development environment with all required dependencies.
    *   **Mechanism:**
    *   Verifies Go installation (1.18+; 1.21+ recommended) and Node.js (18+)
        *   Installs Go dependencies via `go mod tidy`
        *   Installs React dependencies via `npm install`
        *   Builds production-ready frontend assets
    *   **Dependencies:** Go, Node.js, npm, internet connection for package downloads.

*   **Development Workflow (`dev.sh`):**
    *   **Purpose:** Starts development servers for both backend and frontend with hot-reload capabilities.
    *   **Mechanism:**
    *   Backend: `go run main.go` for API server (listens on 3000)
    *   Frontend: Vite dev server on 3001 (proxies `/api` to 3000)

*   **Production Build (`build.sh`):**
    *   **Purpose:** Creates optimized production build for deployment.
    *   **Mechanism:**
        *   Builds React application with production optimizations
        *   Compiles Go binary with embedded frontend assets
        *   Results in single executable `little-linux-helper-gui`

**6. User Interface Features:**

*   **Multi-Panel Layout:**
    *   Resizable panels for optimal screen space utilization
    *   Sidebar module navigation with individual "Start" buttons (hideable for reading mode)
    *   Session dropdown for switching between multiple active sessions
    *   Main terminal area with real-time output display (hideable for documentation focus)
    *   Integrated help panel with user-friendly, context-sensitive guidance
    *   Advanced documentation system with both module-bound and independent browser modes
    *   **Panel Toggle Controls:** Hide/show modules sidebar, terminal panels, help, and docs for optimal screen usage
    *   **Full-Screen Reading Mode:** Hide all panels except documentation for maximum reading space

*   **Multi-Session Management:**
    *   Support for unlimited concurrent module sessions
    *   Session dropdown with status indicators (running/stopped)
    *   Session switching with output preservation
    *   Individual session control (start/stop/close)
    *   Session metadata (creation time, module name, status)
    *   Automatic session cleanup and resource management

*   **Terminal Experience:**
    *   Full ANSI color support preserving CLI aesthetics
    *   Real-time output streaming without buffering delays
    *   Interactive input handling for all module prompts
    *   Session-aware terminal with automatic output switching
    *   Copy/paste functionality and text selection
    *   Click-to-focus: clicking anywhere in terminal automatically focuses input field
    *   Automatic "Any Key" prompt handling - modules continue without user intervention
    *   Direct session control with integrated "Stop" button

*   **Advanced Documentation System:**
    *   **Module-Bound Mode:** Traditional documentation tied to selected modules with related doc links
    *   **Independent Document Browser:** Browse all documentation regardless of current module selection
    *   **Categorized Navigation:** Documents organized by logical groups (System Admin, Backup, Docker, etc.)
    *   **Collapsible Categories:** Expandable/collapsible document groups for better organization
    *   **Hideable Sidebar:** Document browser navigation can be hidden to maximize reading space
    *   **Scrollable Interface:** Long document lists scroll smoothly within navigation panel
    *   **Dual View Toggle:** Switch between module-bound and browser modes with on/off slider
    *   **Full Documentation Coverage:** Access to all project documentation from single interface

**7. Special Considerations:**

*   **Security & Access Control:**
    *   **Secure by default:** Localhost-only binding prevents network exposure
    *   **Configurable network access:** Optional `-network` flag for controlled network access
    *   **Port configuration:** Configurable via `config/general.conf` or command line
    *   **Security warnings:** Clear warnings when network mode is enabled
    *   **Same security context:** Maintains CLI-equivalent security permissions
    *   **WebSocket restrictions:** Connections limited by host binding configuration
    *   **CORS:** Disabled in production (same-origin). In development, the Vite dev server proxies `/api` to avoid cross-origin.

*   **Performance & Scalability:**
    *   Efficient WebSocket communication for minimal latency
    *   Buffered output management to handle high-volume logs
    *   **Multi-session resource management:** Isolated sessions with proper cleanup
    *   **Session state preservation:** Output history maintained per session
    *   **Concurrent execution:** Multiple modules can run simultaneously
    *   PTY size management for proper terminal formatting

*   **Compatibility & Integration:**
    *   Full backward compatibility with existing CLI system
    *   No modifications required to existing modules
    *   Preserves all environment variables and configurations
    *   Seamless switching between GUI and CLI workflows

*   **Error Handling & User Experience:**
    *   Graceful degradation when modules are unavailable
    *   Clear error messages and troubleshooting guidance
    *   Port conflict detection and resolution suggestions
    *   Comprehensive logging for debugging purposes
    *   Input request size limits on `/api/sessions/:sessionId/input` (413 on oversized payloads)

**8. Launcher Integration:**

*   **Standalone Launcher (`gui_launcher.sh`):**
    *   **Purpose:** Provides convenient entry point for GUI access from CLI environment with full configuration support.
    *   **Command Line Options:**
        *   `-b, --build` - Rebuild GUI before launching
        *   `-n, --network` - Enable network access (bind to 0.0.0.0)
        *   `-p, --port PORT` - Set custom port (overrides config file)
        *   `-h, --help` - Display comprehensive help information
    *   **Mechanism:**
        *   Checks for production build availability and builds if needed
        *   Passes all GUI-specific arguments to the binary
        *   Provides security warnings for network mode
        *   Handles dynamic messaging based on selected options
        *   Integrates with configuration file settings

**9. Technical Specifications:**

*   **Network Configuration:**
    *   **Default port:** 3000 (configurable via `config/general.conf` or `-p/--port` flag)
    *   **Default binding:** localhost (secure, configurable via `config/general.conf`)
    *   **Network access:** Available via `-n/--network` flag (binds to 0.0.0.0)
    *   **Protocol:** HTTP with WebSocket upgrade
    *   **Command line options:** `-p/--port`, `-n/--network`, `-h/--help`
    *   **Configuration priority:** Command line > config file > defaults

*   **Session Management:**
    *   **Multi-session architecture:** Support for unlimited concurrent sessions
    *   **Session metadata:** Creation time, module name, status tracking
    *   **PTY isolation:** Each session has its own pseudo-terminal
    *   **Output preservation:** Session output history maintained independently
    *   **Automatic cleanup:** Resources cleaned up on session termination
    *   **Session persistence:** Accessible across browser windows/tabs
    *   **Signal handling:** Graceful shutdown and session management

*   **File System Integration:**
    *   Automatic detection of Little Linux Helper root directory
    *   Dynamic module discovery and documentation mapping
    *   Configuration file preservation and sharing
    *   Log file integration and monitoring

**10. Configuration & Usage:**

*   **Configuration File (`config/general.conf`):**
    *   `CFG_LH_GUI_PORT="3000"` - Set default port for GUI server
    *   `CFG_LH_GUI_HOST="localhost"` - Set default host binding (localhost/0.0.0.0)
    *   Configuration automatically created from `config/general.conf.example`
    *   Settings can be overridden by command line arguments

*   **Command Line Usage:**

    **Via GUI Launcher (Recommended):**
    *   `./gui_launcher.sh` - Start with default settings (localhost, auto-detect port)
    *   `./gui_launcher.sh -p 8080` - Use custom port (short form)
    *   `./gui_launcher.sh --port 8080` - Use custom port (long form)
    *   `./gui_launcher.sh -n` - Enable network access (0.0.0.0 binding)
    *   `./gui_launcher.sh -n -p 80` - Network access on port 80
    *   `./gui_launcher.sh -b -n` - Build and run with network access
    *   `./gui_launcher.sh -h` - Show comprehensive help information

    **Direct Binary Execution:**
    *   `./little-linux-helper-gui` - Start with default settings (localhost:3000)
    *   `./little-linux-helper-gui -p 8080` - Use custom port (short form)
    *   `./little-linux-helper-gui --port 8080` - Use custom port (long form)
    *   `./little-linux-helper-gui -n` - Enable network access (short form)
    *   `./little-linux-helper-gui --network` - Enable network access (long form)
    *   `./little-linux-helper-gui -n -p 80` - Network access on port 80
    *   `./little-linux-helper-gui -h` - Show usage information (short form)
    *   `./little-linux-helper-gui --help` - Show usage information (long form)

    **CLI GUI Mode Testing:**
    *   `./help_master.sh` - Normal CLI mode with "Any Key" prompts
    *   `./help_master.sh -g` - CLI in GUI mode (short form) - skips "Any Key" prompts automatically
    *   `./help_master.sh --gui` - CLI in GUI mode (long form) - skips "Any Key" prompts automatically
    *   `./help_master.sh -h` - Show CLI help information (short form)
    *   `./help_master.sh --help` - Show CLI help information (long form)

*   **Multi-Session Workflow:**
    *   **Module Selection:** Click modules in sidebar to select (doesn't start session)
    *   **Starting Sessions:** Use "Start" buttons on modules or "+ New Session" button
    *   **Session Management:** Use session dropdown to switch between active sessions
    *   **Session Control:** Use "Stop" button in terminal or "×" in session dropdown
    *   **Session Persistence:** Sessions remain accessible in new browser windows

*   **Panel Control & Reading Modes:**
    *   **Hide Modules:** Click "Hide Modules" to hide sidebar and expand content area to full width
    *   **Hide Terminal:** Click "Hide Terminal" to hide all terminal panels for documentation focus
    *   **Full-Screen Reading:** Hide both modules and terminal panels for maximum documentation space
    *   **Document Browser:** Toggle between module-bound docs and independent document browser
    *   **Flexible Layout:** All panels can be shown/hidden independently for optimal workflow
    *   **Navigation Toggle:** Document browser navigation can be hidden to maximize reading area

*   **Security Considerations:**
    *   **Default secure:** GUI only accessible from localhost by default
    *   **Network mode warnings:** Clear warnings displayed when network access enabled
    *   **Firewall awareness:** Network mode requires proper firewall configuration
    *   **Same privileges:** GUI runs with same user permissions as CLI

**11. Version Management:**

*   **Version Tracking:** The GUI component version (`gui/web/package.json`) reflects significant GUI changes and improvements
*   **Current Version:** `0.2.0-beta` - reflects the recent GUI enhancements including document browser, panel controls, and HTML support
*   **Version Policy:** GUI version should be updated when:
    *   Main project version changes (major/minor releases)
    *   Significant GUI features are added or changed
    *   Breaking changes occur in GUI functionality
*   **Beta Status:** The `-beta` suffix indicates the GUI is under active development with evolving features
*   **Maintenance Responsibility:** Version numbers should be updated in both `package.json` and `package-lock.json` files
*   **Version Locations:**
    *   `gui/web/package.json` - Primary version declaration
    *   `gui/web/package-lock.json` - Lock file version (should match package.json)

**12. Future Extensibility:**

*   **Module Compatibility:** Automatically supports new modules added to the system
*   **Documentation Integration:** New documentation files are automatically discovered and integrated
*   **Configuration Management:** Supports extension of configuration options through existing patterns
*   **UI Enhancement:** Modular React components allow for easy feature additions
*   **API Extension:** RESTful design permits additional endpoints for new functionality

---
*This document provides a comprehensive technical overview of the GUI interface system. The GUI maintains full compatibility with the existing Little Linux Helper CLI system while providing a modern, accessible web-based interface for all system administration functions.*