<!--
File: docs/gui/doc_customization.md
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
-->

# GUI Customization Guide

This document provides information about customizing the Little Linux Helper GUI system, including current styling approaches, planned customization features, and extension possibilities.

## Current GUI Styling

### Fixed Dark Theme Implementation

The current GUI implementation uses a **fixed dark theme** with hardcoded CSS colors. The styling is not yet modular or theme-switchable.

**Current Color Scheme (`web/src/index.css`):**
```css
body {
  background-color: #181818; 
  color: #e8e8e8; 
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen',
    'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue', sans-serif;
}

.header {
  background-color: #2a2a2a;
  color: #e0e0e0;
  border-bottom: 2px solid #444;
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

### Current Customizable Elements

**What can currently be customized:**
1. **Language Selection** - EN/DE language switching via LanguageSelector component
2. **Panel Layout** - Resizable panels for terminal, help, and documentation
3. **Developer Controls** - 🔧 Dev Mode toggle to show/hide advanced documentation features
4. **CSS Overrides** - Direct CSS file modifications (requires rebuild)

### User Preference Storage (localStorage)

**Current persistent settings:**
- **Language Preference** - Saved as `'lh-gui-language'` (inherited from i18next)
- **Developer Mode** - Saved as `'lh-gui-dev-controls'` (boolean, default: false)

**Storage Implementation:**
```javascript
// Language persistence (handled by i18next)
localStorage.setItem('lh-gui-language', languageCode);

// Developer controls persistence
localStorage.setItem('lh-gui-dev-controls', 'true'|'false');
```

**What is NOT currently customizable:**
- Theme switching (light/dark/custom themes)
- Color scheme changes via UI
- Font size adjustments
- Panel layout persistence

## Planned Theme System (Future Development)

### CSS Custom Properties Architecture (Planned)

**Future implementation will include CSS variables for theming:**
```css
:root {
  /* Color Palette - Planned */
  --primary-color: #007acc;
  --primary-hover: #005a99;
  --secondary-color: #f8f9fa;
  --accent-color: #28a745;
  
  /* Background Colors - Planned */
  --background-primary: #ffffff;
  --background-secondary: #f8f9fa;
  --background-tertiary: #e9ecef;
  
  /* Text Colors - Planned */
  --text-primary: #212529;
  --text-secondary: #6c757d;
  --text-muted: #adb5bd;
}
```

### Theme Toggle Component (Future Feature)

**Note**: Theme switching is not currently implemented. The GUI uses a fixed dark theme.

**Implementation Steps Required:**
1. Convert hardcoded colors to CSS custom properties
2. Create theme configuration system
3. Implement theme toggle component
4. Add theme persistence (localStorage)
5. Update all components to use CSS variables

## Current Component Customization

### Existing Components (Available for Modification)

**Currently Implemented Components:**
- `LanguageSelector.jsx` - Language switching (EN/DE)
- `ModuleList.jsx` - Module navigation sidebar
- `Terminal.jsx` - Terminal output display
- `HelpPanel.jsx` - Context-sensitive help
- `DocsPanel.jsx` - Documentation viewer
- `DocumentBrowser.jsx` - Document browser interface
- `ResizablePanels.jsx` - Panel layout system
- `SessionDropdown.jsx` - Session management
- `ErrorBoundary.jsx` - Error handling wrapper

### Modifying Existing Components

**Example: Customizing LanguageSelector:**
```jsx
// Current implementation in LanguageSelector.jsx
const languages = [
  { code: 'en', name: 'English', flag: '🇺🇸' },
  { code: 'de', name: 'Deutsch', flag: '🇩🇪' }
];

// To add more languages, modify the array:
const languages = [
  { code: 'en', name: 'English', flag: '🇺🇸' },
  { code: 'de', name: 'Deutsch', flag: '🇩🇪' },
  // Note: Adding languages below requires creating corresponding translation files
  // { code: 'es', name: 'Español', flag: '🇪🇸' },  // Would need translation files in gui/web/src/i18n/locales/es/
  // { code: 'fr', name: 'Français', flag: '🇫🇷' } // Would need translation files in gui/web/src/i18n/locales/fr/
];
```

**Note**: Currently only English and German are fully supported with complete translation files. Additional languages would require creating translation files in `gui/web/src/i18n/locales/` and updating the CLI modules' language support.

**Current CSS Styling Approach:**
```css
/* Direct CSS modifications in index.css */
.language-selector {
  /* Current styling is mixed with component-specific CSS */
  /* No CSS variables or theming system yet */
  background-color: #2a2a2a; /* Hardcoded colors */
  color: #e0e0e0;
  border: 1px solid #444;
}

/* To customize: modify colors directly in CSS files */
.language-selector:hover {
  background-color: #3a3a3a; /* Hardcoded hover state */
}
```

## Practical Customization Steps

### 1. CSS Styling Modifications

**Direct CSS File Editing:**
```bash
# Edit main stylesheet
cd gui/web/src/
vim index.css

# Rebuild after changes
cd ../../
./build.sh
```

**Common Customization Examples:**
```css
/* Change header colors */
.header {
    background-color: #1e3a8a; /* Change from #2a2a2a to blue */
    border-bottom: 2px solid #3b82f6;
}

/* Modify terminal appearance */
.terminal-panel {
    background-color: #0f172a; /* Darker terminal background */
    color: #f1f5f9; /* Lighter text */
    font-family: 'JetBrains Mono', 'Courier New', monospace; /* Custom font */
    font-size: 14px; /* Adjust font size */
}

/* Customize sidebar */
.sidebar {
    background-color: #1e293b; /* Different sidebar color */
    width: 400px; /* Change width from 380px */
}
```

### 2. Adding New Translation Keys

**Steps to add custom translations:**
1. Edit language files in `gui/web/src/i18n/locales/`
2. Add keys to both `en/common.json` and `de/common.json`
3. Rebuild the application

**Example Translation Addition:**
```json
// In en/common.json
{
  "customization": {
    "title": "Customization",
    "theme": "Theme",
    "apply": "Apply Changes"
  }
}

// In de/common.json  
{
  "customization": {
    "title": "Anpassung", 
    "theme": "Design",
    "apply": "Änderungen anwenden"
  }
}
```

### 3. Panel Layout Customization

**Current Panel Configuration:**
The panel system is implemented in `ResizablePanels.jsx` with these default proportions:
- Terminal Panel: 50% width
- Help Panel: 25% width  
- Docs Panel: 25% width

**To modify default panel sizes:**
```jsx
// In App.jsx, modify the initial state
const [panelWidths, setPanelWidths] = useState({ 
    terminal: 60, // Change from 50 to 60%
    help: 20,     // Change from 25 to 20%
    docs: 20      // Change from 25 to 20%
});
```

## API Extensions (Advanced)

### Adding New Backend Endpoints

**Current API Structure:**
The backend in `gui/main.go` provides these existing endpoints:
- `/api/modules` - List all modules
- `/api/modules/:id/start` - Start a module session
- `/api/modules/:id/docs` - Get module documentation
- `/api/sessions` - List active sessions
- `/api/docs` - List all available documentation

**Adding Custom Endpoints:**
```go
// In main.go, add to the API routes section
func setupApiRoutes(api fiber.Router) {
    // Existing routes...
    api.Get("/modules", getModules)
    api.Get("/modules/:id/docs", getModuleDocs)
    
    // Add custom endpoint
    api.Get("/custom/system-info", getCustomSystemInfo)
}

// Implement custom endpoint
func getCustomSystemInfo(c *fiber.Ctx) error {
    // Gather custom system information
    info := map[string]interface{}{
        "timestamp": time.Now().Unix(),
        "uptime":    getSystemUptime(),
        "sessions":  len(sessionManager.sessions),
    }
    
    return c.JSON(fiber.Map{
        "success": true,
        "data":    info,
    })
}

func getSystemUptime() string {
    // Implementation to get system uptime
    cmd := exec.Command("uptime", "-p")
    output, _ := cmd.Output()
    return strings.TrimSpace(string(output))
}
```

**Frontend Integration:**
```jsx
// Create custom API service
const customApi = {
    async getSystemInfo() {
        const response = await fetch('/api/custom/system-info');
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}`);
        }
        return response.json();
    }
};

// Use in component
function SystemInfoWidget() {
    const [info, setInfo] = useState(null);
    
    useEffect(() => {
        const loadInfo = async () => {
            try {
                const result = await customApi.getSystemInfo();
                setInfo(result.data);
            } catch (error) {
                console.error('Failed to load system info:', error);
            }
        };
        
        loadInfo();
        const interval = setInterval(loadInfo, 30000); // Update every 30 seconds
        
        return () => clearInterval(interval);
    }, []);
    
    return (
        <div className="system-info-widget">
            {info && (
                <>
                    <p>Uptime: {info.uptime}</p>
                    <p>Active Sessions: {info.sessions}</p>
                </>
            )}
        </div>
    );
}
```

## Current Limitations and Future Plans

### What's NOT Currently Available

**Missing Features (Planned for Future):**
- Theme switching (light/dark/custom themes)
- User preference persistence
- CSS custom properties/variables system
- Settings panel/configuration UI
- Plugin system architecture
- Advanced WebSocket message handling
- Custom component system
- Configuration file editing interface

### Future Development Roadmap

**Phase 1: Theme System (Planned)**
- Convert hardcoded CSS to CSS custom properties
- Implement theme toggle component
- Add theme persistence with localStorage
- Support for multiple color schemes

**Phase 2: User Preferences (Planned)**
- Backend preferences storage system
- Settings panel UI
- Panel layout persistence
- User customization options

**Phase 3: Advanced Customization (Planned)**
- Plugin system architecture
- Custom component registration
- Extended API customization
- Configuration file editing

### Contributing Customizations

**How to Contribute:**
1. Fork the repository
2. Make customization changes
3. Test with both languages (EN/DE)
4. Submit pull request with documentation

**Development Setup for Customization:**
```bash
# Clone the repository
git clone https://github.com/maschkef/little-linux-helper.git
cd little-linux-helper/gui

# Install dependencies
./setup.sh

# Start development server
./dev.sh

# Make changes to:
# - web/src/index.css (styling)
# - web/src/components/*.jsx (components)
# - web/src/i18n/locales/* (translations)

# Build for production
./build.sh
```

### Best Practices for Current Customizations

**CSS Modifications:**
- Always test in both light terminals and dark backgrounds
- Ensure sufficient color contrast for accessibility
- Test with long module names and text
- Verify panel resizing still works correctly

**Component Modifications:**
- Maintain existing PropTypes validation
- Keep translation support with `useTranslation`
- Test with both EN and DE languages
- Ensure error boundaries still function

**API Extensions:**
- Follow existing error handling patterns
- Maintain consistent JSON response format
- Add proper logging for debugging
- Test WebSocket connections remain stable

---

*This customization guide reflects the current state of the GUI system. Many advanced features are planned for future development. For current development information, see [Frontend React Development](doc_frontend_react.md) and [Backend API Development](doc_backend_api.md).*
