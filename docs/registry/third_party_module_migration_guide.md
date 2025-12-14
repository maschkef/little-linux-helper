<!--
File: docs/registry/third_party_module_migration_guide.md
Copyright (c) 2025 maschkef
SPDX-License-Identifier: Apache-2.0

This project is part of the 'little-linux-helper' collection.
Licensed under the Apache License 2.0. See the LICENSE file in the project root for more information.
-->

# Third-Party Module Migration Guide

This guide helps third-party module developers migrate their modules to the new registry-based system or create new modules that work with Little Linux Helper.

## Overview

The registry-based module system provides:
- **Automatic Discovery**: Drop metadata file → module appears automatically
- **Standardized Structure**: Consistent module format across all modules
- **Translation Support**: Built-in internationalization for module names/descriptions
- **Documentation Integration**: Automatic doc mapping in GUI and CLI
- **Category Support**: Organize modules into logical groups
- **Submodule Support**: Create hierarchical module structures

## Migration Steps for Existing Modules

### Step 1: Assess Your Current Module

**Questions to answer:**
1. Where is your module script currently located?
2. Does it follow the Bash scripting conventions?
3. What external dependencies does it require?
4. Does it need root privileges?
5. What translations already exist?
6. Is there existing documentation?

### Step 2: Create Module Metadata File

**Basic Metadata Template:**
```json
{
  "schema_version": 1,
  "id": "your_module_id",
  "entry": "mods/bin/your_module.sh",
  "category": {
    "id": "system"
  },
  "order": 50,
  "docs": "your_module_docs.md",
  "display": {
    "name_key": "YOUR_MODULE_NAME",
    "description_key": "YOUR_MODULE_DESC",
    "fallback_name": "Your Module Name",
    "fallback_description": "Brief description of what your module does"
  },
  "expose": {
    "cli": true,
    "gui": true
  },
  "enabled": true,
  "requires_root": false,
  "version": "1.0.0",
  "author": "Your Name"
}
```

**Save as:** `mods/meta/your_module.json`

**Field Explanations:**
- `id`: Unique identifier (lowercase, underscores allowed)
- `entry`: Path to your module script relative to repository root
- `category.id`: One of: `system`, `maintenance`, `backup`, `docker`, `restart` (or create new)
- `order`: Numeric sort order within category (10, 20, 30, etc.)
- `docs`: Path to documentation relative to `mods/docs/`
- `display.name_key`: Translation key for module name
- `display.description_key`: Translation key for module description
- `display.fallback_name`: English name when translation missing
- `display.fallback_description`: English description when translation missing
- `expose.cli`: Show in CLI menu (true/false)
- `expose.gui`: Show in GUI interface (true/false)
- `enabled`: Master toggle for module (true/false)
- `requires_root`: Hint that module needs sudo (true/false)

### Step 3: Move Module Files to Mods Structure

**Directory Structure:**
```
mods/
├── bin/               # Module scripts
│   └── your_module.sh
├── docs/              # Module documentation
│   └── your_module_docs.md
├── meta/              # Module metadata
│   └── your_module.json
├── lang/              # Module translations (separate from core)
│   ├── en/
│   │   └── your_module.sh
│   ├── de/
│   │   └── your_module.sh
└── lib/               # Module-specific libraries (optional)
    └── lib_yourmod.sh
```

**Move your script:**
```bash
# Create directories
mkdir -p mods/bin mods/docs mods/meta mods/lang/{en,de}

# Move your module script
mv /path/to/your_module.sh mods/bin/

# Ensure it's executable
chmod +x mods/bin/your_module.sh
```

### Step 4: Update Module Script Headers

**Required Script Structure:**
```bash
#!/bin/bash
#
# Module: Your Module Name
# Description: Brief description
# Author: Your Name
# Version: 1.0.0
#

# Load core library
source "$LH_ROOT_DIR/lib/lib_common.sh"

# Load module-specific language files
lh_load_language_module "your_module"
lh_load_language_module "common"

# Your module code here
main() {
    echo "$(lh_msg 'YOUR_MODULE_WELCOME')"
    # ... module logic ...
}

# Run main function
main "$@"
```

**Important:**
- Always use `$LH_ROOT_DIR` to reference project root
- Source `lib_common.sh` before anything else
- Use `lh_msg` for all user-facing text (enables translation)
- Handle GUI mode properly (see GUI Integration section below)

### Step 5: Create Translation Files

**English Translations** (`mods/lang/en/your_module.sh`):
```bash
#!/bin/bash
[[ ! -v MSG_EN ]] && declare -A MSG_EN

# Module metadata translations
MSG_EN[YOUR_MODULE_NAME]="Your Module Name"
MSG_EN[YOUR_MODULE_DESC]="Brief description of your module"

# Module UI translations
MSG_EN[YOUR_MODULE_WELCOME]="Welcome to Your Module!"
MSG_EN[YOUR_MODULE_OPTION_1]="First Option"
MSG_EN[YOUR_MODULE_OPTION_2]="Second Option"
MSG_EN[YOUR_MODULE_SUCCESS]="Operation completed successfully"
MSG_EN[YOUR_MODULE_ERROR]="An error occurred"
```

**German Translations** (`mods/lang/de/your_module.sh`):
```bash
#!/bin/bash
[[ ! -v MSG_DE ]] && declare -A MSG_DE

# Module metadata translations
MSG_DE[YOUR_MODULE_NAME]="Ihr Modulname"
MSG_DE[YOUR_MODULE_DESC]="Kurze Beschreibung Ihres Moduls"

# Module UI translations
MSG_DE[YOUR_MODULE_WELCOME]="Willkommen bei Ihrem Modul!"
MSG_DE[YOUR_MODULE_OPTION_1]="Erste Option"
MSG_DE[YOUR_MODULE_OPTION_2]="Zweite Option"
MSG_DE[YOUR_MODULE_SUCCESS]="Vorgang erfolgreich abgeschlossen"
MSG_DE[YOUR_MODULE_ERROR]="Ein Fehler ist aufgetreten"
```

**Translation Key Conventions:**
- Use `SCREAMING_SNAKE_CASE` for all keys
- Prefix with your module name: `YOUR_MODULE_*`
- Group related keys together
- See `docs/registry/translation_key_conventions.md` for details

### Step 6: Create Module Documentation

**Documentation Template** (`mods/docs/your_module_docs.md`):
```markdown
# Your Module Name

## Overview
Brief overview of what your module does and why it's useful.

## Features
- Feature 1: Description
- Feature 2: Description
- Feature 3: Description

## Requirements
List any system requirements:
- Required commands (e.g., `curl`, `jq`, `systemctl`)
- Required packages
- Minimum OS versions
- Root privileges (if needed)

## Usage

### From GUI
1. Navigate to Your Category
2. Click on "Your Module Name"
3. Follow on-screen instructions
4. Review results

### From CLI
1. Run `./help_master.sh`
2. Select your category
3. Select your module
4. Follow prompts

## Configuration
If your module uses configuration files, document them here.

## Examples

### Example 1: Basic Usage
```bash
# What the user does
./help_master.sh
# Select category > Select module
```

### Example 2: Advanced Usage
Describe advanced features or options.

## Troubleshooting

### Issue 1
**Symptom:** Description of problem
**Solution:** How to fix it

### Issue 2
**Symptom:** Another problem
**Solution:** How to resolve it

## Technical Details
Any technical implementation details that advanced users might need.

## Version History
- 1.0.0 (2025-12-09): Initial release
```

### Step 7: Handle GUI Mode

**GUI-Aware Code:**
```bash
# Check if running in GUI mode
if lh_gui_mode_active; then
    # Skip interactive prompts
    # Use defaults or command-line arguments
else
    # Show interactive menus
    # Ask for user confirmation
fi

# Example: Confirmation prompt
confirm_action() {
    if lh_gui_mode_active; then
        return 0  # Auto-confirm in GUI mode
    fi
    
    lh_msgln 'CONFIRM_ACTION'
    read -p "Continue? (y/n): " answer
    [[ "$answer" == "y" ]]
}

# Example: Menu navigation
show_menu() {
    lh_print_header "$(lh_msg 'YOUR_MODULE_MENU_TITLE')"
    
    lh_print_menu_item "1" "$(lh_msg 'OPTION_1')"
    lh_print_menu_item "2" "$(lh_msg 'OPTION_2')"
    
    # This item only shows in CLI mode
    lh_print_gui_hidden_menu_item "0" "$(lh_msg 'BACK_TO_MAIN')"
    
    # Menu handling
    read -p "$(lh_msg 'SELECT_OPTION'): " choice
    case $choice in
        1) action_one ;;
        2) action_two ;;
        0)
            if lh_gui_mode_active; then
                lh_log_msg "ERROR" "Invalid selection in GUI mode: $choice"
                return 1
            fi
            return 0  # Exit in CLI mode
            ;;
        *)
            lh_log_msg "ERROR" "Invalid selection: $choice"
            return 1
            ;;
    esac
}
```

### Step 8: Test Your Module

**Validation Steps:**
```bash
# 1. Validate metadata JSON
jq . mods/meta/your_module.json

# 2. Check script syntax
bash -n mods/bin/your_module.sh

# 3. Rebuild registry cache
./scripts/registry_cache_helper.sh rebuild

# 4. Verify module in registry
jq '.modules[] | select(.id == "your_module_id")' cache/module-registry.json

# 5. Test in CLI
./help_master.sh
# Navigate to your module and test

# 6. Test in GUI
./gui_launcher.sh
# Navigate to your module in browser and test

# 7. Test language switching
LH_LANG=de ./help_master.sh
# Verify German translations work
```

**Common Issues:**
- **Module not appearing**: Check metadata file is valid JSON
- **Execution fails**: Verify script has executable permissions
- **Translations missing**: Check translation files exist and keys match
- **Docs not showing**: Verify docs path in metadata is correct

### Step 9: Add to Configuration (Optional)

**Enable/Disable Control:**

Users can control your module via configuration:

**Enable globally** (default):
```bash
# config/general.d/50-enable-module.conf
CFG_LH_MODULES_MODS_ENABLE="true"
```

**Enable only specific modules:**
```bash
# Disable all mods by default
CFG_LH_MODULES_MODS_ENABLE="false"

# Enable only specific ones
CFG_LH_MODULES_MODS_ENABLE_ONE=(
    "your_module_id"
    "another_module_id"
)
```

**Disable specific modules:**
```bash
# Blacklist modules (overrides whitelist)
CFG_LH_MODULES_DISABLE_ONE=(
    "unwanted_module"
)
```

## Creating New Modules from Scratch

### Quickstart Template

**1. Create metadata:**
```bash
cat > mods/meta/hello_world.json << 'EOF'
{
  "schema_version": 1,
  "id": "hello_world",
  "entry": "mods/bin/hello_world.sh",
  "category": {"id": "system"},
  "order": 100,
  "docs": "hello_world.md",
  "display": {
    "name_key": "HELLO_WORLD_NAME",
    "description_key": "HELLO_WORLD_DESC",
    "fallback_name": "Hello World",
    "fallback_description": "A simple hello world module"
  },
  "expose": {"cli": true, "gui": true},
  "enabled": true,
  "version": "1.0.0"
}
EOF
```

**2. Create script:**
```bash
cat > mods/bin/hello_world.sh << 'EOF'
#!/bin/bash
source "$LH_ROOT_DIR/lib/lib_common.sh"
lh_load_language_module "hello_world"
lh_load_language_module "common"

echo "$(lh_msg 'HELLO_WORLD_MESSAGE')"
echo "Running in GUI mode: $LH_GUI_MODE"
echo "Language: $LH_LANG"

lh_press_any_key
EOF

chmod +x mods/bin/hello_world.sh
```

**3. Create translations:**
```bash
# English
cat > mods/lang/en/hello_world.sh << 'EOF'
#!/bin/bash
[[ ! -v MSG_EN ]] && declare -A MSG_EN
MSG_EN[HELLO_WORLD_NAME]="Hello World"
MSG_EN[HELLO_WORLD_DESC]="A simple hello world module"
MSG_EN[HELLO_WORLD_MESSAGE]="Hello, World!"
EOF

# German
cat > mods/lang/de/hello_world.sh << 'EOF'
#!/bin/bash
[[ ! -v MSG_DE ]] && declare -A MSG_DE
MSG_DE[HELLO_WORLD_NAME]="Hallo Welt"
MSG_DE[HELLO_WORLD_DESC]="Ein einfaches Hallo-Welt-Modul"
MSG_DE[HELLO_WORLD_MESSAGE]="Hallo, Welt!"
EOF
```

**4. Create documentation:**
```bash
cat > mods/docs/hello_world.md << 'EOF'
# Hello World Module

## Overview
A simple demonstration module showing the basics of Little Linux Helper module development.

## Features
- Displays "Hello, World!" message
- Shows current language setting
- Demonstrates GUI mode detection

## Usage
Simply select the module from either CLI or GUI interface.

## Technical Details
This module demonstrates:
- Basic script structure
- Translation key usage
- GUI mode handling
- Environment variable access
EOF
```

**5. Test:**
```bash
# Rebuild registry
./scripts/registry_cache_helper.sh rebuild

# Test in CLI
./help_master.sh

# Test in GUI
./gui_launcher.sh
```

## Advanced Features

### Submodules

**Metadata with Submodules:**
```json
{
  "schema_version": 1,
  "id": "parent_module",
  "entry": "mods/bin/parent.sh",
  "category": {"id": "system"},
  "order": 10,
  "docs": "parent_docs.md",
  "display": {
    "name_key": "PARENT_NAME",
    "description_key": "PARENT_DESC",
    "fallback_name": "Parent Module",
    "fallback_description": "Parent with submodules"
  },
  "submodules": [
    {
      "id": "child_one",
      "entry": "mods/bin/child_one.sh",
      "order": 10,
      "docs": "child_one_docs.md",
      "display": {
        "name_key": "CHILD_ONE_NAME",
        "description_key": "CHILD_ONE_DESC"
      }
    },
    {
      "id": "child_two",
      "entry": "mods/bin/child_two.sh",
      "order": 20,
      "docs_inherit": true,
      "display": {
        "name_key": "CHILD_TWO_NAME",
        "description_key": "CHILD_TWO_DESC"
      }
    }
  ]
}
```

**Notes:**
- Submodule IDs must be globally unique
- `docs_inherit: true` uses parent's documentation
- Submodule translations go in parent's language files
- Submodules inherit parent's category by default

### Custom Libraries

**Using Module-Specific Libraries:**
```bash
# In your module script
source "$LH_ROOT_DIR/mods/lib/lib_yourmod.sh"

# Namespace your functions to avoid collisions
yourmod_custom_function() {
    echo "Custom functionality"
}

# Use core libraries too
lh_log_msg "INFO" "Using both custom and core libraries"
```

**Best Practices:**
- Prefix all custom functions with your module name
- Don't override core library functions
- Document any library dependencies
- Keep libraries small and focused

### Configuration Integration

**Module-Specific Configuration:**
```bash
# In your module script
load_module_config() {
    # Source module-specific config if exists
    local config_file="$LH_ROOT_DIR/config/mods.d/yourmod.conf"
    if [[ -f "$config_file" ]]; then
        source "$config_file"
    else
        # Use defaults
        YOURMOD_SETTING1="${YOURMOD_SETTING1:-default_value}"
        YOURMOD_SETTING2="${YOURMOD_SETTING2:-another_default}"
    fi
}

# Provide example config
cat > config/mods.d.example/yourmod.conf << 'EOF'
# Your Module Configuration

# Setting 1 description
YOURMOD_SETTING1="value1"

# Setting 2 description  
YOURMOD_SETTING2="value2"
EOF
```

## Best Practices

### Code Quality

1. **Use ShellCheck**: Validate scripts with `shellcheck mods/bin/*.sh`
2. **Follow Style Guide**: Consistent indentation, naming conventions
3. **Error Handling**: Check return codes, use `set -euo pipefail` carefully
4. **Logging**: Use `lh_log_msg` for all important operations
5. **Comments**: Document complex logic and decisions

### Security

1. **Input Validation**: Always validate user input
2. **Path Safety**: Use absolute paths, validate file operations
3. **Privilege Escalation**: Request root only when necessary
4. **Command Injection**: Quote variables, use arrays for commands
5. **Sensitive Data**: Don't log passwords or secrets

### Performance

1. **Efficiency**: Minimize external command calls
2. **Caching**: Cache expensive operations when possible
3. **Cleanup**: Remove temporary files
4. **Resource Usage**: Be mindful of CPU/memory/disk usage
5. **Async Operations**: Use background jobs for long operations

### User Experience

1. **Clear Messages**: Use descriptive, actionable messages
2. **Progress Indication**: Show progress for long operations
3. **Graceful Degradation**: Handle missing dependencies gracefully
4. **Helpful Errors**: Provide context and solutions in error messages
5. **Consistent UI**: Follow existing UI patterns and conventions

## Testing Checklist

- [ ] Metadata validates with `jq`
- [ ] Script has executable permissions
- [ ] ShellCheck passes with no errors
- [ ] Module appears in CLI menu
- [ ] Module appears in GUI interface
- [ ] Module executes successfully in CLI
- [ ] Module executes successfully in GUI
- [ ] English translations display correctly
- [ ] German translations display correctly
- [ ] Documentation loads in GUI
- [ ] Documentation is clear and complete
- [ ] GUI mode handled correctly (no prompts)
- [ ] CLI mode works with full interactivity
- [ ] Error handling works properly
- [ ] Logging provides useful information
- [ ] Dependencies documented
- [ ] Root requirements documented
- [ ] No security vulnerabilities
- [ ] Performance acceptable
- [ ] Clean exit (no temp files left)

## Support and Resources

### Documentation
- **Troubleshooting**: `docs/registry/module_registry_troubleshooting.md`
- **Technical Details**: `docs/module_registry_technical_details.md`
- **CLI Development**: `docs/CLI_DEVELOPER_GUIDE.md`
- **GUI Development**: `docs/GUI_DEVELOPER_GUIDE.md`

### Examples
- **Core Modules**: `modules/mod_*.sh`
- **Module Metadata**: `modules/meta/*.json`
- **Core Translations**: `lang/*/` directories
- **Mod Translations**: `mods/lang/*/` directories
- **Documentation**: `docs/modules/` directory

### Validation Tools
```bash
# Validate all metadata
for f in mods/meta/*.json; do jq . "$f" >/dev/null || echo "Error in $f"; done

# Validate all scripts
for f in mods/bin/*.sh; do bash -n "$f" || echo "Syntax error in $f"; done

# Check translations
grep -r "lh_msg" mods/bin/*.sh | cut -d"'" -f2 | sort -u > /tmp/keys_used.txt
grep "MSG_EN\[" mods/lang/en/*.sh | cut -d"[" -f2 | cut -d"]" -f1 | sort -u > /tmp/keys_defined.txt
comm -23 /tmp/keys_used.txt /tmp/keys_defined.txt  # Keys used but not defined
```

## Troubleshooting

### Module Not Loading

**Symptom:** Module doesn't appear in CLI or GUI

**Diagnostics:**
```bash
# Check if metadata is valid
jq . mods/meta/your_module.json

# Check if it's in the registry
jq '.modules[] | select(.id == "your_module")' cache/module-registry.json

# Force rebuild registry
./scripts/registry_cache_helper.sh rebuild

# Check for errors in logs
tail -f logs/sessions/latest.log
```

### Translation Missing

**Symptom:** Module shows translation keys instead of text

**Diagnostics:**
```bash
# Check translation files exist
ls -la mods/lang/*/your_module.sh

# Check key is defined
grep "YOUR_MODULE_NAME" mods/lang/en/your_module.sh

# Check module loads language files
grep "lh_load_language_module" mods/bin/your_module.sh

# Test manually
export LH_ROOT_DIR=/path/to/little-linux-helper
export LH_LANG=en
source lib/lib_common.sh
lh_load_language_module "your_module"
echo "$(lh_msg 'YOUR_MODULE_NAME')"
```

### GUI Execution Issues

**Symptom:** Module fails only in GUI mode

**Diagnostics:**
```bash
# Simulate GUI environment
export LH_ROOT_DIR=/path/to/little-linux-helper
export LH_GUI_MODE=true
export LH_LANG=en
export TERM=xterm-256color

# Run module
./mods/bin/your_module.sh

# Check for interactive prompts that should be skipped
grep -n "read -p" mods/bin/your_module.sh
```

## Migration Examples

### Example 1: Simple Utility Module

**Before (standalone script):**
```bash
#!/bin/bash
echo "Welcome to My Utility"
read -p "Continue? " answer
# ... utility logic ...
```

**After (integrated module):**

**Metadata** (`mods/meta/my_utility.json`):
```json
{
  "schema_version": 1,
  "id": "my_utility",
  "entry": "mods/bin/my_utility.sh",
  "category": {"id": "system"},
  "order": 50,
  "docs": "my_utility.md",
  "display": {
    "name_key": "MY_UTILITY_NAME",
    "description_key": "MY_UTILITY_DESC",
    "fallback_name": "My Utility",
    "fallback_description": "A helpful utility tool"
  },
  "expose": {"cli": true, "gui": true},
  "enabled": true
}
```

**Script** (`mods/bin/my_utility.sh`):
```bash
#!/bin/bash
source "$LH_ROOT_DIR/lib/lib_common.sh"
lh_load_language_module "my_utility"
lh_load_language_module "common"

echo "$(lh_msg 'MY_UTILITY_WELCOME')"

# Only prompt in CLI mode
if ! lh_gui_mode_active; then
    read -p "$(lh_msg 'CONTINUE_PROMPT'): " answer
    [[ "$answer" != "y" ]] && exit 0
fi

# ... utility logic ...

lh_press_any_key
```

### Example 2: Complex Multi-Function Module

**Before (monolithic script with submenu):**
```bash
#!/bin/bash
while true; do
    echo "1) Function A"
    echo "2) Function B"
    echo "0) Exit"
    read choice
    case $choice in
        1) function_a ;;
        2) function_b ;;
        0) exit 0 ;;
    esac
done
```

**After (parent with submodules):**

**Parent Metadata** (`mods/meta/complex_tool.json`):
```json
{
  "schema_version": 1,
  "id": "complex_tool",
  "entry": "mods/bin/complex_tool.sh",
  "category": {"id": "maintenance"},
  "order": 40,
  "docs": "complex_tool.md",
  "display": {
    "name_key": "COMPLEX_TOOL_NAME",
    "description_key": "COMPLEX_TOOL_DESC",
    "fallback_name": "Complex Tool",
    "fallback_description": "Multi-function utility tool"
  },
  "submodules": [
    {
      "id": "function_a",
      "entry": "mods/bin/complex_tool_a.sh",
      "order": 10,
      "docs_inherit": true,
      "display": {
        "name_key": "FUNCTION_A_NAME",
        "description_key": "FUNCTION_A_DESC"
      }
    },
    {
      "id": "function_b",
      "entry": "mods/bin/complex_tool_b.sh",
      "order": 20,
      "docs_inherit": true,
      "display": {
        "name_key": "FUNCTION_B_NAME",
        "description_key": "FUNCTION_B_DESC"
      }
    }
  ]
}
```

Each function becomes a separate submodule script, making them independently accessible via GUI.

## Conclusion

The registry-based module system makes it easy to:
- Add new modules without touching backend code
- Maintain consistent module structure
- Provide internationalization
- Integrate documentation seamlessly
- Support both CLI and GUI interfaces

Follow this guide to migrate existing modules or create new ones. For questions or issues, refer to the troubleshooting documentation or check the example modules in the `modules/` directory.

---

**Document Version:** 1.0.0  
**Last Updated:** 2025-12-09  
**Maintained by:** Little Linux Helper Project
