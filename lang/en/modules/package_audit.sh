#!/bin/bash
#
# lang/en/modules/package_audit.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: Apache-2.0
#
# English translation for package audit module

# Declare MSG_EN as associative array
declare -A MSG_EN

MSG_EN[AUDIT_MODULE_NAME]="Package Audit"
MSG_EN[AUDIT_MODULE_DESC]="Audit, review, and restore installed packages and keys"
MSG_EN[AUDIT_HELP_NOTES]="Experimental and currently untested; expect bugs|Profiles are incomplete and may misclassify base packages|Review results before relying on restore output"

# Python requirement
MSG_EN[AUDIT_PYTHON_REQUIRED]="Python3 is required for this module."

MSG_EN[AUDIT_MENU_TITLE]="Package Audit & Restore"
MSG_EN[AUDIT_MENU_SCAN]="Start New Audit Scan"
MSG_EN[AUDIT_MENU_REVIEW]="Review Pending Audit (%s items)"
MSG_EN[AUDIT_MENU_RESTORE]="Restore/Reinstall from Audit"
MSG_EN[AUDIT_MENU_DISCARD]="Discard Current Audit"

MSG_EN[AUDIT_SCANNING]="Scanning system for packages and keys..."
MSG_EN[AUDIT_SCAN_COMPLETE]="Scan complete."
MSG_EN[AUDIT_SCAN_FAILED]="Scan failed. Please check logs for details."
MSG_EN[AUDIT_FOUND_SUMMARY]="Found: %s packages, %s keys, %s alternative managers."

MSG_EN[AUDIT_REVIEW_DISCARDED]="Audit list discarded."

MSG_EN[AUDIT_PKG_DETAILS]="Package: %s"
MSG_EN[AUDIT_PKG_VERSION]="Version: %s"
MSG_EN[AUDIT_PKG_MANAGER]="Manager: %s"
MSG_EN[AUDIT_PKG_DEPS]="Dependencies: %s"

MSG_EN[AUDIT_ACTION_PROMPT]="Action for this package?"
MSG_EN[AUDIT_ACTION_KEEP]="Keep (Save to restore list)"
MSG_EN[AUDIT_ACTION_DISCARD]="Don't keep (Remove from audit)"
MSG_EN[AUDIT_ACTION_SKIP]="Skip (Review again later)"
MSG_EN[AUDIT_ACTION_SKIP_ALL]="Skip All Remaining"

MSG_EN[AUDIT_REVIEW_FILTER_TITLE]="Review Filter"
MSG_EN[AUDIT_REVIEW_FILTER_DESC]="Choose which packages to review:"
MSG_EN[AUDIT_REVIEW_FILTER_AUR]="AUR/Foreign packages only (%s items)"
MSG_EN[AUDIT_REVIEW_FILTER_USER]="User-installed packages (excl. base) (%s items)"
MSG_EN[AUDIT_REVIEW_FILTER_BASE]="Base system packages (%s items)"
MSG_EN[AUDIT_REVIEW_FILTER_ALL]="All packages"
MSG_EN[AUDIT_REVIEW_FILTER_DONE]="No more packages in this filter."

MSG_EN[AUDIT_PKG_INSTALL_DATE]="Installed: %s"
MSG_EN[AUDIT_PKG_DEPS_COUNT]="Dependencies: %s"
MSG_EN[AUDIT_PKG_GROUPS]="Groups: %s"
MSG_EN[AUDIT_PKG_IS_BASE]="⚠ This appears to be a base system package"

MSG_EN[AUDIT_RESTORE_CHECKING]="Checking system against saved audit..."
MSG_EN[AUDIT_RESTORE_SUMMARY]="Missing items found:"
MSG_EN[AUDIT_RESTORE_PROGRAMS]="- %s Programs"
MSG_EN[AUDIT_RESTORE_MANAGERS]="- %s Package Managers"
MSG_EN[AUDIT_RESTORE_NONE]="System is up to date with the audit. Nothing to restore."

MSG_EN[AUDIT_RESTORE_CONFIRM_PACKAGES]="Do you want to install missing packages?"

# Profile selection
MSG_EN[AUDIT_PROFILE_TITLE]="Select Base Package Profile"
MSG_EN[AUDIT_PROFILE_DESC]="Choose a distribution profile to identify base system packages:"
MSG_EN[AUDIT_PROFILE_DEFAULT]="Use default configuration (no profile)"
MSG_EN[AUDIT_USING_PROFILE]="Using profile: %s"
MSG_EN[AUDIT_USING_DEFAULT]="Using default configuration"

# Additional messages
MSG_EN[AUDIT_NO_FILE]="No audit file found. Please run a scan first."
MSG_EN[AUDIT_REVIEW_COMPLETE]="Review complete. All packages have been processed."
MSG_EN[AUDIT_RESTORE_NOT_IMPLEMENTED]="Package installation not yet implemented in this version."

# Restore plan messages
MSG_EN[AUDIT_RESTORE_PLAN_TITLE]="Package Restoration Plan"
MSG_EN[AUDIT_RESTORE_PLAN_PACKAGES]="Total packages to restore: %s"
MSG_EN[AUDIT_RESTORE_PLAN_BREAKDOWN]="Breakdown: %s native, %s AUR, %s Flatpak, %s Snap"
MSG_EN[AUDIT_RESTORE_PLAN_PHASES]="Restoration phases:"
MSG_EN[AUDIT_RESTORE_CONFIRM_START]="Start restoration process?"
MSG_EN[AUDIT_RESTORE_PHASE]="Phase: %s"

# Restore phase-specific messages
MSG_EN[AUDIT_RESTORE_INSTALLING_PREREQS]="Installing build prerequisites..."
MSG_EN[AUDIT_RESTORE_AUR_HELPER_NEEDED]="An AUR helper is required for AUR packages."
MSG_EN[AUDIT_RESTORE_AUR_HELPER_FAILED]="Failed to install AUR helper. AUR packages will be skipped."
MSG_EN[AUDIT_RESTORE_IMPORTING_KEYS]="Importing %s PGP keys..."
MSG_EN[AUDIT_RESTORE_INSTALLING_NATIVE]="Installing %s native packages..."
MSG_EN[AUDIT_RESTORE_INSTALLING_AUR]="Installing %s AUR packages using %s..."
MSG_EN[AUDIT_RESTORE_NO_AUR_HELPER]="No AUR helper available. Skipping AUR packages."
MSG_EN[AUDIT_RESTORE_INSTALLING_FLATPAK]="Installing %s Flatpak applications..."
MSG_EN[AUDIT_RESTORE_INSTALLING_SNAP]="Installing %s Snap packages..."

# Restore completion messages
MSG_EN[AUDIT_RESTORE_COMPLETE]="Package restoration completed successfully!"
MSG_EN[AUDIT_RESTORE_COMPLETE_WITH_ERRORS]="Restoration completed with some errors"
MSG_EN[AUDIT_RESTORE_FAILED_COUNT]="Failed packages: %s"
