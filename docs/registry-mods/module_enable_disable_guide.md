# Module Enable/Disable Configuration Guide

This guide explains how to control which modules appear in Little Linux Helper's CLI menu and GUI interface using the module registry configuration system.

## Table of Contents

1. [Overview](#overview)
2. [Configuration File Location](#configuration-file-location)
3. [Configuration Options](#configuration-options)
4. [Precedence Rules](#precedence-rules)
5. [Common Use Cases](#common-use-cases)
6. [Examples](#examples)
7. [Troubleshooting](#troubleshooting)

---

## Overview

Little Linux Helper's module registry system provides flexible control over module visibility through three configuration options:

- **Global Mods Toggle** (`CFG_LH_MODULES_MODS_ENABLE`) - Enable/disable all third-party mods
- **Whitelist** (`CFG_LH_MODULES_MODS_ENABLE_ONE`) - Enable specific mods when global toggle is off
- **Blacklist** (`CFG_LH_MODULES_DISABLE_ONE`) - Disable specific modules/mods (highest priority)

**Key Points:**
- Core modules (bundled with LLH) are always enabled by default
- Mods (third-party modules in `mods/` directory) can be controlled globally or individually
- The blacklist can disable both core modules and mods
- Disabled modules are completely hidden from CLI menu and GUI
- Configuration changes take effect immediately (no restart needed)

---

## Configuration File Location

Module enable/disable settings are configured in:

```
config/general.d/50-enable-module.conf
```

If this file doesn't exist, copy the example template:

```bash
cp config/general.d.example/50-enable-module.conf config/general.d/50-enable-module.conf
```

**Note:** Configuration files in `config/general.d/` are loaded alphabetically. The `50-` prefix ensures this file loads at an appropriate time during initialization.

---

## Configuration Options

### 1. Global Mods Toggle

**Variable:** `CFG_LH_MODULES_MODS_ENABLE`

**Purpose:** Enable or disable ALL mods (third-party modules) at once.

**Values:**
- `"true"` (default) - All mods are enabled (unless individually blacklisted)
- `"false"` - All mods are disabled (unless individually whitelisted)

**Example:**
```bash
# Disable all third-party mods
CFG_LH_MODULES_MODS_ENABLE="false"
```

**Behavior:**
- Core modules are **not** affected by this setting
- Only modules in the `mods/` directory are affected
- Individual mods can still be enabled via the whitelist (see below)

---

### 2. Whitelist (Enable Specific Mods)

**Variable:** `CFG_LH_MODULES_MODS_ENABLE_ONE`

**Purpose:** Enable specific mods when the global toggle is disabled.

**Values:** Space-separated list of mod IDs

**Example:**
```bash
# Global toggle is OFF, but enable two specific mods
CFG_LH_MODULES_MODS_ENABLE="false"
CFG_LH_MODULES_MODS_ENABLE_ONE="mod_custom_tool mod_network_extras"
```

**Behavior:**
- Only effective when `CFG_LH_MODULES_MODS_ENABLE="false"`
- Ignored when global toggle is `"true"` (all mods already enabled)
- Module IDs must match the `id` field in the mod's metadata file
- Non-existent module IDs are silently ignored

---

### 3. Blacklist (Disable Specific Modules)

**Variable:** `CFG_LH_MODULES_DISABLE_ONE`

**Purpose:** Disable specific modules or mods, regardless of other settings.

**Values:** Space-separated list of module/mod IDs

**Example:**
```bash
# Hide the disk module and an experimental mod
CFG_LH_MODULES_DISABLE_ONE="mod_disk mod_experimental"
```

**Behavior:**
- **Highest priority** - overrides global toggle and whitelist
- Can disable both core modules and mods
- Disabled modules are completely hidden from CLI menu and GUI
- Useful for deprecating modules, hiding broken modules, or customizing deployment

---

## Precedence Rules

The module visibility logic follows this precedence order (highest to lowest):

```
1. BLACKLIST (CFG_LH_MODULES_DISABLE_ONE)
   ↓
2. WHITELIST (CFG_LH_MODULES_MODS_ENABLE_ONE)
   ↓
3. GLOBAL MODS TOGGLE (CFG_LH_MODULES_MODS_ENABLE)
   ↓
4. DEFAULT (core modules always enabled, mods enabled by default)
```

**Decision Tree:**

```
Is module in blacklist (DISABLE_ONE)?
├─ YES → Module is DISABLED (stop here)
└─ NO → Continue to next check

Is module a mod (in mods/ directory)?
├─ NO (core module) → Module is ENABLED
└─ YES (mod) → Continue to next check

Is global mods toggle enabled (MODS_ENABLE="true")?
├─ YES → Module is ENABLED
└─ NO → Continue to next check

Is module in whitelist (ENABLE_ONE)?
├─ YES → Module is ENABLED
└─ NO → Module is DISABLED
```

---

## Common Use Cases

### Use Case 1: Disable All Mods

**Scenario:** You only want to use core LLH modules, no third-party extensions.

**Configuration:**
```bash
CFG_LH_MODULES_MODS_ENABLE="false"
CFG_LH_MODULES_MODS_ENABLE_ONE=""
CFG_LH_MODULES_DISABLE_ONE=""
```

**Result:** Only core modules appear in menu/GUI.

---

### Use Case 2: Enable Only Specific Mods

**Scenario:** You want to use only two trusted third-party mods.

**Configuration:**
```bash
CFG_LH_MODULES_MODS_ENABLE="false"
CFG_LH_MODULES_MODS_ENABLE_ONE="mod_backup_extras mod_monitoring"
CFG_LH_MODULES_DISABLE_ONE=""
```

**Result:** Core modules + `mod_backup_extras` + `mod_monitoring` appear.

---

### Use Case 3: Hide a Broken Core Module

**Scenario:** A core module has a bug and you want to hide it until it's fixed.

**Configuration:**
```bash
CFG_LH_MODULES_MODS_ENABLE="true"
CFG_LH_MODULES_MODS_ENABLE_ONE=""
CFG_LH_MODULES_DISABLE_ONE="mod_network"
```

**Result:** All modules except `mod_network` appear.

---

### Use Case 4: Minimal Installation

**Scenario:** You want only system info and package management, nothing else.

**Configuration:**
```bash
CFG_LH_MODULES_MODS_ENABLE="false"
CFG_LH_MODULES_MODS_ENABLE_ONE=""
CFG_LH_MODULES_DISABLE_ONE="mod_backup mod_docker mod_docker_security mod_docker_setup mod_energy mod_logs mod_network mod_restarts mod_security mod_disk"
```

**Result:** Only `mod_system_info` and `mod_packages` appear.

---

### Use Case 5: Everything Except One Mod

**Scenario:** All mods are fine except one problematic mod.

**Configuration:**
```bash
CFG_LH_MODULES_MODS_ENABLE="true"
CFG_LH_MODULES_MODS_ENABLE_ONE=""
CFG_LH_MODULES_DISABLE_ONE="mod_broken_extension"
```

**Result:** All core modules + all mods except `mod_broken_extension`.

---

## Examples

### Example 1: Default Configuration (Everything Enabled)

```bash
# config/general.d/50-enable-module.conf

CFG_LH_MODULES_MODS_ENABLE="true"
CFG_LH_MODULES_MODS_ENABLE_ONE=""
CFG_LH_MODULES_DISABLE_ONE=""
```

**Result:**
- All core modules: ✅ Enabled
- All mods: ✅ Enabled

---

### Example 2: Production Server (No Mods)

```bash
# config/general.d/50-enable-module.conf

# Disable all third-party mods for security/stability
CFG_LH_MODULES_MODS_ENABLE="false"
CFG_LH_MODULES_MODS_ENABLE_ONE=""
CFG_LH_MODULES_DISABLE_ONE=""
```

**Result:**
- All core modules: ✅ Enabled
- All mods: ❌ Disabled

---

### Example 3: Curated Mods List

```bash
# config/general.d/50-enable-module.conf

# Only enable vetted mods
CFG_LH_MODULES_MODS_ENABLE="false"
CFG_LH_MODULES_MODS_ENABLE_ONE="mod_monitoring mod_backup_cloud mod_security_scan"
CFG_LH_MODULES_DISABLE_ONE=""
```

**Result:**
- All core modules: ✅ Enabled
- `mod_monitoring`: ✅ Enabled (whitelisted)
- `mod_backup_cloud`: ✅ Enabled (whitelisted)
- `mod_security_scan`: ✅ Enabled (whitelisted)
- Other mods: ❌ Disabled

---

### Example 4: Hide Deprecated Modules

```bash
# config/general.d/50-enable-module.conf

CFG_LH_MODULES_MODS_ENABLE="true"
CFG_LH_MODULES_MODS_ENABLE_ONE=""

# Hide deprecated modules being phased out
CFG_LH_MODULES_DISABLE_ONE="mod_old_backup mod_legacy_network"
```

**Result:**
- All core modules: ✅ Enabled
- All mods except blacklisted: ✅ Enabled
- `mod_old_backup`: ❌ Disabled (blacklisted)
- `mod_legacy_network`: ❌ Disabled (blacklisted)

---

### Example 5: Development Environment

```bash
# config/general.d/50-enable-module.conf

CFG_LH_MODULES_MODS_ENABLE="true"
CFG_LH_MODULES_MODS_ENABLE_ONE=""

# Hide stable modules, show only dev/experimental
CFG_LH_MODULES_DISABLE_ONE="mod_disk mod_energy mod_logs"
```

**Result:**
- Most modules: ✅ Enabled
- `mod_disk`, `mod_energy`, `mod_logs`: ❌ Disabled

---

## Troubleshooting

### Problem: Changes Not Taking Effect

**Symptoms:** Modified configuration, but module visibility unchanged.

**Solutions:**

1. **Verify configuration file location:**
   ```bash
   ls -la config/general.d/50-enable-module.conf
   ```
   Ensure the file is in `config/general.d/`, not `config/general.d.example/`.

2. **Check file syntax:**
   ```bash
   # Bash syntax check
   bash -n config/general.d/50-enable-module.conf
   ```

3. **Verify cache rebuild:**
   ```bash
   # Force registry cache rebuild
   rm -f cache/module-registry.json
   ./help_master.sh
   ```

4. **Check for typos in module IDs:**
   ```bash
   # List all available module IDs
   jq -r '.modules[].id' cache/module-registry.json
   ```

---

### Problem: Module Still Appears Despite Blacklist

**Symptoms:** Added module to `DISABLE_ONE`, but it still appears.

**Solutions:**

1. **Verify module ID matches:**
   ```bash
   # Check metadata file
   jq '.id' modules/meta/mod_example.json
   
   # Module ID is case-sensitive!
   # "mod_backup" ≠ "Mod_Backup" ≠ "MOD_BACKUP"
   ```

2. **Check for multiple configuration files:**
   ```bash
   # Search for conflicting config
   grep -r "CFG_LH_MODULES" config/general.d/
   
   # Files loaded alphabetically - later files override earlier ones
   ```

3. **Ensure proper quoting:**
   ```bash
   # CORRECT
   CFG_LH_MODULES_DISABLE_ONE="mod_disk mod_network"
   
   # WRONG (missing quotes)
   CFG_LH_MODULES_DISABLE_ONE=mod_disk mod_network
   ```

---

### Problem: Whitelist Not Working

**Symptoms:** Enabled specific mod via `ENABLE_ONE`, but it doesn't appear.

**Solutions:**

1. **Check global toggle:**
   ```bash
   # Whitelist only works when global toggle is OFF
   CFG_LH_MODULES_MODS_ENABLE="false"  # Must be false!
   CFG_LH_MODULES_MODS_ENABLE_ONE="mod_example"
   ```

2. **Verify mod is not blacklisted:**
   ```bash
   # Blacklist wins over whitelist
   CFG_LH_MODULES_DISABLE_ONE="mod_example"  # Remove from blacklist!
   ```

3. **Check mod metadata:**
   ```bash
   # Ensure mod has metadata file
   ls -la mods/meta/mod_example.json
   
   # Ensure enabled flag is true
   jq '.enabled' mods/meta/mod_example.json
   # Should return: true (or be absent - defaults to true)
   ```

---

### Problem: Core Module Won't Disable

**Symptoms:** Added core module to `DISABLE_ONE`, but it still appears.

**Solutions:**

1. **Verify you're using the correct variable:**
   ```bash
   # Use DISABLE_ONE (not MODS_DISABLE_ONE or MODS_ENABLE_ONE)
   CFG_LH_MODULES_DISABLE_ONE="mod_disk"
   ```

2. **Check for submodules:**
   ```bash
   # Disabling parent module should hide submodules
   # But check if you're seeing a submodule instead
   jq -r '.modules[] | select(.id=="backup") | .submodules[].id' cache/module-registry.json
   ```

3. **Verify module ID:**
   ```bash
   # List all core module IDs
   jq -r '.modules[] | select(.entry | startswith("modules/")) | .id' cache/module-registry.json
   ```

---

### Problem: GUI Shows Different Modules Than CLI

**Symptoms:** Module appears in GUI but not CLI (or vice versa).

**Solutions:**

1. **Check expose flags in metadata:**
   ```bash
   # Verify expose.cli and expose.gui flags
   jq '.expose' modules/meta/mod_example.json
   
   # Both should be true for module to appear in both
   # {
   #   "cli": true,
   #   "gui": true
   # }
   ```

2. **Refresh GUI registry cache:**
   ```bash
   # GUI uses same cache, but may need restart
   # Stop GUI server and restart
   cd gui && ./dev.sh
   ```

3. **Verify GUI is using registry API:**
   ```bash
   # Check GUI backend logs for registry load
   # Should see: "Registry loaded: X modules, Y categories"
   ```

---

### Problem: No Modules Appear At All

**Symptoms:** CLI menu or GUI shows no modules.

**Solutions:**

1. **Check cache file:**
   ```bash
   ls -la cache/module-registry.json
   
   # If missing, rebuild
   ./scripts/registry_cache_helper.sh rebuild
   ```

2. **Verify metadata files exist:**
   ```bash
   ls -la modules/meta/*.json
   # Should show 12+ metadata files
   ```

3. **Check for overly restrictive blacklist:**
   ```bash
   # Review blacklist
   grep "CFG_LH_MODULES_DISABLE_ONE" config/general.d/50-enable-module.conf
   
   # If you blacklisted everything, clear it:
   CFG_LH_MODULES_DISABLE_ONE=""
   ```

4. **Check registry cache for errors:**
   ```bash
   jq '.modules | length' cache/module-registry.json
   # Should return: 12 or more
   
   # If returns 0, check logs:
   tail -100 logs/$(date +%Y-%m)/llh_$(date +%Y%m%d).log | grep -i "error\|warn"
   ```

---

## Advanced Configuration

### Dynamic Blacklist Based on Environment

You can use Bash scripting in configuration files:

```bash
# config/general.d/50-enable-module.conf

# Disable energy module on servers (non-laptop systems)
if [ ! -f /sys/class/power_supply/BAT0/uevent ]; then
    CFG_LH_MODULES_DISABLE_ONE="mod_energy"
else
    CFG_LH_MODULES_DISABLE_ONE=""
fi
```

---

### Role-Based Module Visibility

```bash
# config/general.d/50-enable-module.conf

# Different modules for different user roles
if [ "$USER" = "admin" ]; then
    # Admins see everything
    CFG_LH_MODULES_MODS_ENABLE="true"
    CFG_LH_MODULES_DISABLE_ONE=""
elif [ "$USER" = "developer" ]; then
    # Developers see core + dev mods
    CFG_LH_MODULES_MODS_ENABLE="false"
    CFG_LH_MODULES_MODS_ENABLE_ONE="mod_dev_tools mod_testing"
    CFG_LH_MODULES_DISABLE_ONE=""
else
    # Regular users see only safe modules
    CFG_LH_MODULES_MODS_ENABLE="false"
    CFG_LH_MODULES_DISABLE_ONE="mod_docker mod_docker_security mod_docker_setup"
fi
```

---

## See Also

- [Module Registry Technical Details](module_registry_technical_details.md)
- [Module Registry Schema](module_registry_schema.md)
- [Mods User Guide](mods_user_guide.md)
- [CLI Developer Guide](CLI_DEVELOPER_GUIDE.md)
- [Module Registry Troubleshooting](module_registry_troubleshooting.md)

---

*Last Updated: 2025-12-09*
