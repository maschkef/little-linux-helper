<!--
File: docs/GUI_DEVELOPER_GUIDE.md
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
-->

# Little Linux Helper - GUI Developer Guide

This document provides an overview and quick start guide for developers working with the Little Linux Helper GUI system. For detailed information on specific topics, refer to the specialized documentation files linked throughout this guide.

**This Guide Contains**: Essential concepts, quick start instructions, architecture overview, and navigation to detailed documentation. Use this as your starting point for GUI development, then refer to specialized guides for in-depth information.

## Project Overview

The Little Linux Helper GUI is a modern web-based interface that provides graphical access to all CLI functionality while maintaining full compatibility with the existing system. It consists of a Go backend server that manages module execution and a React frontend that provides an intuitive user interface.

### Key Features
- **Zero CLI Modification**: Existing modules work without changes
- **Automatic Discovery**: New modules are immediately available in GUI
- **Real-time Experience**: Live terminal output and interaction
- **Multi-language Support**: Complete internationalization system
- **Responsive Design**: Works on desktop and mobile devices
- **Session Management**: Safe application exit with active session detection

### Technology Stack
- **Backend**: Go with Fiber web framework
- **Frontend**: React with Vite build system
- **Communication**: RESTful API + WebSockets for real-time data
- **Process Management**: PTY integration for authentic CLI experience

## Quick Start Guide

### Prerequisites
- **Go 1.18+** (1.21+ recommended)
- **Node.js 18+** with npm
- Linux operating system

### Development Setup
```bash
# Navigate to GUI directory
cd gui/

# Run automated setup
./setup.sh

# Start development servers
./dev.sh
```

This starts:
- Backend server on `localhost:3000`
- Frontend dev server on `localhost:3001`
- Both servers with hot reload enabled

### First Steps
1. Open browser to `http://localhost:3001`
2. Verify all modules appear in sidebar
3. Test module execution and terminal output (modules run interactively inside a PTY)
4. Try language switching (EN/DE)
5. Explore documentation panel
6. For BTRFS Backup, note the streamlined CLI menu with a dedicated "Maintenance" submenu (delete backups, cleanup problematic, cleanup script‑created source snapshots, incremental chain inspection, and orphan `.receiving_*` cleanup). These actions are available interactively from within the module when launched in the GUI.

## Architecture Overview

### System Components

**Go Backend Server (`main.go`)**:
- Discovers and catalogs CLI modules automatically
- Executes modules via PTY processes with proper environment
- Provides RESTful API for module management
- Handles WebSocket connections for real-time output
- Serves React frontend and documentation

**React Frontend (`web/src/`)**:
- Modern single-page application
- Component-based architecture with hooks
- Real-time terminal interface with ANSI color support
- Multi-panel layout with resizable sections
- Complete internationalization system

**Module Integration**:
- Automatic discovery of `mod_*.sh` files
- Environment variable inheritance (LH_ROOT_DIR, LH_GUI_MODE, LH_LANG)
- GUI-aware behavior (skips interactive prompts)
- Category-based organization

### Data Flow
1. **Module Discovery**: Backend scans filesystem for modules
2. **Frontend Request**: User selects module to start
3. **Session Creation**: Backend creates PTY process with proper environment
4. **Real-time Streaming**: Output streamed via WebSocket to frontend
5. **Interactive Input**: User input sent back to running module

## Specialized Documentation

For detailed development information, refer to these specialized guides:

### **[Backend API Development](docs/gui/doc_backend_api.md)**
- Go server architecture and data structures
- RESTful API endpoint reference
- WebSocket communication protocols
- PTY integration and session management
- Adding new API endpoints

### **[Frontend React Development](docs/gui/doc_frontend_react.md)**
- React component architecture and patterns  
- State management with Context and hooks
- Real-time terminal implementation
- Component development best practices
- Adding new React components

### **[Internationalization System](docs/gui/doc_i18n.md)**
- Frontend translation with React i18next
- Backend language inheritance to CLI
- Adding new languages and translation keys
- Translation validation and fallback handling
- Language switching implementation

### **[Module Integration](docs/gui/doc_module_integration.md)**
- How CLI modules automatically integrate
- Adding new module categories
- Environment variable handling
- Module discovery and execution process
- Troubleshooting integration issues

### **[Customization Guide](docs/gui/doc_customization.md)**
- Theme customization and CSS variables
- Creating custom components and hooks
- API extensions and custom endpoints
- Configuration and preferences system
- Plugin architecture and advanced customizations

## Essential Development Patterns

### Component Development
```jsx
import React, { useState, useEffect } from 'react';
import { useTranslation } from 'react-i18next';

function MyComponent({ prop1, onAction }) {
    const { t } = useTranslation('common');
    const [state, setState] = useState(null);
    
    useEffect(() => {
        // Component logic
    }, [prop1]);
    
    const handleEvent = () => {
        onAction?.('result');
    };
    
    return (
        <div className="my-component">
            <h2>{t('component.title')}</h2>
            <button onClick={handleEvent}>
                {t('actions.submit')}
            </button>
        </div>
    );
}
```

### API Integration
```jsx
const useModules = () => {
    const [modules, setModules] = useState([]);
    const [loading, setLoading] = useState(true);
    
    useEffect(() => {
        const fetchModules = async () => {
            try {
                const response = await fetch('/api/modules');
                const data = await response.json();
                setModules(data.modules || []);
            } catch (error) {
                console.error('Failed to fetch modules:', error);
            } finally {
                setLoading(false);
            }
        };
        
        fetchModules();
    }, []);
    
    return { modules, loading };
};
```

### Backend Handler Pattern
```go
func handleApiEndpoint(c *fiber.Ctx) error {
    param := c.Params("param")
    if param == "" {
        return c.Status(400).JSON(fiber.Map{
            "error": "Parameter required",
        })
    }
    
    result, err := processRequest(param)
    if err != nil {
        log.Printf("Request failed: %v", err)
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

## Common Development Tasks

### Adding New Module Categories
1. Create directory structure in `modules/`
2. Update backend discovery logic in `main.go`
3. Add category translations to i18n files
4. Test module discovery and execution

### Adding Translation Keys
1. Add to English translation file first
2. Add corresponding translations in all languages
3. Use in components with `t('new.key')`
4. Test with language switching

### Creating New API Endpoints
1. Define handler function in Go backend
2. Register route in main() function
3. Update frontend to call new endpoint
4. Test with both success and error cases

### Adding React Components
1. Create component file in `src/components/`
2. Implement with proper hooks and translation support
3. Add necessary CSS styles
4. Import and use in parent components

## Build and Deployment

### Development Build
```bash
# Start development environment
./dev.sh

# Both servers running with hot reload:
# Backend: localhost:3000
# Frontend: localhost:3001
```

### Production Build
```bash
# Create optimized production build
./build.sh

# Single executable created:
./gui/little-linux-helper-gui

# Launch options:
./gui_launcher.sh                    # Recommended: Full feature set
./gui_launcher.sh -n -f              # Network access with firewall
./gui/little-linux-helper-gui        # Direct binary (development)
```

### Testing Checklist
- [ ] All modules appear and start correctly
- [ ] Terminal output displays with colors
- [ ] Language switching works properly
- [ ] WebSocket connection remains stable
- [ ] Panel resizing and controls function
- [ ] Documentation displays correctly
- [ ] Mobile/responsive design works

## Getting Help

### Documentation Navigation
- Start with this overview for general understanding
- Refer to **[Backend API](docs/gui/doc_backend_api.md)** for Go development  
- See **[Frontend React](docs/gui/doc_frontend_react.md)** for React development

### Development Resources
- React DevTools browser extension for component debugging
- Go pprof for backend performance analysis
- Browser network tab for API debugging
- WebSocket debugging in browser console

### Best Practices
- Always test with both languages (EN/DE)
- Use TypeScript-style PropTypes for component validation
- Implement proper error handling in all API calls
- Follow established patterns from existing components
- Keep components focused and reusable

---

*This overview provides the foundation for GUI development. For detailed implementation information, refer to the specialized documentation files linked throughout this guide.*
