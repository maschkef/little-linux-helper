<!--
File: docs/GUI_DEVELOPER_GUIDE.md
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
-->

# Little Linux Helper - GUI Developer Guide

This document provides a comprehensive guide for developers to understand and work with the Little Linux Helper GUI system. It focuses on practical information needed to create, modify, or integrate modules with the web-based GUI interface.

**This Guide Contains**: GUI architecture overview, frontend/backend development patterns, module integration guidelines, translation system usage, and common development workflows. Use this when you want to understand how the GUI works or need to extend it with new functionality.

## Project Description: GUI System Overview

The Little Linux Helper GUI is a modern web-based interface that provides graphical access to all CLI functionality while maintaining full compatibility with the existing system. It consists of a Go backend server that manages module execution and a React frontend that provides an intuitive user interface.

The GUI automatically discovers and integrates CLI modules without requiring modifications to existing code. New modules added to the CLI system are immediately available in the GUI with full functionality.

### 1. Architecture Overview

**Technology Stack:**
- **Backend**: Go server using Fiber web framework
- **Frontend**: React-based single-page application with modern JavaScript
- **Communication**: RESTful API + WebSockets for real-time data
- **Process Management**: PTY (pseudo-terminal) integration for authentic CLI experience
- **Internationalization**: React i18next for frontend, environment variable inheritance for backend

**Key Design Principles:**
1. **Zero CLI Modification**: Existing modules work without changes
2. **Automatic Discovery**: New modules are automatically detected and integrated
3. **Full CLI Compatibility**: All CLI functionality preserved in GUI
4. **Real-time Experience**: Live terminal output and interaction
5. **Multi-session Support**: Multiple modules can run concurrently

### 2. Directory Structure

```
gui/
├── main.go                    # Go backend server
├── go.mod                     # Go module dependencies
├── go.sum                     # Go module checksums
├── little-linux-helper-gui   # Compiled binary (after build)
├── README.md                  # GUI-specific documentation
├── setup.sh                   # Development environment setup
├── dev.sh                     # Development server launcher
├── build.sh                   # Production build script
├── ensure_deps.sh            # Dependency checker
└── web/                      # React frontend
    ├── package.json          # Node.js dependencies and scripts
    ├── package-lock.json     # Dependency lock file
    ├── vite.config.js        # Vite build configuration
    ├── index.html            # HTML entry point
    ├── build/                # Production build output
    ├── public/               # Static assets
    └── src/                  # React source code
        ├── App.jsx           # Main application component
        ├── index.jsx         # React entry point
        ├── index.css         # Global styles
        ├── components/       # React components
        │   ├── ModuleList.jsx
        │   ├── Terminal.jsx
        │   ├── HelpPanel.jsx
        │   ├── DocsPanel.jsx
        │   └── ...
        ├── contexts/         # React contexts
        │   └── SessionContext.jsx
        └── i18n/            # Internationalization
            ├── index.js      # i18n configuration
            └── locales/      # Translation files
                ├── de/       # German translations
                └── en/       # English translations
```

## 3. Backend Development (Go)

### 3.1 Core Backend Components

**Main Server (`main.go`):**
The Go backend serves multiple purposes:
- Static file serving for the React frontend
- RESTful API endpoints for module management
- WebSocket handling for real-time communication
- Module discovery and execution management
- Session management for concurrent processes

**Key Data Structures:**
```go
type ModuleInfo struct {
    ID             string `json:"id"`
    Name           string `json:"name"`
    Description    string `json:"description"`
    Path           string `json:"path"`
    Category       string `json:"category"`
    Parent         string `json:"parent,omitempty"`
    SubmoduleCount int    `json:"submodule_count,omitempty"`
}

type ModuleSession struct {
    ID          string
    Module      string
    ModuleName  string
    CreatedAt   time.Time
    Status      string
    Process     *exec.Cmd
    PTY         *os.File
    Done        chan bool
    Output      chan string
    Buffer      []string
    BufferMutex sync.RWMutex
}
```

### 3.2 API Endpoints

**Module Management:**
- `GET /api/modules` - List all available modules with metadata
- `GET /api/modules/:id/docs` - Get module documentation
- `POST /api/modules/:id/start` - Start module execution
- `GET /api/health` - System health and status

**Session Management:**
- `GET /api/sessions` - List active sessions
- `POST /api/sessions/:sessionId/input` - Send input to module
- `DELETE /api/sessions/:sessionId` - Stop session

**Documentation:**
- `GET /api/docs` - List all documentation files

**Real-time Communication:**
- `WS /ws` - WebSocket for live terminal output

### 3.3 Module Discovery Process

The backend automatically discovers modules through several mechanisms:

**1. Standard Module Scanning:**
```go
// Scans modules/ directory for mod_*.sh files
moduleFiles, err := filepath.Glob(filepath.Join(lhRootDir, "modules", "mod_*.sh"))
if err != nil {
    log.Printf("Error scanning modules directory: %v", err)
    return modules
}
```

**2. Hierarchical Module Detection:**
```go
// Scans subdirectories for backup modules
backupModules, err := filepath.Glob(filepath.Join(lhRootDir, "modules/backup", "mod_*.sh"))
if err != nil {
    log.Printf("Error scanning backup modules: %v", err)
} else {
    // Process backup modules as subcategory
}
```

**3. Module Categorization:**
Modules are automatically categorized based on their location and naming patterns:
- Standard modules: `modules/mod_*.sh`
- Backup modules: `modules/backup/mod_*.sh` 
- Future categories can be added by extending the discovery patterns

### 3.4 Process Management with PTY

**PTY Integration:**
The GUI uses pseudo-terminals (PTY) to provide authentic CLI experience:

```go
// Create PTY for module execution
pty, err := pty.Start(cmd)
if err != nil {
    return "", fmt.Errorf("failed to start pty: %v", err)
}

// Set up PTY size for proper formatting
err = pty.Setsize(&pty.Winsize{
    Rows: 24, Cols: 80,
})
```

**Benefits of PTY:**
- Preserves ANSI color codes and formatting
- Handles interactive prompts naturally
- Maintains authentic terminal behavior
- Supports all terminal-based features

### 3.5 Environment Variable Management

**Critical Environment Variables:**
```go
cmd.Env = append(os.Environ(),
    "LH_ROOT_DIR="+lhRootDir,
    "LH_GUI_MODE=true",
    "LH_LANG="+language,  // Dynamic language inheritance
)
```

**Key Variables Explained:**
- `LH_ROOT_DIR`: Project root directory (required by all modules)
- `LH_GUI_MODE=true`: Enables GUI-aware behavior in modules
- `LH_LANG`: Language setting inherited from GUI selection

### 3.6 Adding New API Endpoints

**Pattern for New Endpoints:**
```go
// Add to main() function in the API routes section
api.Get("/new-endpoint/:param", handleNewEndpoint)

// Implement handler function
func handleNewEndpoint(c *fiber.Ctx) error {
    param := c.Params("param")
    
    // Process request
    result := processRequest(param)
    
    // Return JSON response
    return c.JSON(fiber.Map{
        "success": true,
        "data":    result,
    })
}
```

**Error Handling Pattern:**
```go
func handleApiCall(c *fiber.Ctx) error {
    // Validate input
    if param := c.Params("required"); param == "" {
        return c.Status(400).JSON(fiber.Map{
            "error": "Missing required parameter",
        })
    }
    
    // Process with error handling
    result, err := someOperation(param)
    if err != nil {
        log.Printf("Operation failed: %v", err)
        return c.Status(500).JSON(fiber.Map{
            "error": "Internal server error",
        })
    }
    
    return c.JSON(fiber.Map{
        "success": true,
        "data":    result,
    })
}
```

## 4. Frontend Development (React)

### 4.1 Core Frontend Architecture

**Application Structure:**
The React frontend follows a component-based architecture with clear separation of concerns:

- **App.jsx**: Main application container and state management
- **Components**: Reusable UI components for specific functionality
- **Contexts**: Global state management (SessionContext)
- **i18n**: Internationalization system

**Key State Management:**
```jsx
// Main application state in App.jsx
const [modules, setModules] = useState([]);
const [selectedModule, setSelectedModule] = useState(null);
const [moduleDocs, setModuleDocs] = useState('');
const [panelWidths, setPanelWidths] = useState({ 
    terminal: 50, help: 25, docs: 25 
});
```

### 4.2 Essential Components

**ModuleList.jsx:**
- Displays categorized module navigation
- Handles module selection and starting
- Provides individual "Start" buttons for each module
- Supports hierarchical module display

**Terminal.jsx:**
- Real-time terminal output display
- ANSI color code support
- Session-aware output switching
- WebSocket integration for live updates

**SessionContext.jsx:**
- Centralized session state management
- WebSocket connection management
- Session lifecycle handling
- Language inheritance for new sessions

**HelpPanel.jsx:**
- Context-sensitive help display
- Translation error recovery
- Module-specific guidance
- Graceful fallback handling

### 4.3 WebSocket Integration

**Connection Management:**
```jsx
// In SessionContext.jsx
useEffect(() => {
    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const wsUrl = `${protocol}//${window.location.host}/ws`;
    const ws = new WebSocket(wsUrl);
    
    ws.onmessage = (event) => {
        const message = JSON.parse(event.data);
        handleWebSocketMessage(message);
    };
    
    return () => ws.close();
}, []);
```

**Message Handling:**
```jsx
const handleWebSocketMessage = (message) => {
    switch (message.type) {
        case 'output':
            // Update terminal output for session
            updateSessionOutput(message.session_id, message.content);
            break;
        case 'session_ended':
            // Handle session termination
            handleSessionEnd(message.session_id);
            break;
    }
};
```

### 4.4 API Integration

**Standard API Call Pattern:**
```jsx
// Fetch modules with error handling
const fetchModules = async () => {
    try {
        const response = await fetch('/api/modules');
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}`);
        }
        const data = await response.json();
        setModules(data);
    } catch (error) {
        console.error('Error fetching modules:', error);
        // Handle error state
    }
};
```

**Starting Module Sessions:**
```jsx
const startModule = async (moduleId, language) => {
    try {
        const response = await fetch(`/api/modules/${moduleId}/start`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ language })
        });
        
        if (!response.ok) {
            throw new Error(`Failed to start module: ${response.status}`);
        }
        
        const data = await response.json();
        return data.session_id;
    } catch (error) {
        console.error('Error starting module:', error);
        throw error;
    }
};
```

### 4.5 Adding New React Components

**Component Template:**
```jsx
import React from 'react';
import { useTranslation } from 'react-i18next';

function NewComponent({ prop1, prop2 }) {
    const { t } = useTranslation('common');
    
    return (
        <div className="new-component">
            <h2>{t('component.title')}</h2>
            {/* Component content */}
        </div>
    );
}

export default NewComponent;
```

**Integration Steps:**
1. Create component file in `src/components/`
2. Import in parent component or App.jsx
3. Add necessary translations to i18n files
4. Update CSS if needed
5. Test with both languages

## 5. Internationalization (i18n) System

### 5.1 Frontend i18n Architecture

**Configuration (`src/i18n/index.js`):**
```javascript
import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';

// Import translation resources
import enCommon from './locales/en/common.json';
import deCommon from './locales/de/common.json';
import enHelp from './locales/en/help.json';
import deHelp from './locales/de/help.json';

const resources = {
    en: {
        common: enCommon,
        help: enHelp
    },
    de: {
        common: deCommon,
        help: deHelp
    }
};

i18n
    .use(initReactI18next)
    .init({
        resources,
        lng: 'en', // default language
        fallbackLng: 'en',
        interpolation: {
            escapeValue: false
        }
    });
```

**Translation File Structure:**
```json
// src/i18n/locales/en/common.json
{
    "app": {
        "title": "Little Linux Helper",
        "subtitle": "System Administration Toolkit"
    },
    "modules": {
        "category": {
            "system": "System Diagnosis & Analysis",
            "backup": "Backup & Recovery"
        }
    },
    "actions": {
        "start": "Start",
        "stop": "Stop",
        "close": "Close"
    }
}
```

### 5.2 Translation Usage Patterns

**Basic Translation:**
```jsx
import { useTranslation } from 'react-i18next';

function Component() {
    const { t } = useTranslation('common');
    
    return <h1>{t('app.title')}</h1>;
}
```

**Translation with Parameters:**
```jsx
const { t } = useTranslation('common');
const message = t('status.active_sessions', { count: sessions.length });
```

**Namespace-specific Translations:**
```jsx
// Use 'help' namespace
const { t } = useTranslation('help');
const helpText = t('modules.backup.overview');
```

**Error-Safe Translation:**
```jsx
// Safe translation with fallback
const getTranslation = (key, fallback = key) => {
    try {
        const translation = t(key);
        return translation !== key ? translation : fallback;
    } catch (error) {
        console.warn(`Translation missing for key: ${key}`);
        return fallback;
    }
};
```

### 5.3 Language Inheritance System

**GUI to CLI Language Passing:**
The GUI automatically passes the selected language to CLI modules:

```jsx
// In SessionContext.jsx
const startNewSession = async (moduleId) => {
    const currentLanguage = i18n.language; // Get current GUI language
    
    // Pass language to backend
    const response = await fetch(`/api/modules/${moduleId}/start`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ language: currentLanguage })
    });
};
```

**Backend Language Processing:**
```go
// In main.go startModule function
var req StartModuleRequest
if err := c.BodyParser(&req); err != nil {
    req.Language = "en" // default fallback
}

// Set environment variable for CLI module
cmd.Env = append(os.Environ(),
    "LH_LANG="+req.Language,
)
```

### 5.4 Adding New Languages

**Steps to Add a Language:**
1. Create new locale directory: `src/i18n/locales/fr/`
2. Create translation files: `common.json`, `help.json`
3. Update i18n configuration to include new resources
4. Add language selector option in LanguageSelector.jsx
5. Test all components with new language

**Language Selector Integration:**
```jsx
// In LanguageSelector.jsx
const languages = [
    { code: 'en', name: 'English', flag: '🇺🇸' },
    { code: 'de', name: 'Deutsch', flag: '🇩🇪' },
    { code: 'fr', name: 'Français', flag: '🇫🇷' }, // New language
];
```

## 6. Module Integration

### 6.1 Automatic Module Discovery

**How Modules Are Discovered:**
1. **File System Scanning**: Backend scans `modules/` directory for `mod_*.sh` files
2. **Metadata Extraction**: Module names and descriptions extracted from filenames and CLI structure
3. **Category Assignment**: Modules automatically categorized based on location and naming
4. **Documentation Mapping**: Associated documentation files automatically linked

**Module Metadata Generation:**
```go
func createModuleInfo(filePath, category, parent string) ModuleInfo {
    // Extract module ID from filename
    fileName := filepath.Base(filePath)
    moduleID := strings.TrimPrefix(fileName, "mod_")
    moduleID = strings.TrimSuffix(moduleID, ".sh")
    
    return ModuleInfo{
        ID:          moduleID,
        Name:        generateModuleName(moduleID),
        Description: generateModuleDescription(moduleID),
        Path:        filePath,
        Category:    category,
        Parent:      parent,
    }
}
```

### 6.2 Module Execution Environment

**Environment Setup:**
When a module is executed through the GUI, it receives:
- All standard environment variables from the system
- `LH_ROOT_DIR`: Project root directory
- `LH_GUI_MODE=true`: Indicates GUI execution mode
- `LH_LANG`: Current GUI language setting
- All other LH_* variables from lib_common.sh

**GUI-Aware Module Behavior:**
Existing modules automatically become GUI-aware through the `LH_GUI_MODE` variable:
```bash
# In module scripts (no changes needed - already implemented)
if [[ "$LH_GUI_MODE" == "true" ]]; then
    # Skip "Any Key" prompts automatically
    # Module continues without user intervention
fi
```

### 6.3 Module Categories and Organization

**Current Category Structure:**
- **Recovery & Restarts**: Service and desktop restart utilities
- **System Diagnosis & Analysis**: System info, disk tools, log analysis  
- **Maintenance & Security**: Package management, security checks
- **Docker & Containers**: Docker management and security
- **Backup & Recovery**: BTRFS, TAR, and RSYNC backup operations

**Adding New Categories:**
1. Create new subdirectory in `modules/` (e.g., `modules/networking/`)
2. Update backend discovery logic in `getModules()` function
3. Add category translations to i18n files
4. Update frontend ModuleList component if needed

### 6.4 Module Documentation Integration

**Automatic Documentation Mapping:**
The GUI automatically links modules to their documentation:
```go
// Map module IDs to documentation files
var moduleDocMap = map[string]string{
    "backup":        "mod_backup.md",
    "btrfs_backup":  "mod_btrfs_backup.md", 
    "disk":          "mod_disk.md",
    // Add new mappings here
}
```

**Documentation File Structure:**
Place documentation files in `docs/` directory with naming pattern `mod_[module_name].md`

## 7. Development Workflows

### 7.1 Development Environment Setup

**Prerequisites:**
- Go 1.18+ (1.21+ recommended)
- Node.js 18+
- npm (included with Node.js)

**Initial Setup:**
```bash
# Navigate to GUI directory
cd gui/

# Run setup script (installs dependencies)
./setup.sh

# Start development servers
./dev.sh
```

**What setup.sh Does:**
- Checks for Go and Node.js installations
- Attempts to install missing dependencies via package manager
- Runs `go mod tidy` for Go dependencies
- Runs `npm install` for Node.js dependencies
- Builds initial production frontend

### 7.2 Development Server Workflow

**Starting Development Servers:**
```bash
# Start both backend and frontend in development mode
./dev.sh
```

**Development Server Details:**
- **Backend**: Runs on localhost:3000 with hot reload
- **Frontend**: Runs on localhost:3001 with Vite dev server
- **Proxy Configuration**: Frontend proxies `/api` requests to backend
- **Live Reload**: Both servers restart automatically on file changes

**Manual Development Start:**
```bash
# Terminal 1: Start Go backend
go run main.go

# Terminal 2: Start Vite frontend
cd web/
npm run dev
```

### 7.3 Production Build Process

**Creating Production Build:**
```bash
# Build production version
./build.sh
```

**Build Process Steps:**
1. Validates dependencies (Go, Node.js, npm)
2. Builds optimized React frontend (`npm run build`)
3. Compiles Go binary with embedded frontend assets
4. Creates single executable: `little-linux-helper-gui`

**Manual Build Process:**
```bash
# Build frontend
cd web/
npm run build

# Build Go binary (from gui/ directory)
go build -o little-linux-helper-gui main.go
```

### 7.4 Testing and Debugging

**Backend Debugging:**
```bash
# Run with verbose logging
go run main.go -v

# Test API endpoints directly
curl http://localhost:3000/api/modules
curl http://localhost:3000/api/health
```

**Frontend Debugging:**
```bash
# Start frontend with debug output
cd web/
npm run dev

# React DevTools available in browser
# Console logs show component updates and API calls
```

**Integration Testing:**
```bash
# Test GUI with different languages
./little-linux-helper-gui -p 3000

# Test CLI compatibility
export LH_GUI_MODE=true
export LH_LANG=de
./help_master.sh -g
```

### 7.5 Common Development Tasks

**Adding New Translation Keys:**
1. Add key to `src/i18n/locales/en/common.json`
2. Add corresponding German translation to `src/i18n/locales/de/common.json`
3. Use in components with `t('new.key')`
4. Test with both languages

**Adding New API Endpoint:**
1. Add route in `main.go` API section
2. Implement handler function
3. Update frontend to call new endpoint
4. Test with both success and error cases

**Adding New React Component:**
1. Create component file in `src/components/`
2. Add necessary imports and dependencies
3. Implement component with translation support
4. Add to parent component or App.jsx
5. Update CSS if needed
6. Test component in isolation

**Debugging Module Execution:**
1. Check backend logs for PTY errors
2. Verify environment variables are set correctly
3. Test module execution directly in CLI
4. Check WebSocket connection in browser dev tools

## 8. Best Practices and Guidelines

### 8.1 Frontend Development Best Practices

**Component Structure:**
```jsx
// Good component structure
import React, { useState, useEffect } from 'react';
import { useTranslation } from 'react-i18next';

function ComponentName({ prop1, prop2, onAction }) {
    const { t } = useTranslation('common');
    const [localState, setLocalState] = useState(null);
    
    // Effects
    useEffect(() => {
        // Component logic
    }, [dependency]);
    
    // Event handlers
    const handleEvent = (event) => {
        // Handle event
        onAction?.(data);
    };
    
    // Early return for loading states
    if (!localState) {
        return <div>{t('common.loading')}</div>;
    }
    
    return (
        <div className="component-name">
            {/* Component JSX */}
        </div>
    );
}

export default ComponentName;
```

**State Management:**
- Use React hooks for local component state
- Use Context for shared state (sessions, language)
- Avoid prop drilling with deep component hierarchies
- Keep state as close to usage as possible

**Error Handling:**
```jsx
// Always handle API errors
const fetchData = async () => {
    try {
        const response = await fetch('/api/endpoint');
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        const data = await response.json();
        setData(data);
    } catch (error) {
        console.error('API call failed:', error);
        setError(error.message);
    }
};
```

### 8.2 Backend Development Best Practices

**Error Handling:**
```go
// Always return appropriate HTTP status codes
func handleRequest(c *fiber.Ctx) error {
    param := c.Params("id")
    if param == "" {
        return c.Status(400).JSON(fiber.Map{
            "error": "Missing required parameter: id",
        })
    }
    
    result, err := processRequest(param)
    if err != nil {
        log.Printf("Request processing failed: %v", err)
        return c.Status(500).JSON(fiber.Map{
            "error": "Internal server error",
        })
    }
    
    return c.JSON(fiber.Map{
        "success": true,
        "data":    result,
    })
}
```

**Resource Management:**
```go
// Always clean up resources
func startModuleSession(moduleID, language string) (*ModuleSession, error) {
    // Create session with cleanup
    session := &ModuleSession{
        ID:        generateSessionID(),
        Done:      make(chan bool),
        Output:    make(chan string, 1000), // Buffered channel
    }
    
    // Set up cleanup
    go func() {
        <-session.Done
        // Clean up resources
        if session.PTY != nil {
            session.PTY.Close()
        }
        if session.Process != nil {
            session.Process.Process.Kill()
        }
    }()
    
    return session, nil
}
```

### 8.3 Translation Best Practices

**Key Naming Conventions:**
```json
{
    "category": {
        "subcategory": {
            "specific_item": "Translation text"
        }
    },
    "actions": {
        "button_start": "Start",
        "button_stop": "Stop"
    },
    "messages": {
        "success_operation": "Operation completed successfully",
        "error_generic": "An error occurred"
    }
}
```

**Parameter Handling:**
```jsx
// Use parameters for dynamic content
const message = t('status.active_count', { count: sessions.length });

// JSON translation file:
{
    "status": {
        "active_count": "{{count}} active session(s)"
    }
}
```

**Fallback Handling:**
```jsx
// Always provide fallbacks for missing translations
const safeTranslate = (key, fallback) => {
    try {
        const result = t(key);
        return result !== key ? result : fallback;
    } catch (error) {
        console.warn(`Missing translation: ${key}`);
        return fallback || key;
    }
};
```

### 8.4 Performance Considerations

**Frontend Performance:**
- Use React.memo for expensive components
- Implement virtual scrolling for long lists
- Debounce user input handling
- Lazy load components when possible

**Backend Performance:**
- Use buffered channels for WebSocket output
- Implement session cleanup to prevent memory leaks
- Cache module discovery results
- Use appropriate HTTP status codes

**WebSocket Optimization:**
```go
// Buffer WebSocket messages to reduce network overhead
type WebSocketBuffer struct {
    messages []string
    ticker   *time.Ticker
}

func (wsb *WebSocketBuffer) flushMessages(conn *websocket.Conn) {
    if len(wsb.messages) > 0 {
        combinedMessage := strings.Join(wsb.messages, "")
        conn.WriteJSON(fiber.Map{
            "type":    "output",
            "content": combinedMessage,
        })
        wsb.messages = wsb.messages[:0] // Clear buffer
    }
}
```

## 9. Troubleshooting Guide

### 9.1 Common Development Issues

**Port Already in Use:**
```bash
# Check what's using port 3000
lsof -i :3000

# Kill process using port
kill -9 $(lsof -t -i:3000)

# Or use different port
./dev.sh -p 3001
```

**Go Module Issues:**
```bash
# Clean Go module cache
go clean -modcache

# Reinstall dependencies
rm go.sum
go mod tidy
```

**Node.js Dependency Issues:**
```bash
# Clear npm cache
npm cache clean --force

# Remove and reinstall dependencies
rm -rf node_modules package-lock.json
npm install
```

**WebSocket Connection Failed:**
- Check browser developer console for WebSocket errors
- Verify backend server is running on correct port
- Ensure no firewall blocking connections
- Check for proxy/network configuration issues

### 9.2 Module Integration Issues

**Module Not Appearing in GUI:**
1. Check file naming convention (`mod_*.sh`)
2. Verify file is executable (`chmod +x`)
3. Ensure file is in correct directory (`modules/` or subdirectory)
4. Check backend logs for scanning errors
5. Restart GUI server to refresh module list

**Module Execution Fails:**
1. Test module directly in CLI first
2. Check `LH_ROOT_DIR` environment variable
3. Verify all dependencies are installed
4. Check PTY creation logs in backend
5. Ensure module has proper shebang (`#!/bin/bash`)

**Translation Issues:**
1. Verify JSON syntax in translation files
2. Check for missing translation keys in console
3. Ensure all namespaces are properly imported
4. Test with fallback language (English)
5. Check i18n configuration in `src/i18n/index.js`

### 9.3 Production Deployment Issues

**Build Failures:**
```bash
# Check all dependencies are installed
./ensure_deps.sh

# Manually run build steps
cd web/
npm run build
cd ..
go build -o little-linux-helper-gui main.go
```

**Runtime Errors:**
- Check file permissions on binary
- Verify all required files are present
- Check system compatibility (Linux required)
- Ensure proper directory structure maintained

**Performance Issues:**
- Monitor memory usage of long-running sessions
- Check for WebSocket connection leaks
- Review session cleanup logic
- Monitor file descriptor usage

## 10. Extension and Customization

### 10.1 Adding Custom Themes

**CSS Custom Properties:**
```css
/* In src/index.css */
:root {
    --primary-color: #007acc;
    --secondary-color: #f0f0f0;
    --background-color: #ffffff;
    --text-color: #333333;
}

/* Dark theme example */
@media (prefers-color-scheme: dark) {
    :root {
        --primary-color: #4fa8d8;
        --secondary-color: #2d2d2d;
        --background-color: #1a1a1a;
        --text-color: #ffffff;
    }
}
```

### 10.2 Custom Module Categories

**Backend Category Addition:**
```go
// Add to getModules() function
customModules, err := filepath.Glob(filepath.Join(lhRootDir, "modules/custom", "mod_*.sh"))
if err != nil {
    log.Printf("Error scanning custom modules: %v", err)
} else {
    for _, modulePath := range customModules {
        modules = append(modules, createModuleInfo(modulePath, "Custom Tools", ""))
    }
}
```

**Frontend Category Translation:**
```json
// Add to common.json
{
    "modules": {
        "category": {
            "custom": "Custom Tools"
        }
    }
}
```

### 10.3 API Extensions

**Adding New Endpoints:**
```go
// Add custom endpoints to main.go
api.Get("/custom/:param", handleCustomEndpoint)

func handleCustomEndpoint(c *fiber.Ctx) error {
    param := c.Params("param")
    // Custom logic here
    return c.JSON(fiber.Map{
        "success": true,
        "data":    customData,
    })
}
```

**Frontend Integration:**
```jsx
// Add custom API calls
const useCustomApi = () => {
    const fetchCustomData = async (param) => {
        const response = await fetch(`/api/custom/${param}`);
        return response.json();
    };
    
    return { fetchCustomData };
};
```

## 11. Testing Strategy

### 11.1 Development Testing

**Manual Testing Checklist:**
- [ ] All modules appear in sidebar
- [ ] Module execution works correctly
- [ ] WebSocket connection stable
- [ ] Language switching functions
- [ ] Session management works
- [ ] Panel resizing and hiding works
- [ ] Documentation displays correctly
- [ ] Error handling graceful

**Browser Compatibility:**
- Test in Chrome, Firefox, Safari, Edge
- Verify WebSocket support
- Check responsive design on mobile
- Test with different screen sizes

### 11.2 Integration Testing

**CLI Compatibility:**
```bash
# Test GUI mode setting
export LH_GUI_MODE=true
./modules/mod_system_info.sh

# Test language inheritance
export LH_LANG=de
./modules/mod_backup.sh
```

**API Testing:**
```bash
# Test all endpoints
curl http://localhost:3000/api/health
curl http://localhost:3000/api/modules
curl -X POST http://localhost:3000/api/modules/system_info/start \
     -H "Content-Type: application/json" \
     -d '{"language":"en"}'
```

## 12. Future Development

### 12.1 Planned Enhancements

**UI Improvements:**
- Dark/light theme toggle
- Customizable panel layouts
- Advanced session filtering
- Module search functionality

**Backend Enhancements:**
- Module dependency checking
- Advanced session logging
- Performance monitoring
- Security enhancements

**Integration Features:**
- Configuration file editing interface
- Log file viewer
- System status dashboard
- Scheduled task management

### 12.2 Architecture Considerations

**Scalability:**
- Consider moving to database-backed sessions for multi-instance deployments
- Implement session persistence across server restarts
- Add load balancing support for high-availability setups

**Security:**
- Add authentication for network mode
- Implement HTTPS support
- Add audit logging for administrative actions
- Consider sandboxing for module execution

**Extensibility:**
- Plugin system for custom modules
- API versioning for backward compatibility
- Module marketplace integration
- Custom dashboard creation

---

*This comprehensive GUI Developer Guide provides all the information needed to understand, develop, and extend the Little Linux Helper GUI system. The GUI maintains full compatibility with the CLI system while providing a modern, accessible interface for system administration tasks.*
