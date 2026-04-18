#!/bin/bash
#
# modules/mod_package_audit.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: Apache-2.0
#
# Module for auditing, reviewing, and restoring installed packages and keys.
# Can run standalone or as a submodule of mod_packages.sh

# Check if running as submodule (sourced from mod_packages.sh)
AUDIT_SUBMODULE_MODE=false
if [[ "$1" == "--submodule" ]]; then
    AUDIT_SUBMODULE_MODE=true
fi

# Load common library only if not already loaded (standalone mode)
if [[ -z "${LH_INITIALIZED:-}" ]]; then
    LIB_COMMON_PATH="$(dirname "${BASH_SOURCE[0]}")/../lib/lib_common.sh"
    if [[ ! -r "$LIB_COMMON_PATH" ]]; then
        echo "Missing required library: $LIB_COMMON_PATH" >&2
        if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
            exit 1
        else
            return 1
        fi
    fi
    # shellcheck source=lib/lib_common.sh
    source "$LIB_COMMON_PATH"
    
    # Initialize if run directly
    lh_load_general_config
    lh_initialize_logging
    lh_detect_package_manager
    lh_detect_alternative_managers
    lh_finalize_initialization
    export LH_INITIALIZED=1
fi

# Load translations if not already loaded
if [[ -z "${MSG[AUDIT_MODULE_NAME]:-}" ]]; then
    lh_load_language_module "package_audit"
    lh_load_language_module "common"
    lh_load_language_module "lib"
fi

lh_log_msg "DEBUG" "Package audit module initializing (submodule=$AUDIT_SUBMODULE_MODE)"
lh_log_msg "DEBUG" "Primary package manager: $LH_PKG_MANAGER"
lh_log_msg "DEBUG" "Alternative managers: ${LH_ALT_PKG_MANAGERS[*]:-none}"

# Ensure Python3 is available
if ! lh_check_command "python3" "true"; then
    lh_log_msg "ERROR" "Python3 not found - required for package audit module"
    lh_msgln 'AUDIT_PYTHON_REQUIRED'
    lh_press_any_key
    if [[ "$AUDIT_SUBMODULE_MODE" == "true" ]]; then
        return 1
    else
        exit 1
    fi
fi
lh_log_msg "DEBUG" "Python3 check passed"

# Paths
AUDIT_STATE_DIR="${LH_STATE_DIR:-$LH_ROOT_DIR/state/package_audit}"
AUDIT_FILE="$AUDIT_STATE_DIR/package_audit_state.json"
AUDIT_CONFIG_DIR="$LH_CONFIG_DIR/audit.d"
mkdir -p "$AUDIT_STATE_DIR"
lh_fix_ownership "$AUDIT_STATE_DIR" >/dev/null 2>&1 || true
lh_log_msg "DEBUG" "Audit state dir: $AUDIT_STATE_DIR"
lh_log_msg "DEBUG" "Audit state file: $AUDIT_FILE"
lh_log_msg "DEBUG" "Audit config dir: $AUDIT_CONFIG_DIR"

# Python helper script embedded
AUDIT_HELPER_SCRIPT=$(cat <<'PYTHON_EOF'
import sys
import json
import subprocess
import os
import shutil
from datetime import datetime, timedelta
import re

AUDIT_FILE = sys.argv[2] if len(sys.argv) > 2 else ""
AUDIT_CONFIG_DIR = sys.argv[3] if len(sys.argv) > 3 else ""

# Configuration - loaded from config files
CONFIG = {
    "detection_mode": "both",  # both, time, pattern, none
    "base_install_hours": 2,
    "base_packages_exact": [],
    "base_packages_prefix": [],
    "active_profile": ""  # Currently selected profile
}

def get_config_dir():
    """Get the config directory path"""
    if AUDIT_CONFIG_DIR:
        # If we have a dedicated audit config dir, use its parent as config root
        return os.path.dirname(AUDIT_CONFIG_DIR)
    if AUDIT_FILE:
        return os.path.dirname(AUDIT_FILE)
    return ""

def get_audit_config_dir():
    """Get the audit.d config directory path"""
    if AUDIT_CONFIG_DIR:
        return AUDIT_CONFIG_DIR
    config_dir = get_config_dir()
    if config_dir:
        return os.path.join(config_dir, "audit.d")
    return ""

def get_profiles_dir():
    """Get the profiles directory path"""
    audit_config_dir = get_audit_config_dir()
    if audit_config_dir:
        return os.path.join(audit_config_dir, "profiles")
    return ""

def list_available_profiles():
    """List all available profile configurations"""
    profiles = []
    profiles_dir = get_profiles_dir()
    
    if not profiles_dir or not os.path.isdir(profiles_dir):
        return profiles
    
    for f in sorted(os.listdir(profiles_dir)):
        if f.endswith('.conf') and not f.endswith('.example'):
            profile_name = f[:-5]  # Remove .conf extension
            profile_info = {"name": profile_name, "distro": profile_name.title(), "file": f}
            
            # Try to read distro name from file header
            filepath = os.path.join(profiles_dir, f)
            try:
                with open(filepath, 'r') as pf:
                    for line in pf:
                        line = line.strip()
                        if line.startswith('# @distro '):
                            profile_info["distro"] = line[10:].strip()
                            break
                        if not line.startswith('#'):
                            break
            except:
                pass
            
            profiles.append(profile_info)
    
    return profiles

def load_profile(profile_name):
    """Load a specific profile configuration"""
    global CONFIG
    
    profiles_dir = get_profiles_dir()
    if not profiles_dir:
        return False
    
    profile_file = os.path.join(profiles_dir, f"{profile_name}.conf")
    if not os.path.isfile(profile_file):
        return False
    
    try:
        with open(profile_file, 'r') as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                if '=' in line:
                    key, value = line.split('=', 1)
                    key = key.strip()
                    value = value.strip().strip('"').strip("'")
                    
                    if key == "CFG_AUDIT_BASE_PACKAGES_EXACT":
                        CONFIG["base_packages_exact"] = [p.strip() for p in value.split(',') if p.strip()]
                    elif key == "CFG_AUDIT_BASE_PACKAGES_PREFIX":
                        CONFIG["base_packages_prefix"] = [p.strip() for p in value.split(',') if p.strip()]
        
        CONFIG["active_profile"] = profile_name
        return True
    except:
        return False

def load_config(profile_name=""):
    """Load audit configuration from config/audit.d/*.conf files and optionally a profile"""
    global CONFIG
    
    audit_config_dir = get_audit_config_dir()
    
    if not audit_config_dir or not os.path.isdir(audit_config_dir):
        return
    
    # Read base config files (00-base-packages.conf etc.) in order
    conf_files = sorted([f for f in os.listdir(audit_config_dir) if f.endswith('.conf') and os.path.isfile(os.path.join(audit_config_dir, f))])
    
    for conf_file in conf_files:
        filepath = os.path.join(audit_config_dir, conf_file)
        try:
            with open(filepath, 'r') as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith('#'):
                        continue
                    if '=' in line:
                        key, value = line.split('=', 1)
                        key = key.strip()
                        # Remove surrounding quotes
                        value = value.strip().strip('"').strip("'")
                        
                        if key == "CFG_AUDIT_DETECTION_MODE":
                            CONFIG["detection_mode"] = value
                        elif key == "CFG_AUDIT_BASE_INSTALL_HOURS":
                            try:
                                CONFIG["base_install_hours"] = int(value)
                            except:
                                pass
                        elif key == "CFG_AUDIT_BASE_PACKAGES_EXACT":
                            CONFIG["base_packages_exact"] = [p.strip() for p in value.split(',') if p.strip()]
                        elif key == "CFG_AUDIT_BASE_PACKAGES_PREFIX":
                            CONFIG["base_packages_prefix"] = [p.strip() for p in value.split(',') if p.strip()]
        except:
            pass
    
    # Load profile if specified (overrides base config package lists)
    if profile_name:
        load_profile(profile_name)

# Load config on module import (without profile - will be loaded later if specified)
load_config()

def run_cmd(cmd):
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        return result.stdout.strip()
    except Exception:
        return ""

def is_base_package_by_pattern(name):
    """Check if package matches base package patterns"""
    if CONFIG["detection_mode"] in ("none", "time"):
        return False
    
    # Check exact matches
    if name in CONFIG["base_packages_exact"]:
        return True
    
    # Check prefix matches
    for prefix in CONFIG["base_packages_prefix"]:
        if name.startswith(prefix):
            return True
    
    return False

def get_base_install_cutoff():
    """Get the datetime cutoff for time-based base detection"""
    if CONFIG["detection_mode"] in ("none", "pattern"):
        return None
    if CONFIG["base_install_hours"] <= 0:
        return None
    
    # Get first install timestamp from pacman.log
    first_install_time = None
    try:
        with open("/var/log/pacman.log", "r") as f:
            for line in f:
                if "[ALPM] installed" in line:
                    # Format: [2024-01-15T10:30:00+0100] [ALPM] installed ...
                    match = re.match(r'\[(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})', line)
                    if match:
                        first_install_time = datetime.fromisoformat(match.group(1))
                        break
    except:
        pass
    
    if first_install_time:
        return first_install_time + timedelta(hours=CONFIG["base_install_hours"])
    return None

def is_base_package_by_time(install_datetime_str, cutoff):
    """Check if package was installed within the base install window"""
    if not cutoff or not install_datetime_str:
        return False
    
    try:
        # Parse various datetime formats
        if 'T' in install_datetime_str:
            install_time = datetime.fromisoformat(install_datetime_str[:19])
        else:
            install_time = datetime.strptime(install_datetime_str[:19], "%Y-%m-%d %H:%M:%S")
        return install_time <= cutoff
    except:
        return False

def get_install_dates_from_log():
    """Build a map of package -> install datetime from pacman.log"""
    install_dates = {}
    try:
        with open('/var/log/pacman.log', 'r') as f:
            for line in f:
                # Format: [2025-08-10T10:34:06+0200] [ALPM] installed alacritty (0.15.1-1.1)
                match = re.match(r'\[(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})[^\]]*\] \[ALPM\] installed ([^ ]+)', line)
                if match:
                    timestamp, pkg_name = match.groups()
                    # Keep only the first install (original install date)
                    if pkg_name not in install_dates:
                        install_dates[pkg_name] = timestamp
    except:
        pass
    return install_dates

def get_pacman_packages():
    # pacman -Qe: explicitly installed
    # We use expac for better performance: %n name, %v version, %D deps, %l install date, %G groups
    
    packages = []
    
    # Get time-based cutoff
    time_cutoff = get_base_install_cutoff()
    
    # Get install dates from pacman.log (more reliable than locale-dependent pacman -Qi)
    install_date_map = get_install_dates_from_log()
    
    # Common base/system package groups to flag
    base_groups = {
        "base", "base-devel", "xorg", "xorg-apps", "xorg-drivers", "xorg-fonts",
        "gnome", "gnome-extra", "kde-applications", "plasma", "plasma-meta",
        "xfce4", "xfce4-goodies", "lxde", "lxqt", "mate", "mate-extra",
        "cinnamon", "budgie", "deepin", "deepin-extra"
    }
    
    try:
        # Check for expac for better performance/parsing
        if shutil.which("expac"):
            # %n: name, %v: version, %D: depends, %G: groups
            out = run_cmd("expac -Qe '%n|%v|%D|%G'")
            for line in out.splitlines():
                parts = line.split('|')
                if len(parts) >= 2:
                    name = parts[0]
                    version = parts[1]
                    deps = parts[2].split() if len(parts) > 2 and parts[2] else []
                    groups = parts[3].split() if len(parts) > 3 and parts[3] else []
                    
                    # Get install date from log (more reliable)
                    install_datetime = install_date_map.get(name, "")
                    install_date = install_datetime[:10] if install_datetime else ""
                    
                    # Determine if this is likely a base system package
                    is_base = False
                    
                    # Always check groups
                    if any(g in base_groups for g in groups):
                        is_base = True
                    
                    # Check pattern-based detection
                    if not is_base and is_base_package_by_pattern(name):
                        is_base = True
                    
                    # Check time-based detection
                    if not is_base and is_base_package_by_time(install_datetime, time_cutoff):
                        is_base = True
                    
                    packages.append({
                        "name": name,
                        "version": version,
                        "manager": "pacman",
                        "dependencies": deps,
                        "groups": groups,
                        "install_date": install_date,
                        "install_datetime": install_datetime,
                        "is_base": is_base,
                        "status": "pending"
                    })
        else:
            # Fallback to pacman -Qei (explicit + info)
            # Note: We get install dates from pacman.log instead of parsing locale-dependent date strings
            out = run_cmd("pacman -Qei")
            current_pkg = {}
            for line in out.splitlines():
                if not line.strip():
                    if current_pkg:
                        # Get install date from log (more reliable than locale-dependent parsing)
                        name = current_pkg.get("name", "")
                        install_datetime = install_date_map.get(name, "")
                        current_pkg["install_datetime"] = install_datetime
                        current_pkg["install_date"] = install_datetime[:10] if install_datetime else ""
                        
                        # Check if base package
                        groups = current_pkg.get("groups", [])
                        
                        is_base = any(g in base_groups for g in groups)
                        if not is_base:
                            is_base = is_base_package_by_pattern(name)
                        if not is_base:
                            is_base = is_base_package_by_time(install_datetime, time_cutoff)
                        
                        current_pkg["is_base"] = is_base
                        packages.append(current_pkg)
                        current_pkg = {}
                    continue
                    
                if ":" in line:
                    key, value = [x.strip() for x in line.split(":", 1)]
                    if key == "Name":
                        current_pkg = {"name": value, "manager": "pacman", "status": "pending", "dependencies": [], "groups": [], "is_base": False}
                    elif key == "Version" and current_pkg:
                        current_pkg["version"] = value
                    elif key == "Depends On" and current_pkg:
                        if value != "None":
                            current_pkg["dependencies"] = value.split()
                    elif key == "Groups" and current_pkg:
                        if value != "None":
                            current_pkg["groups"] = value.split()
            
            if current_pkg:
                # Get install date from log for last package
                name = current_pkg.get("name", "")
                install_datetime = install_date_map.get(name, "")
                current_pkg["install_datetime"] = install_datetime
                current_pkg["install_date"] = install_datetime[:10] if install_datetime else ""
                
                groups = current_pkg.get("groups", [])
                
                is_base = any(g in base_groups for g in groups)
                if not is_base:
                    is_base = is_base_package_by_pattern(name)
                if not is_base:
                    is_base = is_base_package_by_time(install_datetime, time_cutoff)
                
                current_pkg["is_base"] = is_base
                packages.append(current_pkg)

        # Refine manager for AUR packages
        foreign_out = run_cmd("pacman -Qm")
        foreign_pkgs = set()
        for line in foreign_out.splitlines():
            parts = line.split()
            if parts:
                foreign_pkgs.add(parts[0])
        
        has_yay = shutil.which("yay") is not None
        
        for pkg in packages:
            if pkg["name"] in foreign_pkgs:
                pkg["manager"] = "yay" if has_yay else "aur"

    except Exception as e:
        pass
    return packages

def get_apt_packages():
    packages = []
    try:
        # apt-mark showmanual
        manual_pkgs = run_cmd("apt-mark showmanual").splitlines()
        # We can use dpkg-query to get details for these
        # dpkg-query -W -f='${Package}|${Version}|${Depends}\n'
        
        # It's more efficient to get all info and filter
        out = run_cmd("dpkg-query -W -f='${Package}|${Version}|${Depends}\n'")
        manual_set = set(manual_pkgs)
        
        for line in out.splitlines():
            parts = line.split('|')
            if len(parts) >= 2:
                name = parts[0]
                if name in manual_set:
                    version = parts[1]
                    deps_raw = parts[2] if len(parts) > 2 else ""
                    # Clean up deps (remove version constraints)
                    deps = [d.split()[0] for d in deps_raw.split(',')] if deps_raw else []
                    packages.append({
                        "name": name,
                        "version": version,
                        "manager": "apt",
                        "dependencies": deps,
                        "status": "pending"
                    })
    except Exception:
        pass
    return packages

def get_dnf_packages():
    packages = []
    try:
        # dnf repoquery --userinstalled --qf "%{name}|%{version}|%{requires}"
        # This might be slow. 'dnf history userinstalled' is another option but harder to parse.
        # Let's try rpm -qa for everything and filter? No, we want user installed.
        # dnf is tricky for "user installed" vs "dep".
        # We'll use a simplified approach: rpm -qa --qf ... and assume all are relevant for now, 
        # or try to use dnf history.
        
        out = run_cmd("rpm -qa --qf '%{NAME}|%{VERSION}|%{REQUIRENAME}\n'")
        # This lists ALL packages.
        # For the purpose of this tool, maybe listing all is too much.
        # Let's try to stick to user requested if possible.
        # If dnf is present, use it.
        if shutil.which("dnf"):
            out = run_cmd("dnf repoquery --userinstalled --qf '%{name}|%{version}|%{requires}'")
            for line in out.splitlines():
                parts = line.split('|')
                if len(parts) >= 2:
                    name = parts[0]
                    version = parts[1]
                    deps = parts[2].split(',') if len(parts) > 2 and parts[2] else []
                    packages.append({
                        "name": name,
                        "version": version,
                        "manager": "dnf",
                        "dependencies": deps,
                        "status": "pending"
                    })
    except Exception:
        pass
    return packages

def get_flatpak_packages():
    packages = []
    if not shutil.which("flatpak"):
        return packages
    try:
        # flatpak list --app --columns=name,version,application
        out = run_cmd("flatpak list --app --columns=name,version,application")
        for line in out.splitlines():
            parts = line.split('\t')
            if len(parts) >= 3:
                name = parts[0]
                version = parts[1]
                app_id = parts[2]
                packages.append({
                    "name": f"{name} ({app_id})",
                    "version": version,
                    "manager": "flatpak",
                    "dependencies": [], # Flatpak handles deps internally (runtimes)
                    "status": "pending"
                })
    except Exception:
        pass
    return packages

def get_snap_packages():
    packages = []
    if not shutil.which("snap"):
        return packages
    try:
        # snap list
        out = run_cmd("snap list")
        lines = out.splitlines()
        if len(lines) > 1:
            # Skip header
            for line in lines[1:]:
                parts = line.split()
                if len(parts) >= 2:
                    name = parts[0]
                    version = parts[1]
                    packages.append({
                        "name": name,
                        "version": version,
                        "manager": "snap",
                        "dependencies": [],
                        "status": "pending"
                    })
    except Exception:
        pass
    return packages

def get_keys(manager):
    keys = []
    if manager == "pacman":
        # pacman-key --list-keys (not --list!)
        # Output format (GPG 2.1+):
        # pub   rsa4096 2025-08-10 [SC]
        #       82DB7B15D9BF14D528446C9197CDC79E48EEDA75
        # uid           [ultimate] Pacman Keyring Master Key <pacman@localhost>
        
        out = run_cmd("pacman-key --list-keys 2>/dev/null")
        lines = out.splitlines()
        i = 0
        while i < len(lines):
            line = lines[i]
            if line.startswith("pub"):
                # The fingerprint is on the next line (indented)
                if i + 1 < len(lines):
                    next_line = lines[i+1].strip()
                    # Check if it looks like a fingerprint (hex string)
                    fingerprint_clean = next_line.replace(" ", "")
                    if all(c in '0123456789ABCDEFabcdef' for c in fingerprint_clean) and len(fingerprint_clean) >= 16:
                        key_id = fingerprint_clean[-16:]  # Last 16 chars as short ID
                        
                        # Try to get the uid (name) from the next uid line
                        uid_name = ""
                        for j in range(i+2, min(i+10, len(lines))):
                            if lines[j].startswith("uid"):
                                # Extract name between ] and <
                                uid_line = lines[j]
                                try:
                                    start = uid_line.rindex("]") + 1
                                    end = uid_line.rindex("<") if "<" in uid_line else len(uid_line)
                                    uid_name = uid_line[start:end].strip()
                                except:
                                    pass
                                break
                        
                        keys.append({"id": key_id, "name": uid_name, "fingerprint": fingerprint_clean, "manager": "pacman", "status": "installed"})
                        i += 2
                        continue
            i += 1
    elif manager == "apt":
        # apt-key list is deprecated, look at trusted.gpg and trusted.gpg.d
        # We can list files in /etc/apt/trusted.gpg.d/
        try:
            for f in os.listdir("/etc/apt/trusted.gpg.d/"):
                if f.endswith(".gpg") or f.endswith(".asc"):
                    keys.append({"id": f, "manager": "apt", "status": "installed"})
        except:
            pass
    elif manager == "dnf":
        # rpm -qa gpg-pubkey*
        out = run_cmd("rpm -qa gpg-pubkey*")
        for line in out.splitlines():
            keys.append({"id": line, "manager": "dnf", "status": "installed"})
    return keys

def scan_system(profile_name=""):
    # Reload config with profile if specified
    if profile_name:
        load_config(profile_name)
    
    data = {
        "timestamp": datetime.now().isoformat(),
        "status": "pending",
        "profile": CONFIG.get("active_profile", ""),
        "packages": [],
        "keys": [],
        "alternative_managers": []
    }
    
    # Detect PM
    pm = ""
    if shutil.which("pacman"): pm = "pacman"
    elif shutil.which("apt"): pm = "apt"
    elif shutil.which("dnf"): pm = "dnf"
    
    data["package_manager"] = pm
    
    # Scan Packages
    if pm == "pacman":
        data["packages"] = get_pacman_packages()
    elif pm == "apt":
        data["packages"] = get_apt_packages()
    elif pm == "dnf":
        data["packages"] = get_dnf_packages()
        
    # Add Flatpak and Snap packages
    data["packages"].extend(get_flatpak_packages())
    data["packages"].extend(get_snap_packages())
        
    # Scan Keys
    data["keys"] = get_keys(pm)
    
    # Scan Alt Managers (AUR helpers, universal package managers)
    alts = []
    # AUR helpers for Arch
    if shutil.which("yay"): alts.append("yay")
    if shutil.which("paru"): alts.append("paru")
    if shutil.which("trizen"): alts.append("trizen")
    if shutil.which("pikaur"): alts.append("pikaur")
    # Universal package managers
    if shutil.which("flatpak"): alts.append("flatpak")
    if shutil.which("snap"): alts.append("snap")
    if shutil.which("nix-env"): alts.append("nix")
    if shutil.which("brew"): alts.append("brew")
    if shutil.which("cargo"): alts.append("cargo")
    if shutil.which("pip3") or shutil.which("pip"): alts.append("pip")
    data["alternative_managers"] = alts
    
    with open(AUDIT_FILE, 'w') as f:
        json.dump(data, f, indent=2)
    
    print(json.dumps({"count": len(data["packages"]), "keys": len(data["keys"]), "alts": len(alts)}))

def get_stats():
    if not os.path.exists(AUDIT_FILE):
        print(json.dumps({"error": "no_file"}))
        return
        
    with open(AUDIT_FILE, 'r') as f:
        data = json.load(f)
        
    total = len(data["packages"])
    pending = sum(1 for p in data["packages"] if p.get("status") == "pending")
    kept = sum(1 for p in data["packages"] if p.get("status") == "keep")
    skipped = sum(1 for p in data["packages"] if p.get("status") == "skipped")
    discarded = sum(1 for p in data["packages"] if p.get("status") == "discard")
    
    # Count by category (only pending items)
    user_pkgs = sum(1 for p in data["packages"] if not p.get("is_base", False) and p.get("status") == "pending")
    aur_pkgs = sum(1 for p in data["packages"] if p.get("manager") in ["yay", "aur", "paru"] and p.get("status") == "pending")
    base_pkgs = sum(1 for p in data["packages"] if p.get("is_base", False) and p.get("status") == "pending")
    
    print(json.dumps({
        "total": total,
        "pending": pending,
        "kept": kept,
        "skipped": skipped,
        "discarded": discarded,
        "user_pkgs": user_pkgs,
        "aur_pkgs": aur_pkgs,
        "base_pkgs": base_pkgs,
        "status": data.get("status", "pending")
    }))

def reset_skipped():
    """Reset all skipped packages back to pending for next review"""
    if not os.path.exists(AUDIT_FILE):
        return
        
    with open(AUDIT_FILE, 'r') as f:
        data = json.load(f)
    
    count = 0
    for pkg in data["packages"]:
        if pkg.get("status") == "skipped":
            pkg["status"] = "pending"
            count += 1
    
    with open(AUDIT_FILE, 'w') as f:
        json.dump(data, f, indent=2)
    
    print(json.dumps({"reset_count": count}))

def get_next_pending(filter_mode="all"):
    if not os.path.exists(AUDIT_FILE):
        return
        
    with open(AUDIT_FILE, 'r') as f:
        data = json.load(f)
    
    for i, pkg in enumerate(data["packages"]):
        if pkg.get("status") != "pending":
            continue
            
        # Apply filter
        if filter_mode == "user":
            # Skip base packages
            if pkg.get("is_base", False):
                continue
        elif filter_mode == "aur":
            # Only AUR packages
            if pkg.get("manager") not in ["yay", "aur", "paru"]:
                continue
        elif filter_mode == "base":
            # Only base packages
            if not pkg.get("is_base", False):
                continue
        
        pkg["index"] = i
        print(json.dumps(pkg))
        return
            
    print(json.dumps(None))

def update_status(index, status):
    if not os.path.exists(AUDIT_FILE):
        return
        
    with open(AUDIT_FILE, 'r') as f:
        data = json.load(f)
        
    if status == "skip_all":
        # Mark all remaining pending as skipped (temporary - for this review session)
        for pkg in data["packages"]:
            if pkg.get("status") == "pending":
                pkg["status"] = "skipped"
    elif status == "skip":
        # Temporary skip - mark as skipped for this session
        # Will be reset to pending on next scan or manual reset
        if 0 <= index < len(data["packages"]):
            data["packages"][index]["status"] = "skipped"
    else:
        # keep, discard - set the actual permanent status
        if 0 <= index < len(data["packages"]):
            data["packages"][index]["status"] = status
            
    with open(AUDIT_FILE, 'w') as f:
        json.dump(data, f, indent=2)

def discard():
    if os.path.exists(AUDIT_FILE):
        os.remove(AUDIT_FILE)

def get_required_keys_for_aur_packages(package_names):
    """
    Query PKGBUILDs from AUR to find validpgpkeys for specific packages.
    Returns only keys that are actually needed for the given packages.
    """
    required_keys = []
    
    for pkg in package_names:
        try:
            # Fetch PKGBUILD from AUR
            result = subprocess.run(
                ["curl", "-s", f"https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h={pkg}"],
                capture_output=True, text=True, timeout=10
            )
            if result.returncode == 0 and "validpgpkeys" in result.stdout:
                content = result.stdout
                # Find validpgpkeys array
                match = re.search(r"validpgpkeys=\(([^)]+)\)", content, re.DOTALL)
                if match:
                    keys_str = match.group(1)
                    # Extract key IDs (remove quotes and comments)
                    for line in keys_str.split('\n'):
                        line = line.strip()
                        if line and not line.startswith('#'):
                            # Remove quotes and inline comments
                            key = line.strip("'\"").split('#')[0].strip().split()[0] if line else ""
                            if key and len(key) >= 16 and all(c in '0123456789ABCDEFabcdef' for c in key):
                                required_keys.append({
                                    "fingerprint": key,
                                    "name": f"Key for {pkg}",
                                    "package": pkg,
                                    "id": key[-16:]  # Short ID
                                })
        except Exception:
            pass
    
    # Deduplicate by fingerprint
    seen = set()
    unique_keys = []
    for k in required_keys:
        if k["fingerprint"] not in seen:
            seen.add(k["fingerprint"])
            unique_keys.append(k)
    
    return unique_keys

def get_restore_plan():
    """Generate a detailed restoration plan with phases"""
    if not os.path.exists(AUDIT_FILE):
        print(json.dumps({"error": "no_file"}))
        return
    
    with open(AUDIT_FILE, 'r') as f:
        data = json.load(f)
    
    pm = data.get("package_manager", "")
    
    # Get currently installed packages
    current_pkgs = set()
    if pm == "pacman":
        out = run_cmd("pacman -Qq")
        current_pkgs = set(out.splitlines())
    elif pm == "apt":
        out = run_cmd("dpkg-query -W -f='${Package}\\n'")
        current_pkgs = set(out.splitlines())
    elif pm == "dnf":
        out = run_cmd("rpm -qa --qf '%{NAME}\\n'")
        current_pkgs = set(out.splitlines())
    
    plan = {"phases": [], "summary": {}}
    
    # Categorize missing packages
    native_missing = []
    aur_missing = []
    flatpak_missing = []
    snap_missing = []
    
    for pkg in data["packages"]:
        if pkg.get("status") != "keep":
            continue
        if pkg["name"] in current_pkgs:
            continue
            
        manager = pkg.get("manager", pm)
        if manager in ["yay", "aur", "paru"]:
            aur_missing.append(pkg)
        elif manager == "flatpak":
            flatpak_missing.append(pkg)
        elif manager == "snap":
            snap_missing.append(pkg)
        else:
            native_missing.append(pkg)
    
    # Phase 1: Prerequisites (for Arch-based)
    if pm == "pacman" and aur_missing:
        prerequisites = []
        if "base-devel" not in current_pkgs:
            prerequisites.append({"name": "base-devel", "manager": "pacman"})
        if "git" not in current_pkgs:
            prerequisites.append({"name": "git", "manager": "pacman"})
        if prerequisites:
            plan["phases"].append({
                "id": "prerequisites",
                "name": "Prerequisites",
                "packages": prerequisites
            })
    
    # Phase 2: AUR Helper (if needed)
    has_aur_helper = any(shutil.which(h) for h in ["yay", "paru", "trizen", "pikaur"])
    if aur_missing and not has_aur_helper:
        plan["phases"].append({
            "id": "aur_helper",
            "name": "AUR Helper",
            "action": "bootstrap",
            "options": ["yay", "paru"]
        })
    
    # Phase 3: Required Keys (only for AUR packages that need them)
    if aur_missing:
        aur_pkg_names = [p["name"] for p in aur_missing]
        required_keys = get_required_keys_for_aur_packages(aur_pkg_names)
        if required_keys:
            plan["phases"].append({
                "id": "keys",
                "name": "PGP Keys",
                "keys": required_keys
            })
    
    # Phase 4: Native packages
    if native_missing:
        plan["phases"].append({
            "id": "native",
            "name": "System Packages",
            "packages": native_missing,
            "manager": pm,
            "batch_size": 50
        })
    
    # Phase 5: AUR packages
    if aur_missing:
        plan["phases"].append({
            "id": "aur",
            "name": "AUR Packages",
            "packages": aur_missing,
            "batch_size": 10
        })
    
    # Phase 6: Flatpak
    if flatpak_missing:
        plan["phases"].append({
            "id": "flatpak",
            "name": "Flatpak Apps",
            "packages": flatpak_missing
        })
    
    # Phase 7: Snap
    if snap_missing:
        plan["phases"].append({
            "id": "snap",
            "name": "Snap Packages",
            "packages": snap_missing
        })
    
    # Summary
    total_pkgs = len(native_missing) + len(aur_missing) + len(flatpak_missing) + len(snap_missing)
    plan["summary"] = {
        "total_phases": len(plan["phases"]),
        "total_packages": total_pkgs,
        "native_count": len(native_missing),
        "aur_count": len(aur_missing),
        "flatpak_count": len(flatpak_missing),
        "snap_count": len(snap_missing)
    }
    
    print(json.dumps(plan))

def get_profiles():
    """Return list of available profiles as JSON"""
    profiles = list_available_profiles()
    print(json.dumps({"profiles": profiles}))

mode = sys.argv[1]
if mode == "scan": 
    profile = sys.argv[4] if len(sys.argv) > 4 else ""
    scan_system(profile)
elif mode == "profiles": get_profiles()
elif mode == "stats": get_stats()
elif mode == "next": get_next_pending(sys.argv[4] if len(sys.argv) > 4 else "all")
elif mode == "update": update_status(int(sys.argv[4]), sys.argv[5])
elif mode == "discard": discard()
elif mode == "restore_plan": get_restore_plan()
elif mode == "reset_skipped": reset_skipped()

PYTHON_EOF
)

# Helper to run python script
# Returns: stdout from Python script
# Exit code: propagated from Python script
function run_audit_helper() {
    local mode="$1"
    shift
    lh_log_msg "DEBUG" "Running audit helper: mode='$mode' args='$*'"
    local output
    local exit_code
    output=$(python3 -c "$AUDIT_HELPER_SCRIPT" "$mode" "$AUDIT_FILE" "$AUDIT_CONFIG_DIR" "$@")
    exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        lh_log_msg "WARN" "Audit helper returned exit code: $exit_code for mode: $mode"
    fi
    lh_log_msg "DEBUG" "Audit helper output length: ${#output} chars"
    echo "$output"
    return $exit_code
}

function select_profile() {
    lh_log_msg "DEBUG" "Entering select_profile function"
    # Returns the selected profile name or empty string for default
    # Note: All UI output goes to stderr so only the result goes to stdout
    local profiles_json
    profiles_json=$(run_audit_helper "profiles")
    
    local profile_count
    profile_count=$(echo "$profiles_json" | python3 -c "import sys, json; print(len(json.load(sys.stdin).get('profiles', [])))")
    lh_log_msg "DEBUG" "Available profiles count: $profile_count"
    
    if [[ "$profile_count" -eq 0 ]]; then
        lh_log_msg "DEBUG" "No profiles available, returning empty"
        echo ""
        return
    fi
    
    clear >&2
    lh_print_header "$(lh_msg 'AUDIT_PROFILE_TITLE')" >&2
    echo "" >&2
    lh_msgln 'AUDIT_PROFILE_DESC' >&2
    echo "" >&2
    
    # Option 0: Use default config (no profile)
    lh_print_menu_item 0 "$(lh_msg 'AUDIT_PROFILE_DEFAULT')" >&2
    echo "" >&2
    
    # List all profiles
    local i=1
    local profile_names=()
    while IFS= read -r line; do
        local name distro
        name=$(echo "$line" | python3 -c "import sys, json; print(json.load(sys.stdin)['name'])")
        distro=$(echo "$line" | python3 -c "import sys, json; print(json.load(sys.stdin)['distro'])")
        profile_names+=("$name")
        lh_print_menu_item "$i" "$distro ($name)" >&2
        ((i++))
    done < <(echo "$profiles_json" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for p in data.get('profiles', []):
    print(json.dumps(p))
")
    
    echo "" >&2
    lh_print_menu_item "b" "$(lh_msg 'BACK')" >&2
    echo "" >&2
    
    local choice
    read -r -p "$(lh_msg 'CHOOSE_OPTION') " choice </dev/tty
    lh_log_msg "DEBUG" "Profile selection user choice: '$choice'"
    
    case "$choice" in
        0) 
            lh_log_msg "DEBUG" "User selected default config (no profile)"
            echo ""
            ;;
        b|B)
            lh_log_msg "DEBUG" "User selected back"
            echo "__back__"
            ;;
        *)
            if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "${#profile_names[@]}" ]]; then
                local selected="${profile_names[$((choice-1))]}"
                lh_log_msg "DEBUG" "User selected profile: $selected"
                echo "$selected"
            else
                lh_log_msg "DEBUG" "Invalid choice '$choice', showing error"
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'INVALID_SELECTION')${LH_COLOR_RESET}" >&2
                sleep 1
                # Recursively call to allow retry
                select_profile
                return
            fi
            ;;
    esac
}

function audit_scan() {
    lh_log_msg "DEBUG" "Entering audit_scan function"
    # First, let user select a profile
    local selected_profile
    selected_profile=$(select_profile)
    lh_log_msg "DEBUG" "Selected profile: '${selected_profile:-<default>}'"
    
    if [[ "$selected_profile" == "__back__" ]]; then
        lh_log_msg "DEBUG" "User cancelled profile selection, returning"
        return
    fi
    
    clear
    lh_print_header "$(lh_msg 'AUDIT_MENU_SCAN')"
    
    if [[ -n "$selected_profile" ]]; then
        lh_msgln 'AUDIT_USING_PROFILE' "$selected_profile"
    else
        lh_msgln 'AUDIT_USING_DEFAULT'
    fi
    echo ""
    lh_msgln 'AUDIT_SCANNING'
    
    # Update session activity for scan operation
    lh_update_module_session "$(lh_msg 'AUDIT_SCANNING')" "running"
    
    lh_log_msg "DEBUG" "Starting system scan with package manager: $LH_PKG_MANAGER"
    local result
    result=$(run_audit_helper "scan" "$selected_profile")
    
    # Validate scan result
    if [[ -z "$result" ]] || ! echo "$result" | python3 -c "import sys, json; json.load(sys.stdin)" 2>/dev/null; then
        lh_log_msg "ERROR" "Scan failed: invalid or empty result"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'AUDIT_SCAN_FAILED')${LH_COLOR_RESET}"
        lh_press_any_key
        return 1
    fi
    
    local count keys alts
    count=$(echo "$result" | python3 -c "import sys, json; print(json.load(sys.stdin).get('count', 0))")
    keys=$(echo "$result" | python3 -c "import sys, json; print(json.load(sys.stdin).get('keys', 0))")
    alts=$(echo "$result" | python3 -c "import sys, json; print(json.load(sys.stdin).get('alts', 0))")
    
    lh_log_msg "DEBUG" "Scan complete: packages=$count, keys=$keys, alt_managers=$alts"
    lh_log_msg "INFO" "Package audit scan completed: $count packages found"
    
    lh_msgln 'AUDIT_SCAN_COMPLETE'
    lh_msgln 'AUDIT_FOUND_SUMMARY' "$count" "$keys" "$alts"
    
    lh_press_any_key
}

function audit_review() {
    lh_log_msg "DEBUG" "Entering audit_review function"
    # First, reset any skipped packages from previous sessions so they can be reviewed again
    local reset_result
    reset_result=$(run_audit_helper "reset_skipped")
    local reset_count
    reset_count=$(echo "$reset_result" | python3 -c "import sys, json; print(json.load(sys.stdin).get('reset_count', 0))" 2>/dev/null || echo "0")
    if [[ "$reset_count" -gt 0 ]]; then
        lh_log_msg "DEBUG" "Reset $reset_count previously skipped packages to pending"
    fi
    
    # Now ask user what they want to review
    local filter_mode="user"
    
    local stats
    stats=$(run_audit_helper "stats")
    
    if echo "$stats" | grep -q "no_file"; then
        lh_log_msg "DEBUG" "No audit file found, cannot review"
        lh_msgln 'AUDIT_NO_FILE'
        return
    fi
    
    local user_pkgs aur_pkgs base_pkgs
    user_pkgs=$(echo "$stats" | python3 -c "import sys, json; print(json.load(sys.stdin).get('user_pkgs', 0))")
    aur_pkgs=$(echo "$stats" | python3 -c "import sys, json; print(json.load(sys.stdin).get('aur_pkgs', 0))")
    base_pkgs=$(echo "$stats" | python3 -c "import sys, json; print(json.load(sys.stdin).get('base_pkgs', 0))")
    lh_log_msg "DEBUG" "Package stats: user=$user_pkgs, aur=$aur_pkgs, base=$base_pkgs"
    
    clear
    lh_print_header "$(lh_msg 'AUDIT_REVIEW_FILTER_TITLE')"
    echo ""
    lh_msgln 'AUDIT_REVIEW_FILTER_DESC'
    echo ""
    lh_print_menu_item 1 "$(lh_msg 'AUDIT_REVIEW_FILTER_AUR' "$aur_pkgs")"
    lh_print_menu_item 2 "$(lh_msg 'AUDIT_REVIEW_FILTER_USER' "$user_pkgs")"
    lh_print_menu_item 3 "$(lh_msg 'AUDIT_REVIEW_FILTER_BASE' "$base_pkgs")"
    lh_print_menu_item 4 "$(lh_msg 'AUDIT_REVIEW_FILTER_ALL')"
    echo ""
    lh_print_menu_item 0 "$(lh_msg 'BACK')"
    
    local filter_choice
    read -r -p "$(lh_msg 'CHOOSE_OPTION') " filter_choice
    
    case "$filter_choice" in
        1) filter_mode="aur" ;;
        2) filter_mode="user" ;;
        3) filter_mode="base" ;;
        4) filter_mode="all" ;;
        0) lh_log_msg "DEBUG" "User cancelled review, returning"; return ;;
        *) lh_log_msg "DEBUG" "Invalid filter choice, returning"; return ;;
    esac
    lh_log_msg "DEBUG" "User selected filter mode: $filter_mode"
    
    local review_count=0
    while true; do
        stats=$(run_audit_helper "stats")
        
        local pending
        pending=$(echo "$stats" | python3 -c "import sys, json; print(json.load(sys.stdin)['pending'])")
        lh_log_msg "DEBUG" "Review loop iteration: pending=$pending, reviewed=$review_count"
        
        if [[ "$pending" -eq 0 ]]; then
            lh_log_msg "DEBUG" "All packages reviewed"
            lh_log_msg "INFO" "Package review completed: $review_count packages processed"
            lh_msgln 'AUDIT_REVIEW_COMPLETE'
            lh_press_any_key
            return
        fi
        
        local next_pkg
        next_pkg=$(run_audit_helper "next" "$filter_mode")
        
        if [[ "$next_pkg" == "null" ]]; then
            lh_log_msg "DEBUG" "No more packages in filter '$filter_mode'"
            lh_msgln 'AUDIT_REVIEW_FILTER_DONE'
            lh_press_any_key
            return
        fi
        
        local name ver mgr deps deps_count idx is_base groups install_date
        name=$(echo "$next_pkg" | python3 -c "import sys, json; print(json.load(sys.stdin)['name'])")
        ver=$(echo "$next_pkg" | python3 -c "import sys, json; print(json.load(sys.stdin)['version'])")
        mgr=$(echo "$next_pkg" | python3 -c "import sys, json; print(json.load(sys.stdin)['manager'])")
        deps_count=$(echo "$next_pkg" | python3 -c "import sys, json; d=json.load(sys.stdin)['dependencies']; print(len(d))")
        deps=$(echo "$next_pkg" | python3 -c "import sys, json; d=json.load(sys.stdin)['dependencies']; print(', '.join(d[:10]) + (' ...' if len(d) > 10 else '') if d else 'None')")
        idx=$(echo "$next_pkg" | python3 -c "import sys, json; print(json.load(sys.stdin)['index'])")
        is_base=$(echo "$next_pkg" | python3 -c "import sys, json; print(json.load(sys.stdin).get('is_base', False))")
        groups=$(echo "$next_pkg" | python3 -c "import sys, json; print(', '.join(json.load(sys.stdin).get('groups', [])))")
        install_date=$(echo "$next_pkg" | python3 -c "
import sys, json
data = json.load(sys.stdin)
date = data.get('install_date', '')
if not date:
    dt = data.get('install_datetime', '')
    if dt:
        date = dt[:10] if 'T' in dt else dt[:19]
print(date if date else 'Unknown')
")
        
        clear
        lh_print_header "$(lh_msg 'AUDIT_MENU_REVIEW' "$pending")"
        lh_log_msg "DEBUG" "Reviewing package: $name v$ver (manager=$mgr, is_base=$is_base, idx=$idx)"
        
        echo ""
        echo -e "${LH_COLOR_HEADER}$(lh_msg 'AUDIT_PKG_DETAILS' "$name")${LH_COLOR_RESET}"
        lh_msgln 'AUDIT_PKG_VERSION' "$ver"
        lh_msgln 'AUDIT_PKG_MANAGER' "$mgr"
        lh_msgln 'AUDIT_PKG_INSTALL_DATE' "$install_date"
        lh_msgln 'AUDIT_PKG_DEPS_COUNT' "$deps_count"
        lh_msgln 'AUDIT_PKG_DEPS' "$deps"
        [[ -n "$groups" ]] && lh_msgln 'AUDIT_PKG_GROUPS' "$groups"
        
        if [[ "$is_base" == "True" ]]; then
            echo -e "${LH_COLOR_WARNING}$(lh_msg 'AUDIT_PKG_IS_BASE')${LH_COLOR_RESET}"
        fi
        
        echo ""
        lh_msgln 'AUDIT_ACTION_PROMPT'
        lh_print_menu_item 1 "$(lh_msg 'AUDIT_ACTION_KEEP')"
        lh_print_menu_item 2 "$(lh_msg 'AUDIT_ACTION_DISCARD')"
        lh_print_menu_item 3 "$(lh_msg 'AUDIT_ACTION_SKIP')"
        lh_print_menu_item 4 "$(lh_msg 'AUDIT_ACTION_SKIP_ALL')"
        lh_print_menu_item 0 "$(lh_msg 'BACK')"
        
        local choice
        read -r -p "$(lh_msg 'CHOOSE_OPTION') " choice
        
        case "$choice" in
            1) 
                lh_log_msg "DEBUG" "User chose KEEP for package: $name"
                run_audit_helper "update" "$idx" "keep"
                ((review_count++))
                ;;
            2) 
                lh_log_msg "DEBUG" "User chose DISCARD for package: $name"
                run_audit_helper "update" "$idx" "discard"
                ((review_count++))
                ;;
            3) 
                lh_log_msg "DEBUG" "User chose SKIP for package: $name"
                run_audit_helper "update" "$idx" "skip"
                ((review_count++))
                ;;
            4) 
                lh_log_msg "DEBUG" "User chose SKIP ALL remaining packages"
                run_audit_helper "update" "$idx" "skip_all"
                ;;
            0) 
                lh_log_msg "DEBUG" "User exited review after $review_count packages"
                return 
                ;;
        esac
    done
}

function audit_restore() {
    lh_log_msg "DEBUG" "Entering audit_restore function"
    clear
    lh_print_header "$(lh_msg 'AUDIT_MENU_RESTORE')"
    lh_msgln 'AUDIT_RESTORE_CHECKING'
    
    # Update session activity for restore check - elevate to HIGH severity during package installation
    lh_update_module_session "$(lh_msg 'AUDIT_RESTORE_CHECKING')" "running" "${LH_BLOCK_FILESYSTEM_WRITE},${LH_BLOCK_SYSTEM_CRITICAL}" "HIGH"
    
    # Get restoration plan
    local plan
    plan=$(run_audit_helper "restore_plan")
    
    if echo "$plan" | grep -q '"error"'; then
        lh_log_msg "DEBUG" "No audit file found for restore"
        lh_msgln 'AUDIT_NO_FILE'
        lh_press_any_key
        return
    fi
    
    # Parse plan summary
    local total_phases total_packages native_count aur_count flatpak_count snap_count
    total_phases=$(echo "$plan" | python3 -c "import sys, json; print(json.load(sys.stdin)['summary']['total_phases'])")
    total_packages=$(echo "$plan" | python3 -c "import sys, json; print(json.load(sys.stdin)['summary']['total_packages'])")
    native_count=$(echo "$plan" | python3 -c "import sys, json; print(json.load(sys.stdin)['summary'].get('native_count', 0))")
    aur_count=$(echo "$plan" | python3 -c "import sys, json; print(json.load(sys.stdin)['summary'].get('aur_count', 0))")
    flatpak_count=$(echo "$plan" | python3 -c "import sys, json; print(json.load(sys.stdin)['summary'].get('flatpak_count', 0))")
    snap_count=$(echo "$plan" | python3 -c "import sys, json; print(json.load(sys.stdin)['summary'].get('snap_count', 0))")
    
    lh_log_msg "DEBUG" "Restore plan: phases=$total_phases, packages=$total_packages"
    
    if [[ "$total_packages" -eq 0 ]]; then
        lh_log_msg "DEBUG" "No packages to restore"
        lh_msgln 'AUDIT_RESTORE_NONE'
        lh_press_any_key
        return
    fi
    
    # Display plan summary
    echo ""
    lh_print_boxed_message --preset info \
        "$(lh_msg 'AUDIT_RESTORE_PLAN_TITLE')" \
        "$(lh_msg 'AUDIT_RESTORE_PLAN_PACKAGES' "$total_packages")" \
        "$(lh_msg 'AUDIT_RESTORE_PLAN_BREAKDOWN' "$native_count" "$aur_count" "$flatpak_count" "$snap_count")"
    
    echo ""
    lh_msgln 'AUDIT_RESTORE_PLAN_PHASES'
    
    # Show each phase
    echo "$plan" | python3 -c "
import sys, json
plan = json.load(sys.stdin)
for i, phase in enumerate(plan['phases'], 1):
    phase_id = phase['id']
    phase_name = phase['name']
    if 'packages' in phase:
        print(f'  {i}. {phase_name}: {len(phase[\"packages\"])} packages')
    elif 'keys' in phase:
        print(f'  {i}. {phase_name}: {len(phase[\"keys\"])} keys')
    elif 'action' in phase:
        print(f'  {i}. {phase_name}: {phase[\"action\"]}')
"
    
    echo ""
    if ! lh_confirm_action "$(lh_msg 'AUDIT_RESTORE_CONFIRM_START')"; then
        lh_log_msg "DEBUG" "User cancelled restore"
        return
    fi
    
    # Execute restoration phases
    local phase_count=0
    local -a failed_packages=()
    
    while IFS= read -r phase_json; do
        ((phase_count++))
        local phase_id phase_name
        phase_id=$(echo "$phase_json" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
        phase_name=$(echo "$phase_json" | python3 -c "import sys,json; print(json.load(sys.stdin)['name'])")
        
        lh_log_msg "INFO" "Starting restore phase $phase_count: $phase_name"
        lh_update_module_session "$(lh_msg 'AUDIT_RESTORE_PHASE' "$phase_name")" "running"
        
        echo ""
        echo -e "${LH_COLOR_HEADER}=== $(lh_msg 'AUDIT_RESTORE_PHASE' "$phase_name") ===${LH_COLOR_RESET}"
        
        case "$phase_id" in
            prerequisites)
                # Install base-devel and git
                local prereq_pkgs
                prereq_pkgs=$(echo "$phase_json" | python3 -c "import sys,json; print(' '.join([p['name'] for p in json.load(sys.stdin).get('packages', [])]))")
                if [[ -n "$prereq_pkgs" ]]; then
                    lh_msgln 'AUDIT_RESTORE_INSTALLING_PREREQS'
                    # shellcheck disable=SC2086
                    if ! $LH_SUDO_CMD pacman -S --noconfirm --needed $prereq_pkgs; then
                        lh_log_msg "WARN" "Failed to install some prerequisites"
                    fi
                fi
                ;;
            
            aur_helper)
                # Bootstrap AUR helper with user choice
                lh_msgln 'AUDIT_RESTORE_AUR_HELPER_NEEDED'
                if lh_install_aur_helper; then
                    lh_log_msg "INFO" "AUR helper installed: $LH_AUR_HELPER"
                else
                    lh_log_msg "ERROR" "Failed to install AUR helper"
                    lh_msgln 'AUDIT_RESTORE_AUR_HELPER_FAILED'
                fi
                ;;
            
            keys)
                # Import only required PGP keys
                local keys_json
                keys_json=$(echo "$phase_json" | python3 -c "import sys,json; import json as j; print(j.dumps(json.load(sys.stdin).get('keys', [])))")
                local key_count
                key_count=$(echo "$keys_json" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")
                
                lh_msgln 'AUDIT_RESTORE_IMPORTING_KEYS' "$key_count"
                
                while IFS='|' read -r fingerprint name pkg; do
                    [[ -z "$fingerprint" ]] && continue
                    lh_log_msg "DEBUG" "Importing key for $pkg: $fingerprint"
                    echo -e "  ${LH_COLOR_INFO}→ $name ($pkg)${LH_COLOR_RESET}"
                    if $LH_SUDO_CMD pacman-key --recv-keys "$fingerprint" 2>/dev/null; then
                        $LH_SUDO_CMD pacman-key --lsign-key "$fingerprint" 2>/dev/null
                    else
                        lh_log_msg "WARN" "Failed to import key: $fingerprint"
                    fi
                done < <(echo "$keys_json" | python3 -c "
import sys, json
keys = json.load(sys.stdin)
for k in keys:
    print(f\"{k.get('fingerprint', '')}|{k.get('name', '')}|{k.get('package', '')}\")
")
                ;;
            
            native)
                # Install native system packages using library function
                local native_pkgs
                native_pkgs=$(echo "$phase_json" | python3 -c "import sys,json; print(' '.join([p['name'] for p in json.load(sys.stdin).get('packages', [])]))")
                local batch_size
                batch_size=$(echo "$phase_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('batch_size', 50))")
                
                lh_msgln 'AUDIT_RESTORE_INSTALLING_NATIVE' "$native_count"
                if ! lh_install_packages_batch "$native_pkgs" "$LH_PKG_MANAGER" "$batch_size"; then
                    failed_packages+=("${LH_FAILED_PACKAGES[@]}")
                fi
                ;;
            
            aur)
                # Install AUR packages
                local aur_helper
                aur_helper=$(lh_detect_aur_helper)
                if [[ -z "$aur_helper" ]]; then
                    lh_log_msg "ERROR" "No AUR helper available for AUR packages"
                    lh_msgln 'AUDIT_RESTORE_NO_AUR_HELPER'
                    continue
                fi
                
                local aur_pkgs
                aur_pkgs=$(echo "$phase_json" | python3 -c "import sys,json; print(' '.join([p['name'] for p in json.load(sys.stdin).get('packages', [])]))")
                
                lh_msgln 'AUDIT_RESTORE_INSTALLING_AUR' "$aur_count" "$aur_helper"
                # Use smaller batch for AUR to handle build failures better
                if ! lh_install_packages_batch "$aur_pkgs" "$aur_helper" "5"; then
                    failed_packages+=("${LH_FAILED_PACKAGES[@]}")
                fi
                ;;
            
            flatpak)
                # Install Flatpak apps
                lh_msgln 'AUDIT_RESTORE_INSTALLING_FLATPAK' "$flatpak_count"
                
                while IFS= read -r pkg_name; do
                    [[ -z "$pkg_name" ]] && continue
                    echo -e "  ${LH_COLOR_INFO}→ $pkg_name${LH_COLOR_RESET}"
                    if ! flatpak install -y "$pkg_name" 2>/dev/null; then
                        failed_packages+=("flatpak:$pkg_name")
                        lh_log_msg "WARN" "Failed to install Flatpak: $pkg_name"
                    fi
                done < <(echo "$phase_json" | python3 -c "
import sys, json
pkgs = json.load(sys.stdin).get('packages', [])
for p in pkgs:
    print(p['name'])
")
                ;;
            
            snap)
                # Install Snap packages
                lh_msgln 'AUDIT_RESTORE_INSTALLING_SNAP' "$snap_count"
                
                while IFS= read -r pkg_name; do
                    [[ -z "$pkg_name" ]] && continue
                    echo -e "  ${LH_COLOR_INFO}→ $pkg_name${LH_COLOR_RESET}"
                    if ! $LH_SUDO_CMD snap install "$pkg_name" 2>/dev/null; then
                        failed_packages+=("snap:$pkg_name")
                        lh_log_msg "WARN" "Failed to install Snap: $pkg_name"
                    fi
                done < <(echo "$phase_json" | python3 -c "
import sys, json
pkgs = json.load(sys.stdin).get('packages', [])
for p in pkgs:
    print(p['name'])
")
                ;;
        esac
        
    done < <(echo "$plan" | python3 -c "
import sys, json
plan = json.load(sys.stdin)
for phase in plan['phases']:
    print(json.dumps(phase))
")
    
    # Summary
    echo ""
    if [[ ${#failed_packages[@]} -gt 0 ]]; then
        lh_log_msg "WARN" "Restore completed with ${#failed_packages[@]} failed packages"
        lh_print_boxed_message --preset warning \
            "$(lh_msg 'AUDIT_RESTORE_COMPLETE_WITH_ERRORS')" \
            "$(lh_msg 'AUDIT_RESTORE_FAILED_COUNT' "${#failed_packages[@]}")"
    else
        lh_log_msg "INFO" "Package restore completed successfully"
        echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'AUDIT_RESTORE_COMPLETE')${LH_COLOR_RESET}"
    fi
    
    lh_press_any_key
}

function audit_menu() {
    lh_log_msg "DEBUG" "Entering audit_menu main loop"
    while true; do
        clear
        local stats
        stats=$(run_audit_helper "stats")
        local pending=0
        local has_file=false
        
        if ! echo "$stats" | grep -q "no_file"; then
            has_file=true
            pending=$(echo "$stats" | python3 -c "import sys, json; print(json.load(sys.stdin)['pending'])")
            lh_log_msg "DEBUG" "Audit file exists: pending=$pending packages"
        else
            lh_log_msg "DEBUG" "No audit file found"
        fi
        
        lh_print_header "$(lh_msg 'AUDIT_MENU_TITLE')"
        
        lh_print_menu_item 1 "$(lh_msg 'AUDIT_MENU_SCAN')"
        
        if [[ "$has_file" == "true" ]]; then
            lh_print_menu_item 2 "$(lh_msg 'AUDIT_MENU_REVIEW' "$pending")"
            lh_print_menu_item 3 "$(lh_msg 'AUDIT_MENU_RESTORE')"
            lh_print_menu_item 4 "$(lh_msg 'AUDIT_MENU_DISCARD')"
        fi
        
        echo ""
        lh_print_menu_item 0 "$(lh_msg 'EXIT')"
        
        local choice
        read -r -p "$(lh_msg 'CHOOSE_OPTION') " choice
        lh_log_msg "DEBUG" "Main menu user choice: '$choice'"
        
        case "$choice" in
            1) audit_scan ;;
            2) 
                if [[ "$has_file" == "true" ]]; then
                    audit_review
                fi
                ;;
            3)
                if [[ "$has_file" == "true" ]]; then
                    audit_restore
                fi
                ;;
            4)
                if [[ "$has_file" == "true" ]]; then
                    lh_log_msg "DEBUG" "User discarding audit file"
                    run_audit_helper "discard"
                    lh_log_msg "INFO" "Audit file discarded by user"
                    lh_msgln 'AUDIT_REVIEW_DISCARDED'
                    sleep 1
                fi
                ;;
            0) 
                lh_log_msg "DEBUG" "User exiting package audit module"
                break 
                ;;
        esac
    done
}

# Start the module
# In submodule mode, we don't register a new session (parent already has one)
if [[ "$AUDIT_SUBMODULE_MODE" == "false" ]]; then
    lh_log_msg "DEBUG" "Package audit module starting (standalone mode)"
    lh_log_active_sessions_debug "$(lh_msg 'AUDIT_MODULE_NAME')"
    lh_begin_module_session "mod_package_audit" "$(lh_msg 'AUDIT_MODULE_NAME')" "$(lh_msg 'LIB_SESSION_ACTIVITY_MENU')" "${LH_BLOCK_FILESYSTEM_WRITE}" "MEDIUM"
    lh_log_msg "INFO" "Package audit module initialized"
    audit_menu
    lh_log_msg "DEBUG" "Package audit module exiting"
else
    lh_log_msg "DEBUG" "Package audit module starting (submodule mode)"
    lh_update_module_session "$(lh_msg 'AUDIT_MODULE_NAME')" "running" "${LH_BLOCK_FILESYSTEM_WRITE}"
    audit_menu
    lh_log_msg "DEBUG" "Package audit submodule returning to parent"
fi
