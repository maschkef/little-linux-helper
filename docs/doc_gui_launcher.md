<!--
File: docs/doc_gui_launcher.md
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
-->

# GUI Launcher Script: `gui_launcher.sh`

**Purpose:**
The GUI Launcher Script (`gui_launcher.sh`) is a specialized launcher that provides convenient access to the Little Linux Helper GUI with comprehensive configuration options, security features, and automatic dependency management. It serves as the recommended entry point for GUI access from CLI environments.

**Location:** `gui_launcher.sh` (project root directory)

## 1. Core Functionality

**Primary Functions:**
- **GUI Launch Management:** Intelligent launching of the GUI with configurable options
- **Automatic Build Management:** Handles GUI building when necessary with user consent
- **Network Security Control:** Manages secure local vs. network access modes
- **Firewall Integration:** Automatic firewall port management with cleanup
- **Dependency Validation:** Ensures all required tools are available before execution
- **Configuration Integration:** Seamlessly integrates with project configuration files

**Initialization Process:**
1. Command line argument parsing with comprehensive debugging
2. Integration with Little Linux Helper library system (`lib_common.sh`)
3. Configuration loading and environment setup
4. Dependency validation and management
5. Build process handling (conditional or forced)
6. Firewall management setup
7. GUI binary execution with appropriate parameters

## 2. Command Line Interface

### Usage Syntax
```bash
./gui_launcher.sh [OPTIONS]
```

### Available Options

| Option | Long Form | Description | Security Level |
|--------|-----------|-------------|----------------|
| `-h` | `--help` | Display comprehensive help information | Safe |
| `-b` | `--build` | Force rebuild of GUI before launching | Safe |
| `-n` | `--network` | Enable network access (bind to 0.0.0.0) | **Caution** |
| `-f` | `--open-firewall` | Automatically manage firewall port opening | **Requires Admin** |
| `-p PORT` | `--port PORT` | Set custom port (overrides config) | Safe |

### Usage Examples

**Secure Local Access (Recommended):**
```bash
# Default secure access - localhost only
./gui_launcher.sh

# Custom port, still secure
./gui_launcher.sh -p 8080
./gui_launcher.sh --port 8080
```

**Network Access (Use with Caution):**
```bash
# Enable network access
./gui_launcher.sh -n

# Network access with automatic firewall management
./gui_launcher.sh -n -f

# Network access on custom port with firewall
./gui_launcher.sh -n -p 80 -f
```

**Build Management:**
```bash
# Force rebuild before launching
./gui_launcher.sh -b

# Rebuild and enable network access
./gui_launcher.sh -b -n
```

## 3. Security Features

### Access Control Modes

**Secure Mode (Default):**
- Binds to `localhost` only
- Accessible only from local machine
- No network exposure risk
- No firewall modifications needed

**Network Mode (`-n/--network`):**
- Binds to `0.0.0.0` (all interfaces)
- Accessible from network (LAN/WAN)
- **Security Warning:** Displayed automatically
- Requires careful consideration of network security

### Enhanced Firewall Management

**Intelligent Port Management (`-f/--open-firewall`):**
- **Supported Firewalls:** firewalld, ufw, iptables
- **Automatic Detection:** Detects available firewall tools
- **Smart IP Restrictions:** Configurable access control with network detection
- **Port Opening:** Opens specified port with IP-based restrictions
- **Cleanup on Exit:** Automatically closes port when GUI stops
- **Signal Handling:** Handles Ctrl+C, termination signals
- **Multi-Tool Support:** Works with different Linux distributions

**IP Restriction Options:**
1. **All IPs (0.0.0.0/0)** - Global internet access (high risk)
2. **Detected Local Networks** - Automatically detected current networks (recommended)
3. **Specific IP Address** - Single machine access (most secure)
4. **Custom CIDR Range** - Custom network segment

**Configuration Support (`config/general.d/30-gui.conf`, legacy `config/general.conf`):**
```bash
# Firewall IP restriction configuration
CFG_LH_GUI_FIREWALL_RESTRICTION="local"     # Auto-detect local networks
CFG_LH_GUI_FIREWALL_RESTRICTION="all"       # Allow all IPs (not recommended)
CFG_LH_GUI_FIREWALL_RESTRICTION="192.168.1.100"  # Specific IP
CFG_LH_GUI_FIREWALL_RESTRICTION=""          # Prompt user each time
```

**Network Detection:**
- **Automatic Discovery:** Detects actual local network ranges (not hardcoded)
- **Interface Analysis:** Scans all network interfaces
- **CIDR Calculation:** Calculates proper network addresses from detected IPs
- **Security Focus:** Only allows access from networks the system is actually connected to

**Firewall Tool Priority:**
1. **firewalld** - Enterprise/Red Hat systems (supports rich rules with IP restrictions)
2. **ufw** - Ubuntu/Debian systems (supports source IP filtering)
3. **iptables** - Direct iptables management (supports source filtering, non-persistent)

**Cleanup Mechanism:**
```bash
# Automatic cleanup on:
# - Normal exit
# - Ctrl+C (SIGINT)  
# - Termination (SIGTERM)
# - Script exit
# Removes all created firewall rules
```

### Enhanced Security Warnings

**Elevated Privilege Detection:**
When running with sudo and network mode (`-n`), displays comprehensive security assessment:

**Real-time Security Status:**
- **Port Detection:** Shows actual port being used
- **Firewall Status:** Active/inactive with firewall type (firewalld/ufw/iptables)
- **Port Accessibility:** Whether port is already open or blocked
- **Configuration Status:** Shows firewall restriction settings from config
- **Risk Assessment:** Categorizes security risk level

**Dynamic Risk Categories:**
- **🚨 HIGH RISK:** No firewall active or port already open without protection
- **⚠️ MODERATE RISK:** Configured for global internet access ("all" setting)
- **✅ LOWER RISK:** Active firewall with proper IP restrictions

**Contextual Recommendations:**
- **Smart suggestions** based on current system state
- **Specific guidance** like using `-f` flag when firewall is available
- **Security best practices** tailored to detected configuration

**Interactive Confirmation:**
- **Required confirmation** for elevated privilege network access
- **User education** about risks and mitigation strategies
- **Cancellation option** to abort launch for security reasons

## 4. Configuration Integration

### Configuration File Support

**Primary Configuration:** `config/general.d/*.conf` (legacy `config/general.conf`)
```bash
# Default port setting
CFG_LH_GUI_PORT="3000"

# Default host binding
CFG_LH_GUI_HOST="localhost"

# Firewall IP restriction configuration (new feature)
CFG_LH_GUI_FIREWALL_RESTRICTION="local"    # Auto-detect local networks
# CFG_LH_GUI_FIREWALL_RESTRICTION="all"    # Allow all IPs (not recommended)
# CFG_LH_GUI_FIREWALL_RESTRICTION="192.168.1.100"  # Specific IP
# CFG_LH_GUI_FIREWALL_RESTRICTION=""       # Prompt user each time
```

**Configuration Priority:**
1. **Command Line Arguments** (highest priority)
2. **Configuration File** (`config/general.d/*.conf`)
3. **Built-in Defaults** (port 3000, localhost binding)

### Environment Integration

**Environment Variables Set:**
- `LH_ROOT_DIR` - Project root directory
- `LH_GUI_MODE=true` - GUI mode indicator
- `LH_LOG_FILE` - Custom log file with timestamp

**Custom Logging:**
- **Log File Format:** `YYMMDD-HHMM_gui_launcher.log`
- **Log Location:** `$LH_LOG_DIR/` directory
- **Debug Information:** Comprehensive debug logging throughout execution

## 5. Build Management

### Automatic Build Detection

**Build Triggers:**
- **Missing Binary:** GUI executable not found
- **Explicit Request:** `-b/--build` flag used
- **User Confirmation:** Interactive confirmation for missing binary

**Build Process:**
1. **Dependency Verification:** Checks for Go, Node.js, npm
2. **Setup Execution:** Runs `setup.sh` if needed
3. **Build Execution:** Runs `build.sh` for compilation
4. **Success Verification:** Confirms successful build completion

### Dependency Management

**Required Dependencies:**
- **Go** (1.18+, 1.21+ recommended)
- **Node.js** (18+)
- **npm** (Node Package Manager)

**Dependency Handling:**
- **Automatic Detection:** Uses Little Linux Helper library functions
- **Installation Attempts:** Via detected package manager
- **Error Reporting:** Clear messages for missing dependencies
- **Graceful Failure:** Exits cleanly if dependencies unavailable

## 6. Advanced Features

### Multi-Language Support

**Language Integration:**
- **Translation Loading:** Loads GUI launcher translations
- **Common Translations:** Integrates with common message system
- **Library Translations:** Uses library translation functions
- **Error Messages:** Localized error and status messages

**Supported Languages:**
- English (default)
- German
- Framework for additional languages

### Debug and Logging

**Comprehensive Debug Information:**
- **CLI Argument Parsing:** Debug output for all arguments
- **Execution Flow:** Step-by-step process logging
- **Error Tracking:** Detailed error information
- **Environment Status:** Variable and configuration state logging

**Log Categories:**
- **DEBUG:** Detailed execution information
- **INFO:** General status updates
- **WARN:** Warning conditions
- **ERROR:** Error conditions with details

### Error Handling

**Robust Error Management:**
- **Dependency Failures:** Clear messages for missing tools
- **Build Failures:** Detailed build error reporting
- **Configuration Errors:** Configuration validation and reporting
- **Firewall Failures:** Graceful handling of firewall issues
- **Permission Errors:** Clear messages for privilege requirements

## 7. Integration Points

### Little Linux Helper Integration

**Library Dependencies:**
- **`lib_common.sh`** - Core library functions
- **Configuration Management** - Config file handling
- **Logging System** - Integrated logging
- **Package Detection** - System package manager detection
- **Language System** - Translation and localization

**Environment Preservation:**
- **Variable Inheritance** - All LH environment variables
- **Configuration Consistency** - Same config as CLI system
- **Permission Model** - Same security context as CLI

### GUI Binary Interface

**Parameter Passing:**
- **Network Mode:** `-network` flag forwarding
- **Port Configuration:** `-port` parameter forwarding
- **Clean Execution:** `exec` for optimal resource usage

**Binary Requirements:**
- **Location:** `gui/little-linux-helper-gui`
- **Build Status:** Must exist or be buildable
- **Execution Context:** Same directory as binary

## 8. Troubleshooting

### Common Issues

**Build Problems:**
```bash
# Missing dependencies
./gui_launcher.sh -b    # Force rebuild with dependency check
```

**Network Access Issues:**
```bash
# Port conflicts
./gui_launcher.sh -p 8080    # Try different port

# Firewall problems  
./gui_launcher.sh -n -f      # Automatic firewall management
```

**Permission Issues:**
```bash
# Firewall requires sudo
# Launcher automatically handles sudo requirements via LH_SUDO_CMD
```

### Error Resolution

**Dependency Errors:**
1. Check system package manager
2. Install missing tools (Go, Node.js)
3. Verify versions meet requirements
4. Run setup manually if needed

**Build Errors:**
1. Verify all dependencies installed
2. Check network connectivity for package downloads
3. Review build logs for specific errors
4. Clean and retry build process

**Firewall Errors:**
1. Verify administrative privileges
2. Check firewall service status
3. Try manual port management
4. Review system firewall configuration

## 9. Technical Implementation

### Script Architecture

**Modular Design:**
- **Argument Processing** - Clean CLI parameter handling
- **Configuration Integration** - Seamless config file support
- **Security Functions** - Firewall management functions
- **Build Management** - Comprehensive build handling
- **Error Management** - Robust error handling throughout

### Function Documentation

**Key Internal Functions:**
- **`_determine_gui_port()`** - Port resolution logic
- **`_open_firewall_port()`** - Firewall port opening
- **`_close_firewall_port()`** - Firewall port closing  
- **`cleanup_firewall()`** - Exit cleanup handling

**Security Functions:**
```bash
# Firewall management with multi-tool support
_open_firewall_port "$PORT_NUMBER"    # Opens port
_close_firewall_port "$PORT_NUMBER"   # Closes port
cleanup_firewall                      # Automatic cleanup
```

### Integration Points

**Library Integration:**
```bash
source "$LH_ROOT_DIR/lib/lib_common.sh"    # Core functions
lh_ensure_config_files_exist               # Config setup
lh_load_general_config                     # Config loading
lh_initialize_logging                      # Logging setup
```

## 10. Best Practices

### Recommended Usage Patterns

**Development Workflow:**
```bash
# Development with automatic rebuild
./gui_launcher.sh -b

# Development with network access
./gui_launcher.sh -b -n -f
```

**Production Deployment:**
```bash
# Secure production access
./gui_launcher.sh

# Production with custom port
./gui_launcher.sh -p 8080
```

**Security-Conscious Usage:**
```bash
# Always prefer local access when possible
./gui_launcher.sh

# Use network mode only when necessary
./gui_launcher.sh -n -f    # With automatic firewall management
```

### Security Guidelines

**Network Access Considerations:**
1. **Use Local Mode** when possible (default)
2. **Network Mode** only for legitimate remote access needs
3. **Firewall Management** always use `-f` flag with `-n` flag
4. **Monitor Access** be aware of who can access the network-enabled GUI
5. **Clean Shutdown** use Ctrl+C for proper firewall cleanup

**Administrative Privileges:**
- **Firewall Management** may require sudo privileges
- **Port Binding** ports below 1024 require root access
- **System Integration** respects existing user permissions

---

*This documentation provides comprehensive guidance for using the GUI Launcher Script effectively and securely. The launcher serves as the primary entry point for GUI access while maintaining the security and reliability standards of the Little Linux Helper project.*
