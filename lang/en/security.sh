#!/bin/bash
#
# lang/en/security.sh
# Copyright (c) 2025 wuldorf
# SPDX-License-Identifier: MIT
#
# English security module language strings

# Declare MSG_EN as associative array if not already declared
[[ ! -v MSG_EN ]] && declare -A MSG_EN

# Security module main menu
MSG_EN[SECURITY_TITLE]="Security Checks"
MSG_EN[SECURITY_MENU_OPEN_PORTS]="Show Open Network Ports"
MSG_EN[SECURITY_MENU_FAILED_LOGINS]="Show Failed Login Attempts"
MSG_EN[SECURITY_MENU_ROOTKITS]="Check System for Rootkits"
MSG_EN[SECURITY_MENU_FIREWALL]="Check Firewall Status"
MSG_EN[SECURITY_MENU_UPDATES]="Check for Security Updates"
MSG_EN[SECURITY_MENU_PASSWORDS]="Check Password Policies"
MSG_EN[SECURITY_MENU_DOCKER]="Docker Security Check"
MSG_EN[SECURITY_MENU_BACK]="Back to Main Menu"

# Open ports section
MSG_EN[SECURITY_OPEN_PORTS_TITLE]="Open Network Ports"
MSG_EN[SECURITY_OPEN_PORTS_SS_NOT_FOUND]="The program 'ss' is not installed and could not be installed."
MSG_EN[SECURITY_OPEN_PORTS_TCP_LISTEN]="Open TCP Ports (LISTEN):"
MSG_EN[SECURITY_OPEN_PORTS_UDP_SHOW]="Would you also like to show UDP ports?"
MSG_EN[SECURITY_OPEN_PORTS_UDP_TITLE]="Open UDP Ports:"
MSG_EN[SECURITY_OPEN_PORTS_TCP_CONNECTIONS_SHOW]="Would you also like to show existing TCP connections?"
MSG_EN[SECURITY_OPEN_PORTS_TCP_CONNECTIONS_TITLE]="Existing TCP Connections:"
MSG_EN[SECURITY_OPEN_PORTS_NMAP_SCAN]="Would you like to perform a local port scan to check open ports?"
MSG_EN[SECURITY_OPEN_PORTS_NMAP_STARTING]="Starting local port scan (127.0.0.1)..."

# Failed logins section
MSG_EN[SECURITY_FAILED_LOGINS_TITLE]="Failed Login Attempts"
MSG_EN[SECURITY_FAILED_LOGINS_CHOOSE_OPTION]="Choose an option for display:"
MSG_EN[SECURITY_FAILED_LOGINS_SSH]="Recent failed SSH login attempts"
MSG_EN[SECURITY_FAILED_LOGINS_PAM]="Recent failed PAM/Login attempts"
MSG_EN[SECURITY_FAILED_LOGINS_ALL]="All failed login attempts"
MSG_EN[SECURITY_FAILED_LOGINS_SSH_JOURNALCTL]="Recent failed SSH login attempts (journalctl):"
MSG_EN[SECURITY_FAILED_LOGINS_SSH_AUTH_LOG]="Recent failed SSH login attempts (auth.log):"
MSG_EN[SECURITY_FAILED_LOGINS_SSH_SECURE]="Recent failed SSH login attempts (secure):"
MSG_EN[SECURITY_FAILED_LOGINS_PAM_JOURNALCTL]="Recent failed PAM login attempts (journalctl):"
MSG_EN[SECURITY_FAILED_LOGINS_PAM_AUTH_LOG]="Recent failed PAM login attempts (auth.log):"
MSG_EN[SECURITY_FAILED_LOGINS_PAM_SECURE]="Recent failed PAM login attempts (secure):"
MSG_EN[SECURITY_FAILED_LOGINS_ALL_JOURNALCTL]="All failed login attempts (journalctl):"
MSG_EN[SECURITY_FAILED_LOGINS_ALL_AUTH_LOG]="All failed login attempts (auth.log):"
MSG_EN[SECURITY_FAILED_LOGINS_ALL_SECURE]="All failed login attempts (secure):"
MSG_EN[SECURITY_FAILED_LOGINS_NO_LOGS]="No suitable log files found."
MSG_EN[SECURITY_FAILED_LOGINS_OPERATION_CANCELLED]="Operation cancelled."
MSG_EN[SECURITY_FAILED_LOGINS_LASTB_SHOW]="Would you also like to show failed login attempts via 'lastb'?"
MSG_EN[SECURITY_FAILED_LOGINS_LASTB_TITLE]="Failed login attempts (lastb):"

# Rootkit check section
MSG_EN[SECURITY_ROOTKIT_TITLE]="Check System for Rootkits"
MSG_EN[SECURITY_ROOTKIT_RKHUNTER_NOT_FOUND]="The program 'rkhunter' is not installed and could not be installed."
MSG_EN[SECURITY_ROOTKIT_CHOOSE_MODE]="rkhunter offers the following check modes:"
MSG_EN[SECURITY_ROOTKIT_QUICK_TEST]="Quick test (--check --sk)"
MSG_EN[SECURITY_ROOTKIT_FULL_TEST]="Full test (--check)"
MSG_EN[SECURITY_ROOTKIT_PROP_UPDATE]="Only check properties (--propupd)"
MSG_EN[SECURITY_ROOTKIT_QUICK_STARTING]="Starting rkhunter quick test..."
MSG_EN[SECURITY_ROOTKIT_QUICK_DURATION]="This may take a few minutes."
MSG_EN[SECURITY_ROOTKIT_FULL_STARTING]="Starting full rkhunter test..."
MSG_EN[SECURITY_ROOTKIT_FULL_DURATION]="This may take significantly longer and may require user input."
MSG_EN[SECURITY_ROOTKIT_PROP_UPDATING]="Updating properties database..."
MSG_EN[SECURITY_ROOTKIT_PROP_SUCCESS]="Properties updated successfully. It is recommended to recheck properties after system changes."
MSG_EN[SECURITY_ROOTKIT_CHKROOTKIT_INSTALL]="Would you also like to install and run 'chkrootkit' as a second rootkit scanner?"
MSG_EN[SECURITY_ROOTKIT_CHKROOTKIT_RUN]="chkrootkit is already installed. Would you like to run it?"
MSG_EN[SECURITY_ROOTKIT_CHKROOTKIT_STARTING]="Starting chkrootkit check..."

# Firewall check section
MSG_EN[SECURITY_FIREWALL_TITLE]="Check Firewall Status"
MSG_EN[SECURITY_FIREWALL_UFW_STATUS]="UFW Status:"
MSG_EN[SECURITY_FIREWALL_FIREWALLD_STATUS]="firewalld Status:"
MSG_EN[SECURITY_FIREWALL_FIREWALLD_ZONES]="Active Zones:"
MSG_EN[SECURITY_FIREWALL_IPTABLES_RULES]="iptables Rules:"
MSG_EN[SECURITY_FIREWALL_NOT_FOUND]="No known firewall (UFW, firewalld, iptables) found."
MSG_EN[SECURITY_FIREWALL_INACTIVE_WARNING]="WARNING: A firewall (%s) was found, but it appears to be inactive."
MSG_EN[SECURITY_FIREWALL_ACTIVATION_RECOMMENDED]="It is recommended to activate the firewall to protect your system."
MSG_EN[SECURITY_FIREWALL_SHOW_ACTIVATION_INFO]="Would you like to show information on how to activate the firewall?"
MSG_EN[SECURITY_FIREWALL_UFW_ACTIVATE_INFO]="UFW activation:"
MSG_EN[SECURITY_FIREWALL_UFW_DEFAULT_SSH]="Default configuration with SSH access allowed:"
MSG_EN[SECURITY_FIREWALL_UFW_CHECK_STATUS]="Check status:"
MSG_EN[SECURITY_FIREWALL_FIREWALLD_ACTIVATE_INFO]="firewalld activation:"
MSG_EN[SECURITY_FIREWALL_FIREWALLD_CHECK_STATUS]="Check status:"
MSG_EN[SECURITY_FIREWALL_IPTABLES_COMPLEX]="iptables basic configuration is more complex and is best managed via a script or another firewall solution like UFW."
MSG_EN[SECURITY_FIREWALL_IPTABLES_MINIMAL]="For minimal security, you could use the following (caution, this might block remote access):"
MSG_EN[SECURITY_FIREWALL_IPTABLES_SAVE_INFO]="To save these rules (depending on distribution):"
MSG_EN[SECURITY_FIREWALL_ACTIVE_SUCCESS]="The firewall (%s) is active. Your system has basic protection."

# Security updates section
MSG_EN[SECURITY_UPDATES_TITLE]="Check for Security Updates"
MSG_EN[SECURITY_UPDATES_NO_PKG_MANAGER]="No supported package manager found."
MSG_EN[SECURITY_UPDATES_SEARCHING]="Searching for available security updates..."
MSG_EN[SECURITY_UPDATES_AVAILABLE]="Available updates:"
MSG_EN[SECURITY_UPDATES_PACMAN_INFO]="Updates are available. Comprehensive security analysis per package is not directly possible with pacman."
MSG_EN[SECURITY_UPDATES_INSTALL_RECOMMENDED]="It is recommended to install all updates regularly."
MSG_EN[SECURITY_UPDATES_INSTALL_NOW]="Would you like to install all updates now?"
MSG_EN[SECURITY_UPDATES_SECURITY_AVAILABLE]="Security updates (if available):"
MSG_EN[SECURITY_UPDATES_TOTAL_COUNT]="Total available updates: %d"
MSG_EN[SECURITY_UPDATES_SHOW_ALL]="Would you like to show all available updates?"
MSG_EN[SECURITY_UPDATES_ALL_AVAILABLE]="All available updates:"
MSG_EN[SECURITY_UPDATES_NO_UPDATES]="No updates found. The system is up to date."
MSG_EN[SECURITY_UPDATES_UNKNOWN_PKG_MANAGER]="Unknown package manager: %s"

# Password policy section
MSG_EN[SECURITY_PASSWORD_TITLE]="Check Password Policies"
MSG_EN[SECURITY_PASSWORD_QUALITY_CONFIG]="Password quality policies (pwquality.conf):"
MSG_EN[SECURITY_PASSWORD_PAM_COMMON]="PAM password settings (common-password):"
MSG_EN[SECURITY_PASSWORD_PAM_SYSTEM]="PAM password settings (system-auth):"
MSG_EN[SECURITY_PASSWORD_NO_CONFIG]="No known password policy files found."
MSG_EN[SECURITY_PASSWORD_EXPIRY_POLICIES]="Password expiry policies (login.defs):"
MSG_EN[SECURITY_PASSWORD_LOGIN_DEFS_NOT_FOUND]="File /etc/login.defs not found."
MSG_EN[SECURITY_PASSWORD_PASSWD_NOT_AVAILABLE]="The program 'passwd' is not available."
MSG_EN[SECURITY_PASSWORD_NO_PASSWORD_CHECK]="Check for users without password:"
MSG_EN[SECURITY_PASSWORD_NO_PASSWORD_FOUND]="No users without password found."
MSG_EN[SECURITY_PASSWORD_NO_PASSWORD_WARNING]="WARNING: Users without password were found. This poses a security risk."
MSG_EN[SECURITY_PASSWORD_SET_PASSWORD_INFO]="Use 'sudo passwd [username]' to set a password."
MSG_EN[SECURITY_PASSWORD_ACCOUNT_DETAILS]="Would you like to show detailed information about user accounts?"
MSG_EN[SECURITY_PASSWORD_ACCOUNT_INFO]="Details about user accounts:"
MSG_EN[SECURITY_PASSWORD_INFO_UNAVAILABLE]="Information could not be retrieved."

# Common options
MSG_EN[SECURITY_OPTION_1_TO_4]="Option (1-4): "
MSG_EN[SECURITY_OPTION_1_TO_7]="Choose an option (1-7): "
MSG_EN[SECURITY_CHOOSE_OPTION]="Choose an option: "
MSG_EN[SECURITY_INVALID_OPTION]="Invalid option. Operation cancelled."
