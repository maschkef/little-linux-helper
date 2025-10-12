<!--
File: docs/gui/doc_frontend_react.md
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
-->

# GUI Frontend Development - React Components

This document provides comprehensive information about developing and extending the React frontend for the Little Linux Helper GUI system.

## Frontend Architecture Overview

**Technology Stack:**
- **React 19.x** (currently 19.2.0, see `gui/web/package.json`) - Modern functional components with hooks
- **Vite** - Fast build tool and development server  
- **React i18next** - Internationalization framework
- **ansi-to-html** - ANSI terminal color conversion
- **Modern JavaScript (ES6+)** - Latest language features
- **CSS3** - Fixed dark theme with responsive design

**Application Structure:**
```
web/src/
├── App.jsx              # Main application container with SessionProvider wrapper
├── index.jsx            # React entry point
├── index.css            # Global styles (fixed dark theme)
├── components/          # React components
│   ├── ModuleList.jsx           # Module navigation with parent/submodule support
│   ├── Terminal.jsx             # Terminal output display with ANSI support
│   ├── TerminalInput.jsx        # Terminal input component
│   ├── HelpPanel.jsx            # Context-sensitive help display
│   ├── DocsPanel.jsx            # Documentation viewer
│   ├── DocumentBrowser.jsx      # Full documentation browser
│   ├── ResizablePanels.jsx      # Panel layout system
│   ├── SessionDropdown.jsx      # Session management dropdown
│   ├── LanguageSelector.jsx     # EN/DE language switching
│   ├── ExitButton.jsx           # Application exit with session-aware confirmation
│   └── ErrorBoundary.jsx        # Error handling wrapper
├── contexts/            # React contexts
│   └── SessionContext.jsx      # Session and WebSocket management
└── i18n/               # Internationalization
    ├── index.js
    └── locales/
        ├── de/
        └── en/
```

## Core Components

### App.jsx - Main Application Container

**Purpose:** Root component managing global state, layout, and providing session context

**Key State Variables:**
```jsx
const [modules, setModules] = useState([]);              // Available modules array
const [selectedModule, setSelectedModule] = useState(null);  // Currently selected module object
const [moduleDocs, setModuleDocs] = useState('');        // Module documentation content
const [panelWidths, setPanelWidths] = useState({         // Panel layout configuration
  terminal: 50, 
  help: 25, 
  docs: 25 
});
const [showHelpPanel, setShowHelpPanel] = useState(true);     // Help panel visibility
const [showDocsPanel, setShowDocsPanel] = useState(false);    // Documentation panel visibility  
const [docBrowserMode, setDocBrowserMode] = useState(false);  // Document browser vs module docs
const [showSidebar, setShowSidebar] = useState(true);         // Module sidebar visibility
const [showTerminalPanels, setShowTerminalPanels] = useState(true); // Terminal area visibility
const [showDevControls, setShowDevControls] = useState(() => {       // Developer controls visibility
  const saved = localStorage.getItem('lh-gui-dev-controls');
  return saved === 'true'; // Default: false (hidden)
});
const [lastDocumentationSource, setLastDocumentationSource] = useState('module'); // Tracks doc source
```

**Key Functions:**
```jsx
// Fetch modules from backend API
const fetchModules = async () => {
  try {
    const response = await fetch('/api/modules');
    const data = await response.json(); // Direct array response
    setModules(data);
  } catch (error) {
    console.error('Failed to fetch modules:', error);
  }
};

// Handle module selection (receives full module object)
const handleModuleSelect = (module) => {
  setSelectedModule(module);
  // Documentation fetch happens via useEffect
};

// Fetch module documentation
const fetchModuleDocs = async (moduleId) => {
  try {
    const response = await fetch(`/api/modules/${moduleId}/docs`);
    if (response.ok) {
      const data = await response.json();
      setModuleDocs(data.content); // Extract content field
    } else {
      setModuleDocs(t('docs.notAvailable'));
    }
  } catch (error) {
    console.error('Failed to fetch module docs:', error);
    setModuleDocs(t('docs.errorLoading'));
  }
};

// Toggle developer controls with persistence and auto-cleanup
const toggleDevControls = (newValue) => {
  setShowDevControls(newValue);
  localStorage.setItem('lh-gui-dev-controls', newValue.toString());
  
  // Auto-close documentation panels when disabling dev mode
  if (!newValue) {
    setShowDocsPanel(false);
    setDocBrowserMode(false);
  }
};

// Start new session (uses SessionContext)
const startModule = async (module) => {
  try {
    await startNewSession(module); // Pass full module object
  } catch (error) {
    console.error('Error starting module:', error);
  }
};

// Pop-out the current session into a standalone browser tab
const handleOpenTTYTab = () => {
  if (!activeSessionId) {
    return;
  }

  const url = `/?ttySession=${encodeURIComponent(activeSessionId)}&standalone=1`;
  const newTab = window.open(url, '_blank', 'noopener,noreferrer');
  if (!newTab) {
    alert(t('terminal.popupBlocked'));
  }
};

// Group modules by category for display
const groupedModules = modules.reduce((acc, module) => {
  if (!acc[module.category]) {
    acc[module.category] = [];
  }
  acc[module.category].push(module);
  return acc;
}, {});
```

**Layout Structure:**
```jsx
// App reads query params and seeds SessionProvider so pop-out tabs can
// hydrate directly into the correct session
function App() {
  const params = new URLSearchParams(window.location.search);
  const standaloneSessionId = params.get('ttySession');
  const standaloneParam = params.get('standalone');
  const isStandalone = standaloneParam === '1' || standaloneParam === 'true';

  return (
    <SessionProvider initialSessionId={standaloneSessionId}>
      <AppContent
        standaloneSessionId={standaloneSessionId}
        isStandalone={isStandalone}
      />
    </SessionProvider>
  );
}

// Main application layout (renders StandaloneTerminalView when needed)
function AppContent({ standaloneSessionId, isStandalone }) {
  return (
    <ErrorBoundary>
      <div className="app">
        {/* Header with three-section layout */}
        <header className="header">
          <div className="header-content">
            {/* Left: Developer controls toggle */}
            <div style={{ flex: 1, display: 'flex', alignItems: 'center' }}>
              <div className="dev-controls-toggle">
                <input type="checkbox" id="dev-controls-toggle" 
                       checked={showDevControls} 
                       onChange={(e) => toggleDevControls(e.target.checked)} />
                <label htmlFor="dev-controls-toggle">🔧 {t('dev.toggle')}</label>
              </div>
            </div>
            
            {/* Center: App title and logo */}
            <div style={{ display: 'flex', alignItems: 'center', gap: '20px' }}>
              <h1>{t('app.title')}</h1>
              <img src="/header-logo.svg" className="header-logo" />
            </div>
            
            {/* Right: Language selector */}
            <div style={{ flex: 1, display: 'flex', justifyContent: 'flex-end' }}>
              <LanguageSelector />
            </div>
          </div>
        </header>
        
        <div className="main-content">
          {/* Conditional sidebar */}
          {showSidebar && (
            <div className="sidebar">
              <ModuleList {...moduleListProps} />
            </div>
          )}
          
          <div className="content-area">
            {/* Session controls with grouped toggles */}
            <div className="session-controls">
              {/* Session dropdown, new session button, panel toggles */}
              {/* Panel visibility toggles */}
            </div>
            
            {/* Main panel area or full-width docs */}
            {showTerminalPanels ? (
              <ResizablePanels {...panelProps}>
                <Terminal />
                <HelpPanel module={selectedModule} />
                {docBrowserMode ? <DocumentBrowser /> : <DocsPanel {...docsProps} />}
              </ResizablePanels>
            ) : (
              showDocsPanel && <div>/* Full-width docs */</div>
            )}
          </div>
        </div>
      </div>
    </ErrorBoundary>
  );
}

// When AppContent runs in standalone mode it renders only the terminal
function StandaloneTerminalView({ sessionId }) {
  useEffect(() => {
    // ensure the correct session is active and title reflects it
  }, [sessionId]);

  return (
    <div className="standalone-terminal">
      <header className="standalone-terminal__header">…</header>
      <div className="standalone-terminal__body">
        <Terminal />
      </div>
    </div>
  );
}

**Standalone terminal mode highlights**
- Triggered by visiting `/?ttySession=<id>&standalone=1` (the `Open PTY tab` button builds the URL automatically).
- `SessionProvider` receives the session id via `initialSessionId`, ensuring the correct PTY subscription without a full page reload.
- The React terminal renderer is reused unchanged, preserving ANSI colors and input handling in the pop-out tab.
```

### ModuleList.jsx - Hierarchical Module Navigation

**Purpose:** Displays categorized modules with parent/submodule hierarchy and start functionality

**Props Interface:**
```jsx
function ModuleList({ groupedModules, selectedModule, onModuleSelect, onModuleStart })
```

**Key Features:**
- **Hierarchical Display**: Supports parent modules with submodules
- **Visual Hierarchy**: Submodules indented with visual indicators (↳ symbol)
- **Submodule Badges**: Shows count of available submodules
- **Individual Start Buttons**: Each module/submodule has its own start button
- **Selection Highlighting**: Visual feedback for selected modules

**Component Structure:**
```jsx
function ModuleList({ groupedModules, selectedModule, onModuleSelect, onModuleStart }) {
  // Separate parent and submodules for hierarchical rendering
  const renderModules = (modules) => {
    const parentModules = modules.filter(module => !module.parent);
    const subModules = modules.filter(module => module.parent);
    
    return parentModules.map((module) => {
      const childModules = subModules.filter(sub => sub.parent === module.id);
      
      return (
        <React.Fragment key={module.id}>
          {/* Parent module */}
          <li className={`module-item ${selectedModule?.id === module.id ? 'active' : ''}`}
              onClick={() => onModuleSelect(module)}>
            <div className="module-header">
              <div className="module-name">
                {module.name}
                {module.submodule_count > 0 && (
                  <span className="submodule-badge">
                    {module.submodule_count} options
                  </span>
                )}
              </div>
              <button className="start-module-btn"
                      onClick={(e) => {
                        e.stopPropagation();
                        onModuleStart(module);
                      }}>
                Start
              </button>
            </div>
            <p className="module-description">{module.description}</p>
          </li>
          
          {/* Submodules with visual hierarchy */}
          {childModules.map((subModule) => (
            <li key={subModule.id}
                className={`module-item submodule ${selectedModule?.id === subModule.id ? 'active' : ''}`}
                style={{
                  paddingLeft: '2rem',
                  borderLeft: '2px solid #007acc'
                }}>
              <div className="module-header">
                <div className="module-name">↳ {subModule.name}</div>
                <button className="start-module-btn"
                        onClick={(e) => {
                          e.stopPropagation();
                          onModuleStart(subModule);
                        }}>
                  Start
                </button>
              </div>
              <p className="module-description">{subModule.description}</p>
            </li>
          ))}
        </React.Fragment>
      );
    });
  };

  return (
    <div>
      <div className="panel-header">Available Modules</div>
      <ul className="module-list">
        {Object.entries(groupedModules).map(([category, modules]) => (
          <React.Fragment key={category}>
            <li className="module-category">{category}</li>
            {renderModules(modules)}
          </React.Fragment>
        ))}
      </ul>
    </div>
  );
}
```

### HelpPanel.jsx - Context-Sensitive Module Guidance

**Purpose:** Provides the translated quick reference for the currently selected module so users understand the workflow before starting it.

**Key behaviours:**
- Reads module-specific copy from the `help` namespace (see `help.json`)
- Falls back gracefully if a translation key is missing
- Preserves whitespace in standard notes and converts fenced code blocks into formatted `<pre>` sections (ideal for directory trees like the BTRFS bundle layout)

**Code-block rendering helper:**
```jsx
const renderNoteContent = (note, index) => {
  if (typeof note !== 'string') {
    return <span>{`[Invalid note format: ${JSON.stringify(note)}]`}</span>;
  }

  if (!note.includes('```')) {
    return <span style={{ whiteSpace: 'pre-wrap' }}>{note}</span>;
  }

  const segments = note.split('```');

  return (
    <>
      {segments.map((segment, segIndex) => {
        const isCodeBlock = segIndex % 2 === 1;

        if (isCodeBlock) {
          const codeContent = segment.trim();
          return (
            <pre key={segIndex} className="help-note-code">
              {codeContent}
            </pre>
          );
        }

        if (segment.trim().length === 0) {
          return null;
        }

        return (
          <span key={segIndex} style={{ whiteSpace: 'pre-wrap' }}>
            {segment}
          </span>
        );
      })}
    </>
  );
};
```

> **Tip:** Wrap tree diagrams or command examples in triple backticks inside `help.json`. The helper automatically renders them in a monospace block with preserved spacing.

**Styling hint:** Help-panel list items enable `white-space: pre-wrap`, so manual line breaks added in translations remain visible without additional markup.

### Terminal.jsx - Real-time Terminal Display

**Purpose:** Displays live terminal output with ANSI color support and session management

**Key Features:**
- **Real-time Output**: WebSocket-based live output streaming
- **ANSI Color Support**: Full ANSI color code rendering via ansi-to-html
- **Session Switching**: Loads different output when active session changes
- **Auto-scrolling**: Automatically scrolls to latest output
- **Interactive Input**: Terminal input component for running sessions
- **Custom Events**: Uses window events for WebSocket output distribution

**Component Structure:**
```jsx
function Terminal() {
  const { t } = useTranslation('common');
  const { activeSessionId, getActiveSession, getSessionOutput, sendInput, stopSession } = useSession();
  const [localOutput, setLocalOutput] = useState('');
  const outputRef = useRef(null);
  const terminalInputRef = useRef(null);
  const ansiConverter = useRef(new AnsiToHtml());

  // Listen for WebSocket output via custom events
  useEffect(() => {
    const handleOutput = (event) => {
      if (activeSessionId) {
        const newOutput = event.detail;
        setLocalOutput(prev => prev + newOutput);
      }
    };

    window.addEventListener('terminal-output', handleOutput);
    return () => window.removeEventListener('terminal-output', handleOutput);
  }, [activeSessionId]);

  // Load session output when active session changes
  useEffect(() => {
    if (activeSessionId) {
      const sessionOutput = getSessionOutput(activeSessionId);
      setLocalOutput(sessionOutput.join(''));
    } else {
      setLocalOutput(t('terminal.noActiveSession') + '\\n');
    }
  }, [activeSessionId, getSessionOutput]);

  // Auto-scroll to bottom
  useEffect(() => {
    if (outputRef.current) {
      outputRef.current.scrollTop = outputRef.current.scrollHeight;
    }
  }, [localOutput]);

  const handleSendInput = async (input) => {
    if (activeSessionId && input.trim()) {
      try {
        await sendInput(activeSessionId, input);
        setLocalOutput(prev => prev + `> ${input}\\n`);
      } catch (error) {
        console.error('Failed to send input:', error);
        setLocalOutput(prev => prev + `Error sending input: ${error.message}\\n`);
      }
    }
  };

  const activeSession = getActiveSession();
  const isActive = activeSession?.status === 'running';
  
  return (
    <div className="terminal-panel">
      {/* Terminal output with ANSI color rendering */}
      <div className="terminal-output" 
           ref={outputRef}
           onClick={() => terminalInputRef.current?.focus()}
           dangerouslySetInnerHTML={{ 
             __html: localOutput ? ansiConverter.current.toHtml(localOutput) : 'Waiting for module output...' 
           }} />
      
      {/* Terminal input for active sessions */}
      {isActive && (
        <div className="terminal-input-area">
          <TerminalInput 
            ref={terminalInputRef}
            sessionId={activeSessionId}
            onSendInput={handleSendInput}
            onStopSession={stopSession}
            isActive={isActive}
          />
        </div>
      )}
    </div>
  );
}
```

### SessionContext.jsx - Session and WebSocket Management

**Purpose:** Centralized session state management with WebSocket communication

**Key Features:**
- **Session Management**: Track multiple concurrent module sessions
- **WebSocket Handling**: Individual WebSocket connection per session
- **Output Buffering**: Store session output for switching between sessions
- **Language Inheritance**: Pass GUI language preference to backend
- **Auto-Reconnection**: Reconnect WebSocket connections when needed

**Context API:**
```jsx
// Context hook
export const useSession = () => {
  const context = useContext(SessionContext);
  if (!context) {
    throw new Error('useSession must be used within a SessionProvider');
  }
  return context;
};

// Provider component
export const SessionProvider = ({ children }) => {
  const { i18n } = useTranslation();
  const [sessions, setSessions] = useState(new Map());     // Map of session objects
  const [activeSessionId, setActiveSessionId] = useState(null);
  const wsConnections = useRef(new Map());                 // WebSocket connections
```

**Key Methods:**
```jsx
// Start new session with language inheritance
const startNewSession = async (module) => {
  try {
    const response = await fetch(`/api/modules/${module.id}/start`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        language: i18n.language  // Pass current GUI language
      })
    });
    
    if (response.ok) {
      const data = await response.json();
      const newSession = {
        id: data.sessionId,
        module: module.id,
        module_name: module.name,
        created_at: new Date().toISOString(),
        status: 'running',
        output: [],
        wsConnected: false
      };
      
      setSessions(prev => new Map(prev.set(data.sessionId, newSession)));
      setActiveSessionId(data.sessionId);
      connectWebSocket(data.sessionId);
      
      return data.sessionId;
    }
  } catch (error) {
    console.error('Failed to start session:', error);
    throw error;
  }
};

// WebSocket connection management
const connectWebSocket = (sessionId) => {
  const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
  const wsUrl = `${protocol}//${window.location.host}/ws`;
  const ws = new WebSocket(wsUrl);
  
  ws.onopen = () => {
    // Subscribe to session output
    ws.send(JSON.stringify({
      type: 'subscribe',
      content: sessionId
    }));
    
    // Update connection status
    setSessions(prev => {
      const updated = new Map(prev);
      const session = updated.get(sessionId);
      if (session) {
        session.wsConnected = true;
        updated.set(sessionId, session);
      }
      return updated;
    });
  };
  
  ws.onmessage = (event) => {
    const message = JSON.parse(event.data);
    
    switch (message.type) {
      case 'output':
        // Store in session buffer
        setSessions(prev => {
          const updated = new Map(prev);
          const session = updated.get(sessionId);
          if (session) {
            session.output.push(message.content);
            updated.set(sessionId, session);
          }
          return updated;
        });
        
        // Dispatch custom event for terminal component
        window.dispatchEvent(new CustomEvent('terminal-output', {
          detail: message.content
        }));
        break;
        
      case 'session_ended':
        // Update session status
        setSessions(prev => {
          const updated = new Map(prev);
          const session = updated.get(sessionId);
          if (session) {
            session.status = 'completed';
            updated.set(sessionId, session);
          }
          return updated;
        });
        break;
    }
  };
  
  wsConnections.current.set(sessionId, ws);
};

// Send input to session
const sendInput = async (sessionId, input) => {
  try {
    const response = await fetch(`/api/sessions/${sessionId}/input`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ data: input })  // Note: 'data' field, not 'input'
    });
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }
  } catch (error) {
    console.error('Failed to send input:', error);
    throw error;
  }
};

// Get session output
const getSessionOutput = (sessionId) => {
  const session = sessions.get(sessionId);
  return session?.output || [];
};

// Get active session
const getActiveSession = () => {
  return activeSessionId ? sessions.get(activeSessionId) : null;
};
```

## Component Communication Patterns

### Parent-Child Communication
```jsx
// App.jsx passes data and handlers to child components
<ModuleList 
  groupedModules={groupedModules}
  selectedModule={selectedModule}
  onModuleSelect={handleModuleSelect}    // Receives full module object
  onModuleStart={startModule}            // Uses SessionContext internally
/>

<DocsPanel 
  content={moduleDocs}
  selectedModule={selectedModule}
  onModuleSelect={handleModuleSelect}
/>
```

### Context-based Communication
```jsx
// Components consume SessionContext for session management
function Terminal() {
  const { 
    activeSessionId, 
    getActiveSession, 
    getSessionOutput, 
    sendInput, 
    stopSession 
  } = useSession();
  
  // Component logic using context methods
}
```

### Custom Event Communication
```jsx
// SessionContext dispatches events for terminal output
window.dispatchEvent(new CustomEvent('terminal-output', {
  detail: message.content
}));

// Terminal.jsx listens for these events
useEffect(() => {
  const handleOutput = (event) => {
    const newOutput = event.detail;
    setLocalOutput(prev => prev + newOutput);
  };

  window.addEventListener('terminal-output', handleOutput);
  return () => window.removeEventListener('terminal-output', handleOutput);
}, [activeSessionId]);
```

### ExitButton.jsx - Application Exit with Session Management

**Purpose:** Provides safe application exit functionality with session-aware confirmation dialogs

**Key Features:**
- **Session Detection**: Automatically detects and lists active running modules
- **Smart Confirmation**: Shows different dialogs based on session status
- **Progressive Warnings**: Lists each active session with module name and start time
- **Graceful Shutdown**: Coordinates with backend API to properly terminate sessions
- **Browser Integration**: Attempts automatic window close with fallback message

**Component Implementation:**
```jsx
import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useSession } from '../contexts/SessionContext.jsx';

const ExitButton = () => {
  const { t } = useTranslation('common');
  const { sessions } = useSession();
  const [showConfirmDialog, setShowConfirmDialog] = useState(false);
  const [isShuttingDown, setIsShuttingDown] = useState(false);
  
  // Get active sessions for warning display
  const activeSessions = Array.from(sessions.values()).filter(session => 
    session.status !== 'stopped'
  );
  
  const handleConfirmExit = async (force = false) => {
    const url = force ? '/api/shutdown?force=true' : '/api/shutdown';
    const response = await fetch(url, { method: 'POST' });
    const result = await response.json();
    
    // Close browser window after server shutdown
    if (result.activeSessions?.length === 0 || force) {
      setTimeout(() => {
        window.close();
        // Fallback message if window.close() fails
        setTimeout(() => alert(t('exit.browserCloseMessage')), 1000);
      }, 1500);
    }
  };
  
  return (
    <button onClick={() => setShowConfirmDialog(true)}>
      {t('exit.exit')}
    </button>
  );
};
```

**Confirmation Dialog Features:**
- **Session Warnings**: Lists all running modules by name and start time
- **Visual Hierarchy**: Warning colors for destructive actions (red buttons)
- **Two-Step Confirmation**: Cancel/Exit options with clear messaging
- **Internationalization**: All text elements support EN/DE translations
- **Shutdown Progress**: "Shutting down..." status with server response display

**API Integration:**
- **Initial Call**: `POST /api/shutdown` (checks for active sessions)
- **Force Shutdown**: `POST /api/shutdown?force=true` (bypasses warnings)
- **Response Handling**: Processes server response for session details
- **Error Handling**: Graceful degradation with user-friendly error messages

**Translation Keys Used:**
```json
{
  "exit.confirmTitle": "Confirm Exit",
  "exit.activeSessionsWarning": "Active Sessions Running:",
  "exit.sessionsWillBeTerminated": "All running modules will be stopped.",
  "exit.confirmExit": "Exit Application",
  "exit.shuttingDown": "Shutting down...",
  "exit.browserCloseMessage": "Server has been stopped. You can now close this browser window."
}
```

**Integration with App.jsx:**
```jsx
// Header placement alongside LanguageSelector
<div style={{ flex: 1, display: 'flex', justifyContent: 'flex-end', alignItems: 'center' }}>
  <LanguageSelector />
  <ExitButton />
</div>
```

## Development Patterns

### Component Structure Template
```jsx
import React, { useState, useEffect } from 'react';
import { useTranslation } from 'react-i18next';
import { useSession } from '../contexts/SessionContext';

function MyComponent({ prop1, prop2, onAction }) {
  const { t } = useTranslation('common');
  const { sessions, activeSessionId } = useSession();
  const [localState, setLocalState] = useState(null);
  
  // Effects for component lifecycle
  useEffect(() => {
    // Component initialization
  }, []);
  
  // Event handlers
  const handleEvent = (event) => {
    // Handle event, call prop callbacks
    onAction?.(data);
  };
  
  return (
    <div className="my-component">
      {/* Component JSX with translation support */}
      <h2>{t('component.title')}</h2>
      {/* Component content */}
    </div>
  );
}

export default MyComponent;
```

### Error Handling Pattern
```jsx
// All components wrapped in ErrorBoundary
<ErrorBoundary>
  <AppContent />
</ErrorBoundary>

// API calls with try-catch
const fetchData = async () => {
  try {
    const response = await fetch('/api/endpoint');
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }
    const data = await response.json();
    setData(data);
  } catch (error) {
    console.error('API call failed:', error);
    setError(error.message);
  }
};
```

### Translation Integration
```jsx
// Hook usage
const { t } = useTranslation('common');

// Basic translation
<span>{t('actions.start')}</span>

// Translation with fallback
<span>{t(`modules.names.${module.id}`, { defaultValue: module.name })}</span>

// Conditional translation
<span>{showTerminalPanels ? t('panels.hideTerminal') : t('panels.showTerminal')}</span>
```

## Styling Architecture

**CSS Organization:**
- **Global Styles**: `src/index.css` - Fixed dark theme
- **Component Styles**: Inline styles and CSS classes
- **Responsive Design**: Flexbox-based layout system

**Current Theme Values:**
```css
/* Fixed dark theme colors */
body {
  background-color: #181818;
  color: #e8e8e8;
}

.header {
  background-color: #2a2a2a;
  color: #e0e0e0;
}

.sidebar {
  background-color: #2a2a2a;
  border-right: 1px solid #444;
}

.terminal-panel {
  background-color: #1a1a1a;
  color: #e8e8e8;
  font-family: 'Courier New', monospace;
}
```

## Adding New Components

### 1. Create Component File
```jsx
// src/components/NewComponent.jsx
import React, { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useSession } from '../contexts/SessionContext';

function NewComponent({ requiredProp, onAction }) {
  const { t } = useTranslation('common');
  const { activeSessionId } = useSession();
  
  return (
    <div className="new-component">
      <h3>{t('newComponent.title')}</h3>
      {/* Component implementation */}
    </div>
  );
}

export default NewComponent;
```

### 2. Add Translations
```json
// src/i18n/locales/en/common.json
{
  "newComponent": {
    "title": "New Component Title"
  }
}

// src/i18n/locales/de/common.json  
{
  "newComponent": {
    "title": "Neuer Komponenten Titel"
  }
}
```

### 3. Import and Use
```jsx
// In App.jsx or parent component
import NewComponent from './components/NewComponent';

// Usage
<NewComponent 
  requiredProp={someValue}
  onAction={handleAction}
/>
```

### 4. Add CSS Styling
```css
/* In src/index.css or component-specific styles */
.new-component {
  background-color: #2a2a2a;
  border: 1px solid #444;
  border-radius: 4px;
  padding: 1rem;
}

.new-component h3 {
  color: #e0e0e0;
  margin-top: 0;
}
```

## Testing and Development

### Development Workflow
```bash
# Start development server
cd gui/
./dev.sh

# This starts:
# - Vite dev server on :3001 (frontend)  
# - Go backend on :3000 (API/WebSocket)
# - Frontend proxies /api requests to backend
```

### Component Testing
```jsx
// Manual testing checklist:
// - Component renders without errors
// - Translations work in both EN and DE
// - Props are correctly used
// - Event handlers function properly
// - Context data is accessed correctly
// - WebSocket communication works (if applicable)
```

### Browser DevTools Usage
- **React DevTools**: Inspect component state and props
- **Network Tab**: Monitor API calls and WebSocket connections
- **Console**: Check for JavaScript errors and debug logs
- **Application Tab**: Inspect localStorage and session data

---

*This React frontend guide reflects the actual implementation as of the current codebase. For backend API information, see [Backend API Development](doc_backend_api.md).*
