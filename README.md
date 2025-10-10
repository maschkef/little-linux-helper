# Little Linux Helper

## Description

<img src="gui/web/public/header-logo.svg" alt="Little Linux Helper" width="350" height="350" align="right" style="margin-left: 20px; margin-top: 20px;">

Little Linux Helper is a comprehensive collection of Bash scripts designed to simplify various system administration, diagnostic, and maintenance tasks on Linux. It provides both a traditional command-line menu-driven interface and a modern web-based GUI for easy access to a variety of tools and functions.

More detailed technical English documentation for individual modules and core components can be found in the `docs` directory.
The `docs/CLI_DEVELOPER_GUIDE.md` contains all the information about `lib/lib_common.sh` and `help_master.sh` needed to create a new module.
Note: The original `lib_common.sh` has been split into multiple specialized libraries for better organization (e.g., `lib_colors.sh`, `lib_i18n.sh`, `lib_notifications.sh`, etc.), but `lib_common.sh` remains the main entry point and automatically loads all other core libraries. Additionally, `lib_btrfs.sh` is a specialized library used exclusively by BTRFS modules and is not part of the core library system.

My environment is typically Arch (main system) or Debian (various services on my Proxmox - hence the Docker components), so there may be unknown issues on other distributions, although I try to keep everything compatible.

<br clear="right">

> **🎯 Project Status:**
> - **Documentation**: Comprehensive technical documentation is available in the `docs/` directory for all modules and core components
> - **GUI Interface**: Full internationalization (English/German) with error-resilient translation system and comprehensive help content
> - **BTRFS Modules**: Advanced BTRFS backup and restore modules with atomic operations, incremental backup chains, and comprehensive safety features
> - **Modular Architecture**: Clean separation of backup types into specialized modules (BTRFS, TAR, RSYNC) with unified dispatcher interface
> - **Session Awareness**: Enhanced session registry with intelligent conflict detection and blocking categories to prevent dangerous concurrent operations
> - **Testing Status**: Backup functions are well-tested and stable; restore functions are implemented but require comprehensive testing before production use
> - **Update**: the btrfs backup module needs testing (again)

<details>
<summary>⚠️ Important Usage Notes</summary>

**Please carefully consider the following points before using the scripts from this repository:**

* **Not a professional programmer:** I'm not actually a programmer. These scripts were created as a hobby project and for simplification. They may therefore contain suboptimal approaches, errors, or inefficient methods.
* **Use at your own risk:** The use of the scripts provided here is entirely at your own risk. I assume no responsibility or liability for possible data loss, system instabilities, damage to hardware or software, or any other direct or indirect consequences that could result from using these scripts. It is strongly recommended to always create backups of your important data and system before performing critical operations.
* **AI-generated content:** A significant portion of the scripts and accompanying documentation was created with the assistance of Artificial Intelligence (AI). Although I have endeavored to test the functionality and verify the information, the scripts may contain errors, unexpected behavior, or logical flaws attributable to the AI generation process. Be aware of this circumstance and critically review the code before deploying it, especially in production or sensitive environments.

</details>

## License

This project is licensed under the MIT License. For more information, see the `LICENSE` file in the project root directory.

<details>
<summary>❗ Known Issues and Limitations</summary>

Here is a list of known issues, limitations, or behaviors you might encounter when using the scripts.

* **System Compatibility:**
    * Primary testing environment: Arch Linux (main system) and Debian (Proxmox services)
    * Other distributions may have unknown compatibility issues, though scripts are designed for broad compatibility
    * Some features require specific package managers or system tools

* **Advanced Log Analysis (`scripts/advanced_log_analyzer.py`):**
    * Known limitations regarding log format recognition and character encoding
    * Complex regular expressions may not handle all log variations
    * See `docs/tools/doc_advanced_log_analyzer.md` for detailed limitations and usage notes

* **Module-Specific Limitations:**
    * **BTRFS Operations**: Requires BTRFS filesystem and appropriate privileges
    * **Docker Security**: Scanning depth and accuracy depend on Compose file complexity
    * **Hardware Monitoring**: Temperature sensors require `lm-sensors` and proper hardware support

</details>

## Features

The project offers two interfaces for accessing its functionality:

### 🖥️ **Command Line Interface (CLI)**
The main script `help_master.sh` serves as the central CLI entry point and provides access to all modules through a traditional menu-driven interface.

### 🌐 **Graphical User Interface (GUI)**
A modern web-based GUI is available through `gui_launcher.sh`, providing:
- **Web-based Interface**: Modern React frontend with responsive design accessible via web browser
- **Multi-Session Support**: Unlimited concurrent module sessions with session dropdown management
- **Real-time Terminal**: Integrated terminal display with ANSI color support and interactive input handling
- **Advanced Session Management**: Session switching, status indicators, output preservation, and individual session control
- **Module Navigation**: Categorized sidebar with individual "Start" buttons and intuitive module selection (hideable)
- **Enhanced Documentation System**: Dual-mode documentation with module-bound docs and independent document browser
- **Document Browser**: Categorized navigation through all documentation with collapsible groups and search
- **Panel Control System**: Hide/show modules sidebar, terminal panels, help, and docs for optimal reading experience
- **Full-Screen Reading Mode**: Hide all panels except documentation for maximum reading space
- **Multi-panel Layout**: Resizable panels with flexible show/hide controls for optimal workspace organization
- **Security Features**: Localhost-only binding by default with optional network access via command line
- **Configurable Networking**: Port and host configuration via `config/general.conf` or command line arguments
- **Internationalization Support**: Full English/German translations with dynamic language switching
- **Error-Resilient Design**: Missing translation keys display fallback content instead of crashing
- **Comprehensive Help System**: Context-sensitive help with detailed module guidance and usage notes
- **Advanced Features**: PTY integration for authentic terminal experience, WebSocket communication for real-time updates

> **🌐 Internationalization:** The GUI supports full English/German translations with dynamic language switching and GUI-to-CLI language inheritance.

<details>
<summary>GUI Configuration & Usage:</summary>

```bash
# GUI Launcher (Recommended):
./gui_launcher.sh              # Default: secure localhost
./gui_launcher.sh -n           # Enable network access (-n shorthand)
./gui_launcher.sh -n -f        # Network access with firewall port opening
./gui_launcher.sh -p 8080      # Custom port (short form)
./gui_launcher.sh --port 8080  # Custom port (long form)
./gui_launcher.sh -n -p 80 -f  # Network access on custom port with firewall
./gui_launcher.sh -b -n        # Build and run with network access
./gui_launcher.sh -h           # Comprehensive help

# Custom configuration via config/general.conf:
CFG_LH_GUI_PORT="3000"        # Set default port
CFG_LH_GUI_HOST="localhost"   # Set binding (localhost/0.0.0.0)
CFG_LH_GUI_FIREWALL_RESTRICTION="local"  # IP restrictions for firewall opening

# Direct binary execution (advanced users):
./gui/little-linux-helper-gui -p 8080         # Custom port (short form)
./gui/little-linux-helper-gui --port 8080     # Custom port (long form)
./gui/little-linux-helper-gui -n              # Enable network access (-n shorthand)
./gui/little-linux-helper-gui --network -p 80 # Network access on port 80
./gui/little-linux-helper-gui -h              # Show usage information (short form)
./gui/little-linux-helper-gui --help          # Show usage information (long form)
```

The GUI maintains full compatibility with all CLI functionality while providing an enhanced user experience with powerful multi-session capabilities and **full internationalization support (English/German)** with dynamic language switching.

</details>

---

Both interfaces provide access to the following modules:

<details>
<summary>🔄 Recovery & Restarts (<code>mod_restarts.sh</code>)</summary>

* Restart the login manager (display manager).
* Restart the sound system (PipeWire, PulseAudio, ALSA).
* Restart the desktop environment (KDE, GNOME, XFCE, Cinnamon, MATE, LXDE, LXQt).
* Restart network services (NetworkManager, systemd-networkd, dhcpcd, systemd-resolved).
* Restart firewall services (firewalld, UFW, nftables, netfilter-persistent, Shorewall).
* **Session Awareness**: Registers with blocking categories (`SYSTEM_CRITICAL`) and checks for conflicts before critical operations.

</details>

<details>
<summary>💾 Backup & Restore System</summary>

* **Unified Backup Dispatcher** (`modules/backup/mod_backup.sh`):
    * Central dispatcher providing unified interface for all backup types
    * Shared configuration management and status reporting across all backup methods
    * Comprehensive status overview covering BTRFS, TAR, and RSYNC backups
    * **Session Awareness**: Registers with blocking categories (`FILESYSTEM_WRITE`, `SYSTEM_CRITICAL`) to prevent conflicts

* **BTRFS Snapshot Backup & Restore** (`modules/backup/mod_btrfs_backup.sh`, `modules/backup/mod_btrfs_restore.sh`):
    * **Advanced Features**: Atomic backup operations, received_uuid protection, incremental chain validation
    * **Advanced BTRFS Library** (`lib/lib_btrfs.sh`): Specialized library solving critical BTRFS limitations with true atomic patterns
    * **Dynamic Subvolume Support**: Automatically detects BTRFS subvolumes from system configuration (`/etc/fstab`, `/proc/mounts`) while supporting manual configuration for `@`, `@home`, `@var`, `@opt`, and other @-prefixed subvolumes with optional source preservation
    * **Incremental Backups**: Intelligent parent detection, automatic fallback, and comprehensive chain integrity validation
    * **Restore Capabilities**: Complete system restore, individual subvolume restore, folder-level restoration, and bootloader integration *(Note: Restore functions are implemented but require comprehensive testing)*
    * **Safety Features**: Live environment detection, filesystem health checking, rollback capabilities, and dry-run support
    * **Maintenance Submenu**: Dedicated maintenance section with deletion tools, problematic backup cleanup, source snapshot management, incremental chain inspection, and orphan `.receiving_*` staging snapshot cleanup
    * **Detailed Documentation**: See `docs/mod/doc_btrfs_backup.md`, `docs/mod/doc_btrfs_restore.md`, and `docs/lib/doc_btrfs.md`

* **TAR Archive Backup & Restore** (`modules/backup/mod_backup_tar.sh`, `modules/backup/mod_restore_tar.sh`):
    * **Flexible Backup Options**: Home only, system config, full system, or custom directory selection
    * **Intelligent Exclusions**: Built-in system exclusions, user-configurable patterns, and interactive exclusion management
    * **Archive Management**: Compressed `.tar.gz` archives with automatic cleanup and retention policies
    * **Safe Restoration**: Multiple destination options with safety warnings and confirmation prompts
    * **Session Awareness**: Backup and restore operations register with appropriate blocking categories
    * **Documentation**: See `docs/mod/doc_backup_tar.md` and `docs/mod/doc_restore_tar.md`

* **RSYNC Incremental Backup & Restore** (`modules/backup/mod_backup_rsync.sh`, `modules/backup/mod_restore_rsync.sh`):
    * **Incremental Intelligence**: Space-efficient backups using hardlink optimization with `--link-dest`
    * **Backup Types**: Full backups and incremental backups with automatic parent detection
    * **Advanced Options**: Comprehensive RSYNC configuration with atomic operations and progress monitoring
    * **Flexible Restoration**: Real-time progress monitoring and complete directory tree restoration
    * **Session Awareness**: Backup and restore operations register with appropriate blocking categories
    * **Documentation**: See `docs/mod/doc_backup_rsync.md` and `docs/mod/doc_restore_rsync.md`

</details>

<details>
<summary>💻 System Diagnostics & Analysis</summary>

* **System Information Display (`mod_system_info.sh`)**:
    * Display of operating system and kernel details.
    * CPU information.
    * RAM usage and memory statistics.
    * Listing of PCI and USB devices.
    * Disk overview (block devices, file systems, mount points).
    * Display of top processes by CPU and memory usage.
    * Network configuration (interfaces, routes, active connections, hostname, DNS).
    * Temperatures and sensor values (requires `lm-sensors`).
* **Disk Tools (`mod_disk.sh`)**:
    * Display of mounted drives and block devices.
    * Reading S.M.A.R.T. values (requires `smartmontools`).
    * Checking file access to folders (requires `lsof`).
    * Analysis of disk usage (with `df` and optionally `ncdu`).
    * Testing disk speed (requires `hdparm`).
    * File system verification (requires `fsck`).
    * Checking disk health status (requires `smartmontools`).
    * Display of largest files in a directory.
    * **Session Awareness**: Resource-intensive operations register with blocking categories (`RESOURCE_INTENSIVE`).
* **Log Analysis Tools (`mod_logs.sh`)**:
    * Display of logs from the last X minutes (current and previous boot, may require `journalctl`).
    * Display logs of a specific systemd service (requires `journalctl`).
    * Display Xorg logs.
    * Display and filter dmesg output.
    * Display package manager logs (supports pacman, apt, dnf, yay).
    * **Advanced Log Analysis (`scripts/advanced_log_analyzer.py`)**:
        * Performs more detailed analysis of log files (requires Python 3, typically as `python3` command).
        * Supports formats like Syslog, Journald (text export), and Apache (Common/Combined), including automatic format detection.
        * Shows general statistics (total entries, error count, error rate).
        * Lists frequent error messages or error status codes.
        * Analyzes temporal distribution of log entries (e.g., per hour).
        * Identifies top sources (programs/services for Syslog, IP addresses for Apache).
        * Offers options for customizing output (e.g., number of top entries, summary only, errors only).
        * *Note: This script offers advanced features but should be used with care and understanding of its functionality, especially considering the general project notes*.

</details>

<details>
<summary>🛠️ Maintenance & Security</summary>

* **Package Management & Updates (`mod_packages.sh`)**:
    * System updates (supports pacman, apt, dnf, yay).
    * Updates of alternative package managers (Flatpak, Snap, Nix).
    * Search and removal of orphaned packages.
    * Package cache cleanup.
    * Search and installation of packages.
    * Display of installed packages (including alternative sources).
    * Display of package manager logs.
    * **Session Awareness**: Critical operations check for conflicts with backup processes.
* **Security Checks (`mod_security.sh`)**:
    * Display of open network ports (requires `ss`, optionally `nmap`).
    * Display of failed login attempts.
    * Check system for rootkits (requires `rkhunter`, optionally `chkrootkit`).
    * Check firewall status (UFW, firewalld, iptables).
    * Check for security updates.
    * Verification of password policies and user accounts.
    * **Docker Security Check**:
        * Analyzes Docker Compose files (`docker-compose.yml`, `compose.yml`) for common security issues.
        * Search path for Compose files, search depth, and directories to exclude are configurable.
        * Provides interactive configuration of the search path if the current path is invalid or needs to be changed.
        * Performs a series of checks, including:
            * Missing update management labels (e.g., for Diun, Watchtower).
            * Insecure permissions for `.env` files.
            * Too open permissions for directories containing Compose files.
            * Use of `:latest` image tags or images without specific versioning. (Disabled by default in `config/docker.conf.example`.)
            * Configuration of containers with `privileged: true`.
            * Mounting critical host paths as volumes (e.g., `/`, `/etc`, `/var/run/docker.sock`). (Currently not output in the summary.)
            * Ports exposed on `0.0.0.0`, making services available to all network interfaces.
            * Use of potentially dangerous Linux capabilities (e.g., `SYS_ADMIN`, `NET_ADMIN`).
            * Disabled security options like `apparmor:unconfined` or `seccomp:unconfined`.
            * Occurrence of known default passwords in environment variables.
            * Direct embedding of sensitive data (e.g., API keys, tokens) instead of environment variables. (currently not working properly)
        * Optionally displays a list of currently running Docker containers. (Disabled by default in `config/docker.conf.example`.)
        * Provides a summary of found potential issues with recommendations.
    * **Session Awareness**: Rootkit scans register with blocking categories (`RESOURCE_INTENSIVE`) to prevent interference.

</details>

<details>
<summary>🐳 Docker Management</summary>

* **Docker Container Management (`mod_docker.sh`)**:
    * Container status monitoring and management.
    * Docker system information and resource usage.
    * Container log access and analysis.
    * Network and volume management.
    * **Session Awareness**: Registers with blocking categories to coordinate with system operations.
* **Docker Setup & Installation (`mod_docker_setup.sh`)**:
    * Automated Docker installation across distributions.
    * Docker Compose setup and configuration.
    * User permission configuration for Docker access.
    * System service configuration and startup.
    * **Session Awareness**: Installation operations register with blocking categories (`SYSTEM_CRITICAL`).

</details>

<details>
<summary>🔋 Energy Management & System Control</summary>

* **Energy Management (`mod_energy.sh`)**:
    * Power profile management (performance, balanced, power-saver).
    * Sleep/suspend control with timed inhibit functionality.
    * Screen brightness control.
    * Quick actions for restoring sleep functionality.
    * **Session Awareness**: Registers with session registry to coordinate with other system operations.

</details>

<details>
<summary>✨ Special Features</summary>

* Collect important debug information in a file.

</details>

## Internationalization

<details>
<summary>🌍 Multi-language Support</summary>

Little Linux Helper supports multiple languages for the user interface. The internationalization system enables a consistent and user-friendly experience in different languages.

**Supported Languages:**
* **German (de)**: Full translation support for all modules
* **English (en)**: Full translation support for all modules (default language and fallback)
* **Spanish (es)**: Only scattered internal translations (log entries, etc.), practically unusable
* **French (fr)**: Only scattered internal translations (log entries, etc.), practically unusable

**Language Selection:**
* **Automatic Detection**: The system automatically detects the system language based on environment variables (`LANG`, `LC_ALL`, `LC_MESSAGES`)
* **Manual Configuration**: The language can be set in the `config/general.conf` file with the `CFG_LH_LANG` setting
* **Fallback Mechanism**: For missing translations or unsupported languages, the system automatically falls back to English

**Language Configuration:**
```bash
# In config/general.conf
CFG_LH_LANG="auto"    # Automatic system language detection
CFG_LH_LANG="de"      # German
CFG_LH_LANG="en"      # English
CFG_LH_LANG="es"      # Spanish (practically unusable, only internal messages)
CFG_LH_LANG="fr"      # French (practically unusable, only internal messages)
```

**Technical Details:**
* All user texts are retrieved through the `lh_msg()` system
* Translation files are located in the `lang/` directory, organized by language codes
* The system first loads English as a fallback base and then overwrites with the desired language
* Missing translation keys are automatically logged and displayed as `[KEY]`

</details>

## Requirements

<details>
<summary>📋 Requirements</summary>

### Core Requirements:
* Bash shell
* Standard Linux utilities (such as `grep`, `awk`, `sed`, `find`, `df`, `lsblk`, `ip`, `ps`, `free`, `tar`, `rsync`, `btrfs-progs`, etc.)
* Some functions may require root privileges and will use `sudo` if necessary.

### GUI Requirements (optional):
* **Go** (1.18 or later) for backend server compilation
* **Node.js** (16 or later) and **npm** for frontend development and building
* **Web browser** for accessing the GUI interface
* Additional system dependencies: `github.com/gofiber/fiber/v2`, `github.com/gofiber/websocket/v2`, `github.com/creack/pty` (installed automatically)

### Optional Dependencies:
For specific functions, additional packages are required that the script will attempt to install as needed:
    * `btrfs-progs` (for BTRFS backup/restore)
    * `rsync` (for RSYNC backup/restore)
    * `smartmontools` (for S.M.A.R.T. values and disk health status)
    * `lsof` (for file access checking)
    * `hdparm` (for disk speed testing)
    * `ncdu` (for interactive disk analysis, optional)
    * `util-linux` (contains `fsck`)
    * `iproute2` (contains `ss`)
    * `rkhunter` (for rootkit checking)
    * `chkrootkit` (optional, for additional rootkit checking)
    * `lm-sensors` (for temperature and sensor values)
    * `nmap` (optional, for local port scanning)
    * **Desktop notifications:** `libnotify` (provides `notify-send`), `zenity`, or `kdialog`.
    * Python 3 (typically as `python` or `python3` command; for advanced log analysis)
    * `pacman-contrib` (for `paccache` on Arch-based systems, if not available)
    * `expac` (for recently installed packages on Arch-based systems)

The script attempts to automatically detect the package manager in use (pacman, yay, apt, dnf). It also recognizes alternative package managers like Flatpak, Snap, Nix, and AppImage.

</details>

## Installation & Setup

<details>
<summary>🚀 Installation & Setup</summary>

### 📦 **Pre-built Releases (Recommended)**

**Starting with v0.4.0, pre-built GUI releases are available** that eliminate the need for Node.js/npm on user systems:

#### Quick Install:
```bash
# Download and run the automatic installer
curl -L https://raw.githubusercontent.com/maschkef/little-linux-helper/main/install-prebuilt.sh | sudo bash
```

#### Manual Download:
1. Go to [GitHub Releases](https://github.com/maschkef/little-linux-helper/releases)
2. Download the package for your architecture:
   - **AMD64** - Most modern 64-bit systems (Intel/AMD processors)
   - **ARM64** - Raspberry Pi 4, modern ARM servers
   - **ARMv7** - Raspberry Pi 2/3, older ARM devices
3. Extract and run:
   ```bash
   tar -xzf little-linux-helper-gui-<arch>.tar.gz
   cd little-linux-helper-gui-<arch>
   ./gui_launcher.sh
   ```

**System Requirements (Pre-built):**
- Any Linux distribution
- No Node.js, npm, or Go required!
- Ready to run out of the box

#### 📋 **GUI Launcher vs Direct Binary**

**Recommended: Use `./gui_launcher.sh`**
- ✅ **Full feature set**: Build management, advanced firewall configuration, security warnings
- ✅ **Library integration**: Colors, i18n, logging, configuration management  
- ✅ **Interactive firewall setup**: Automatic network detection, IP restrictions
- ✅ **Security features**: Comprehensive warnings for network + elevated privileges
- ✅ **Build automation**: Automatic dependency checking and GUI building when needed

**Advanced: Direct `./gui/little-linux-helper-gui`**
- ⚠️  **Basic functionality only**: Simple server startup with minimal features
- ⚠️  **No build management**: Manual building required if needed
- ⚠️  **No firewall integration**: Manual firewall configuration required
- ✅ **Lightweight**: Faster startup for development/testing

#### Why Pre-built Releases?

**The switch to automated pre-built releases was made to solve compatibility issues:**
- **Problem**: Previous versions required users to build the GUI on their systems using `npm install` and `npm run build`
- **Issue**: Modern build tools (like Vite 7.x) require newer Node.js versions than available in stable Linux distributions
- **Solution**: GitHub Actions now build the GUI with the latest tools and provide ready-to-run packages
- **Benefit**: Maximum Linux distribution compatibility without compromising on modern development tools

---

### 🛠️ **Build from Source (Advanced Users)**

#### CLI Installation:
1. Clone the repository or download the scripts.
2. Make sure the main script `help_master.sh` is executable:
    ```bash
    chmod +x help_master.sh
    ```
3. Run the CLI interface:
    ```bash
    ./help_master.sh
    ```

#### GUI Self-Build (Development/Advanced):
**Note**: The GUI components are built automatically in pre-built releases. Self-building is only needed for development or customization.

**Requirements:**
* **Go** (1.18 or later) for backend server compilation
* **Node.js** (18 or later) and **npm** for frontend development and building
* **Web browser** for accessing the GUI interface

**Build Process:**
1. Ensure Go (1.18+) and Node.js (18+) are installed on your system.
2. Make the GUI launcher executable:
    ```bash
    chmod +x gui_launcher.sh
    ```
3. Launch the GUI interface:
    ```bash
    ./gui_launcher.sh
    ```
4. The GUI will automatically:
   - Set up dependencies on first run
   - Build the application if needed
   - Start the web server on `http://localhost:3000`
   - Open your default web browser to the interface

**GUI Development Mode:**
For development with hot-reload capabilities:
```bash
cd gui/
./setup.sh    # One-time setup
./dev.sh      # Start development servers
```

#### Which Version Should You Choose?

| Use Case | Recommended Version | Why |
|----------|-------------------|-----|
| **General Usage** | Pre-built Release (latest) | Ready to run, no dependencies, maximum compatibility |
| **Stable Production** | Wait for v1.0.0 | Currently all releases are pre-releases/beta |
| **Development** | Build from Source | Access to latest changes, development tools |
| **Customization** | Build from Source | Modify GUI, custom builds |
| **Older Systems** | Pre-built Release | No need for modern Node.js/Go on target system |

**Important**: The **CLI functionality is completely independent** and works on any system with Bash. The GUI is an optional enhancement that builds on top of the CLI system.

</details>

## Running with Sudo

<details>
<summary>🔐 Sudo Usage and File Ownership</summary>

Little Linux Helper automatically handles file ownership issues when run with `sudo`. This ensures that log files, configuration files, and build artifacts maintain correct ownership even when elevated privileges are used.

**Automatic Ownership Correction:**
When the tool is run with `sudo`, the system automatically:
- Detects the original user (via `SUDO_USER` environment variable)
- Creates files and directories with root ownership initially (as expected with sudo)
- Immediately corrects ownership back to the original user
- Applies recursively to directories and all their contents

**What Gets Fixed:**
- **Log files** in `logs/` directory
- **Log directories** including monthly subdirectories
- **Session registry** files in `logs/sessions/`
- **Configuration directories** and files in `config/`
- **GUI build artifacts** when building with `sudo`
- **JSON output files** in temporary directories

**How It Works:**
The `lh_fix_ownership()` function is automatically called after creating files or directories. It:
1. Only acts when running as root via sudo (checks `EUID=0` and `SUDO_USER` is set)
2. Determines the original user's UID and GID
3. Changes ownership recursively using `chown`
4. Logs the operation at DEBUG level for transparency
5. Fails gracefully if ownership cannot be changed

**User Experience:**
- **Transparent**: No user action required
- **Safe**: Only acts when appropriate (sudo context)
- **Silent**: Normal operations show DEBUG logs only
- **Compatible**: Works identically whether run with or without sudo

**For Module Developers:**
The ownership fix is applied automatically in core library functions. No special handling is needed in custom modules unless creating files outside standard paths. If needed, simply call:
```bash
mkdir -p "$my_directory"
lh_fix_ownership "$my_directory"
```

**Example:**
```bash
# Running with sudo - files will be owned by the original user
sudo ./help_master.sh
# Log files in logs/ are automatically owned by your user, not root

# Building GUI with sudo - artifacts owned by original user  
sudo ./gui/build.sh
# The little-linux-helper-gui binary and web/build/ are owned by your user
```

</details>

## Configuration

<details>
<summary>⚙️ Configuration Files</summary>

Little Linux Helper uses configuration files to customize certain aspects of its behavior. These files are located in the `config/` directory.

When the main script (`help_master.sh`) is started for the first time, default configuration files are automatically created if they don't already exist. This is done by copying template files with the `.example` extension (e.g., `backup.conf.example`) to their active counterparts without the suffix (e.g., `backup.conf`).

**Important:** You will be notified when a configuration file is first created. It is recommended to review these newly created `.conf` files and adapt them to your specific needs if necessary.

Configuration files are currently used for the following modules:
* **General Settings (`help_master.sh`)**: Language, logging behavior, GUI port/host configuration, and other basic settings (`config/general.conf`).
* **Backup & Restore (`modules/backup/mod_backup.sh`, `modules/backup/mod_btrfs_backup.sh`, `modules/backup/mod_btrfs_restore.sh`)**: Settings for backup paths, retention policies, etc. (`config/backup.conf`).
* **Docker Security Check (`mod_security.sh`)**: Settings for search paths, warnings to skip, etc. (`config/docker.conf`).

**GUI Configuration Options:**
The GUI server can be configured via `config/general.conf`:
```bash
# GUI server port (default: 3000)
CFG_LH_GUI_PORT="3000"

# GUI server host binding (default: localhost for security)
# Options: "localhost" (secure) or "0.0.0.0" (network access)
CFG_LH_GUI_HOST="localhost"

# Firewall IP restriction for -f flag (default: "local")
# Options: "all" (any IP), "local" (detected networks), specific IP/CIDR
CFG_LH_GUI_FIREWALL_RESTRICTION="local"
```

Command line arguments (both short -x and long --word forms) override configuration file settings for temporary changes.

</details>

## Module Overview

<details>
<summary>📦 Module Overview</summary>

The project is divided into modules to organize functionality:

* **`lib/lib_common.sh`**: The heart of the project. Contains central functions used by all modules such as:
    * A unified logging system.
    * Functions for command checking and automatic dependency installation.
    * Standardized user interactions (yes/no questions, input prompts).
    * Detection of system components (package managers, etc.).
    * Management of colored terminal output for better readability.
    * Complex logic for determining the active desktop user.
    * The ability to send **desktop notifications** to the user.
    * **Enhanced Session Registry**: Intelligent session tracking with blocking categories for conflict detection and prevention.
    * **Core Library System**: Automatically loads specialized library components (`lib_colors.sh`, `lib_i18n.sh`, `lib_ui.sh`, etc.).
* **`lib/lib_btrfs.sh`**: **Specialized BTRFS library** (not part of core library system). Provides advanced BTRFS-specific functions for atomic backup operations, incremental chain validation, and comprehensive BTRFS safety mechanisms. Used exclusively by BTRFS modules and must be explicitly sourced.
* **`modules/mod_restarts.sh`**: Provides options for restarting services and the desktop environment.
* **`modules/backup/mod_backup.sh`**: Unified backup dispatcher providing centralized interface for all backup types (BTRFS, TAR, RSYNC).
* **`modules/backup/mod_btrfs_backup.sh`**: BTRFS-specific backup functions (snapshots, transfer, integrity checking, markers, cleanup, status, etc.). Uses `lib_btrfs.sh` for advanced BTRFS operations.
* **`modules/backup/mod_btrfs_restore.sh`**: BTRFS-specific restore functions (complete system, individual subvolumes, folders, and dry-run). Uses `lib_btrfs.sh` for atomic restore operations.
* **`modules/backup/mod_backup_tar.sh`**: TAR archive backup functionality with multiple backup types and intelligent exclusion management.
* **`modules/backup/mod_restore_tar.sh`**: TAR archive restoration with safety features and flexible destination options.
* **`modules/backup/mod_backup_rsync.sh`**: RSYNC incremental backup with hardlink optimization and comprehensive configuration.
* **`modules/backup/mod_restore_rsync.sh`**: RSYNC backup restoration with real-time progress monitoring and complete directory tree restoration.
* **`modules/mod_system_info.sh`**: Displays detailed system information.
* **`modules/mod_disk.sh`**: Tools for disk analysis and maintenance.
* **`modules/mod_logs.sh`**: Analysis of system and application logs.
* **`modules/mod_packages.sh`**: Package management, system updates, cleanup.
* **`modules/mod_security.sh`**: Security checks, Docker security, network, rootkit checking.
* **`modules/mod_docker.sh`**: Docker container management and monitoring.
* **`modules/mod_docker_setup.sh`**: Docker installation and setup automation.
* **`modules/mod_energy.sh`**: Energy and power management features (power profiles, sleep control, brightness).

</details>

## Logging

<details>
<summary>📜 Logging</summary>

All actions are logged to help with tracking and troubleshooting.

* **Location:** Log files are created in the `logs` subdirectory within the project directory. A separate subfolder is created for each month (e.g., `logs/2025-06`).
* **Filenames:** General log files receive a timestamp indicating when the script was started. Backup and restore-specific logs are also timestamped to capture each session separately.

</details>

## Contact

If you have questions, suggestions, or encounter issues with this project, feel free to reach out:

📧 **Email:** [maschkef-git@pm.me](mailto:maschkef-git@pm.me)
