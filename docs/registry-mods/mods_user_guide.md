# Little Linux Helper - Third-Party Modules (Mods) User Guide

## What are Mods?

Mods are third-party modules that extend Little Linux Helper with additional functionality. They work exactly like the built-in modules but are stored separately in the `mods/` directory, making them easy to add, update, or remove without affecting the core system.

## Directory Structure

The `mods/` directory follows this structure:

```
mods/
├── bin/           # Module scripts (executable files)
├── docs/          # Module documentation
├── meta/          # Module metadata (JSON files)
└── lib/           # Module-specific libraries (optional)
```

**Example structure with an installed mod:**
```
mods/
├── bin/
│   └── network_monitor.sh
├── docs/
│   └── network_monitor.md
├── meta/
│   └── network_monitor.json
└── lib/
    └── lib_netmon.sh
```

## Managing Mods

### View Installed Mods

**List all mod metadata files:**
```bash
ls -la mods/meta/
```

**See which mods are loaded in the registry:**
```bash
jq '.modules[] | select(.entry | startswith("mods/")) | {id, name: .display.fallback_name}' cache/module-registry.json
```

### Enable/Disable Specific Mods

**Disable a specific mod:**

Create or edit: `config/general.d/50-enable-module.conf`

```bash
# Disable specific modules (works for core modules and mods)
CFG_LH_MODULES_DISABLE_ONE=(
    "unwanted_mod_id"
    "another_mod_to_disable"
)
```

**Enable only specific mods:**

```bash
# Disable all mods by default
CFG_LH_MODULES_MODS_ENABLE="false"

# Enable only these specific mods
CFG_LH_MODULES_MODS_ENABLE_ONE=(
    "trusted_mod_id"
    "another_trusted_mod"
)
```

**Disable all mods globally:**

```bash
# In config/general.d/50-enable-module.conf
CFG_LH_MODULES_MODS_ENABLE="false"
```

After changing configuration, restart the application to apply changes.

### Update a Mod

To update a mod, simply replace its files:

```bash
# Backup current version (optional)
cp mods/bin/old_mod.sh mods/bin/old_mod.sh.backup

# Replace with new version
cp /path/to/updated/mod.sh mods/bin/
cp /path/to/updated/mod.json mods/meta/

# Rebuild registry
./scripts/registry_cache_helper.sh rebuild

# Restart application
./help_master.sh  # or ./gui_launcher.sh
```

### Uninstall a Mod

To remove a mod completely:

```bash
cd /path/to/little-linux-helper

# Remove mod files
rm mods/bin/mod_to_remove.sh
rm mods/meta/mod_to_remove.json
rm mods/docs/mod_to_remove.md  # if exists
rm mods/lib/lib_mod_to_remove.sh  # if exists

# Rebuild registry
./scripts/registry_cache_helper.sh rebuild

# Restart application
./help_master.sh  # or ./gui_launcher.sh
```

The mod will no longer appear in menus.

## Creating Your Own Mod

See the comprehensive developer guide: `docs/registry/third_party_module_migration_guide.md`

**Quick start for simple mods:**

1. **Create the script:** `mods/bin/my_tool.sh`
   ```bash
   #!/bin/bash
   source "$LH_ROOT_DIR/lib/lib_common.sh"
   lh_load_language_module "my_tool"
   lh_load_language_module "common"
   
   echo "$(lh_msg 'MY_TOOL_MESSAGE')"
   # Your tool logic here
   
   lh_press_any_key
   ```

2. **Create metadata:** `mods/meta/my_tool.json`
   ```json
   {
     "schema_version": 1,
     "id": "my_tool",
     "entry": "mods/bin/my_tool.sh",
     "category": {"id": "system"},
     "order": 100,
     "docs": "my_tool.md",
     "display": {
       "name_key": "MY_TOOL_NAME",
       "description_key": "MY_TOOL_DESC",
       "fallback_name": "My Tool",
       "fallback_description": "My custom tool"
     },
     "expose": {"cli": true, "gui": true},
     "enabled": true
   }
   ```

3. **Create translations:** `lang/en/my_tool.sh`
   ```bash
   #!/bin/bash
   [[ ! -v MSG_EN ]] && declare -A MSG_EN
   MSG_EN[MY_TOOL_NAME]="My Tool"
   MSG_EN[MY_TOOL_DESC]="My custom tool"
   MSG_EN[MY_TOOL_MESSAGE]="Hello from my custom tool!"
   ```

4. **Test it:**
   ```bash
   ./scripts/registry_cache_helper.sh rebuild
   ./help_master.sh
   ```

## Troubleshooting

### Mod doesn't appear in menu

**Check if metadata is valid:**
```bash
jq . mods/meta/your_mod.json
```

**Check if it's in the registry:**
```bash
jq '.modules[] | select(.id == "your_mod_id")' cache/module-registry.json
```

**Check logs for errors:**
```bash
tail -f logs/sessions/latest.log
```

**Rebuild registry with force:**
```bash
./scripts/registry_cache_helper.sh rebuild
```

### Mod execution fails

**Check script permissions:**
```bash
ls -la mods/bin/your_mod.sh
# Should show: -rwxr-xr-x (executable)

# Fix if needed:
chmod +x mods/bin/your_mod.sh
```

**Check script syntax:**
```bash
bash -n mods/bin/your_mod.sh
```

**Test manually:**
```bash
export LH_ROOT_DIR=/path/to/little-linux-helper
export LH_LANG=en
export LH_GUI_MODE=false
./mods/bin/your_mod.sh
```

### Translations not working

**Check translation files exist:**
```bash
ls -la lang/en/your_mod.sh
ls -la lang/de/your_mod.sh
```

**Check keys are defined:**
```bash
grep "MY_MOD_NAME" lang/en/your_mod.sh
```

**Check module loads language files:**
```bash
grep "lh_load_language_module" mods/bin/your_mod.sh
```

### Mod conflicts with core module

Mods cannot override core module IDs. If you see an ID conflict error:

1. Choose a different, unique ID for your mod
2. Update the `id` field in your metadata file
3. Rebuild the registry

## Advanced Configuration

### Custom Module Categories

You can create new categories for mods by editing:
`modules/meta/_categories.json`

```json
{
  "id": "custom_tools",
  "order": 70,
  "name_key": "CATEGORY_CUSTOM_TOOLS",
  "fallback_name": "Custom Tools"
}
```

Then add translations to `lang/*/common.sh`:
```bash
MSG_EN[CATEGORY_CUSTOM_TOOLS]="Custom Tools"
MSG_DE[CATEGORY_CUSTOM_TOOLS]="Benutzerdefinierte Werkzeuge"
```

### Module Configuration Files

Some mods may use configuration files. These typically go in:
```
config/mods.d/
├── mod_name.conf
└── mod_name.conf.example
```

Check the mod's documentation for configuration options.
