/*
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
*/

import React from 'react';

function HelpPanel({ module }) {
  if (!module) {
    return (
      <div className="help-panel">
        <div className="panel-header">Module Help</div>
        <p>Select a module to see help information and available options.</p>
      </div>
    );
  }

  // This would be expanded to show actual help content based on the module
  const getModuleHelp = (moduleId) => {
    const helpContent = {
      restarts: {
        overview: "Restart system services and desktop components safely.",
        options: [
          "1. Restart Login Manager - Restarts display manager (GDM, SDDM, etc.)",
          "2. Restart Sound System - Restarts PulseAudio/PipeWire",
          "3. Restart Desktop Environment - Restarts your desktop session", 
          "4. Restart Network Services - Restarts network components"
        ],
        notes: [
          "Some operations may require sudo privileges",
          "Desktop restart will close all applications",
          "Network restart may temporarily disconnect you"
        ]
      },
      system_info: {
        overview: "Display comprehensive system information and hardware details. Gathers data from various Linux commands and system files to provide a complete overview of your system's configuration and current status.",
        options: [
          "1. Operating System & Kernel - Shows OS details from /etc/os-release, kernel version, and system uptime",
          "2. CPU Details - Processor information using lscpu (architecture, cores, threads, cache sizes, frequencies)",
          "3. RAM Usage - Memory utilization with free/vmstat commands, shows total/available/cached memory",
          "4. PCI Devices - Lists hardware components, offers detailed view with lspci -vnnk (requires sudo)",
          "5. USB Devices - Connected USB devices, detailed view with lsusb -v shows full specifications (requires sudo)",
          "6. Disk Overview - Block devices with lsblk, mounted filesystems with df, shows usage and types",
          "7. Top Processes - Shows top CPU and memory consumers, offers real-time monitoring with top command",
          "8. Network Configuration - Interface details, routing table, active connections, DNS servers",
          "9. Temperatures/Sensors - Hardware sensors using sensors command or /sys/class/thermal data"
        ],
        notes: [
          "Missing commands (lspci, lsusb, sensors, ss) will be offered for installation",
          "Detailed PCI/USB views require sudo privileges for hardware access",
          "Temperature readings need lm-sensors package installed",
          "Network connection details use ss command for better performance than netstat",
          "System commands may vary slightly between Linux distributions"
        ]
      },
      disk: {
        overview: "Disk utilities and storage analysis tools.",
        options: [
          "1. Show Mounted Drives - Display mounted filesystems",
          "2. SMART Values - Check disk health status",
          "3. File Access Times - Analyze file access patterns",
          "4. Directory Sizes - Show directory space usage",
          "5. Largest Files - Find largest files in directories"
        ],
        notes: [
          "SMART values require smartmontools",
          "Some operations may be slow on large filesystems",
          "Root privileges may be required for some operations"
        ]
      },
      logs: {
        overview: "Analyze system logs and troubleshoot issues.",
        options: [
          "1. Recent Logs (Current Boot) - Show recent log entries",
          "2. Recent Logs (Previous Boot) - Show logs from last boot",
          "3. Service-Specific Logs - Show logs for specific services",
          "4. X.org Logs - Display graphics system logs",
          "5. Kernel Messages - Show dmesg output",
          "6. Package Manager Logs - Show package installation logs",
          "7. Advanced Analysis - Python-based log analysis"
        ],
        notes: [
          "Advanced analysis requires Python",
          "Some logs may require sudo access",
          "Log availability depends on systemd/journald"
        ]
      },
      packages: {
        overview: "Manage packages and system updates.",
        options: [
          "1. System Update - Update all packages",
          "2. Find Orphaned Packages - Detect unused packages",
          "3. Clean Package Cache - Clear cached package files",
          "4. Search & Install - Find and install new packages",
          "5. Docker Setup - Install and configure Docker",
          "6. List Installed - Show installed packages",
          "7. Show Package Logs - Display package manager logs"
        ],
        notes: [
          "Supports multiple package managers",
          "Automatic detection of available managers",
          "Some operations require internet connection"
        ]
      },
      security: {
        overview: "Comprehensive security audit toolkit for Linux systems. Performs various security checks including network analysis, login monitoring, malware detection, firewall status, and system hardening verification.",
        options: [
          "1. Show Open Ports - Lists TCP/UDP listening ports with ss, optional nmap localhost scan (1-1000)",
          "2. Failed Login Attempts - Analyzes SSH/PAM failures from journalctl or log files, shows lastb output",
          "3. Rootkit Detection - Runs rkhunter (quick/full scan) and optionally chkrootkit for malware detection",
          "4. Firewall Status - Checks UFW, firewalld, or iptables status, shows rules and activation help",
          "5. Security Updates - Scans for available security patches using your package manager",
          "6. Password Security - Reviews password policies, aging settings, and accounts without passwords"
        ],
        notes: [
          "Most functions require sudo privileges for log access and system scanning",
          "Missing tools (ss, nmap, rkhunter, chkrootkit) will be offered for installation",
          "Rootkit scans can be time-consuming and may require user interaction",
          "Port scanning of localhost is safe but external scans may trigger alerts",
          "Failed login analysis covers SSH, PAM, and systemd login services",
          "Password policy checks examine /etc/security/pwquality.conf and PAM configuration"
        ]
      },
      backup: {
        overview: "Backup and restore operations for data protection.",
        options: [
          "1. BTRFS Operations - Snapshot-based backups",
          "2. TAR Backup - Archive-based backups", 
          "3. RSYNC Backup - Incremental file-based backups",
          "4. Restore Operations - Restore from backups",
          "5. Backup Status - Check backup status and logs",
          "6. Configure Backup - Modify backup settings"
        ],
        notes: [
          "BTRFS backups require BTRFS filesystem",
          "Configure backup paths before first use",
          "Test restore procedures regularly"
        ]
      },
      docker: {
        overview: "Docker container management and administration tools. Provides comprehensive Docker operations including container monitoring, configuration management, and security auditing.",
        options: [
          "1. Show Running Containers - Display active containers with detailed information",
          "2. Manage Configuration - Configure Docker scanning settings, paths, exclusions, and security check parameters",
          "3. Installation & Setup - Install Docker components and verify installation",
          "4. Security Audit - Comprehensive Docker security scanning and vulnerability assessment"
        ],
        notes: [
          "Requires Docker to be installed for container operations",
          "Configuration settings affect security scanning behavior",
          "Security audit performs comprehensive vulnerability assessment",
          "Setup option handles complete Docker installation and configuration"
        ]
      },
      energy: {
        overview: "Power management and energy optimization.",
        options: [
          "1. Power Profiles - Switch between power modes",
          "2. CPU Frequency - Adjust processor frequency",
          "3. Display Brightness - Control screen brightness",
          "4. Energy Statistics - Show power consumption",
          "5. Sleep/Suspend - Configure sleep modes"
        ],
        notes: [
          "Features depend on hardware support",
          "Some controls require root privileges",
          "Power profiles vary by system"
        ]
      },
      btrfs_backup: {
        overview: "Advanced BTRFS snapshot-based backup system with dynamic subvolume detection. Creates atomic backups of configurable BTRFS subvolumes using btrfs send/receive with comprehensive integrity checking and automatic incremental backup chains.",
        options: [
          "1. Create BTRFS Backup - Creates snapshots of configured and auto-detected subvolumes and transfers to backup destination",
          "2. Show/Change Configuration - View and modify backup settings (subvolumes, paths, retention, auto-detection)",
          "3. Show Backup Status - Display backup history, space usage, and detected subvolumes information", 
          "4. Delete BTRFS Backups - Remove old backups with options for selective or automatic deletion",
          "5. Cleanup Problematic Backups - Fix corrupted or incomplete backup operations",
          "6. Clean up script-created source snapshots - Remove temporary snapshots and manage preserved snapshots",
          "7. Restore BTRFS Backup - Enhanced restore with bootloader integration and set-default capability"
        ],
        notes: [
          "Supports flexible BTRFS subvolume layouts (@ @home @var @opt @tmp @srv, etc.)",
          "Auto-detects subvolumes from /etc/fstab and /proc/mounts when enabled",
          "Configurable subvolume list via LH_BACKUP_SUBVOLUMES setting", 
          "Backup destination must be on a BTRFS filesystem",
          "Uses enterprise-grade atomic operations with comprehensive validation",
          "Automatically creates space-efficient incremental backups when possible",
          "Source snapshot preservation for maintaining incremental backup chains"
        ]
      },
      btrfs_restore: {
        overview: "⚠️ DESTRUCTIVE: Enterprise-grade BTRFS disaster recovery system with dynamic subvolume detection. Designed to run from live environment to restore systems from BTRFS backups with atomic operations, bootloader integration, and comprehensive safety validation.",
        options: [
          "1. Setup Restore Environment - Configure target system, backup source, and detect available subvolumes automatically",
          "2. System/Subvolume Restore - Restore any detected subvolumes (@, @home, @var, @opt, etc.) with timestamp matching",
          "3. Individual Folder Restore - Restore specific files/folders from any available subvolume snapshots", 
          "4. Show Disk Information - Display target system disk layout, BTRFS structure, and detected subvolumes",
          "5. Review Safety Information - Show critical safety warnings, live environment detection, and restore procedures",
          "6. Cleanup Restore Environment - Clean up temporary files, mount points, and restore artifacts"
        ],
        notes: [
          "⚠️ CRITICAL: Only run from live environment, never on running system",
          "⚠️ Will destroy existing data on target subvolumes during full restore",
          "Auto-detects available subvolumes from backup structure and system configuration",
          "Supports flexible BTRFS layouts with any @-prefixed subvolumes",
          "Coordinated multi-subvolume restore with timestamp-based snapshot pairing", 
          "Advanced bootloader integration with multiple update strategies",
          "Uses enterprise-grade 4-step atomic restore process with comprehensive validation and rollback"
        ]
      },
      backup_tar: {
        overview: "TAR archive-based backup system for creating compressed backups of system directories and user data. Simple and widely compatible backup method using standard tar command.",
        options: [
          "1. Only /home - Backup user directories and personal data",
          "2. Only /etc - Backup system configuration files",
          "3. /home and /etc - Backup both user data and system configuration",
          "4. Full system (except temporary files) - Complete system backup excluding temporary directories",
          "5. Custom directories - Specify custom paths to backup"
        ],
        notes: [
          "Creates compressed tar.gz archives for space efficiency",
          "Preserves file permissions and ownership information",
          "Full system backups can be very large depending on your system",
          "Custom directory option allows flexible backup of specific paths",
          "Backup location is configurable in backup.conf"
        ]
      },
      restore_tar: {
        overview: "Restore system files and directories from TAR archive backups. Offers flexible restore options including safe temporary extraction for file recovery.",
        options: [
          "1. To original location (overwrites existing files) - Direct restore that replaces current files",
          "2. To temporary directory (/tmp/restore_tar) - Safe extraction for file browsing and selective recovery",
          "3. Custom path - Restore to a user-specified directory"
        ],
        notes: [
          "⚠️ Original location restore will overwrite existing files",
          "Temporary directory restore is safest for exploring backup contents",
          "Custom path restore allows flexible extraction location",
          "Preserves original file permissions and ownership during restore",
          "Temporary extractions are automatically cleaned up"
        ]
      },
      backup_rsync: {
        overview: "RSYNC-based backup system for efficient incremental backups. Uses rsync to create space-efficient backups that only copy changed files, making it ideal for regular backup schedules.",
        options: [
          "1. Only /home - Backup user directories and personal data",
          "2. Full system (except temporary files) - Complete system backup excluding temporary directories", 
          "3. Custom directories - Specify custom paths to backup",
          "After selecting directories:",
          "• Full backup (copy everything) - Complete copy of all selected files",
          "• Incremental backup (changes only) - Only copy files that have changed since last backup"
        ],
        notes: [
          "Incremental backups are much faster and use less space than full backups",
          "First backup is always full, subsequent backups can be incremental",
          "Preserves file permissions, ownership, and timestamps", 
          "Offers dry-run mode to preview operations without making changes",
          "Backup destination is configurable in backup.conf",
          "Requires rsync command (will be installed if missing)"
        ]
      },
      restore_rsync: {
        overview: "Restore files and directories from RSYNC backups. Provides flexible restoration options with the efficiency and reliability of rsync.",
        options: [
          "1. To original location (overwrites existing files) - Direct restore that replaces current files",
          "2. To temporary directory (/tmp/restore_rsync) - Safe extraction for file browsing and selective recovery", 
          "3. Custom path - Restore to a user-specified directory"
        ],
        notes: [
          "⚠️ Original location restore will overwrite existing files",
          "Temporary directory restore is safest for exploring backup contents",
          "Custom path restore allows flexible extraction location",
          "Preserves original file permissions, ownership, and timestamps",
          "Can restore from both full and incremental RSYNC backups",
          "Temporary extractions are automatically cleaned up"
        ]
      },
      docker_setup: {
        overview: "Docker installation and setup utilities. Automatically detects, installs, and configures Docker and Docker Compose on your system with proper user permissions.",
        options: [
          "Automatically performs these tasks:",
          "• Check if Docker is already installed and show version information",
          "• Install Docker if not present using your system's package manager",
          "• Check if Docker Compose is available (docker-compose or docker compose)",
          "• Install Docker Compose if needed",
          "• Add current user to docker group for non-root Docker usage",
          "• Start and enable Docker service",
          "• Verify installation with test container run"
        ],
        notes: [
          "Installation method depends on your Linux distribution",
          "May require logout/login after adding user to docker group",
          "Automatically detects whether to use docker-compose or docker compose command",
          "Starts Docker service and enables it for automatic startup",
          "Performs verification test to ensure Docker is working properly"
        ]
      },
      docker_security: {
        overview: "Comprehensive Docker security audit tool. Scans Docker containers, images, and configurations for security vulnerabilities and best practice violations.",
        options: [
          "1. Docker Security Check - Runs complete security audit including:",
          "• Container security configuration analysis",
          "• Image vulnerability scanning",
          "• Docker daemon security settings review", 
          "• Network security configuration check",
          "• Volume and mount security analysis",
          "• Privilege escalation detection",
          "• Resource limit verification"
        ],
        notes: [
          "Requires Docker to be installed and running",
          "Scans all running containers and available images",
          "Configuration options affect scan depth and strictness",
          "Can detect common security misconfigurations",
          "Reports findings with severity levels and remediation suggestions",
          "Should be run regularly to maintain Docker security posture"
        ]
      }
    };

    return helpContent[moduleId] || {
      overview: "Help information not available for this module.",
      options: [],
      notes: []
    };
  };

  const help = getModuleHelp(module.id);

  return (
    <div className="help-panel">
      <div className="panel-header">Module Help: {module.name}</div>
      
      <div style={{ marginBottom: '1rem' }}>
        <h4 style={{ margin: '0 0 0.5rem 0', color: '#2c3e50' }}>Overview</h4>
        <p style={{ margin: 0, fontSize: '0.9rem', lineHeight: '1.4' }}>
          {help.overview}
        </p>
      </div>

      {help.options.length > 0 && (
        <div style={{ marginBottom: '1rem' }}>
          <h4 style={{ margin: '0 0 0.5rem 0', color: '#2c3e50' }}>Available Options</h4>
          <ul style={{ margin: 0, paddingLeft: '1.2rem', fontSize: '0.85rem' }}>
            {help.options.map((option, index) => (
              <li key={index} style={{ marginBottom: '0.3rem' }}>
                {option}
              </li>
            ))}
          </ul>
        </div>
      )}

      {help.notes.length > 0 && (
        <div>
          <h4 style={{ margin: '0 0 0.5rem 0', color: '#2c3e50' }}>Important Notes</h4>
          <ul style={{ margin: 0, paddingLeft: '1.2rem', fontSize: '0.85rem' }}>
            {help.notes.map((note, index) => (
              <li key={index} style={{ marginBottom: '0.3rem', color: '#666' }}>
                {note}
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
}

export default HelpPanel;
