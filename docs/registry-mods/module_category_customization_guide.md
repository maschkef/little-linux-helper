# Module Category Customization Guide

This guide explains how to customize the display order of module categories in Little Linux Helper's CLI menu and GUI interface.

## Table of Contents

1. [Overview](#overview)
2. [Configuration File Location](#configuration-file-location)
3. [Category Configuration](#category-configuration)
4. [Default Categories](#default-categories)
5. [Customizing Category Order](#customizing-category-order)
6. [Adding New Categories](#adding-new-categories)
7. [Category Merging Rules](#category-merging-rules)
8. [Examples](#examples)
9. [Troubleshooting](#troubleshooting)

---

## Overview

Module categories organize modules into logical groups in the CLI menu and GUI. The category system provides:

- **Logical Grouping:** Related modules appear together
- **Customizable Ordering:** Control which categories appear first
- **Dynamic Merging:** Mods can introduce new categories or extend existing ones
- **Automatic Cleanup:** Empty categories (no modules) are hidden automatically

**Key Points:**
- Category definitions are stored in `modules/meta/_categories.json`
- Category display order is configured in `config/general.d/60-module-categories.conf`
- Mods can use existing categories or introduce new ones
- Categories without modules are automatically hidden

---

## Configuration File Location

Category ordering is configured in:

```
config/general.d/60-module-categories.conf
```

If this file doesn't exist, copy the example template:

```bash
cp config/general.d.example/60-module-categories.conf config/general.d/60-module-categories.conf
```

---

## Category Configuration

### Configuration Variable

**Variable:** `CFG_LH_MODULE_CATEGORY_ORDER`

**Purpose:** Define the display order of module categories.

**Format:** Space-separated list of category IDs

**Example:**
```bash
CFG_LH_MODULE_CATEGORY_ORDER="system maintenance security backup network docker logs energy"
```

**Behavior:**
- Categories appear in the specified order
- Categories not listed appear after these (alphabetically sorted)
- Empty categories (no modules) are hidden automatically
- Configuration affects both CLI menu and GUI

---

## Default Categories

Little Linux Helper includes these default categories (in recommended order):

| Category ID    | Name (English)               | Description                                      |
|----------------|------------------------------|--------------------------------------------------|
| `system`       | System Information           | System information and management tools          |
| `maintenance`  | System Maintenance           | System maintenance, updates, and package mgmt    |
| `security`     | Security & Hardening         | Security tools, checks, and hardening            |
| `backup`       | Backup & Recovery            | Backup and restore operations                    |
| `network`      | Network & Connectivity       | Network configuration and diagnostics            |
| `docker`       | Docker Management            | Docker management, setup, and security           |
| `logs`         | Logs & Diagnostics           | Log viewing and system analysis                  |
| `energy`       | Power Management             | Power and energy management (laptops)            |

**Category Metadata Location:**
```
modules/meta/_categories.json
```

**Example Category Definition:**
```json
{
  "id": "system",
  "order": 1,
  "name_key": "CATEGORY_SYSTEM",
  "fallback_name": "System Information"
}
```

---

## Customizing Category Order

### Basic Customization

Edit `config/general.d/60-module-categories.conf`:

```bash
# Show security-related categories first
CFG_LH_MODULE_CATEGORY_ORDER="security backup system maintenance network docker logs energy"
```

**Result:**
1. Security & Hardening
2. Backup & Recovery
3. System Information
4. System Maintenance
5. Network & Connectivity
6. Docker Management
7. Logs & Diagnostics
8. Power Management

---

### Partial Ordering

You don't need to list all categories. Unlisted categories appear after listed ones:

```bash
# Only specify top 3 categories, rest appear alphabetically
CFG_LH_MODULE_CATEGORY_ORDER="system backup security"
```

**Result:**
1. System Information
2. Backup & Recovery
3. Security & Hardening
4. Docker Management (alphabetically sorted)
5. Power Management
6. Logs & Diagnostics
7. Network & Connectivity
8. System Maintenance

---

### Hide Categories by Module Filtering

Categories with no modules are automatically hidden. To hide a category, disable all its modules:

```bash
# In config/general.d/50-enable-module.conf
# Disable all Docker modules → Docker category hidden
CFG_LH_MODULES_DISABLE_ONE="mod_docker mod_docker_security mod_docker_setup"
```

---

## Adding New Categories

### Via Mods

Mods can introduce new categories by specifying them in their metadata:

**Example:** `mods/meta/mod_custom_tool.json`
```json
{
  "id": "mod_custom_tool",
  "entry": "mods/bin/mod_custom_tool.sh",
  "category": {
    "id": "custom_tools",
    "order": 999
  },
  "display": {
    "name_key": "CUSTOM_TOOL_MODULE_NAME",
    "fallback_name": "Custom Tool"
  }
}
```

**Category Definition:** `mods/meta/_categories.json`
```json
{
  "schema_version": 1,
  "categories": [
    {
      "id": "custom_tools",
      "order": 999,
      "name_key": "CATEGORY_CUSTOM_TOOLS",
      "fallback_name": "Custom Tools"
    }
  ]
}
```

**Add to Ordering:**
```bash
# config/general.d/60-module-categories.conf
CFG_LH_MODULE_CATEGORY_ORDER="system maintenance security backup network docker logs energy custom_tools"
```

---

### Extending Core Categories

Mods can add modules to existing core categories:

**Example:** `mods/meta/mod_backup_cloud.json`
```json
{
  "id": "mod_backup_cloud",
  "entry": "mods/bin/mod_backup_cloud.sh",
  "category": {
    "id": "backup",
    "order": 10
  },
  "display": {
    "name_key": "BACKUP_CLOUD_MODULE_NAME",
    "fallback_name": "Cloud Backup"
  }
}
```

**Result:** The "Backup & Recovery" category now includes both core backup modules and the cloud backup mod.

---

## Category Merging Rules

When core modules and mods are loaded, category merging follows these rules:

### Rule 1: Category Order Sources (Priority)

```
1. CONFIG (CFG_LH_MODULE_CATEGORY_ORDER)
   ↓
2. MODS CATEGORIES (_categories.json in mods/meta/)
   ↓
3. CORE CATEGORIES (_categories.json in modules/meta/)
   ↓
4. ALPHABETICAL (fallback for undefined categories)
```

---

### Rule 2: Category ID Conflicts

**Scenario:** Both core and mods define category `"backup"`.

**Resolution:**
- Category name/translations come from core definition (core wins)
- Both core and mod modules appear in the same category
- Display order controlled by config (if specified)

**Example:**
```
Category: Backup & Recovery
├─ mod_backup (core)
├─ mod_btrfs_backup (core)
├─ mod_backup_cloud (mod) ← Added by mod
└─ mod_backup_extras (mod) ← Added by mod
```

---

### Rule 3: New Category Ordering

**Scenario:** Mod introduces new category `"monitoring"` not in config.

**Resolution:**
1. Check config: Is `"monitoring"` in `CFG_LH_MODULE_CATEGORY_ORDER`?
   - **YES** → Use configured position
   - **NO** → Append after configured categories (alphabetically)

**Example:**
```bash
CFG_LH_MODULE_CATEGORY_ORDER="system backup security"
# Mod adds "monitoring" category
```

**Result:**
1. System Information (configured)
2. Backup & Recovery (configured)
3. Security & Hardening (configured)
4. Docker Management (alphabetically sorted)
5. Power Management
6. Logs & Diagnostics
7. **Monitoring** ← New mod category
8. Network & Connectivity
9. System Maintenance

---

### Rule 4: Empty Category Hiding

**Scenario:** Category defined but has no modules.

**Resolution:**
- Category is automatically hidden from CLI menu and GUI
- Useful when all modules in a category are disabled

**Example:**
```bash
# Disable all network modules
CFG_LH_MODULES_DISABLE_ONE="mod_network"
```

**Result:** "Network & Connectivity" category does not appear.

---

## Examples

### Example 1: Default Order

```bash
# config/general.d/60-module-categories.conf

# Default recommended order
CFG_LH_MODULE_CATEGORY_ORDER="system maintenance security backup network docker logs energy"
```

**CLI Menu Output:**
```
=== Little Linux Helper ===

1. System Information
   1.1 Display System Information

2. System Maintenance
   2.1 Package Management
   2.2 Service Restart Manager

3. Security & Hardening
   3.1 Security Checks & Hardening

4. Backup & Recovery
   4.1 Backup Management
   4.2 Btrfs Snapshot Backup

...
```

---

### Example 2: Security-First Order

```bash
# config/general.d/60-module-categories.conf

# Security and backup first (for production servers)
CFG_LH_MODULE_CATEGORY_ORDER="security backup system maintenance logs network docker energy"
```

**CLI Menu Output:**
```
=== Little Linux Helper ===

1. Security & Hardening
   1.1 Security Checks & Hardening

2. Backup & Recovery
   2.1 Backup Management
   2.2 Btrfs Snapshot Backup

3. System Information
   3.1 Display System Information

...
```

---

### Example 3: Developer Workstation

```bash
# config/general.d/60-module-categories.conf

# Docker and development tools first
CFG_LH_MODULE_CATEGORY_ORDER="docker system maintenance network security backup logs energy"
```

---

### Example 4: Minimal Server (Top 3 Only)

```bash
# config/general.d/60-module-categories.conf

# Only specify critical categories
CFG_LH_MODULE_CATEGORY_ORDER="system security backup"
```

**Result:**
- System Information (first)
- Security & Hardening (second)
- Backup & Recovery (third)
- Other categories appear alphabetically after these

---

### Example 5: Custom Category from Mod

**Mod Category Definition:** `mods/meta/_categories.json`
```json
{
  "schema_version": 1,
  "categories": [
    {
      "id": "monitoring",
      "order": 100,
      "name_key": "CATEGORY_MONITORING",
      "fallback_name": "Monitoring & Alerts"
    }
  ]
}
```

**Configuration:**
```bash
# config/general.d/60-module-categories.conf

# Include new monitoring category
CFG_LH_MODULE_CATEGORY_ORDER="system monitoring maintenance security backup network docker logs energy"
```

**Result:** Monitoring category appears second in menu.

---

## Troubleshooting

### Problem: Category Order Not Changing

**Symptoms:** Modified config, but categories still appear in old order.

**Solutions:**

1. **Verify configuration file location:**
   ```bash
   ls -la config/general.d/60-module-categories.conf
   ```
   Ensure file is in active config directory, not example directory.

2. **Check syntax:**
   ```bash
   # Verify no syntax errors
   bash -n config/general.d/60-module-categories.conf
   
   # Check variable is set
   source config/general.d/60-module-categories.conf
   echo "$CFG_LH_MODULE_CATEGORY_ORDER"
   ```

3. **Rebuild cache:**
   ```bash
   # Force registry cache rebuild
   rm -f cache/module-registry.json
   ./help_master.sh
   ```

4. **Verify category IDs:**
   ```bash
   # List all available category IDs
   jq -r '.categories[].id' cache/module-registry.json
   ```

---

### Problem: Category Not Appearing

**Symptoms:** Added category to config, but it doesn't appear.

**Solutions:**

1. **Check if category has modules:**
   ```bash
   # Categories with no modules are hidden
   jq -r --arg cat "monitoring" '.modules[] | select(.category.id == $cat) | .id' cache/module-registry.json
   
   # If no output, category is empty
   ```

2. **Verify category is defined:**
   ```bash
   # Check category metadata exists
   jq -r --arg cat "monitoring" '.categories[] | select(.id == $cat)' cache/module-registry.json
   
   # If no output, category is not defined anywhere
   ```

3. **Check module enable/disable settings:**
   ```bash
   # Ensure modules in category are not disabled
   grep "CFG_LH_MODULES_DISABLE_ONE" config/general.d/50-enable-module.conf
   ```

---

### Problem: New Mod Category Not Showing

**Symptoms:** Mod defines new category, but it doesn't appear.

**Solutions:**

1. **Verify mod is enabled:**
   ```bash
   # Check mods toggle
   grep "CFG_LH_MODULES_MODS_ENABLE" config/general.d/50-enable-module.conf
   
   # Should be "true" or mod should be whitelisted
   ```

2. **Check mod metadata:**
   ```bash
   # Verify category definition in mod
   jq '.category' mods/meta/mod_example.json
   
   # Should show category ID and order
   ```

3. **Verify category metadata file:**
   ```bash
   # Check if mods/meta/_categories.json exists
   ls -la mods/meta/_categories.json
   
   # Verify category definition
   jq '.categories[]' mods/meta/_categories.json
   ```

4. **Rebuild cache:**
   ```bash
   # Mods metadata changes require cache rebuild
   rm -f cache/module-registry.json
   ./scripts/registry_cache_helper.sh rebuild
   ```

---

### Problem: Categories in Wrong Order

**Symptoms:** Categories appear in unexpected order.

**Solutions:**

1. **Check for multiple config files:**
   ```bash
   # Search for all category order configs
   grep -r "CFG_LH_MODULE_CATEGORY_ORDER" config/general.d/
   
   # Later files (higher numbers) override earlier ones
   ```

2. **Verify no typos in category IDs:**
   ```bash
   # Category IDs are case-sensitive!
   # "System" ≠ "system"
   
   # List exact IDs from cache
   jq -r '.categories[].id' cache/module-registry.json
   ```

3. **Check alphabetical fallback:**
   ```bash
   # Categories not in config appear alphabetically
   # This is expected behavior
   ```

---

### Problem: GUI Shows Different Order Than CLI

**Symptoms:** Category order differs between CLI menu and GUI.

**Solutions:**

1. **Verify GUI is using registry API:**
   ```bash
   # Check GUI backend logs
   cd gui && ./dev.sh
   # Look for: "Registry loaded: X modules, Y categories"
   ```

2. **Refresh GUI cache:**
   ```bash
   # GUI uses same cache, but may need restart
   # Stop and restart GUI server
   ```

3. **Check API response:**
   ```bash
   # Verify /api/modules returns categories in correct order
   curl -s http://localhost:3000/api/modules | jq '.categories'
   ```

---

### Problem: CLI Numbers Incorrect After Reordering

**Symptoms:** Menu numbering seems wrong or skips numbers.

**Solutions:**

This is expected behavior. Categories are numbered sequentially (1, 2, 3...), but modules within categories use the category number as a prefix:

```
1. Category One
   1.1 Module A
   1.2 Module B

2. Category Two
   2.1 Module C

3. Category Three
   3.1 Module D
   3.2 Module E
   3.3 Module F
```

If a category is empty, its number is skipped:

```
1. Category One
   1.1 Module A

3. Category Three  ← Category Two was empty, so skipped
   3.1 Module D
```

To fix: Disable empty categories or add modules to them.

---

## Advanced Configuration

### Dynamic Category Order Based on System Type

```bash
# config/general.d/60-module-categories.conf

# Detect system type and adjust categories
if [ -f /sys/class/power_supply/BAT0/uevent ]; then
    # Laptop: energy management first
    CFG_LH_MODULE_CATEGORY_ORDER="energy system maintenance security backup network docker logs"
elif systemctl is-active docker &>/dev/null; then
    # Docker host: Docker first
    CFG_LH_MODULE_CATEGORY_ORDER="docker system maintenance security backup network logs energy"
else
    # Server: security and backup first
    CFG_LH_MODULE_CATEGORY_ORDER="security backup system maintenance network docker logs energy"
fi
```

---

### Role-Based Category Ordering

```bash
# config/general.d/60-module-categories.conf

# Different category order for different users
if [ "$USER" = "admin" ]; then
    # Admins: security first
    CFG_LH_MODULE_CATEGORY_ORDER="security system maintenance backup network docker logs energy"
elif [ "$USER" = "developer" ]; then
    # Developers: Docker and network first
    CFG_LH_MODULE_CATEGORY_ORDER="docker network system maintenance security backup logs energy"
else
    # Regular users: system info first
    CFG_LH_MODULE_CATEGORY_ORDER="system maintenance network backup security docker logs energy"
fi
```

---

## Category Translation

Category names are translated using the translation key system. To add translations for a custom category:

**1. Define category with translation key:**
```json
{
  "id": "monitoring",
  "order": 100,
  "name_key": "CATEGORY_MONITORING",
  "fallback_name": "Monitoring & Alerts"
}
```

**2. Add translations in language files:**

`lang/en/main_menu.sh`:
```bash
MSG_EN[CATEGORY_MONITORING]="Monitoring & Alerts"
```

`lang/de/main_menu.sh`:
```bash
MSG_DE[CATEGORY_MONITORING]="Überwachung & Benachrichtigungen"
```

**3. Sync to GUI translations:**
```bash
# Auto-sync to GUI JSON files
./scripts/sync_gui_translations.sh
```

---

## See Also

- [Module Enable/Disable Guide](module_enable_disable_guide.md)
- [Module Registry Schema](module_registry_schema.md)
- [Translation Key Conventions](translation_key_conventions.md)
- [Mods User Guide](mods_user_guide.md)
- [Third-Party Module Migration Guide](third_party_module_migration_guide.md)

---

*Last Updated: 2025-12-09*
