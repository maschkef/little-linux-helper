<!--
File: docs/gui/doc_backend_api.md
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
-->

# GUI Backend Development - API Reference

This document provides comprehensive information about developing and extending the Go backend server for the Little Linux Helper GUI system.

## Backend Architecture Overview

**Technology Stack:**
- **Go 1.18+** (1.21+ recommended)
- **Fiber v2** - High-performance HTTP web framework
- **gofiber/websocket/v2** - WebSocket implementation for Fiber
- **PTY** - Pseudo-terminal integration for authentic CLI experience

**Core Responsibilities:**
- Serve React frontend static files
- Provide RESTful API endpoints
- Manage WebSocket connections for real-time communication
- Execute CLI modules via PTY processes
- Handle session management for concurrent executions
- Serve documentation files dynamically

## Key Data Structures

### ModuleInfo Structure
```go
type ModuleInfo struct {
    ID             string `json:"id"`              // Unique module identifier
    Name           string `json:"name"`            // Display name
    Description    string `json:"description"`     // Module description
    Path           string `json:"path"`            // File system path
    Category       string `json:"category"`        // Module category
    Parent         string `json:"parent,omitempty"` // Parent module (for hierarchies)
    SubmoduleCount int    `json:"submodule_count,omitempty"` // Count of sub-modules
}
```

### ModuleSession Structure
```go
type ModuleSession struct {
    ID          string           // Unique session identifier
    Module      string          // Module ID being executed
    ModuleName  string          // Display name of module
    CreatedAt   time.Time       // Session creation timestamp
    Status      string          // Current status (running, completed, error)
    Process     *exec.Cmd       // OS process reference
    PTY         *os.File        // Pseudo-terminal file descriptor
    Done        chan bool       // Completion signal channel
    Output      chan string     // Output stream channel
    Buffer      []string        // Output buffer for reconnection
    BufferMutex sync.RWMutex    // Thread-safe buffer access
}
```

## RESTful API Endpoints

### Authentication

#### `POST /api/login`
**Purpose:** Authenticate the user and issue a session cookie.

**Request Body:**
```json
{
    "user": "admin",
    "pass": "secret"
}
```

**Responses:**
- `204 No Content` on success (session cookie set).
- `401 Unauthorized` for invalid credentials.
- `429 Too Many Requests` when the rate limiter (10 attempts/minute per IP) is triggered.

**Notes:**
- Requires the `X-CSRF-Token` header if CSRF protection is enabled (default in session mode). The frontend helper reads the `csrf_` cookie and injects the header automatically.

#### `POST /api/logout`
**Purpose:** Destroy the active session and remove the authentication cookie.

**Responses:**
- `204 No Content` regardless of state (idempotent).

> All other `/api/*` routes return `401 Unauthorized` when accessed without a valid session or Basic Auth credentials.

### Module Management

#### `GET /api/modules`
**Purpose:** Retrieve list of all available modules with metadata

**Response Format:**
```json
[
    {
        "id": "system_info",
        "name": "Display System Information",
        "description": "Show comprehensive system information and hardware details",
        "path": "modules/mod_system_info.sh",
        "category": "System Diagnosis & Analysis",
        "parent": "",
        "submodule_count": 9
    }
]
```

**Implementation Details:**
- Returns a direct array of ModuleInfo objects (not wrapped in an object)
- Uses hardcoded module definitions with predefined categories and submodule counts
- Includes hierarchical backup modules with parent/child relationships
- Categories include: "Recovery & Restarts", "System Diagnosis & Analysis", "Maintenance & Security", "Docker & Containers", "Backup & Recovery"

#### `GET /api/modules/:id/docs`
**Purpose:** Retrieve documentation for a specific module

**Parameters:**
- `id`: Module identifier

**Response Format:**
```json
{
    "content": "# Module Documentation\n\nMarkdown content here..."
}
```

**Documentation Mapping:**
```go
var moduleDocMap = map[string]string{
    // Module docs live in docs/mod/
    "backup":        "mod/doc_backup.md",
    "btrfs_backup":  "mod/doc_btrfs_backup.md",
    "disk":          "mod/doc_disk.md",
    "docker":        "mod/doc_docker.md",
    "energy":        "mod/doc_energy.md",
    "logs":          "mod/doc_logs.md",
    "packages":      "mod/doc_packages.md",
    "restarts":      "mod/doc_restarts.md",
    "security":      "mod/doc_security.md",
    "system_info":   "mod/doc_system_info.md",

    // Library docs live in docs/lib/
    "lib_common":    "lib/doc_common.md",
    // ...additional entries omitted
}
```

#### `POST /api/modules/:id/start`
**Purpose:** Start execution of a module in a new session

**Request Body:**
```json
{
    "language": "en"  // Optional: "en" or "de" (defaults to "en")
}
```

**Response Format:**
```json
{
    "sessionId": "backup_1739023512"
}
```

**Implementation Process:**
1. Validate module existence
2. Create unique session ID
3. Set up PTY for authentic terminal experience
4. Configure environment variables (LH_ROOT_DIR, LH_GUI_MODE, LH_LANG)
5. Start module process
6. Initialize output streaming
7. Register session for management

### Session Management

#### `GET /api/sessions`
**Purpose:** List all active sessions

**Response Format:**
```json
[
    {
        "id": "system_info_1739023512",
        "module": "system_info",
        "module_name": "Display System Information",
        "created_at": "2025-02-11T12:45:50Z",
        "status": "running"
    }
]
```

#### `POST /api/sessions/:sessionId/input`
**Purpose:** Send input to a running module session

**Request Body:**
```json
{
    "data": "user input string"
}
```

**Response Format:**
```json
{
    "status": "sent"
}
```

#### `DELETE /api/sessions/:sessionId`
**Purpose:** Stop a running session

**Response Format:**
```json
{
    "status": "stopped"
}
```

#### `POST /api/shutdown`
**Purpose:** Gracefully shut down the GUI server with session awareness

**Query Parameters:**
- `force` (optional, boolean): If `true`, forces shutdown even with active sessions

**Response (force=false):**
```json
{
    "activeSessions": [
        {
            "id": "restarts_1739023512",
            "module": "restarts",
            "moduleName": "Services & Desktop Restart Options",
            "createdAt": "2025-02-11T12:45:50Z",
            "status": "running"
        }
    ],
    "message": "Server shutdown initiated",
    "warning": "Active sessions will be terminated"
}
```

**Response (force=true or no active sessions):**
```json
{
    "activeSessions": [],
    "message": "Server shutdown initiated"
}
```

**Implementation Details:**
- **Session Detection**: Automatically detects and reports all active running modules
- **Graceful Termination**: Uses SIGTERM signal first, then SIGKILL after 2-second timeout
- **Force Shutdown**: `?force=true` parameter bypasses session warnings and immediately shuts down
- **Process Safety**: Cleans up all PTY connections and session data before exit
- **Response Timing**: Server exits after 500ms delay to ensure response is sent
- **Frontend Integration**: Designed to work with ExitButton.jsx confirmation dialogs

**Usage Example:**
```bash
# Check for active sessions first
curl -X POST http://localhost:3000/api/shutdown

# Force shutdown regardless of active sessions
curl -X POST "http://localhost:3000/api/shutdown?force=true"
```

### Configuration Forms

The configuration manager consumes a schema defined in `gui/config-schema/config-forms.json`. The backend loads this file at startup and exposes helper endpoints that deliver both the schema and live values.

#### `GET /api/config/forms`
**Purpose:** List the available configuration forms.

**Response Format:**
```json
[
  {
    "filename": "general.d/00-language.conf",
    "display_name": "Language & Locale",
    "display_key": "config.generalLanguage",
    "config_type": "general",
    "advanced": false,
    "description": "Choose the default interface language that should be applied when the helper starts."
  },
  {
    "filename": "general.d/20-logging-detail.conf",
    "display_name": "Logging (Advanced)",
    "config_type": "general",
    "advanced": true
  }
]
```

#### `GET /api/config/forms/:filename`
**Purpose:** Retrieve the schema and current values for a single form.

**Response Format:**
```json
{
  "filename": "backup.d/00-storage.conf",
  "display_name": "Backup Storage",
  "config_type": "backup",
  "advanced": false,
  "has_example": true,
  "groups": [
    {
      "title": "Paths",
      "fields": [
        {
          "key": "CFG_LH_BACKUP_ROOT",
          "type": "text",
          "label": "Backup root",
          "placeholder": "/mnt/backup_drive/"
        },
        {
          "key": "CFG_LH_BACKUP_DIR",
          "type": "text",
          "label": "Backup directory",
          "help": "Relative to the backup root and usually starts with '/'."
        }
      ]
    }
  ],
  "values": {
    "CFG_LH_BACKUP_ROOT": "/media/backup",
    "CFG_LH_BACKUP_DIR": "/backups",
    "CFG_LH_TEMP_SNAPSHOT_DIR": "/.snapshots_lh_temp"
  },
  "last_modified": "2025-01-14T08:15:30Z"
}
```

#### `PUT /api/config/forms/:filename`
**Purpose:** Persist changes from the options menu back to the configuration fragment.

**Request Body:**
```json
{
  "values": {
    "CFG_LH_GUI_PORT": "3010",
    "CFG_LH_GUI_HOST": "localhost",
    "CFG_LH_GUI_FIREWALL_RESTRICTION": "local"
  }
}
```

**Responses:**
- `200 OK` with `{ "status": "saved", "form": { ...updated detail... } }`
- `400 Bad Request` for missing/invalid fields
- `500 Internal Server Error` if the shell helpers fail (logs contain `lh_gui_write_config_file` output)

> Saving via this endpoint delegates to `lh_config_update_fragment()` and `lh_gui_ensure_edit_marker()`. Every fragment touched by the GUI receives the marker `# Edited from Little Linux Helper GUI on YYYY-mm-DD`, which is refreshed on subsequent edits.

#### `GET /api/config/changes`
**Purpose:** Provide a read-only summary of keys that differ from their default template values.

**Response Format:**
```json
[
  {
    "filename": "general.d/30-gui.conf",
    "display_name": "GUI Server",
    "config_type": "general",
    "changes": [
      {
        "key": "CFG_LH_GUI_PORT",
        "default": "3000",
        "current": "3010"
      }
    ]
  }
]
```

**Notes:**
- Values are normalised strings with quotes removed to simplify comparison in the frontend.
- Keys without a known template default fall back to the schema-defined `default` property (if present); otherwise the default column remains blank.
- Entries with zero differences are omitted, resulting in an empty array when the installation matches its defaults.

### System Endpoints

#### `GET /api/health`
**Purpose:** System health and status information

**Response Format:**
```json
{
    "status": "ok",
    "uptime": 9015.0,
    "sessions": 3
}
```

**Field Descriptions:**
- `status`: Always returns "ok" if server is responsive
- `uptime`: Server uptime in seconds (as float)
- `sessions`: Number of currently active module sessions

#### `GET /api/docs`
**Purpose:** List all available documentation files

**Response Format:**
```json
[
    {
        "id": "mod_system_info",
        "name": "System Information",
        "description": "Show comprehensive system information and hardware details",
        "filename": "mod/doc_system_info.md"
    },
    {
        "id": "gui_backend_api",
        "name": "GUI Backend API",
        "description": "Go backend development, API endpoints, and data structures",
        "filename": "gui/doc_backend_api.md"
    }
]
```

## WebSocket Communication

### Connection Endpoint
`WS /ws` - WebSocket endpoint for real-time communication

### Message Types

#### Output Messages
```json
{
    "type": "output",
    "content": "Terminal output chunk with ANSI codes"
}
```

#### Session Status Messages
```json
{
    "type": "session_ended",
    "content": "system_info_1739023512"
}
```

#### Error Messages
```json
{
    "type": "error",
    "session_id": "uuid-string",
    "message": "Error description"
}
```

### WebSocket Implementation Example

```go
func handleWebSocket(c *websocket.Conn) {
    defer c.Close()
    
    var sessionId string
    
    for {
        // Read message from client
        messageType, msg, err := c.ReadMessage()
        if err != nil {
            log.Println("WebSocket read error:", err)
            break
        }
        
        // Process only text messages
        if messageType == websocket.TextMessage {
            var message Message
            if err := json.Unmarshal(msg, &message); err != nil {
                log.Println("JSON unmarshal error:", err)
                continue
            }
            
            // Process message based on type
            switch message.Type {
            case "subscribe":
                if id, ok := message.Content.(string); ok {
                    sessionId = id
                    go streamSessionOutput(c, sessionId)
                }
            }
        }
    }
}

// Message structure for WebSocket communication
type Message struct {
    Type    string      `json:"type"`
    Content interface{} `json:"content"`
}
```

## PTY Integration

### Creating PTY Sessions

```go
import "github.com/creack/pty"

func startModuleWithPTY(modulePath string, env []string) (*ModuleSession, error) {
    cmd := exec.Command("bash", modulePath)
    cmd.Env = env
    
    // Start command with PTY
    pty, err := pty.Start(cmd)
    if err != nil {
        return nil, fmt.Errorf("failed to start PTY: %v", err)
    }
    
    // Set PTY size for proper formatting
    err = pty.Setsize(&pty.Winsize{
        Rows: 24, Cols: 80,
    })
    if err != nil {
        log.Printf("Warning: Could not set PTY size: %v", err)
    }
    
    session := &ModuleSession{
        ID:      generateSessionID(),
        Process: cmd,
        PTY:     pty,
        Done:    make(chan bool),
        Output:  make(chan string, 1000),
        Buffer:  make([]string, 0),
    }
    
    // Start output reader
    go readPTYOutput(session)
    
    return session, nil
}
```

### Benefits of PTY Usage
- **ANSI Color Support**: Preserves terminal colors and formatting
- **Interactive Prompts**: Handles user input naturally
- **Authentic Experience**: Behaves exactly like running in terminal
- **Size Awareness**: Modules can respond to terminal size

## Environment Variable Management

### Critical Variables Set for Modules
```go
func setupModuleEnvironment(language string) []string {
    env := os.Environ()
    
    // Add GUI-specific variables
    env = append(env,
        "LH_ROOT_DIR="+lhRootDir,      // Project root directory
        "LH_GUI_MODE=true",            // Enable GUI-aware behavior
        "LH_LANG="+language,           // Dynamic language setting
    )
    
    return env
}
```

### Environment Variable Explanation
- **`LH_ROOT_DIR`**: Essential for module operation, provides project root path
- **`LH_GUI_MODE=true`**: Signals modules to skip interactive prompts like "Press any key"
- **`LH_LANG`**: Dynamically inherited from GUI language selection

## Error Handling Patterns

### Standard Error Response
```go
func handleError(c *fiber.Ctx, statusCode int, message string) error {
    return c.Status(statusCode).JSON(fiber.Map{
        "error":   message,
        "success": false,
    })
}
```

### Input Validation Pattern
```go
func validateModuleID(c *fiber.Ctx) error {
    moduleID := c.Params("id")
    if moduleID == "" {
        return handleError(c, 400, "Module ID is required")
    }
    
    if !isValidModuleID(moduleID) {
        return handleError(c, 404, "Module not found")
    }
    
    return c.Next()
}
```

### Resource Cleanup Pattern
```go
func cleanupSession(session *ModuleSession) {
    // Signal completion
    close(session.Done)
    
    // Clean up PTY
    if session.PTY != nil {
        session.PTY.Close()
    }
    
    // Terminate process if still running
    if session.Process != nil && session.Process.Process != nil {
        session.Process.Process.Kill()
    }
    
    // Clean up channels
    close(session.Output)
}
```

## Adding New API Endpoints

### Step-by-Step Process

1. **Define Route Handler**
```go
func handleNewEndpoint(c *fiber.Ctx) error {
    // Parameter extraction
    param := c.Params("param")
    
    // Input validation
    if param == "" {
        return handleError(c, 400, "Parameter is required")
    }
    
    // Business logic
    result, err := processRequest(param)
    if err != nil {
        log.Printf("Processing failed: %v", err)
        return handleError(c, 500, "Internal server error")
    }
    
    // Success response
    return c.JSON(fiber.Map{
        "success": true,
        "data":    result,
    })
}
```

2. **Register Route**
```go
// Add to main() function in API routes section
api.Get("/new-endpoint/:param", handleNewEndpoint)
api.Post("/new-endpoint", handleNewEndpointPost)
api.Delete("/new-endpoint/:param", handleNewEndpointDelete)
```

3. **Add Documentation**
Update this document with endpoint specification, request/response formats, and usage examples.

## Performance Considerations

### Session Management
- **Memory Usage**: Limit session output buffer size to prevent memory leaks
- **Cleanup**: Implement proper session cleanup to free resources
- **Concurrent Sessions**: Use goroutines for handling multiple sessions

### WebSocket Optimization
```go
// Buffer WebSocket messages to reduce network overhead
type WebSocketBuffer struct {
    messages []string
    ticker   *time.Ticker
    mutex    sync.Mutex
}

func (wsb *WebSocketBuffer) addMessage(content string) {
    wsb.mutex.Lock()
    defer wsb.mutex.Unlock()
    wsb.messages = append(wsb.messages, content)
}

func (wsb *WebSocketBuffer) flush(conn *websocket.Conn) {
    wsb.mutex.Lock()
    defer wsb.mutex.Unlock()
    
    if len(wsb.messages) > 0 {
        combined := strings.Join(wsb.messages, "")
        response := Message{
            Type:    "output",
            Content: combined,
        }
        data, _ := json.Marshal(response)
        conn.WriteMessage(websocket.TextMessage, data)
        wsb.messages = wsb.messages[:0] // Clear buffer
    }
}
```

## Security Considerations

### Input Sanitization
- Always validate and sanitize user input
- Use parameter binding instead of direct string concatenation
- Implement rate limiting for API endpoints

### Process Security
- Run module processes with same user permissions as GUI
- Validate module paths to prevent directory traversal
- Implement session timeouts to prevent resource exhaustion

### Network Security
- Default to localhost-only binding for security
- Provide clear warnings when enabling network access
- Authentication is mandatory for network deployments: the adaptive default (`auto`) activates session login whenever the GUI is exposed, while loopback-only runs may proceed without credentials.
- `LLH_GUI_AUTH_MODE` controls the mode (`auto` | `session` | `basic` | `none`). `none` is rejected if the server binds to anything other than `127.0.0.1`.
- Credentials are configured via `LLH_GUI_USER` and `LLH_GUI_PASS_HASH` (bcrypt). The backend exposes `--hash-password` to generate hashes without external tools.
- CSRF protection, secure cookie settings, and login rate limiting are enabled automatically in session mode.
- `LLH_GUI_ALLOWED_ORIGINS` can be set to a comma-separated list when trusted tooling (e.g., Vite) needs cross-origin access; same-origin requests are always accepted.

---

*This document provides comprehensive backend development information for the Little Linux Helper GUI system. For frontend development, see [Frontend React Development](doc_frontend_react.md).*
