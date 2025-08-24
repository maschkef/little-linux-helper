#!/bin/bash
#
# English translations for GUI launcher
#
[[ ! -v MSG_EN ]] && declare -A MSG_EN

# Error messages
MSG_EN[GUI_LAUNCHER_UNKNOWN_OPTION]="Unknown option: %s"
MSG_EN[GUI_LAUNCHER_HELP_HINT]="Use -h or --help for usage information."
MSG_EN[GUI_LAUNCHER_DIR_NOT_FOUND]="GUI directory not found: %s"
MSG_EN[GUI_LAUNCHER_GUI_NOT_INSTALLED]="Please ensure the GUI is properly installed."
MSG_EN[GUI_LAUNCHER_CHECKING_DEPS]="Checking GUI dependencies..."
MSG_EN[GUI_LAUNCHER_DEPS_MISSING]="Missing dependencies required for building the GUI."
MSG_EN[GUI_LAUNCHER_BUILD_SCRIPT_MISSING]="Build script not found: %s"
MSG_EN[GUI_LAUNCHER_BUILD_SCRIPT_UNAVAILABLE]="Please ensure the GUI build script is available."
MSG_EN[GUI_LAUNCHER_SETUP_FAILED]="Setup failed. Please check the error messages above."
MSG_EN[GUI_LAUNCHER_BUILD_FAILED]="Build failed. Please check the error messages above."

# Status messages
MSG_EN[GUI_LAUNCHER_REBUILDING]="Rebuilding GUI as requested..."
MSG_EN[GUI_LAUNCHER_NOT_BUILT]="GUI is not built yet."
MSG_EN[GUI_LAUNCHER_BUILD_NEEDED]="The GUI needs to be built before it can be launched."
MSG_EN[GUI_LAUNCHER_BUILD_QUESTION]="Do you want to build it now? [y/N]: "
MSG_EN[GUI_LAUNCHER_BUILD_CANCELLED]="Build cancelled. Cannot launch GUI without building it first."
MSG_EN[GUI_LAUNCHER_BUILDING]="Building GUI..."
MSG_EN[GUI_LAUNCHER_SETUP_RUNNING]="Running initial setup..."
MSG_EN[GUI_LAUNCHER_BUILD_COMPLETED]="Build completed successfully!"
MSG_EN[GUI_LAUNCHER_STARTING]="Starting Little Linux Helper GUI..."
MSG_EN[GUI_LAUNCHER_NETWORK_WARNING1]="WARNING: Network mode enabled - GUI will be accessible from other machines"
MSG_EN[GUI_LAUNCHER_NETWORK_WARNING2]="WARNING: Ensure your firewall is properly configured"
MSG_EN[GUI_LAUNCHER_ACCESS_NETWORK]="The GUI will be accessible from the network (check console output for actual port)"
MSG_EN[GUI_LAUNCHER_ACCESS_LOCAL]="The GUI will be accessible locally (check console output for actual port)"
MSG_EN[GUI_LAUNCHER_STOP_HINT]="Press Ctrl+C to stop the GUI server."

# Firewall messages
MSG_EN[GUI_LAUNCHER_FW_OPENING]="Opening firewall for port %s/%s (if a supported firewall is active)..."
MSG_EN[GUI_LAUNCHER_FW_FIREWALLD_SUCCESS]="firewalld: opened %s/%s"
MSG_EN[GUI_LAUNCHER_FW_FIREWALLD_FAILED]="firewalld: failed to add %s/%s"
MSG_EN[GUI_LAUNCHER_FW_FIREWALLD_NOT_RUNNING]="firewalld detected but not running; skipping."
MSG_EN[GUI_LAUNCHER_FW_UFW_SUCCESS]="ufw: allowed %s/%s"
MSG_EN[GUI_LAUNCHER_FW_UFW_FAILED]="ufw: failed to allow %s/%s"
MSG_EN[GUI_LAUNCHER_FW_IPTABLES_EXISTS]="iptables: rule already present for %s/%s"
MSG_EN[GUI_LAUNCHER_FW_IPTABLES_SUCCESS]="iptables: added ACCEPT rule for %s/%s (not persistent)"
MSG_EN[GUI_LAUNCHER_FW_IPTABLES_PERSISTENT]="Consider saving rules (e.g., iptables-persistent) if needed."
MSG_EN[GUI_LAUNCHER_FW_IPTABLES_FAILED]="iptables: failed to add rule for %s/%s"
MSG_EN[GUI_LAUNCHER_FW_NO_TOOL]="No supported firewall tool detected (firewalld/ufw/iptables)."
MSG_EN[GUI_LAUNCHER_FW_CLOSING]="Closing firewall for port %s/%s..."
MSG_EN[GUI_LAUNCHER_FW_FIREWALLD_CLOSE_SUCCESS]="firewalld: closed %s/%s"
MSG_EN[GUI_LAUNCHER_FW_FIREWALLD_CLOSE_FAILED]="firewalld: failed to remove %s/%s"
MSG_EN[GUI_LAUNCHER_FW_UFW_CLOSE_SUCCESS]="ufw: removed allow rule for %s/%s"
MSG_EN[GUI_LAUNCHER_FW_UFW_CLOSE_FAILED]="ufw: failed to remove rule for %s/%s"
MSG_EN[GUI_LAUNCHER_FW_IPTABLES_CLOSE_SUCCESS]="iptables: removed ACCEPT rule for %s/%s"
MSG_EN[GUI_LAUNCHER_FW_IPTABLES_CLOSE_FAILED]="iptables: failed to remove rule for %s/%s"
MSG_EN[GUI_LAUNCHER_FW_IPTABLES_NO_RULE]="iptables: no rule found for %s/%s"
MSG_EN[GUI_LAUNCHER_FW_CLEANUP]="Cleaning up firewall rule..."
MSG_EN[GUI_LAUNCHER_FW_AUTO_REMOVE]="Firewall rule will be automatically removed when GUI stops."
