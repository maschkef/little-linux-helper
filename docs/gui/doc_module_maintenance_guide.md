<!--
File: docs/gui/doc_module_maintenance_guide.md
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
-->

# GUI Module Maintenance Guide

This document describes what information needs to be updated when modules are changed, added, or removed from the Little Linux Helper system. Use this as a comprehensive checklist to ensure all components remain in sync.

## Overview

The GUI system has multiple interconnected components that display module information. When modules change, several locations need updating to maintain consistency across the user interface, documentation system, and help panels.

**Critical Components That Must Stay In Sync:**
- Backend module definitions (Go)
- Frontend help content (React/i18n)
- Documentation files (Markdown)
- Translation keys (JSON)
- Module documentation mapping

## 1. Backend Module Registration (`gui/main.go`)

### When Adding a New Module

**Location**: `gui/main.go` - `getModules()` function
**What to Update**: Add new `ModuleInfo` struct to the hardcoded modules array

```go
// Add to the modules array in getModules() function
{
    ID:             "new_module",
    Name:           "New Module Name",
    Description:    "Description of what the new module does",
    Path:           "modules/mod_new_module.sh",
    Category:       "Appropriate Category",
    SubmoduleCount: 0,  // Or actual count if it has submodules
},
```

**Available Categories** (choose existing or create new):
- "Recovery & Restarts"
- "System Diagnosis & Analysis" 
- "Maintenance & Security"
- "Docker & Containers"
- "Backup & Recovery"

### When Removing a Module

1. **Remove from modules array** in `getModules()` function
2. **Remove from documentation mapping** in `getModuleDocs()` function (if it exists)
3. **Clean up any related documentation references**

### When Modifying Module Properties

**Common Changes:**
- **Module Name**: Update `Name` field in `ModuleInfo` struct
- **Description**: Update `Description` field 
- **Category**: Update `Category` field (affects sidebar grouping)
- **Submodule Count**: Update `SubmoduleCount` if adding/removing submodules
- **File Path**: Update `Path` if module file moved

**Example**:
```go
// Before
{
    ID:             "system_info",
    Name:           "System Information",
    Description:    "Basic system info",
    Category:       "System Tools",
    SubmoduleCount: 5,
},

// After (expanded functionality)  
{
    ID:             "system_info",
    Name:           "Advanced System Analysis",
    Description:    "Comprehensive system information and diagnostics",
    Category:       "System Diagnosis & Analysis", 
    SubmoduleCount: 9,
},
```

## 2. Documentation Mapping (`gui/main.go`)

### When Adding Module Documentation

**Location**: `gui/main.go` - `getModuleDocs()` function
**Purpose**: Links module IDs to their documentation files

```go
// Add to moduleDocMap
var moduleDocMap = map[string]string{
    "new_module": "mod_new_module.md",
    // ... existing mappings
}
```

**Documentation File Requirements:**
- Create corresponding `.md` file in `docs/mod/` directory
- Use standard documentation structure (see existing files)
- Include proper license header

### When Removing Module Documentation

1. **Remove from `moduleDocMap`** in `getModuleDocs()`
2. **Delete documentation file** from `docs/mod/`
3. **Update DocumentBrowser categories** (see section 7)

## 3. Frontend Help Content (`gui/web/src/i18n/locales/`)

### Help Content Structure

**Files to Update**:
- `gui/web/src/i18n/locales/en/help.json` (English)
- `gui/web/src/i18n/locales/de/help.json` (German)

### When Adding New Module Help

**Template Structure**:
```json
// In en/help.json
{
  "new_module": {
    "overview": "Brief description of what this module does and its primary purpose.",
    "options": [
      "1. Option Name - Description of what this option does",
      "2. Another Option - Description of another available option",
      "3. Advanced Feature - Description of advanced functionality"
    ],
    "notes": [
      "Important safety consideration or requirement",
      "System requirement or dependency information",
      "Usage warning or best practice recommendation"
    ]
  }
}

// In de/help.json (German translation)
{
  "new_module": {
    "overview": "Kurze Beschreibung dessen, was dieses Modul tut und sein Hauptzweck.",
    "options": [
      "1. Optionsname - Beschreibung dessen, was diese Option tut",
      "2. Weitere Option - Beschreibung einer weiteren verfügbaren Option", 
      "3. Erweiterte Funktion - Beschreibung erweiterter Funktionalität"
    ],
    "notes": [
      "Wichtige Sicherheitsüberlegung oder Anforderung",
      "Systemanforderung oder Abhängigkeitsinformation",
      "Nutzungswarnung oder Best-Practice-Empfehlung"
    ]
  }
}
```

### When Modifying Existing Help Content

**Common Updates**:
- **New Options Added**: Add to `options` array in both languages
- **Functionality Changes**: Update `overview` description
- **New Requirements**: Add to `notes` array
- **Safety Changes**: Update warning information in `notes`

**Example Update**:
```json
// Before - Basic functionality
{
  "backup": {
    "overview": "Create system backups using various methods.",
    "options": [
      "1. Full System Backup - Complete system backup",
      "2. Home Directory - Backup user files only"
    ],
    "notes": [
      "Requires sufficient disk space for backup storage"
    ]
  }
}

// After - Added BTRFS support
{
  "backup": {
    "overview": "Create system backups using TAR, RSYNC, or BTRFS snapshot methods.",
    "options": [
      "1. Full System Backup - Complete system backup using TAR",
      "2. Home Directory - Backup user files only",
      "3. BTRFS Snapshot - Create filesystem snapshots (BTRFS only)",
      "4. Incremental Backup - RSYNC-based incremental backups"
    ],
    "notes": [
      "Requires sufficient disk space for backup storage",
      "BTRFS snapshot requires BTRFS filesystem",
      "Root privileges may be required for system-wide backups"
    ]
  }
}
```

### Help Content Display Logic

**HelpPanel Component** (`gui/web/src/components/HelpPanel.jsx`):
- Automatically loads help content using module ID
- Displays `overview`, `options`, and `notes` sections
- Handles missing translations gracefully with fallbacks
- Shows warnings in console for missing help content

## 4. Module Names and Categories Translation

### Frontend Module Display Names

**Location**: `gui/web/src/i18n/locales/*/common.json`

### When Adding New Module Names

```json
// In en/common.json
{
  "modules": {
    "names": {
      "new_module": "Display Name for New Module",
      // ... existing names
    },
    "categories": {
      "new_category": "New Category Display Name",
      // ... existing categories  
    }
  }
}

// In de/common.json
{
  "modules": {
    "names": {
      "new_module": "Anzeigename für Neues Modul", 
      // ... existing names
    },
    "categories": {
      "new_category": "Neuer Kategorie-Anzeigename",
      // ... existing categories
    }
  }
}
```

### When Renaming Modules

**Update Locations**:
1. **Module display name**: `modules.names.module_id` in both `en/common.json` and `de/common.json`
2. **Category name**: `modules.categories.category_key` if creating new category
3. **Backend module definition**: `Name` field in `getModules()` function

## 5. Documentation Panel Related Docs (`DocsPanel.jsx`)

### When Adding Related Documentation Links

**Location**: `gui/web/src/components/DocsPanel.jsx` - `relatedDocs` object

**Purpose**: Shows related documentation buttons for modules with multiple sub-documents

```jsx
const relatedDocs = {
  backup: [
    { id: 'mod_btrfs_backup', name: 'BTRFS Backup', description: 'Snapshot-based BTRFS backups' },
    { id: 'mod_btrfs_restore', name: 'BTRFS Restore', description: 'Restore from BTRFS snapshots' },
    { id: 'mod_backup_tar', name: 'TAR Backup', description: 'Archive-based backups' },
    // ... add new related docs here
  ],
  new_module: [  // Add for new modules with sub-documentation
    { id: 'mod_new_module_feature1', name: 'Feature 1', description: 'First feature docs' },
    { id: 'mod_new_module_feature2', name: 'Feature 2', description: 'Second feature docs' },
  ]
};
```

**When to Add Related Docs**:
- Module has multiple operational modes or sub-functions
- Module has separate documentation for different features
- Module has related tools or utilities with their own docs

## 6. Document Browser Categories (`DocumentBrowser.jsx`)

### When Adding New Documentation

**Location**: `gui/web/src/components/DocumentBrowser.jsx`

**Two Objects to Update**:

1. **documentCategories** - Maps category names to document IDs
```jsx
const documentCategories = {
  'System Administration': [
    'mod_system_info', 'mod_security', 'mod_disk', 
    'new_module'  // Add new module ID here
  ],
  'New Category': [  // Add new category if needed
    'new_category_module1', 'new_category_module2'
  ]
};
```

2. **documentNames** - Maps document IDs to friendly display names
```jsx
const documentNames = {
  'new_module': 'New Module Documentation',
  'new_category_module1': 'First New Category Module',
  // ... existing mappings
};
```

### When Creating New Documentation Categories

**Steps**:
1. **Add category** to `documentCategories` with appropriate module IDs
2. **Add display names** for all modules in `documentNames`
3. **Update default expanded state** in `expandedCategories` (optional)

```jsx
const [expandedCategories, setExpandedCategories] = useState({
  'System Administration': true,
  'Backup & Recovery': false,
  'New Category': false,  // Add new categories here
  // ... existing categories
});
```

## 7. Rebuild and Testing Requirements

### After Making Changes

**Required Steps**:
1. **Rebuild GUI**: Run `./gui/build.sh` to compile changes
2. **Restart Server**: Stop and restart GUI server
3. **Clear Browser Cache**: Force refresh or clear browser cache
4. **Test Both Languages**: Switch between English and German

**Testing Checklist**:
- [ ] Module appears in sidebar under correct category
- [ ] Module starts successfully from GUI
- [ ] Help panel displays correct information
- [ ] Documentation panel shows module docs (if mapped)
- [ ] Related documentation links work (if configured)
- [ ] Document browser shows module in correct category
- [ ] All text displays correctly in both languages
- [ ] No missing translation warnings in browser console

### Development vs Production

**Development Testing**:
```bash
cd gui/
./dev.sh  # Start development server
# Test changes with hot reload
```

**Production Build**:
```bash
cd gui/
./build.sh  # Create production build
./little-linux-helper-gui  # Test production binary
```

## 8. Common Maintenance Scenarios

### Scenario 1: Adding a New Backup Module

**Example**: Adding `mod_backup_database.sh`

**Checklist**:
1. ✅ **Backend Registration** (`gui/main.go`):
   ```go
   {
       ID:             "backup_database",
       Name:           "Database Backup",
       Description:    "Backup MySQL and PostgreSQL databases",
       Path:           "modules/backup/mod_backup_database.sh",
       Category:       "Backup & Recovery",
       SubmoduleCount: 0,
   }
   ```

2. ✅ **Documentation Mapping** (`gui/main.go`):
   ```go
   "backup_database": "mod_backup_database.md",
   ```

3. ✅ **Create Documentation File**: `docs/mod/mod_backup_database.md`

4. ✅ **Help Content** (`help.json`):
   ```json
   "backup_database": {
     "overview": "Create backups of MySQL and PostgreSQL databases with compression and encryption options.",
     "options": [
       "1. MySQL Backup - Full database backup with mysqldump",
       "2. PostgreSQL Backup - Full database backup with pg_dump",
       "3. Selective Tables - Backup specific tables only",
       "4. Compressed Backup - Create compressed backup files"
     ],
     "notes": [
       "Requires database credentials or admin access",
       "Large databases may take significant time to backup",
       "Ensure sufficient disk space for backup files"
     ]
   }
   ```

5. ✅ **Module Name Translation** (`common.json`):
   ```json
   "modules": {
     "names": {
       "backup_database": "Database Backup"
     }
   }
   ```

6. ✅ **Related Docs** (`DocsPanel.jsx`):
   ```jsx
   backup: [
     // ... existing entries
     { id: 'mod_backup_database', name: 'Database Backup', description: 'MySQL and PostgreSQL backup utilities' }
   ]
   ```

7. ✅ **Document Browser** (`DocumentBrowser.jsx`):
   ```jsx
   'Backup & Recovery': [
     // ... existing entries
     'mod_backup_database'
   ]
   ```

### Scenario 2: Renaming an Existing Module

**Example**: Renaming "System Info" to "System Diagnostics"

**Checklist**:
1. ✅ **Backend Name** (`gui/main.go`):
   ```go
   Name: "System Diagnostics",  // Changed from "System Information"
   ```

2. ✅ **Translation Updates** (`common.json`):
   ```json
   "modules": {
     "names": {
       "system_info": "System Diagnostics"  // Update display name
     }
   }
   ```

3. ✅ **Help Content Review**: Update help content if functionality changed

4. ✅ **Documentation Updates**: Update any references in documentation files

### Scenario 3: Changing Module Categories

**Example**: Moving "Energy Management" from "System Tools" to "Maintenance & Security"

**Checklist**:
1. ✅ **Backend Category** (`gui/main.go`):
   ```go
   Category: "Maintenance & Security",  // Changed from previous category
   ```

2. ✅ **Document Browser** (`DocumentBrowser.jsx`):
   ```jsx
   'Maintenance & Security': [
     // ... existing entries  
     'mod_energy'  // Move from old category
   ]
   ```

3. ✅ **Test Sidebar Grouping**: Verify module appears under new category

## 9. Debugging and Troubleshooting

### Common Issues After Changes

**Module Not Appearing in GUI**:
- Check backend module definition in `getModules()`
- Verify module file exists at specified path
- Restart GUI server after backend changes

**Help Content Not Displaying**:
- Check `help.json` files have correct module ID keys
- Verify JSON syntax is valid
- Look for console warnings about missing translations

**Documentation Not Loading**:
- Verify `moduleDocMap` entry exists
- Check documentation file exists in `docs/mod/`
- Ensure file has proper markdown format

**Missing Translations**:
- Check both `en/` and `de/` translation files
- Verify key structures match between languages
- Look for console warnings about missing keys

### Browser Console Debugging

**Useful Console Messages**:
- `[HelpPanel] No help content found for module: module_id`
- `[i18n] Missing translation key: "key" in namespace "ns"`
- `Translation missing for key: some.key`
- `Failed to fetch module docs:` (network errors)

**Enable Debug Mode**:
```javascript
// In development, i18n debug mode shows detailed translation info
localStorage.setItem('i18nextDebug', 'true');
```

## 10. Best Practices

### Maintenance Workflow

1. **Plan Changes**: Document what needs updating before starting
2. **Update Backend First**: Module definitions and mappings
3. **Add Documentation**: Create or update markdown files  
4. **Update Frontend**: Help content and translations
5. **Test Incrementally**: Test each change before moving to next
6. **Test Both Languages**: Always verify English and German content
7. **Clear Cache**: Force refresh browsers after changes

### Translation Best Practices

- **Consistent Terminology**: Use same terms across all translations
- **Cultural Adaptation**: Adapt for German technical terminology
- **Complete Coverage**: Never leave English keys in German files
- **Professional Tone**: Use professional, technical language
- **User-Friendly**: Write help content for end users, not developers

### Documentation Standards

- **Consistent Structure**: Follow existing documentation patterns
- **Comprehensive Coverage**: Document all features and options
- **User-Focused**: Write for system administrators, not developers
- **Examples Included**: Provide usage examples where helpful
- **Safety Notes**: Include warnings for potentially dangerous operations

---

*This maintenance guide ensures consistency across all GUI components when modules change. Always test thoroughly after making updates, and refer to the specialized documentation guides for detailed implementation information.*