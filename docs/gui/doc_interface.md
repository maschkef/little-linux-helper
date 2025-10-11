<!--
File: docs/gui/doc_interface.md
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
        *   **Internationalization support:** Dynamic language inheritance from GUI to CLI modules
    *   **API Endpoints:**
        *   `GET /api/modules` - List all available modules with metadata
    *   `GET /api/health` - Health/status info (uptime, active sessions)
        *   `GET /api/modules/:id/docs` - Retrieve module documentation (supports both main and related module docs)
        *   `GET /api/docs` - List all available documentation files with metadata for document browser
        *   `POST /api/modules/:id/start` - Start module execution session (accepts language parameter for dynamic i18n)
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
        *   `SessionContext.jsx` - React context for centralized session state management with language inheritance
        *   `HelpPanel.jsx` - Context-sensitive help with comprehensive module guidance, practical usage notes, and error-resilient translation handling
        *   `DocsPanel.jsx` - Module-bound documentation viewer with related documentation links and navigation
    *   `DocumentBrowser.jsx` - Independent documentation browser with categorized navigation
        *   `ResizablePanels.jsx` - Flexible panel layout management with hide/show panel controls
        *   `LanguageSelector.jsx` - Language selection component with real-time switching
        *   `ExitButton.jsx` - Application exit component with session-aware confirmation and graceful shutdown
    *   **Dependencies (system):** `node.js` (18+), `npm`, React ecosystem, React i18next.
    *   **Internationalization Features:**
        *   Full multi-language support with React i18next framework
        *   Language selector with flag emojis for English and German
        *   Browser language detection with localStorage persistence
        *   Dynamic language inheritance: new modules automatically use selected GUI language
        *   Comprehensive translations for all UI elements, module names, descriptions, and categories
        *   **Robust error handling:** Missing translation keys show fallback text with console warnings instead of crashes
        *   **Safe translation system:** Graceful degradation when translation resources are unavailable
        *   **Debug logging:** Development mode provides detailed translation debugging information

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
    *   **Backup & Recovery:** BTRFS, TAR, and RSYNC backup/restore operations with comprehensive help documentation

*   **Enhanced Error Handling & Stability:**
    *   **Translation Error Recovery:** Missing translation keys display fallback content instead of causing application crashes
    *   **Help System Resilience:** Missing help content shows placeholder text with clear error messages
    *   **Console Debugging:** Comprehensive logging of missing translations and errors for development debugging
    *   **Graceful Degradation:** Application remains functional even with incomplete translation resources

*   **Execution Environment:**
    *   Preserves all environment variables from the original CLI system
    *   Maintains `LH_ROOT_DIR` and other critical project variables
    *   Sets `LH_GUI_MODE=true` environment variable for GUI-aware module behavior
    *   **Dynamic language setting:** Sets `LH_LANG` environment variable based on GUI language selection
    *   Uses PTY for authentic terminal behavior with color support
    *   Handles interactive prompts and menu selections seamlessly
    *   Automatic "Any Key" prompt handling via module behavior when `LH_GUI_MODE=true`

**5. Setup & Deployment:**

*   **Development Setup (`setup.sh`):**
    *   **Purpose:** Initializes the development environment with all required dependencies.
    *   **Mechanism:**
    *   **Automatic Dependency Management:** Checks for Go (1.18+; 1.21+ recommended) and Node.js (18+) using integrated Little Linux Helper libraries; attempts installation via detected package manager if missing
        *   **Comprehensive Error Reporting:** Lists all missing tools (e.g., both Go and Node.js) in a single message rather than failing on the first missing dependency
        *   Installs Go dependencies via `go mod tidy`
        *   Installs React dependencies via `npm install`
        *   Builds production-ready frontend assets
    *   **Dependencies:** Go, Node.js, npm automatically managed; internet connection for package downloads.

*   **Development Workflow (`dev.sh`):**
    *   **Purpose:** Starts development servers for both backend and frontend with hot-reload capabilities.
    *   **Mechanism:**
    *   **Dependency Validation:** Performs automatic dependency checking before startup; installs missing components if needed
    *   Backend: `go run main.go` for API server (listens on 3000)
    *   Frontend: Vite dev server on 3001 (proxies `/api` to 3000)

*   **Production Build (`build.sh`):**
    *   **Purpose:** Creates optimized production build for deployment.
    *   **Mechanism:**
        *   **Pre-Build Validation:** Ensures all required tools (Go, Node.js, npm) are available before building
        *   Builds React application with production optimizations
        *   Compiles Go binary with embedded frontend assets
        *   Results in single executable `gui/little-linux-helper-gui`

**6. User Interface Features:**

*   **Multi-Panel Layout:**
    *   **Header Layout:** Three-section design with dev controls (left), app title/logo (center), and language selector (right)
    *   **Developer Controls:** 🔧 Dev Mode toggle in top-left for showing/hiding advanced documentation features
    *   Resizable panels for optimal screen space utilization
    *   Sidebar module navigation with individual "Start" buttons (hideable for reading mode)
    *   Session dropdown for switching between multiple active sessions
    *   Main terminal area with real-time output display (hideable for documentation focus)
    *   Integrated help panel with user-friendly, context-sensitive guidance (only visible when terminal panels are shown)
    *   Advanced documentation system with both module-bound and independent browser modes (hidden by default)
    *   **Grouped Control Layout:** Documentation controls grouped together when dev mode is enabled, separated from layout controls
    *   **Smart Help Button Display:** Help button only appears when terminal panels are visible, reducing UI clutter in documentation-only mode
    *   **Full-Screen Reading Mode:** Hide all panels except documentation for maximum reading space
    *   **Language Selection:** Integrated language selector with flag emojis for immediate language switching

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
    *   **Smart Documentation Tracking:** Documentation panel intelligently follows user's last action (module selection vs. session switching)

*   **Advanced Documentation System:**
    *   **📖 Module Docs:** Context-sensitive documentation tied to the currently selected or active module with intelligent source tracking
    *   **📚 All Documentation:** Browse all project documentation regardless of current module selection
    *   **Developer Controls Toggle:** 🔧 Dev Mode checkbox in top-left header to show/hide documentation controls (hidden by default)
    *   **Smart Documentation Logic:** Prioritizes user's last interaction - respects manual module selection over automatic session switching
    *   **Visual Status Indicators:** Colored dot on Module Docs button shows documentation source (green for active session, blue for selected module)
    *   **Persistent Settings:** Dev mode preference saved in browser localStorage for consistency across sessions
    *   **Auto-cleanup:** Documentation panels automatically close when dev mode is disabled
    *   **Categorized Navigation:** Documents organized by logical groups (System Admin, Backup, Docker, etc.)
    *   **Collapsible Categories:** Expandable/collapsible document groups for better organization
    *   **Hideable Sidebar:** Document browser navigation can be hidden to maximize reading space
    *   **Scrollable Interface:** Long document lists scroll smoothly within navigation panel
    *   **Clean User Experience:** Debug information removed from interface for cleaner presentation
    *   **Full Documentation Coverage:** Access to all project documentation from single interface

*   **Internationalization (i18n) Features:**
    *   **Multi-Language Support:** English and German translations with framework for additional languages
    *   **Dynamic Language Switching:** Real-time language changes without page reload
    *   **Language Inheritance:** New module sessions automatically inherit GUI language selection
    *   **Comprehensive Translation Coverage:**
        *   All GUI interface elements and navigation
        *   Module names, descriptions, and categories
        *   Help content and documentation elements
        *   Session management and status messages
    *   **Language Persistence:** Language selection saved in browser localStorage
    *   **Browser Language Detection:** Automatic language detection from browser settings
    *   **Graceful Fallbacks:** Missing translations fall back to English
    *   **Flag Emojis:** Visual language indicators (🇺🇸 English, 🇩🇪 German)
    *   **CLI Integration:** GUI language setting passed to CLI modules via LH_LANG environment variable

**7. Special Considerations:**

*   **Security & Access Control:**
    *   **Secure by default:** Localhost-only binding prevents network exposure
    *   **Configurable network access:** Optional `-network` flag for controlled network access (direct binary) or `-n/--network` when using the launcher
    *   **Firewall assistance via launcher:** `gui_launcher.sh -f/--open-firewall` can add temporary rules for ufw/firewalld/iptables when network mode is enabled
    *   **Port configuration:** Configurable via `config/general.conf` or command line
    *   **Security warnings:** Launcher prints explicit warnings when network mode is enabled (especially with sudo)
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
    *   Run from the project root: `./gui_launcher.sh` - Start with default settings (localhost, auto-detect port)
    *   `./gui_launcher.sh -p 8080` / `--port 8080` - Use custom port
    *   `./gui_launcher.sh -n` - Enable network access (0.0.0.0 binding)
    *   `./gui_launcher.sh -n -p 80 -f` - Network access on port 80 and add a firewall rule for that session
    *   `./gui_launcher.sh -b -n` - Build and run with network access
    *   `./gui_launcher.sh -h` - Show comprehensive help information

    **Direct Binary Execution (Advanced Users):**
    *   `./gui/little-linux-helper-gui` - Start with default settings (localhost:3000)
    *   `./gui/little-linux-helper-gui -p 8080` / `--port 8080` - Use custom port
    *   `./gui/little-linux-helper-gui -n` / `--network` - Enable network access
    *   `./gui/little-linux-helper-gui -h` / `--help` - Show usage information
    *   (Firewall helpers are not built into the binary—use the launcher if you need automated rules)

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
    *   **Optimized Button Layout:** Documentation controls positioned on left for accessibility, layout controls on right
    *   **Smart Help Button:** Help panel toggle only visible when terminal panels are active, reducing UI clutter
    *   **Developer Docs Button:** Shows module-specific documentation with intelligent source tracking and clear tooltips
    *   **Comprehensive Documentation Button:** Opens full project documentation browser with 📚 icon for clarity
    *   **Visual Feedback:** Clear indicators showing documentation source ("from selected module" vs "from active session")
    *   **Hide Modules:** Click "Hide Modules" to hide sidebar and expand content area to full width
    *   **Hide Terminal:** Click "Hide Terminal" to hide all terminal panels for documentation focus
    *   **Full-Screen Reading:** Hide both modules and terminal panels for maximum documentation space
    *   **Document Browser:** Toggle between module-bound docs and independent document browser
    *   **Flexible Layout:** All panels can be shown/hidden independently for optimal workflow
    *   **Navigation Toggle:** Document browser navigation can be hidden to maximize reading area

*   **Security Considerations:**
    *   **Default secure:** GUI only accessible from localhost by default
    *   **Network mode warnings:** Clear warnings displayed when network access enabled
    *   **Launcher-managed firewall rules:** Optional firewall port opening/closing with cleanup on exit when `gui_launcher.sh -f` is used
    *   **Same privileges:** GUI runs with same user permissions as CLI

**11. Help System & Error Resilience:**

*   **Comprehensive Help Content:**
    *   **Complete Coverage:** Help documentation for all module categories including backup, system tools, Docker, and security
    *   **Structured Information:** Each module help includes overview, available options, and important usage notes
    *   **Practical Guidance:** User-friendly descriptions with step-by-step option explanations
    *   **Safety Notes:** Important warnings and considerations for each module type

*   **Multi-Language Help:**
    *   **Full Translation:** Help content available in English and German
    *   **Consistent Structure:** Same help structure across all supported languages
    *   **Cultural Adaptation:** Terminology and explanations adapted for language-specific audiences

*   **Error Handling & Stability:**
    *   **Translation Error Recovery:** Missing translation keys display fallback text instead of crashing the application
    *   **Console Debugging:** Missing translations logged with detailed information for developers
    *   **Graceful Degradation:** Application remains fully functional even with incomplete translation resources
    *   **Help Content Fallbacks:** Missing help content shows clear placeholder messages
    *   **Safe Translation Functions:** Protected translation calls prevent React crashes from i18n errors
    *   **Development Logging:** Comprehensive error tracking for translation issues in development mode

*   **Help Content Coverage:**
    *   **Backup Modules:** BTRFS backup/restore operations with snapshot management details
    *   **System Modules:** System information, disk tools, log analysis, and restart utilities
    *   **Maintenance Tools:** Package management, security audits, and energy optimization
    *   **Docker Integration:** Container management, security analysis, and setup procedures
    *   **Usage Guidelines:** Best practices, prerequisites, and safety considerations for each tool

**12. Enhanced Documentation & User Interface System:**

*   **Intelligent Documentation Source Tracking:**
    *   **Last Action Memory:** System remembers whether user last clicked a module or switched terminal sessions
    *   **Priority Logic:** Respects user's explicit choices over automatic session switching
    *   **Visual Feedback:** Clear status indicators showing documentation source with color coding
    *   **Persistent Choices:** Documentation selection remains stable until user makes a different choice

*   **Two-Tiered Documentation System:**
    *   **Developer Docs (Module-Specific):**
        *   Shows documentation for currently active or selected module
        *   Follows user's last interaction (module click vs. session switch)
        *   Clear tooltip: "Show/hide developer documentation for the active module"
        *   Contextual help tied to actual workflow
    *   **Comprehensive Documentation (Project-Wide):**
        *   Independent browser for all project documentation
        *   Clear 📚 icon and descriptive label
        *   Tooltip: "Browse all project documentation and developer guides"
        *   Not tied to current module selection

*   **Optimized Button Layout & UX:**
    *   **Left-Side Positioning:** Documentation buttons moved to top-left for better accessibility
    *   **Right-Side Controls:** Layout and panel toggles positioned on right side
    *   **Visual Separation:** Clear divider between documentation and layout controls
    *   **Conditional Display:** Help button only shown when terminal panels are visible
    *   **Intuitive Labeling:** "Developer Docs" and "Comprehensive Documentation" replace ambiguous "Docs" labels

*   **Status Display Enhancements:**
    *   **Source Indicators:** Shows whether docs are "from selected module" or "from active session"
    *   **Color Coding:** Blue for module selection, green for session-based docs
    *   **Real-Time Updates:** Status updates immediately when source changes
    *   **Clear Messaging:** Eliminates confusion about which module's documentation is displayed

*   **User Interaction Scenarios:**
    *   **Module-First Workflow:** Click module → documentation stays on that module regardless of session switches
    *   **Session-First Workflow:** Switch session → documentation follows active session until module clicked
    *   **Mixed Workflow:** System intelligently maintains last explicit user choice
    *   **Visual Confirmation:** Always clear which source is providing current documentation

**13. Version Management:**

*   **Version Tracking:** The GUI component version (`gui/web/package.json`) reflects significant GUI changes and improvements
*   **Current Version:** `0.3.0-beta`
*   **Recent Improvements (v0.3.0-beta):**
    *   Smart documentation source tracking with last-action memory
    *   Optimized button layout with left-positioned documentation controls
    *   Conditional Help button display for reduced UI clutter
    *   Enhanced status indicators with visual source feedback
    *   Improved button labeling for better user clarity
    *   Intelligent documentation persistence across user interactions
*   **Version Policy:** GUI version should be updated when:
    *   Main project version changes (major/minor releases)
    *   Significant GUI features are added or changed
    *   Breaking changes occur in GUI functionality
*   **Beta Status:** The `-beta` suffix indicates the GUI is under active development with evolving features
*   **Maintenance Responsibility:** Version numbers should be updated in both `package.json` and `package-lock.json` files
*   **Version Locations:**
    *   `gui/web/package.json` - Primary version declaration
    *   `gui/web/package-lock.json` - Lock file version (should match package.json)

**14. Future Extensibility:**

*   **Module Compatibility:** Automatically supports new modules added to the system
*   **Documentation Integration:** New documentation files are automatically discovered and integrated
*   **Configuration Management:** Supports extension of configuration options through existing patterns
*   **UI Enhancement:** Modular React components allow for easy feature additions
*   **API Extension:** RESTful design permits additional endpoints for new functionality

---
*This document provides a comprehensive technical overview of the GUI interface system. The GUI maintains full compatibility with the existing Little Linux Helper CLI system while providing a modern, accessible web-based interface for all system administration functions.*
