# Mods Directory Structure Guide

## Overview

Third-party modules (mods) in Little Linux Helper have a dedicated directory structure separate from core modules. This separation ensures clean organization and prevents conflicts between core and community-contributed modules.

## Directory Structure

```
mods/
├── bin/                    # Module executable scripts
│   ├── mod_demo.sh
│   └── your_module.sh
├── docs/                   # Module documentation (Markdown)
│   ├── demo_mod.md
│   └── your_module.md
├── meta/                   # Module metadata (JSON)
│   ├── demo_mod.json
│   └── your_module.json
├── lang/                   # Module translations (separate from core!)
│   ├── en/                 # English translations
│   │   ├── demo_mod.sh
│   │   └── your_module.sh
│   └── de/                 # German translations
│       ├── demo_mod.sh
│       └── your_module.sh
└── lib/                    # Module-specific libraries (optional)
    └── lib_yourmod.sh
```

## Core vs Mods: Language File Locations

### Core Modules
Core module translations are stored in:
```
lang/
├── en/
│   ├── core/              # Core system translations
│   │   ├── common.sh
│   │   └── main_menu.sh
│   └── modules/           # Core module translations
│       ├── backup.sh
│       ├── docker.sh
│       └── system_info.sh
├── de/
│   ├── core/
│   └── modules/
└── ...
```

### Third-Party Mods
Mod translations are stored **separately** in:
```
mods/lang/
├── en/
│   ├── demo_mod.sh
│   └── your_module.sh
├── de/
│   ├── demo_mod.sh
│   └── your_module.sh
└── ...
```

## Why Separate Language Directories?

1. **Clean Separation**: Core and third-party modules don't mix
2. **Easy Distribution**: Mods can be distributed as self-contained packages
3. **No Conflicts**: Module authors don't need to modify core lang/ directory
4. **Portable**: The entire `mods/` directory can be copied between installations

## How It Works

The `lh_load_language_module()` function in `lib/lib_i18n.sh` checks multiple locations in this order:

1. **`mods/lang/<language>/<module_name>.sh`** - Third-party mods (new structure)
2. **`lang/<language>/modules/<module_name>.sh`** - Core modules (new structure)
3. **`lang/<language>/<module_name>.sh`** - Fallback (old flat structure)

This ensures:
- Mods are loaded from `mods/lang/` first
- Core modules are loaded from `lang/`
- Backwards compatibility with old structure

## Creating a New Mod

### 1. Create Module Structure

```bash
# Create all necessary directories
mkdir -p mods/{bin,docs,meta,lang/{en,de}}

# Create your module script
cat > mods/bin/my_module.sh << 'EOF'
#!/bin/bash
# Load libraries
LIB_COMMON_PATH="$(dirname "${BASH_SOURCE[0]}")/../../lib/lib_common.sh"
source "$LIB_COMMON_PATH"

# Load translations
lh_load_language_module "my_module"
lh_load_language_module "common"

# Your code here
echo "$(lh_msg 'MY_MODULE_WELCOME')"
EOF

chmod +x mods/bin/my_module.sh
```

### 2. Create Translations

```bash
# English translations
cat > mods/lang/en/my_module.sh << 'EOF'
#!/bin/bash
[[ ! -v MSG_EN ]] && declare -A MSG_EN

MSG_EN[MY_MODULE_NAME]="My Module"
MSG_EN[MY_MODULE_DESC]="Description of my module"
MSG_EN[MY_MODULE_WELCOME]="Welcome to My Module!"
EOF

# German translations
cat > mods/lang/de/my_module.sh << 'EOF'
#!/bin/bash
[[ ! -v MSG_DE ]] && declare -A MSG_DE

MSG_DE[MY_MODULE_NAME]="Mein Modul"
MSG_DE[MY_MODULE_DESC]="Beschreibung meines Moduls"
MSG_DE[MY_MODULE_WELCOME]="Willkommen bei Mein Modul!"
EOF
```

### 3. Create Metadata

```bash
cat > mods/meta/my_module.json << 'EOF'
{
  "schema_version": 1,
  "id": "my_module",
  "entry": "mods/bin/my_module.sh",
  "category": {
    "id": "system"
  },
  "order": 50,
  "docs": "my_module.md",
  "display": {
    "name_key": "MY_MODULE_NAME",
    "description_key": "MY_MODULE_DESC",
    "fallback_name": "My Module",
    "fallback_description": "Description of my module"
  },
  "i18n": {
    "module_name": "my_module"
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
EOF
```

### 4. Create Documentation

```bash
cat > mods/docs/my_module.md << 'EOF'
# My Module

## Overview
Brief description of what your module does.

## Features
- Feature 1
- Feature 2

## Usage
How to use the module from CLI and GUI.

## Requirements
Any dependencies or prerequisites.
EOF
```

### 5. Rebuild Registry and Test

```bash
# Rebuild the module registry cache
./scripts/registry_cache_helper.sh rebuild

# Test in CLI
./help_master.sh

# Test in GUI
./gui_launcher.sh
```

## Migration from Old Structure

If you have existing mods with language files in the old location:

```bash
# Move language files from lang/ to mods/lang/
for lang in en de; do
    if [ -d "lang/$lang" ]; then
        # Find mod-specific language files (not core modules)
        for file in lang/$lang/your_module.sh; do
            if [ -f "$file" ]; then
                mv "$file" "mods/lang/$lang/"
                echo "Moved $file to mods/lang/$lang/"
            fi
        done
    fi
done
```

## Best Practices

1. **Use Consistent Naming**: Module filename, metadata ID, and i18n module_name should match
2. **All Languages**: Provide at least English and German translations
3. **Translation Keys**: Use `SCREAMING_SNAKE_CASE` prefixed with your module name
4. **Documentation**: Always include comprehensive documentation
5. **Version Control**: Use semantic versioning for your mods
6. **Test Both Interfaces**: Test in both CLI and GUI modes

## Troubleshooting

### Module appears but shows translation keys

**Problem**: Module displays `[MY_MODULE_NAME]` instead of the actual name

**Solution**: 
```bash
# Check if translation file exists
ls -la mods/lang/en/my_module.sh

# Check if i18n.module_name is set in metadata
jq '.i18n.module_name' mods/meta/my_module.json

# Check if lh_load_language_module is called in script
grep "lh_load_language_module" mods/bin/my_module.sh
```

### Module doesn't appear in menu

**Problem**: Module is not visible in CLI or GUI

**Solution**:
```bash
# Rebuild registry
./scripts/registry_cache_helper.sh rebuild

# Check if module is in registry
jq '.modules[] | select(.id == "my_module")' cache/module-registry.json

# Check if module is enabled
jq '.enabled' mods/meta/my_module.json
```

## See Also

- [Third-Party Module Migration Guide](third_party_module_migration_guide.md)
- [Translation Key Conventions](translation_key_conventions.md)
- [Module Registry Schema](module_registry_schema.md)
- [CLI Developer Guide](CLI_DEVELOPER_GUIDE.md)
