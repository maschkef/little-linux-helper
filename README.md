# Little Linux Helper

> **⚠️ Documentation Status Notice:**
> - **Documentation Update Needed**: The documentation (including this README.md) needs to be updated to reflect recent changes and improvements.
> - **BTRFS Modules Need Testing**: The BTRFS backup and restore modules require comprehensive testing. The backup module has been enhanced and improved, while the restore module has been completely recreated. Please use with caution and test thoroughly beforehand.

## Description

Little Linux Helper is a collection of Bash scripts designed to simplify various system administration, diagnostic, and maintenance tasks on Linux. It provides a menu-driven interface for easy access to a variety of tools and functions.

More detailed technical English documentation for individual modules and core components can be found in the `docs` directory. This documentation was created in part to provide AI with the context of a module or file without having to read it completely and to save context.
The `docs/DEVELOPER_GUIDE.md` contains all the information about `lib/lib_common.sh` and `help_master.sh` needed to create a new module.
Note: The original `lib_common.sh` has been split into multiple specialized libraries for better organization (e.g., `lib_colors.sh`, `lib_i18n.sh`, `lib_notifications.sh`, etc.), but `lib_common.sh` remains the main entry point and automatically loads all other core libraries. Additionally, `lib_btrfs.sh` is a specialized library used exclusively by BTRFS modules and is not part of the core library system.

My environment is typically Arch (main system) or Debian (various services on my Proxmox - hence the Docker components), so there may be unknown issues on other distributions, although I try to keep everything compatible.

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
* **Backups:**
    * **BTRFS Backup:** The BTRFS backup and restore functions are now moved to the modules `modules/backup/mod_btrfs_backup.sh` and `modules/backup/mod_btrfs_restore.sh`. The other backup methods (TAR, RSYNC) are less intensively tested.
* **Advanced Log Analysis (`scripts/advanced_log_analyzer.py`):**
    * This script is less intensively tested and has known limitations regarding log format recognition, character encoding, and the complexity of its regular expressions (see `docs/advanced_log_analyzer.md` for details).

</details>

## Features

The main script `help_master.sh` serves as the central entry point and provides access to the following modules:

<details>
<summary>🔄 Recovery & Restarts (<code>mod_restarts.sh</code>)</summary>

* Restart the login manager (display manager).
* Restart the sound system (PipeWire, PulseAudio, ALSA).
* Restart the desktop environment (KDE, GNOME, XFCE, Cinnamon, MATE, LXDE, LXQt).
* Restart network services (NetworkManager, systemd-networkd, dhcpcd, systemd-resolved).

</details>

<details>
<summary>💾 Backup & Restore</summary>

* **BTRFS Snapshot Backup & Restore** (`modules/backup/mod_btrfs_backup.sh`, `modules/backup/mod_btrfs_restore.sh`):
    * Creation and management of snapshots for subvolumes `@` and `@home`.
    * Transfer of snapshots to backup destination using `btrfs send/receive`.
    * Integrated integrity checking, marker files, automatic cleanup, manual and automatic deletion, status display, and desktop notifications.
    * Restoration of complete systems, individual subvolumes, or individual folders from snapshots – with dry-run support.
    * Detailed technical description: see `docs/mod_btrfs_backup.md` and `docs/mod_btrfs_restore.md`.
* **TAR Archive Backup & Restore** (`modules/backup/mod_backup.sh`):
    * Creation of compressed TAR archives (`.tar.gz`) from selected directories.
    * Configurable exclusion lists and retention policies.
    * Restoration to original location, temporary directory, or custom path.
* **RSYNC Backup & Restore** (`modules/backup/mod_backup.sh`):
    * Backups with `rsync` (full or incremental, with hardlinks for space savings).
    * Selection of source directories and exclusion lists.
    * Restoration to original location, temporary directory, or custom path.
* **Backup Status and Configuration**:
    * Display of current backup status (online/offline, free disk space, existing backups, latest backups, total size).
    * Display and modification of backup configuration (target path, directory, retention, temporary snapshot directory).

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

* Bash shell
* Standard Linux utilities (such as `grep`, `awk`, `sed`, `find`, `df`, `lsblk`, `ip`, `ps`, `free`, `tar`, `rsync`, `btrfs-progs`, etc.)
* Some functions may require root privileges and will use `sudo` if necessary.
* For specific functions, additional packages are required that the script will attempt to install as needed:
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

1. Clone the repository or download the scripts.
2. Make sure the main script `help_master.sh` is executable:
    ```bash
    chmod +x help_master.sh
    ```

</details>

## Configuration

<details>
<summary>⚙️ Configuration Files</summary>

Little Linux Helper uses configuration files to customize certain aspects of its behavior. These files are located in the `config/` directory.

When the main script (`help_master.sh`) is started for the first time, default configuration files are automatically created if they don't already exist. This is done by copying template files with the `.example` extension (e.g., `backup.conf.example`) to their active counterparts without the suffix (e.g., `backup.conf`).

**Important:** You will be notified when a configuration file is first created. It is recommended to review these newly created `.conf` files and adapt them to your specific needs if necessary.

Configuration files are currently used for the following modules:
* **General Settings (`help_master.sh`)**: Language, logging behavior, and other basic settings (`config/general.conf`).
* **Backup & Restore (`modules/backup/mod_backup.sh`, `modules/backup/mod_btrfs_backup.sh`, `modules/backup/mod_btrfs_restore.sh`)**: Settings for backup paths, retention policies, etc. (`config/backup.conf`).
* **Docker Security Check (`mod_security.sh`)**: Settings for search paths, warnings to skip, etc. (`config/docker.conf`).

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
    * **Core Library System**: Automatically loads specialized library components (`lib_colors.sh`, `lib_i18n.sh`, `lib_ui.sh`, etc.).
* **`lib/lib_btrfs.sh`**: **Specialized BTRFS library** (not part of core library system). Provides advanced BTRFS-specific functions for atomic backup operations, incremental chain validation, and comprehensive BTRFS safety mechanisms. Used exclusively by BTRFS modules and must be explicitly sourced.
* **`modules/mod_restarts.sh`**: Provides options for restarting services and the desktop environment.
* **`modules/backup/mod_backup.sh`**: Provides backup and restore functions using TAR and RSYNC.
* **`modules/backup/mod_btrfs_backup.sh`**: BTRFS-specific backup functions (snapshots, transfer, integrity checking, markers, cleanup, status, etc.). Uses `lib_btrfs.sh` for advanced BTRFS operations.
* **`modules/backup/mod_btrfs_restore.sh`**: BTRFS-specific restore functions (complete system, individual subvolumes, folders, and dry-run). Uses `lib_btrfs.sh` for atomic restore operations.
* **`modules/mod_system_info.sh`**: Displays detailed system information.
* **`modules/mod_disk.sh`**: Tools for disk analysis and maintenance.
* **`modules/mod_logs.sh`**: Analysis of system and application logs.
* **`modules/mod_packages.sh`**: Package management, system updates, cleanup.
* **`modules/mod_security.sh`**: Security checks, Docker security, network, rootkit checking.

</details>

## Logging

<details>
<summary>📜 Logging</summary>

All actions are logged to help with tracking and troubleshooting.

* **Location:** Log files are created in the `logs` subdirectory within the project directory. A separate subfolder is created for each month (e.g., `logs/2025-06`).
* **Filenames:** General log files receive a timestamp indicating when the script was started. Backup and restore-specific logs are also timestamped to capture each session separately.

</details>
