<!--
File: docs/gui/doc_module_integration.md
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
-->

# GUI Module Integration Guide

This document explains how CLI modules automatically integrate with the GUI system, how to add new module categories, and how the module discovery and execution process works.

## Overview

The Little Linux Helper GUI provides seamless integration with all CLI modules through a well-defined backend interface. While new CLI modules work without modifications once added to the system, they must be registered in the GUI backend to appear in the web interface.

**Key Integration Features:**
- **Zero Code Changes**: Existing modules work without modifications
- **Manual Registration**: New modules must be added to the backend module list  
- **Full CLI Compatibility**: All CLI functionality preserved
- **Environment Inheritance**: Proper variable passing from GUI to CLI
- **Real-time Execution**: Live terminal output and interaction

## Module Discovery Process

### Hardcoded Module Definitions

**Current Implementation:**
The GUI backend currently uses a hardcoded list of modules rather than automatic file system scanning. This provides stable, predictable module information with consistent categorization and metadata.

```go
func getModules(c *fiber.Ctx) error {
    modules := []ModuleInfo{
        {
            ID:             "system_info",
            Name:           "Display System Information", 
            Description:    "Show comprehensive system information and hardware details",
            Path:           "modules/mod_system_info.sh",
            Category:       "System Diagnosis & Analysis",
            SubmoduleCount: 9,
        },
        // ... additional hardcoded modules
    }
    return c.JSON(modules)
}
```

**Module Categories (Predefined):**
- **Recovery & Restarts**: Services and desktop restart utilities  
- **System Diagnosis & Analysis**: System information, disk tools, log analysis
- **Maintenance & Security**: Package management, security checks, energy management
- **Docker & Containers**: Docker management and security tools
- **Backup & Recovery**: BTRFS, TAR, and RSYNC backup/restore operations

**Adding New Modules:**
To add a new module to the GUI, you must:
1. Create the CLI module script (e.g., `modules/mod_newfeature.sh`)
2. Add a corresponding entry to the hardcoded modules list in `gui/main.go`
3. Optionally add documentation mapping in the `getModuleDocs` function
4. Rebuild and restart the GUI server

### Current Module Categories

**Note**: Categories are hardcoded in the `getModules()` function in `gui/main.go`. Each module explicitly defines its category in the ModuleInfo struct.

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

**Critical Variables for GUI-CLI Integration:**
```go
func setupModuleEnvironment(moduleID, language string) []string {
    env := os.Environ()
    
    // Essential GUI-CLI integration variables
    env = append(env,
        "LH_ROOT_DIR="+lhRootDir,           // Project root directory
        "LH_GUI_MODE=true",                 // GUI execution mode flag
        "LH_LANG="+language,                // Dynamic language inheritance
        "PATH="+os.Getenv("PATH"),          // Preserve system PATH
    )
    
    return env
}
```

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

**1. Create Category Directory Structure:**
```bash
# Create new category directory
mkdir -p modules/networking

# Add sample module
cat > modules/networking/mod_network_info.sh << 'EOF'
#!/bin/bash
source "$LH_ROOT_DIR/lib/lib_common.sh"
lh_detect_package_manager

lh_load_language_module "network_info"
lh_load_language_module "common"

echo "$(lh_msg 'NETWORK_INFO_TITLE')"
# Network information gathering logic here
EOF

chmod +x modules/networking/mod_network_info.sh
```

**2. Add to Backend Module List:**
```go
// Add to the modules array in getModules() function in main.go
{
    ID:             "network_info",
    Name:           "Network Information",
    Description:    "Display network configuration and status",
    Path:           "modules/networking/mod_network_info.sh",
    Category:       "Network Tools",
    SubmoduleCount: 0,
},
    
    return modules
}

// Add to getModules() function
func getModules() []ModuleInfo {
    // ... existing discovery code ...
    
    // Add networking modules discovery
    networkingModules := discoverNetworkingModules(lhRootDir)
    allModules = append(allModules, networkingModules...)
    
    return allModules
}
```

**3. Add Category Translations:**
```json
// src/i18n/locales/en/common.json
{
    "modules": {
        "category": {
            "network": "Network Tools",
            "networking": "Network Tools"
        }
    }
}

// src/i18n/locales/de/common.json  
{
    "modules": {
        "category": {
            "network": "Netzwerk-Tools",
            "networking": "Netzwerk-Tools"
        }
    }
}
```

**4. Create Module-Specific Translations:**
```bash
# Create translation files for new modules
mkdir -p lang/en lang/de

# English translations
cat > lang/en/network_info.sh << 'EOF'
#!/bin/bash
[[ ! -v MSG_EN ]] && declare -A MSG_EN

MSG_EN[NETWORK_INFO_TITLE]="Network Information Analysis"
MSG_EN[NETWORK_CONFIG_FOUND]="Network configuration detected"
EOF

# German translations  
cat > lang/de/network_info.sh << 'EOF'
#!/bin/bash
[[ ! -v MSG_DE ]] && declare -A MSG_DE

MSG_DE[NETWORK_INFO_TITLE]="Netzwerk-Informations-Analyse"
MSG_DE[NETWORK_CONFIG_FOUND]="Netzwerkkonfiguration erkannt"
EOF
```

**5. Test New Category:**
```bash
# Restart GUI to discover new modules
./little-linux-helper-gui

# Verify in browser:
# - New category appears in sidebar
# - Module starts successfully
# - Correct language inheritance
# - Terminal output displays properly
```

## Module Documentation Integration

### Automatic Documentation Mapping

**Documentation Discovery:**
```go
var moduleDocMap = map[string]string{
    "backup":        "mod_backup.md",
    "btrfs_backup":  "mod_btrfs_backup.md",
    "disk":          "mod_disk.md", 
    "docker":        "mod_docker.md",
    "network_info":  "mod_network_info.md",  // New module docs
}

func getModuleDocumentation(moduleID string) (string, error) {
    docFile, exists := moduleDocMap[moduleID]
    if !exists {
        return "No documentation available", nil
    }
    
    docPath := filepath.Join(lhRootDir, "docs", "mod", docFile)
    content, err := ioutil.ReadFile(docPath)
    if err != nil {
        return "Documentation file not found", err
    }
    
    return string(content), nil
}
```

**Documentation File Creation:**
```bash
# Create documentation for new module
cat > docs/mod/mod_network_info.md << 'EOF'
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

## Advanced Integration Patterns


### Adding New Module Categories

**Current Implementation:**
To add a new module category, you must modify the hardcoded module list in `gui/main.go` and add the new modules with the appropriate category string.

```go
// Add to the modules array in getModules() function
{
    ID:             "new_module",
    Name:           "New Module Name", 
    Description:    "Description of the new module",
    Path:           "modules/mod_new_module.sh",
    Category:       "New Category", // New category
    SubmoduleCount: 3,
},
```

**Available Categories (Current):**
- "Recovery & Restarts"
- "System Diagnosis & Analysis"
- "Maintenance & Security" 
- "Docker & Containers"
- "Backup & Recovery"

**Note**: The current implementation does not automatically scan the file system for modules. All module information is predefined in the backend code for stable, consistent categorization and metadata.


### Module Metadata Enhancement

**Extended Module Information:**
```go
type ExtendedModuleInfo struct {
    ModuleInfo
    Version     string            `json:"version"`
    Author      string            `json:"author"`
    License     string            `json:"license"`
    Dependencies []string         `json:"dependencies"`
    Tags        []string          `json:"tags"`
    Metadata    map[string]string `json:"metadata"`
}

func extractModuleMetadata(modulePath string) ExtendedModuleInfo {
    // Read module file and extract metadata from comments
    content, err := ioutil.ReadFile(modulePath)
    if err != nil {
        return ExtendedModuleInfo{}
    }
    
    lines := strings.Split(string(content), "\n")
    metadata := make(map[string]string)
    
    for _, line := range lines {
        if strings.HasPrefix(line, "# @") {
            // Parse metadata comments like: # @version 1.0.0
            parts := strings.SplitN(line[3:], " ", 2)
            if len(parts) == 2 {
                metadata[parts[0]] = parts[1]
            }
        }
    }
    
    return ExtendedModuleInfo{
        ModuleInfo: createModuleInfo(modulePath, "", ""),
        Version:    metadata["version"],
        Author:     metadata["author"],
        License:    metadata["license"],
        // ... other metadata fields
    }
}
```

## Troubleshooting Module Integration

### Common Integration Issues

**Module Not Appearing in GUI:**
1. **Hardcoded List**: Verify module is added to the `modules` array in `gui/main.go`
2. **Module File**: Ensure the actual module file exists at the specified path
3. **File Permissions**: Verify file is executable (`chmod +x`) 
4. **Backend Rebuild**: Restart GUI server after adding to hardcoded list
5. **JSON Syntax**: Check for syntax errors in module definition

**Module Execution Failures:**
1. **Environment Variables**: Verify `LH_ROOT_DIR` is set correctly
2. **Dependencies**: Ensure all required system commands are available
3. **Permissions**: Check file and directory permissions
4. **Shebang Line**: Confirm proper shebang (`#!/bin/bash`)
5. **Library Loading**: Verify `lib_common.sh` sources correctly

**Language Integration Problems:**
1. **Translation Files**: Ensure language files exist in `lang/` directory
2. **Key Definitions**: Verify all translation keys are defined
3. **Loading Order**: Check module loads language files after `lib_common.sh`
4. **Environment Variable**: Confirm `LH_LANG` is passed correctly

### Debugging Module Integration

**Module Definition Verification:**
Check the hardcoded module list in `gui/main.go` for correct entries:

```go
// Verify your module is in the array
func getModules(c *fiber.Ctx) error {
    modules := []ModuleInfo{
        // ... existing modules ...
        {
            ID:             "your_module",
            Name:           "Your Module Name",
            Description:    "Module description",
            Path:           "modules/mod_your_module.sh", // Check path is correct
            Category:       "Your Category",
            SubmoduleCount: 0,
        },
    }
    return c.JSON(modules)
}
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

---

*This document provides comprehensive module integration information for the GUI system. For additional development guides, see [Backend API Development](doc_backend_api.md) and [Development Workflow](doc_development_workflow.md).*
