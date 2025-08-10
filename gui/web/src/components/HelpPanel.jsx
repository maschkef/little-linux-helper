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
        overview: "View comprehensive information about your computer's hardware, software, and current system status. Perfect for troubleshooting, system monitoring, or getting to know your Linux system better.",
        options: [
          "1. Operating System & Kernel - Shows your Linux distribution, version, and kernel information",
          "2. CPU Details - Display processor information including model, cores, and performance specs", 
          "3. RAM Usage - Check memory usage and see how much RAM is available vs used",
          "4. PCI Devices - List hardware components like graphics cards, network adapters, and sound cards",
          "5. USB Devices - Show connected USB devices like keyboards, mice, storage drives, and webcams",
          "6. Disk Overview - View hard drives, SSDs, and storage devices with their mount points and usage",
          "7. Top Processes - See which programs are using the most CPU and memory resources",
          "8. Network Configuration - Display network settings, IP addresses, and active connections", 
          "9. Temperatures/Sensors - Monitor hardware temperatures and fan speeds (if sensors are available)"
        ],
        notes: [
          "Some detailed information may require administrator privileges",
          "Missing tools will be offered for automatic installation",
          "Hardware sensor readings require the 'sensors' package to be installed",
          "All information is read-only - this won't change any system settings"
        ]
      },
      disk: {
        overview: "Tools for managing and analyzing your storage devices and disk space. Check drive health, find large files, monitor disk usage, and perform disk diagnostics.",
        options: [
          "1. Show Mounted Drives - See all connected drives and how much space they're using",
          "2. SMART Values - Get detailed health information from your hard drives and SSDs", 
          "3. File Access Times - Check which programs are currently using files in a folder",
          "4. Directory Sizes - Analyze disk space usage with visual tools like ncdu",
          "5. Disk Speed Test - Test read/write performance of your storage devices",
          "6. Check Filesystem - Scan drives for errors and fix file system problems",
          "7. Check Health - Quick health check of your drives using SMART data",
          "8. Largest Files - Find the biggest files taking up space on your system"
        ],
        notes: [
          "Drive health checks require administrator privileges",
          "Missing diagnostic tools will be offered for automatic installation", 
          "Filesystem checks work best on unmounted drives",
          "Speed tests and health checks are safe and won't modify data"
        ]
      },
      logs: {
        overview: "Find and analyze system logs to troubleshoot problems, monitor system health, or investigate what happened during crashes or errors.",
        options: [
          "1. Recent Logs (Current Boot) - See what happened in the last few minutes or hours on your system",
          "2. Recent Logs (Previous Boot) - Check what went wrong before your last reboot or crash",
          "3. Service-Specific Logs - View logs for specific programs like SSH, web servers, or databases", 
          "4. X.org Logs - Check graphics system logs to troubleshoot display or driver issues",
          "5. Kernel Messages - View low-level system messages from the Linux kernel (hardware, drivers)",
          "6. Package Manager Logs - See history of software installations, updates, and removals",
          "7. Advanced Analysis - Python-powered log analysis to automatically find errors and patterns"
        ],
        notes: [
          "Most logs are automatically filtered to show errors and warnings first",
          "You can save any log output to files for later review or sharing",
          "Advanced analysis uses Python with regex patterns to parse logs and highlight issues",
          "Some system logs require administrator privileges to access"
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
        overview: "Central hub for protecting your data with multiple backup methods. Choose from BTRFS snapshots, TAR archives, or RSYNC incremental backups depending on your needs.",
        options: [
          "1. BTRFS Operations - Advanced snapshot-based backups for BTRFS filesystems (atomic, space-efficient)",
          "2. TAR Backup - Create compressed archive backups of directories (compatible with all systems)",
          "3. RSYNC Backup - Fast incremental backups that only copy changed files",
          "4. Restore Operations - Access specialized restore tools for each backup type",
          "5. Backup Status - View comprehensive status of all your backups and disk space usage", 
          "6. Configure Backup - Set backup destinations, retention policies, and other settings"
        ],
        notes: [
          "🚨 BTRFS WARNING: BTRFS backup is tested on limited systems - use with caution",
          "🚨 BTRFS RESTORE: Requires testing - Do NOT use in production! For debugging/testing only!",
          "💡 See individual BTRFS module help (when called directly) for more information",
          "Each backup type has its own specialized tools accessible through this menu",
          "BTRFS operations require BTRFS filesystem and provide the most advanced features",
          "TAR backups work on any filesystem but create larger archive files",
          "RSYNC is ideal for regular backups as it's fast and space-efficient",
          "Configure your backup destination before creating your first backup"
        ]
      },
      docker: {
        overview: "Manage Docker containers and ensure they're secure. Get container information, install Docker if needed, and run security audits on your containerized applications.",
        options: [
          "1. Show Running Containers - See all active Docker containers with resource usage and status",
          "2. Manage Configuration - Configure Docker security scanning settings and parameters",
          "3. Installation & Setup - Automatically install Docker and Docker Compose on your system", 
          "4. Security Audit - Comprehensive security scan of containers, images, and Docker configuration"
        ],
        notes: [
          "Installation option includes complete Docker setup with user permissions",
          "Security audit checks for vulnerabilities, misconfigurations, and best practices",
          "Configuration settings control how thorough security scans will be",
          "Docker must be installed to view and manage containers"
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
          "⚠️ BETA SOFTWARE: Tested on limited systems - use with caution",
          "Supports flexible BTRFS subvolume layouts (@ @home @var @opt @tmp @srv, etc.)",
          "Auto-detects subvolumes from /etc/fstab and /proc/mounts when enabled",
          "Configurable subvolume list via LH_BACKUP_SUBVOLUMES setting", 
          "Backup destination must be on a BTRFS filesystem",
          "Uses comprehensive atomic operations with thorough validation",
          "Automatically creates space-efficient incremental backups when possible",
          "Source snapshot preservation for maintaining incremental backup chains"
        ]
      },
      btrfs_restore: {
        overview: "⚠️ DESTRUCTIVE: Advanced BTRFS disaster recovery system with dynamic subvolume detection. Designed to run from live environment to restore systems from BTRFS backups with atomic operations, bootloader integration, and comprehensive safety validation.",
        options: [
          "1. Setup Restore Environment - Configure target system, backup source, and detect available subvolumes automatically",
          "2. System/Subvolume Restore - Restore any detected subvolumes (@, @home, @var, @opt, etc.) with timestamp matching",
          "3. Individual Folder Restore - Restore specific files/folders from any available subvolume snapshots", 
          "4. Show Disk Information - Display target system disk layout, BTRFS structure, and detected subvolumes",
          "5. Review Safety Information - Show critical safety warnings, live environment detection, and restore procedures",
          "6. Cleanup Restore Environment - Clean up temporary files, mount points, and restore artifacts"
        ],
        notes: [
          "🚨 DANGER: REQUIRES TESTING - Do NOT use in production! For debugging/testing only!",
          "🚨 Use only if you fully understand BTRFS restore procedures and potential data loss",
          "⚠️ CRITICAL: Only run from live environment, never on running system",
          "⚠️ Will destroy existing data on target subvolumes during full restore",
          "Auto-detects available subvolumes from backup structure and system configuration",
          "Supports flexible BTRFS layouts with any @-prefixed subvolumes",
          "Coordinated multi-subvolume restore with timestamp-based snapshot pairing", 
          "Advanced bootloader integration with multiple update strategies",
          "Uses robust 4-step atomic restore process with comprehensive validation and rollback"
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
        <h4 style={{ margin: '0 0 0.5rem 0', color: '#5e97cfff' }}>Overview</h4>
        <p style={{ margin: 0, fontSize: '1.0rem', lineHeight: '1.4' }}>
          {help.overview}
        </p>
      </div>

      {help.options.length > 0 && (
        <div style={{ marginBottom: '1rem' }}>
          <h4 style={{ margin: '0 0 0.5rem 0', color: '#5e97cfff' }}>Available Options</h4>
          <ul style={{ margin: 0, paddingLeft: '1.2rem', fontSize: '0.9rem' }}>
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
          <h4 style={{ margin: '0 0 0.5rem 0', color: '#5e97cfff' }}>Important Notes</h4>
          <ul style={{ margin: 0, paddingLeft: '1.2rem', fontSize: '0.9rem' }}>
            {help.notes.map((note, index) => (
              <li key={index} style={{ marginBottom: '0.3rem', color: '#bb9900ff' }}>
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
