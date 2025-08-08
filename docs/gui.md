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
        *   `GET /api/modules/:id/docs` - Retrieve module documentation
        *   `POST /api/modules/:id/start` - Start module execution session
        *   `POST /api/sessions/:sessionId/input` - Send input to running module
        *   `DELETE /api/sessions/:sessionId` - Stop module session
        *   `WS /ws` - WebSocket for real-time communication
    *   **Dependencies (system):** `go`, `github.com/gofiber/fiber/v2`, `github.com/gofiber/websocket/v2`, `github.com/creack/pty`.

*   **Frontend Application (`web/`):**
    *   **Purpose:** Provides intuitive graphical interface with multi-panel layout for comprehensive module interaction.
    *   **Key Components:**
        *   `ModuleList.js` - Categorized sidebar navigation with module hierarchy
        *   `Terminal.js` - Real-time terminal output display with ANSI color support
        *   `TerminalInput.js` - Interactive input handling for module prompts
        *   `HelpPanel.js` - Context-sensitive help and module guidance
        *   `DocsPanel.js` - Integrated markdown documentation viewer
        *   `ResizablePanels.js` - Flexible panel layout management
    *   **Dependencies (system):** `node.js` (16+), `npm`, React ecosystem.

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
    *   Uses PTY for authentic terminal behavior with color support
    *   Handles interactive prompts and menu selections seamlessly

**5. Setup & Deployment:**

*   **Development Setup (`setup.sh`):**
    *   **Purpose:** Initializes the development environment with all required dependencies.
    *   **Mechanism:**
        *   Verifies Go installation (1.21+) and Node.js (16+)
        *   Installs Go dependencies via `go mod tidy`
        *   Installs React dependencies via `npm install`
        *   Builds production-ready frontend assets
    *   **Dependencies:** Go, Node.js, npm, internet connection for package downloads.

*   **Development Workflow (`dev.sh`):**
    *   **Purpose:** Starts development servers for both backend and frontend with hot-reload capabilities.
    *   **Mechanism:**
        *   Backend: `go run main.go` for API server
        *   Frontend: `npm start` for React development server
        *   Automatic browser launching to `http://localhost:3000`

*   **Production Build (`build.sh`):**
    *   **Purpose:** Creates optimized production build for deployment.
    *   **Mechanism:**
        *   Builds React application with production optimizations
        *   Compiles Go binary with embedded frontend assets
        *   Results in single executable `little-linux-helper-gui`

**6. User Interface Features:**

*   **Multi-Panel Layout:**
    *   Resizable panels for optimal screen space utilization
    *   Sidebar module navigation with search and filtering
    *   Main terminal area with real-time output display
    *   Integrated help panel with context-sensitive guidance
    *   Documentation viewer with markdown rendering

*   **Terminal Experience:**
    *   Full ANSI color support preserving CLI aesthetics
    *   Real-time output streaming without buffering delays
    *   Interactive input handling for all module prompts
    *   Session management for multiple concurrent modules
    *   Copy/paste functionality and text selection

*   **Module Help System:**
    *   Comprehensive help content for each module
    *   Available options and menu explanations
    *   Important notes and prerequisites
    *   Real-time updates based on selected module

**7. Special Considerations:**

*   **Security & Access Control:**
    *   Local-only operation (localhost binding) for security
    *   No external network exposure by default
    *   Maintains same security context as CLI operations
    *   WebSocket connections restricted to local clients

*   **Performance & Scalability:**
    *   Efficient WebSocket communication for minimal latency
    *   Buffered output management to handle high-volume logs
    *   Session cleanup and resource management
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

**8. Launcher Integration:**

*   **Standalone Launcher (`gui_launcher.sh`):**
    *   **Purpose:** Provides convenient entry point for GUI access from CLI environment.
    *   **Mechanism:**
        *   Checks for production build availability
        *   Falls back to development mode if needed
        *   Handles port availability and browser launching
        *   Provides status feedback and error handling

**9. Technical Specifications:**

*   **Network Configuration:**
    *   Default port: 3000 (configurable in source)
    *   Protocol: HTTP with WebSocket upgrade
    *   Binding: localhost only for security

*   **Process Management:**
    *   PTY integration for authentic terminal experience
    *   Session isolation for concurrent module execution
    *   Automatic cleanup on session termination
    *   Signal handling for graceful shutdown

*   **File System Integration:**
    *   Automatic detection of Little Linux Helper root directory
    *   Dynamic module discovery and documentation mapping
    *   Configuration file preservation and sharing
    *   Log file integration and monitoring

**10. Future Extensibility:**

*   **Module Compatibility:** Automatically supports new modules added to the system
*   **Documentation Integration:** New documentation files are automatically discovered and integrated
*   **Configuration Management:** Supports extension of configuration options through existing patterns
*   **UI Enhancement:** Modular React components allow for easy feature additions
*   **API Extension:** RESTful design permits additional endpoints for new functionality

---
*This document provides a comprehensive technical overview of the GUI interface system. The GUI maintains full compatibility with the existing Little Linux Helper CLI system while providing a modern, accessible web-based interface for all system administration functions.*