<!--
File: docs/gui/doc_i18n.md
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
-->

# GUI Internationalization (i18n) System

This document provides comprehensive information about the internationalization system for both the React frontend and Go backend of the Little Linux Helper GUI.

## Overview

The GUI internationalization system handles translation for both frontend (React components) and backend-to-CLI communication, ensuring a consistent multilingual experience across the entire application.

**Supported Languages:**
- **German (de)**: Complete translation support for both GUI and CLI
- **English (en)**: Complete translation support for both GUI and CLI (default and fallback)

**Note**: Currently only English and German are fully supported with complete translation files in the GUI. The CLI system supports additional languages (Spanish and French) which can be found in the `lang/` directory, but GUI support would require creating corresponding translation files in `gui/web/src/i18n/locales/`.

## Frontend Internationalization (React i18next)

### Configuration Structure

**Main Configuration (`src/i18n/index.js`):**
```javascript
import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import LanguageDetector from 'i18next-browser-languagedetector';

// Import translation files
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
  .use(LanguageDetector)
  .use(initReactI18next)
  .init({
    resources,
    fallbackLng: 'en',
    debug: process.env.NODE_ENV === 'development',

    // Detection options with localStorage persistence
    detection: {
      order: ['localStorage', 'navigator', 'htmlTag'],
      caches: ['localStorage'],
      lookupLocalStorage: 'lh-gui-language'
    },

    // Namespace configuration
    defaultNS: 'common',
    ns: ['common', 'help'],

    interpolation: {
      escapeValue: false // React already does escaping
    },

    // Fallback configuration
    fallbackNS: 'common',
    
    // Load namespaces on demand
    load: 'languageOnly', // Load 'en' instead of 'en-US'
    
    // React specific options
    react: {
      useSuspense: false
    },

    // Missing key handling
    saveMissing: true,
    missingKeyHandler: (lng, ns, key, fallbackValue) => {
      console.warn(`[i18n] Missing translation key: "${key}" in namespace "${ns}" for language "${lng}"`);
      console.log(`[i18n] Fallback value: "${fallbackValue}"`);
    },

    // Return key if translation is missing (instead of empty string)
    returnEmptyString: false,
    returnNull: false,
    
    // Custom key separator to avoid conflicts
    keySeparator: '.',
    nsSeparator: ':'
  });

export default i18n;
```

### Translation File Structure

**Directory Organization:**
```
src/i18n/locales/
├── en/                    # English translations
│   ├── common.json        # Common UI elements
│   └── help.json          # Help content
└── de/                    # German translations
    ├── common.json        # Common UI elements
    └── help.json          # Help content
```

**Common Translations (`common.json`):**
```json
{
  "app": {
    "title": "Little Linux Helper",
    "moduleHelp": "Module Help"
  },
  "session": {
    "currentModule": "Current Module:",
    "activeModule": "Active Module:",
    "selectedModule": "Selected Module:",
    "selectedDifferent": "Selected",
    "selectModule": "Select a module from the sidebar to get started",
    "newSession": "+ New Session", 
    "selectModuleFirst": "Please select a module first",
    "startNewSessionTooltip": "Start new session",
    "noActiveSession": "No active session",
    "sessionCount": "{{count}} session",
    "sessionCount_other": "{{count}} sessions",
    "activeSessions": "Active Sessions",
    "startedAt": "Started at {{time}}",
    "closeTooltip": "Close session"
  },
  "dev": {
    "toggle": "Dev Mode",
    "toggleTooltip": "Show/hide developer documentation controls"
  },
  "panels": {
    "hideModules": "Hide Modules",
    "showModules": "Show Modules",
    "hideTerminal": "Hide Terminal", 
    "showTerminal": "Show Terminal",
    "hideHelp": "Hide Help",
    "showHelp": "Show Help",
    "hideDeveloperDocs": "Hide Module Docs",
    "showDeveloperDocs": "📖 Module Docs",
    "hideConfig": "Hide Config",
    "showConfig": "Show Config",
    "comprehensiveDocumentation": "📚 All Documentation",
    "developerDocsTooltip": "View technical documentation and developer guides for the currently selected or active module",
    "comprehensiveDocsTooltip": "Open a full browser with all project documentation, including developer guides, library references, and module documentation"
  },
  "modules": {
    "availableModules": "Available Modules",
    "start": "Start",
    "startTooltip": "Start new session with this module",
    "options": "options",
    "submoduleCount": "{{count}} options",
    "categories": {
      "recovery_and_restarts": "Recovery & Restarts",
      "system_diagnosis_and_analysis": "System Diagnosis & Analysis", 
      "maintenance_and_security": "Maintenance & Security",
      "docker_and_containers": "Docker & Containers",
      "backup_and_recovery": "Backup & Recovery"
    },
    "names": {
      "restarts": "Services & Desktop Restart Options",
      "system_info": "Display System Information",
      "disk": "Disk Tools", 
      "logs": "Log Analysis Tools",
      "packages": "Package Management & Updates",
      "security": "Security Checks",
      "energy": "Energy Management",
      "docker": "Docker Functions",
      "backup": "Backup & Recovery",
      "btrfs_backup": "BTRFS Backup",
      "btrfs_restore": "BTRFS Restore"
    }
  },
  "help": {
    "selectModulePrompt": "Select a module to see help information and available options.",
    "overview": "Overview",
    "availableOptions": "Available Options",
    "importantNotes": "Important Notes",
    "noHelpAvailable": "Help information not available for this module."
  },
  "docs": {
    "notAvailable": "Documentation not available for this module.",
    "errorLoading": "Error loading documentation."
  },
  "terminal": {
    "noActiveSession": "No active session. Select a module to start.",
    "inputPlaceholder": "Type your input and press Enter...",
    "startModulePrompt": "Start a module to enable input",
    "send": "Send",
    "stop": "Stop",
    "stopTooltip": "Stop current session"
  },
  "general": {
    "loading": "Loading...",
    "error": "Error", 
    "success": "Success",
    "cancel": "Cancel",
    "ok": "OK",
    "yes": "Yes",
    "no": "No"
  }
}
```

**Help Content (`help.json`):**
```json
{
  "restarts": {
    "overview": "Restart system services and desktop components safely.",
    "options": [
      "1. Restart Login Manager - Restarts display manager (GDM, SDDM, etc.)",
      "2. Restart Sound System - Restarts PulseAudio/PipeWire",
      "3. Restart Desktop Environment - Restarts your desktop session",
      "4. Restart Network Services - Restarts network components"
    ],
    "notes": [
      "Some operations may require sudo privileges",
      "Desktop restart will close all applications",
      "Network restart may temporarily disconnect you"
    ]
  },
  "system_info": {
    "overview": "View comprehensive information about your computer's hardware, software, and current system status.",
    "options": [
      "1. Operating System & Kernel - Shows your Linux distribution, version, and kernel information",
      "2. CPU Details - Display processor information including model, cores, and performance specs",
      "3. RAM Usage - Check memory usage and see how much RAM is available vs used",
      "4. PCI Devices - List hardware components like graphics cards, network adapters, and sound cards",
      "5. USB Devices - Show connected USB devices like keyboards, mice, storage drives, and webcams",
      "6. Disk Overview - View hard drives, SSDs, and storage devices with their mount points and usage",
      "7. Top Processes - See which programs are using the most CPU and memory resources",
      "8. Network Configuration - Display network settings, IP addresses, and active connections",
      "9. Temperatures/Sensors - Monitor hardware temperatures and fan speeds (if sensors are available)"
    ],
    "notes": [
      "Some detailed information may require administrator privileges",
      "Hardware sensors depend on your system configuration",
      "Temperature readings may not be available on all systems"
    ]
  }
  // ... additional module help content
}
```

#### Advanced Help Formatting

- `notes` entries support manual line breaks. They are rendered with `white-space: pre-wrap`, so newline characters (`\n`) appear as expected.
- Wrap structured content (directory trees, command snippets) in triple backticks. The React help panel detects fenced blocks and renders them inside a styled `<pre>` element with preserved spacing.

**Example with tree layout:**
```json
{
  "btrfs_backup": {
    "notes": [
      "📁 Backup bundle layout:\n```\n${LH_BACKUP_ROOT}${LH_BACKUP_DIR}/\n├── snapshots/\n│   ├── <timestamp>/\n│   │   ├── @/\n│   │   ├── @.backup_complete\n│   │   ├── <subvol>/\n│   │   └── <subvol>.backup_complete\n└── meta/<timestamp>.json\n```"
    ]
  }
}
```

> Remember to add the same formatting to every supported language file so the help panel renders consistently.

### Usage in React Components

**Basic Translation Usage:**
```jsx
import { useTranslation } from 'react-i18next';

function MyComponent() {
    const { t } = useTranslation('common');
    
    return (
        <div>
            <h1>{t('app.title')}</h1>
            <p>{t('app.subtitle')}</p>
        </div>
    );
}
```

**Translation with Parameters:**
```jsx
// Translation with interpolation
const message = t('status.active_sessions', { count: sessions.length });

// JSON structure:
{
    "status": {
        "active_sessions": "{{count}} active session(s)"
    }
}
```

**Namespace-Specific Translations:**
```jsx
// Use specific namespace
const { t: tHelp } = useTranslation('help');
const helpText = tHelp('modules.backup.overview');

// Or with namespace parameter
const { t } = useTranslation(['common', 'help']);
const title = t('modules.backup.title', { ns: 'help' });
```

**Safe Translation with Fallbacks:**
```jsx
// Error-safe translation function
const safeTranslate = useCallback((key, fallback = key, options = {}) => {
    try {
        const result = t(key, options);
        // Check if translation was found (i18next returns key if not found)
        return result !== key ? result : fallback;
    } catch (error) {
        console.warn(`Translation missing for key: ${key}`);
        return fallback;
    }
}, [t]);

// Usage
const text = safeTranslate('some.key', 'Default Text');
```

### Language Switching

**Language Selector Component:**
```jsx
import React from 'react';
import { useTranslation } from 'react-i18next';

const languages = [
  { code: 'en', name: 'English', flag: '🇺🇸' },
  { code: 'de', name: 'Deutsch', flag: '🇩🇪' }
];

function LanguageSelector() {
  const { i18n, t } = useTranslation();

  const changeLanguage = (languageCode) => {
    i18n.changeLanguage(languageCode);
    // Store in localStorage for persistence (automatic via LanguageDetector)
    localStorage.setItem('lh-gui-language', languageCode);
  };

  return (
    <div className="language-selector" style={{
      display: 'flex',
      alignItems: 'center',
      gap: '8px',
      color: '#ecf0f1',
      fontSize: '14px'
    }}>
      <span>🌐</span>
      <select 
        value={i18n.language} 
        onChange={(e) => changeLanguage(e.target.value)}
        style={{
          backgroundColor: '#34495e',
          color: '#ecf0f1',
          border: '1px solid #5a6c7d',
          borderRadius: '4px',
          padding: '4px 8px',
          fontSize: '12px',
          outline: 'none',
          cursor: 'pointer'
        }}
      >
        {languages.map((lang) => (
          <option key={lang.code} value={lang.code}>
            {lang.flag} {lang.name}
          </option>
        ))}
      </select>
    </div>
  );
}

export default LanguageSelector;
```

**Persistence of Language Selection:**
```jsx
// Language persistence is handled automatically by i18next-browser-languagedetector
// Configuration in src/i18n/index.js:
detection: {
  order: ['localStorage', 'navigator', 'htmlTag'],
  caches: ['localStorage'],
  lookupLocalStorage: 'lh-gui-language'
}

// Manual storage in LanguageSelector for explicit persistence:
const changeLanguage = (languageCode) => {
  i18n.changeLanguage(languageCode);
  localStorage.setItem('lh-gui-language', languageCode);
};

// Language is automatically loaded on app startup from localStorage
```

## Backend Language Inheritance

### GUI to CLI Language Passing

**Session Creation with Language:**
```jsx
// In SessionContext.jsx
const startNewSession = async (module) => {
    const currentLanguage = i18n.language; // Get current GUI language
    
    const response = await fetch(`/api/modules/${module.id}/start`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ 
            language: currentLanguage 
        })
    });
    
    // Session inherits GUI language automatically
};
```

**Backend Language Processing (Go):**
```go
// In main.go
type StartModuleRequest struct {
    Language string `json:"language"`
}

func startModule(c *fiber.Ctx) error {
    var req StartModuleRequest
    if err := c.BodyParser(&req); err != nil {
        req.Language = "en" // Default fallback
    }
    
    // Validate language - fallback to English if invalid
    if req.Language == "" || (req.Language != "en" && req.Language != "de") {
        req.Language = "en"
    }
    
    // Set environment variable for CLI module
    env := os.Environ()
    env = append(env, 
        "LH_ROOT_DIR="+lhRootDir,
        "LH_GUI_MODE=true",
        "LH_LANG="+req.Language, // Pass language to CLI
    )
    
    cmd := exec.Command("bash", modulePath)
    cmd.Env = env
    
    // CLI module automatically uses LH_LANG for translations
}
```

### Environment Variable Integration

**CLI Module Language Detection:**
```bash
# In CLI modules (automatic via lib_common.sh)
# LH_LANG is automatically set by GUI backend
# CLI internationalization system uses this variable
# No changes needed in existing modules

echo "$(lh_msg 'WELCOME_MESSAGE')"  # Uses LH_LANG from GUI
```

## Translation Management

### Adding New Translation Keys

**Step-by-Step Process:**

1. **Add English Translation First:**
```json
// src/i18n/locales/en/common.json
{
    "new_feature": {
        "title": "New Feature",
        "description": "Description of the new feature",
        "action_button": "Perform Action"
    }
}
```

2. **Add German Translation:**
```json
// src/i18n/locales/de/common.json
{
    "new_feature": {
        "title": "Neue Funktion",
        "description": "Beschreibung der neuen Funktion", 
        "action_button": "Aktion Ausführen"
    }
}
```

3. **Use in Components:**
```jsx
const { t } = useTranslation('common');

return (
    <div className="new-feature">
        <h2>{t('new_feature.title')}</h2>
        <p>{t('new_feature.description')}</p>
        <button>{t('new_feature.action_button')}</button>
    </div>
);
```

4. **Test Both Languages:**
```jsx
// Test component with language switching
// Verify all keys display correctly
// Check for missing translations in console
```

### Key Naming Conventions

**Hierarchical Structure:**
```json
{
    "category": {
        "subcategory": {
            "specific_item": "Translation"
        }
    }
}
```

**Consistent Naming Patterns:**
```json
{
    "actions": {
        "button_save": "Save",
        "button_cancel": "Cancel",
        "button_delete": "Delete"
    },
    "messages": {
        "success_save": "Successfully saved",
        "error_network": "Network error occurred",
        "warning_unsaved": "You have unsaved changes"
    },
    "labels": {
        "field_name": "Name",
        "field_email": "Email",
        "field_password": "Password"
    }
}
```

### Translation Validation

**Missing Translation Detection:**
```jsx
// Development helper to detect missing translations
const useTranslationValidator = () => {
    const { t, i18n } = useTranslation();
    
    const validateTranslation = useCallback((key, namespace = 'common') => {
        const translation = i18n.getResource(i18n.language, namespace, key);
        
        if (!translation) {
            console.warn(`Missing translation: ${namespace}:${key} for language: ${i18n.language}`);
            return false;
        }
        
        return true;
    }, [i18n]);
    
    return { validateTranslation };
};
```

**Translation Coverage Report:**
```javascript
// Development script to check translation coverage
const checkTranslationCoverage = () => {
    const enKeys = getAllKeys(enTranslations);
    const deKeys = getAllKeys(deTranslations);
    
    const missingInGerman = enKeys.filter(key => !deKeys.includes(key));
    const extraInGerman = deKeys.filter(key => !enKeys.includes(key));
    
    console.log('Missing in German:', missingInGerman);
    console.log('Extra in German:', extraInGerman);
};
```

## Error Handling and Fallbacks

### Frontend Error Handling

**Missing Translation Handling:**
```jsx
// Component-level error boundary for translations
const TranslationErrorBoundary = ({ children, fallback }) => {
    const [hasError, setHasError] = useState(false);
    
    useEffect(() => {
        const handleError = (error) => {
            if (error.message?.includes('i18n')) {
                console.error('Translation error:', error);
                setHasError(true);
            }
        };
        
        window.addEventListener('error', handleError);
        return () => window.removeEventListener('error', handleError);
    }, []);
    
    if (hasError) {
        return <div className="translation-error">{fallback}</div>;
    }
    
    return children;
};
```

**Safe Translation Hook:**
```jsx
const useSafeTranslation = (namespace = 'common') => {
    const { t, i18n } = useTranslation(namespace);
    
    const safeT = useCallback((key, defaultValue = key, options = {}) => {
        try {
            const result = t(key, { ...options, defaultValue });
            
            // Log missing translations in development
            if (process.env.NODE_ENV === 'development' && result === key) {
                console.warn(`Missing translation: ${namespace}:${key}`);
            }
            
            return result;
        } catch (error) {
            console.error(`Translation error for key ${key}:`, error);
            return defaultValue;
        }
    }, [t, namespace]);
    
    return { t: safeT, i18n };
};
```

### Graceful Degradation

**Component Fallback Strategy:**
```jsx
const ComponentWithTranslations = () => {
    const { t } = useSafeTranslation('common');
    const [translationError, setTranslationError] = useState(false);
    
    // Fallback content for critical translations
    const fallbackContent = {
        title: 'Little Linux Helper',
        startButton: 'Start',
        stopButton: 'Stop'
    };
    
    const getTextSafely = (key, fallback) => {
        try {
            const text = t(key);
            return text !== key ? text : fallback;
        } catch {
            return fallback;
        }
    };
    
    return (
        <div>
            <h1>{getTextSafely('app.title', fallbackContent.title)}</h1>
            <button>{getTextSafely('actions.start', fallbackContent.startButton)}</button>
        </div>
    );
};
```

## Adding New Languages

### Complete Language Addition Process

**1. Create Translation Directory Structure:**
```bash
mkdir -p src/i18n/locales/fr
touch src/i18n/locales/fr/common.json
touch src/i18n/locales/fr/help.json
```

**2. Create Translation Files:**
```json
// src/i18n/locales/fr/common.json
{
    "app": {
        "title": "Little Linux Helper",
        "subtitle": "Boîte à outils d'administration système"
    },
    "actions": {
        "start": "Démarrer",
        "stop": "Arrêter",
        "send": "Envoyer"
    }
    // ... continue with all translations
}
```

**3. Update i18n Configuration:**
```javascript
// src/i18n/index.js
import frCommon from './locales/fr/common.json';
import frHelp from './locales/fr/help.json';

const resources = {
    en: { common: enCommon, help: enHelp },
    de: { common: deCommon, help: deHelp },
    fr: { common: frCommon, help: frHelp } // Example: Add French (requires translation files)
};
```

**4. Add to Language Selector:**
```jsx
const languages = [
    { code: 'en', name: 'English', flag: '🇺🇸' },
    { code: 'de', name: 'Deutsch', flag: '🇩🇪' },
    { code: 'fr', name: 'Français', flag: '🇫🇷' } // Example: Add French (requires translation files)
];
```

**Note**: This is an example for adding French. Currently only English (en) and German (de) are fully supported with complete translation resources.

**5. Update CLI Language Support:**
```bash
# Create CLI translation files (if not already existing)
mkdir -p lang/fr
# Copy and translate CLI language files
cp lang/en/* lang/fr/
# Translate content in French files
```

**6. Test New Language:**
- Switch to new language in GUI
- Test all components display correctly
- Verify CLI modules receive correct language
- Check for missing translations in console

## Best Practices

### Translation Key Design
- Use hierarchical structures for organization
- Keep keys descriptive and consistent
- Avoid abbreviations in key names
- Group related translations together

### Performance Optimization
- Use namespace splitting to avoid loading unused translations
- Implement lazy loading for large translation files
- Cache translations in production builds

### Development Workflow
- Always create English translations first
- Use translation validation tools in development
- Implement automated translation coverage reports
- Test all languages before deployment

### Accessibility
- Ensure text expansion doesn't break layouts
- Test with screen readers in all languages
- Consider right-to-left languages for future expansion

---

*This document provides comprehensive internationalization information for the GUI system. For additional development guides, see [Frontend React Development](doc_frontend_react.md) and [Backend API Development](doc_backend_api.md).*
