<!--
File: docs/gui/doc_module_integration.md
Copyright (c) 2025 maschkef
SPDX-License-Identifier: Apache-2.0

This project is part of the 'little-linux-helper' collection.
Licensed under the Apache License 2.0. See the LICENSE file in the project root for more information.
-->

# GUI Module Integration Guide

This document explains how CLI modules automatically integrate with the GUI system, how to add new module categories, and how the module discovery and execution process works.

## Overview

The Little Linux Helper GUI provides seamless integration with all CLI modules through a registry-based backend interface. New CLI modules are automatically discovered when you add their metadata file - no code changes required in the backend.

**Key Integration Features:**
- **Automatic Discovery**: New modules appear automatically when metadata is added
- **Zero Backend Changes**: No need to edit Go code to add modules
- **Full CLI Compatibility**: All CLI functionality preserved
- **Environment Inheritance**: Proper variable passing from GUI to CLI
- **Real-time Execution**: Live terminal output and interaction
- **Registry-Based**: Single source of truth for both CLI and GUI

## Module Discovery Process

### Registry-Based Discovery

**Current Implementation:**
The GUI backend loads modules from a JSON registry cache that is automatically built from metadata files. This provides stable, predictable module information with automatic discovery of new modules.

The registry cache is loaded via a subprocess call to `scripts/registry_cache_helper.sh`:

```go
func loadModuleRegistry() (*RegistryCache, error) {
    cmd := exec.Command(filepath.Join(lhRootDir, "scripts/registry_cache_helper.sh"), "rebuild-or-read")
    cmd.Dir = lhRootDir
    cmd.Env = os.Environ()
    
    output, err := cmd.Output()
    if err != nil {
        return nil, fmt.Errorf("failed to load registry: %w", err)
    }
    
    cachePath := strings.TrimSpace(string(output))
    data, err := os.ReadFile(cachePath)
    // ... parse JSON registry
}
```

**Registry Structure:**
The registry contains:
- **Modules Array**: All discovered modules with metadata
- **Categories Array**: Category definitions with ordering
- **Schema Version**: For compatibility handling
- **Cache Metadata**: Build time, loader version, validation hash

**Module Categories (Registry-Defined):**
Categories are defined in `modules/meta/_categories.json` and can be extended by mods:
- **system**: System Diagnosis & Analysis
- **maintenance**: Maintenance & Security
- **backup**: Backup & Recovery
- **docker**: Docker & Containers  
- **restart**: Recovery & Restarts

**Adding New Modules:**
To add a new module to the GUI:
1. Create the CLI module script (e.g., `modules/mod_newfeature.sh`)
2. Create metadata file: `modules/meta/mod_newfeature.json`
3. Add translations in `lang/*/newfeature.sh`
4. Add documentation in `docs/modules/doc_newfeature.md`
5. Restart the GUI server - module appears automatically!

No code changes required in the backend!

### Module Registry API

**Note**: Modules and categories are loaded from the registry cache. The `/api/modules` endpoint returns both modules and categories with translation keys.

**API Response Structure:**
```json
{
  "modules": [
    {
      "id": "backup",
      "name": "Backup Tools",
      "name_key": "BACKUP_MODULE_NAME",
      "description": "BTRFS, TAR and RSYNC backup/restore operations",
      "description_key": "BACKUP_MODULE_DESC",
      "path": "modules/mod_backup.sh",
      "category": "backup",
      "submodule_count": 6,
      "docs": "mod/doc_backup.md"
    }
  ],
  "categories": [
    {
      "id": "backup",
      "name_key": "CATEGORY_BACKUP",
      "fallback_name": "Backup & Recovery",
      "order": 30
    }
  ]
}
```

**Category Translation Integration:**
Categories are automatically translated using the GUI's internationalization system:

```json
// Frontend translation mapping
{
    "modules": {
        "category": {
            "recovery": "Recovery & Restarts",
            "backup": "Backup & Recovery",
            "docker": "Docker & Containers", 
            "system": "System Diagnosis & Analysis",
            "security": "Maintenance & Security"
        }
    }
}
```

## Module Execution Environment

### Environment Variable Setup

The backend currently constructs the execution environment directly inside `startModule` rather than delegating to a helper. The relevant snippet looks like this:

```go
cmd := exec.Command("stdbuf", "-i0", "-o0", "-e0", "bash", scriptPath)
cmd.Dir = lhRootDir

cmd.Env = append(os.Environ(),
    "LH_ROOT_DIR="+lhRootDir,
    "LH_GUI_MODE=true",
    "LH_LANG="+req.Language,
    "TERM=xterm-256color",
    "FORCE_COLOR=1",
    "COLUMNS=120",
    "LINES=40",
    "LANG="+os.Getenv("LANG"),
    "PS1=$ ",
)
```

This ensures every module receives the same variables the CLI provides while adding a few GUI conveniences (fixed terminal size, forced colour output).

**Environment Variable Explanation:**

1. **`LH_ROOT_DIR`**:
   - **Purpose**: Provides absolute path to project root
   - **Usage**: Required by all modules to locate libraries and config files
   - **Example**: `/home/user/little-linux-helper`

2. **`LH_GUI_MODE=true`**:
   - **Purpose**: Signals modules they're running in GUI context
   - **Behavior**: Modules automatically skip interactive prompts
   - **Implementation**: Already handled in existing modules via `lib_common.sh`

3. **`LH_LANG`**:
   - **Purpose**: Inherits language selection from GUI
   - **Values**: `en`, `de`, `es`, `fr`
   - **Integration**: Automatically used by CLI internationalization system

> **Authentication note:** All HTTP/WebSocket endpoints are secured by the GUI backend. Modules do not need to implement any authentication logic—the browser must already be logged in (session cookie or Basic Auth) before it can start a module.

### GUI-Aware Module Behavior

**Automatic Prompt Skipping:**
Existing modules already support GUI mode through the common library:

```bash
# In lib_ui.sh (already implemented)
lh_press_any_key() {
    if [[ "$LH_GUI_MODE" == "true" ]]; then
        return 0  # Skip prompt in GUI mode
    fi
    
    echo
    lh_msgln 'PRESS_ANY_KEY'
    read -n 1 -s -r
    echo
}
```

**Menu Item Visibility Control:**
GUI mode also controls visibility of CLI-specific menu items:

```bash
# In lib_ui.sh (already implemented)
lh_print_gui_hidden_menu_item() {
    local number="$1"
    local text="$2"
    
    if lh_gui_mode_active; then
        return  # Hide menu item in GUI mode
    fi
    
    lh_print_menu_item "$number" "$text"
}
```

**Usage in Module Menus:**
```bash
# Module menu implementation
lh_print_header "$(lh_msg 'MODULE_MENU_TITLE')"

lh_print_menu_item "1" "$(lh_msg 'OPTION_ONE')"
lh_print_menu_item "2" "$(lh_msg 'OPTION_TWO')"

# This item only appears in CLI mode
lh_print_gui_hidden_menu_item "0" "$(lh_msg 'BACK_TO_MAIN_MENU')"

# Menu handling with GUI mode validation
case $option in
    1) action_one ;;
    2) action_two ;;
    0)
        # Validate selection in GUI mode
        if lh_gui_mode_active; then
            lh_log_msg "DEBUG" "Invalid selection: '$option'"
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'INVALID_SELECTION')${LH_COLOR_RESET}"
            continue
        fi
        return 0  # Exit to main menu in CLI
        ;;
esac
```

**Rationale:**
- GUI provides its own navigation controls and back buttons
- "Back to Main Menu" options would be redundant and confusing in GUI
- Modules remain fully functional in both CLI and GUI modes
- Single codebase works seamlessly in both interfaces

**Language Inheritance:**
Modules automatically use GUI language setting:

```bash
# In module scripts (no changes needed)
source "$LH_ROOT_DIR/lib/lib_common.sh"

# LH_LANG is automatically set from GUI
echo "$(lh_msg 'WELCOME_MESSAGE')"  # Uses GUI language
```

## Adding New Module Categories

### Step-by-Step Category Addition

**1. Add Category to Registry:**
```bash
# Edit the categories file
vi modules/meta/_categories.json

# Add new category entry
{
  "id": "network",
  "order": 60,
  "name_key": "CATEGORY_NETWORK",
  "fallback_name": "Network Tools"
}
```

**2. Create Category Translations:**
```bash
# Add to common language files
# lang/en/common.sh
MSG_EN[CATEGORY_NETWORK]="Network Tools"

# lang/de/common.sh  
MSG_DE[CATEGORY_NETWORK]="Netzwerk-Tools"
```

**3. Create Module with New Category:**
```bash
# Create module script
cat > modules/mod_network_info.sh << 'EOF'
#!/bin/bash
source "$LH_ROOT_DIR/lib/lib_common.sh"
lh_detect_package_manager

lh_load_language_module "network_info"
lh_load_language_module "common"

echo "$(lh_msg 'NETWORK_INFO_TITLE')"
# Network information gathering logic here
EOF

chmod +x modules/mod_network_info.sh
```

**4. Create Module Metadata:**
```bash
cat > modules/meta/mod_network_info.json << 'EOF'
{
  "schema_version": 1,
  "id": "network_info",
  "entry": "modules/mod_network_info.sh",
  "category": {
    "id": "network"
  },
  "order": 10,
  "docs": "mod/doc_network_info.md",
  "display": {
    "name_key": "NETWORK_INFO_MODULE_NAME",
    "description_key": "NETWORK_INFO_MODULE_DESC",
    "fallback_name": "Network Information",
    "fallback_description": "Display network configuration and status"
  },
  "expose": {
    "cli": true,
    "gui": true
  },
  "enabled": true
}
EOF
```

**5. Create Module-Specific Translations:**
```bash
# Create translation files for new modules
mkdir -p lang/en lang/de

# English translations
cat > lang/en/network_info.sh << 'EOF'
#!/bin/bash
[[ ! -v MSG_EN ]] && declare -A MSG_EN

MSG_EN[NETWORK_INFO_MODULE_NAME]="Network Information"
MSG_EN[NETWORK_INFO_MODULE_DESC]="Display network configuration and status"
MSG_EN[NETWORK_INFO_TITLE]="Network Information Analysis"
MSG_EN[NETWORK_CONFIG_FOUND]="Network configuration detected"
EOF

# German translations  
cat > lang/de/network_info.sh << 'EOF'
#!/bin/bash
[[ ! -v MSG_DE ]] && declare -A MSG_DE

MSG_DE[NETWORK_INFO_MODULE_NAME]="Netzwerk-Information"
MSG_DE[NETWORK_INFO_MODULE_DESC]="Netzwerkkonfiguration und -status anzeigen"
MSG_DE[NETWORK_INFO_TITLE]="Netzwerk-Informations-Analyse"
MSG_DE[NETWORK_CONFIG_FOUND]="Netzwerkkonfiguration erkannt"
EOF
```

**6. Test New Category:**
```bash
# Restart GUI to discover new modules
./gui_launcher.sh
# OR (direct binary):
./gui/little-linux-helper-gui

# Verify in browser:
# - New category appears automatically in sidebar
# - Module starts successfully
# - Correct language inheritance
# - Terminal output displays properly

# Test CLI integration
./help_master.sh
# - New category appears in main menu
# - Module executes correctly
```

## Module Documentation Integration

### Registry-Based Documentation Mapping

**Documentation Discovery:**
Documentation paths are stored in the module metadata and automatically resolved by the backend:

```go
func getModuleDocumentation(c *fiber.Ctx) error {
    moduleID := c.Params("id")
    
    // Find module in registry
    module := findModuleByID(moduleID)
    if module == nil {
        return c.Status(404).JSON(fiber.Map{
            "error": "Module not found",
        })
    }
    
    // Use docs path from registry metadata
    docPath := filepath.Join(lhRootDir, "docs", module.Docs)
    
    // Validate path is within allowed directory
    if !isPathSafe(docPath, filepath.Join(lhRootDir, "docs")) {
        return c.Status(403).JSON(fiber.Map{
            "error": "Invalid documentation path",
        })
    }
    
    content, err := os.ReadFile(docPath)
    if err != nil {
        return c.Status(404).JSON(fiber.Map{
            "error": "Documentation not found",
        })
    }
    
    return c.SendString(string(content))
}
```

**Documentation File Creation:**
```bash
# Create documentation for new module
cat > docs/modules/doc_network_info.md << 'EOF'
# Network Information Module

## Overview
This module provides comprehensive network configuration analysis and troubleshooting information.

## Features
- Network interface analysis
- Routing table examination  
- DNS configuration review
- Connection status monitoring

## Usage
1. Start the module from the GUI
2. Review network interface information
3. Check routing configuration
4. Analyze DNS settings
5. Monitor active connections

## Requirements
- `ip` command (iproute2 package)
- `ss` or `netstat` for connection monitoring
- Root privileges for some detailed information
EOF
```

**Metadata Documentation Reference:**
```json
{
  "id": "network_info",
  "docs": "mod/doc_network_info.md",
  // ... other metadata fields
}
```

The registry system automatically maps module IDs to their documentation paths - no manual mapping required!

## Advanced Integration Patterns

### Registry Metadata Schema

**Complete Module Metadata Example:**
```json
{
  "schema_version": 1,
  "id": "advanced_module",
  "entry": "modules/mod_advanced.sh",
  "category": {
    "id": "system"
  },
  "order": 20,
  "docs": "mod/doc_advanced.md",
  "display": {
    "name_key": "ADVANCED_MODULE_NAME",
    "description_key": "ADVANCED_MODULE_DESC",
    "fallback_name": "Advanced System Module",
    "fallback_description": "Advanced system management features"
  },
  "i18n": {
    "module_name": "advanced"
  },
  "expose": {
    "cli": true,
    "gui": true
  },
  "enabled": true,
  "requires_root": true,
  "tags": ["system", "advanced", "admin"],
  "version": "1.0.0",
  "author": "Your Name",
  "submodules": [
    {
      "id": "advanced_sub1",
      "entry": "modules/advanced/sub1.sh",
      "order": 10,
      "docs_inherit": true,
      "display": {
        "name_key": "ADVANCED_SUB1_NAME",
        "description_key": "ADVANCED_SUB1_DESC"
      }
    }
  ]
}
```

**Registry Cache Structure:**
The registry cache (`cache/module-registry.json`) contains:
```json
{
  "schema_version": 1,
  "loader_version": 1,
  "cache_metadata": {
    "build_time": "2025-12-09T10:30:00Z",
    "validation_hash": "abc123...",
    "file_hash": "def456..."
  },
  "modules": [...],
  "categories": [...]
}
```

**Registry Cache Structure:**

### Common Integration Issues

**Module Not Appearing in GUI:**
1. **Metadata File**: Verify module metadata exists in `modules/meta/`
2. **JSON Validity**: Validate JSON with `jq . modules/meta/mod_yourmodule.json`
3. **Module File**: Ensure the actual module file exists at the specified `entry` path
4. **File Permissions**: Verify file is executable (`chmod +x`)
5. **Cache Rebuild**: Check registry cache rebuilt correctly in `cache/module-registry.json`
6. **Backend Restart**: Restart GUI server to reload registry

**Module Execution Failures:**
1. **Environment Variables**: Verify `LH_ROOT_DIR` is set correctly
2. **Dependencies**: Ensure all required system commands are available
3. **Permissions**: Check file and directory permissions
4. **Shebang Line**: Confirm proper shebang (`#!/bin/bash`)
5. **Library Loading**: Verify `lib_common.sh` sources correctly
6. **Registry Entry**: Check module `entry` path in metadata is correct

**Language Integration Problems:**
1. **Translation Files**: Ensure language files exist in `lang/` directory
2. **Key Definitions**: Verify all translation keys are defined
3. **Loading Order**: Check module loads language files after `lib_common.sh`
4. **Environment Variable**: Confirm `LH_LANG` is passed correctly
5. **Metadata Keys**: Verify `name_key` and `description_key` match translation keys

### Debugging Module Integration

**Registry Validation:**
```bash
# Validate registry cache
jq . cache/module-registry.json

# Check if module is in registry
jq '.modules[] | select(.id == "your_module")' cache/module-registry.json

# Force registry rebuild
./scripts/registry_cache_helper.sh rebuild

# Validate all metadata files
for f in modules/meta/*.json; do
  echo "Validating $f..."
  jq . "$f" >/dev/null || echo "ERROR in $f"
done
```

**Module Metadata Verification:**
```bash
# Check module metadata syntax
jq . modules/meta/mod_your_module.json

# Verify required fields
jq '{id, entry, category, order, docs, display}' modules/meta/mod_your_module.json

# Check for validation errors in logs
grep -i "your_module" logs/sessions/latest.log
```

**Manual Module Testing:**
```bash
# Test module execution outside GUI
export LH_ROOT_DIR="/path/to/little-linux-helper"  
export LH_GUI_MODE=true
export LH_LANG=en

# Run module directly
./modules/mod_your_module.sh

# Check for errors
echo "Exit code: $?"
```

**Registry Cache Debugging:**
```bash
# Check cache metadata
jq '.cache_metadata' cache/module-registry.json

# List all modules in cache
jq '.modules[].id' cache/module-registry.json

# Check module count
echo "Modules in cache: $(jq '.modules | length' cache/module-registry.json)"

# Compare with metadata files
echo "Metadata files: $(ls -1 modules/meta/*.json | wc -l)"
```

### Registry System Troubleshooting

For comprehensive registry troubleshooting, see:
- `docs/registry/module_registry_troubleshooting.md` - Complete troubleshooting guide

---

*This document provides comprehensive module integration information for the GUI system. For additional development guides, see [Backend API Development](doc_backend_api.md) and [Development Workflow](doc_development_workflow.md).*
