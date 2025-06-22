#!/bin/bash
#
# modules/mod_docker_setup.sh
# Copyright (c) 2025 wuldorf
# SPDX-License-Identifier: MIT
#
# This script is part of the 'little-linux-helper' collection.
# Licensed under the MIT License. See the LICENSE file in the project root for more information.
#
# Module for Docker and Docker Compose installation and verification

# Load common library
# Use BASH_SOURCE to get the correct path when sourced
source "$(dirname "${BASH_SOURCE[0]}")/../lib/lib_common.sh"

# Complete initialization when run directly (not via help_master.sh)
if [[ -z "${LH_INITIALIZED:-}" ]]; then
    lh_load_general_config        # Load general config first for log level
    lh_initialize_logging
    lh_detect_package_manager
    lh_finalize_initialization
    export LH_INITIALIZED=1
fi

# Load translations if not already loaded
if [[ -z "${MSG[DOCKER_SETUP_CHECK_TITLE]:-}" ]]; then
    lh_load_language_module "common"
    lh_load_language_module "docker_setup"
    lh_load_language_module "lib"
fi

# Function to check if Docker is installed
function check_docker_installation() {
    lh_print_header "$(lh_msg 'DOCKER_SETUP_CHECK_TITLE')"
    
    local docker_installed=false
    local docker_compose_installed=false
    local docker_compose_command=""
    
    # Check Docker
    if command -v docker >/dev/null 2>&1; then
        docker_installed=true
        lh_log_msg "INFO" "$(lh_msg 'DOCKER_SETUP_DOCKER_FOUND')"
        echo -e "${LH_COLOR_SUCCESS}✓ $(lh_msg 'DOCKER_SETUP_DOCKER_FOUND')${LH_COLOR_RESET}"
        
        # Show Docker version
        local docker_version=$(docker --version 2>/dev/null)
        if [ $? -eq 0 ]; then
            echo -e "  ${LH_COLOR_INFO}$docker_version${LH_COLOR_RESET}"
        fi
    else
        lh_log_msg "WARN" "$(lh_msg 'DOCKER_SETUP_DOCKER_NOT_FOUND')"
        echo -e "${LH_COLOR_ERROR}✗ $(lh_msg 'DOCKER_SETUP_DOCKER_NOT_FOUND')${LH_COLOR_RESET}"
    fi
    
    # Check Docker Compose (new syntax)
    if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
        docker_compose_installed=true
        docker_compose_command="docker compose"
        lh_log_msg "INFO" "$(lh_msg 'DOCKER_SETUP_COMPOSE_FOUND') (docker compose)"
        echo -e "${LH_COLOR_SUCCESS}✓ $(lh_msg 'DOCKER_SETUP_COMPOSE_FOUND') (docker compose)${LH_COLOR_RESET}"
        
        # Show Docker Compose version
        local compose_version=$(docker compose version 2>/dev/null)
        if [ $? -eq 0 ]; then
            echo -e "  ${LH_COLOR_INFO}$compose_version${LH_COLOR_RESET}"
        fi
    # Check Docker Compose (old syntax)
    elif command -v docker-compose >/dev/null 2>&1; then
        docker_compose_installed=true
        docker_compose_command="docker-compose"
        lh_log_msg "INFO" "$(lh_msg 'DOCKER_SETUP_COMPOSE_FOUND') (docker-compose)"
        echo -e "${LH_COLOR_SUCCESS}✓ $(lh_msg 'DOCKER_SETUP_COMPOSE_FOUND') (docker-compose)${LH_COLOR_RESET}"
        
        # Show Docker Compose version
        local compose_version=$(docker-compose --version 2>/dev/null)
        if [ $? -eq 0 ]; then
            echo -e "  ${LH_COLOR_INFO}$compose_version${LH_COLOR_RESET}"
        fi
    else
        lh_log_msg "WARN" "$(lh_msg 'DOCKER_SETUP_COMPOSE_NOT_FOUND')"
        echo -e "${LH_COLOR_ERROR}✗ $(lh_msg 'DOCKER_SETUP_COMPOSE_NOT_FOUND')${LH_COLOR_RESET}"
    fi
    
    echo ""
    
    # Offer installation if needed
    if [ "$docker_installed" = false ] || [ "$docker_compose_installed" = false ]; then
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'DOCKER_SETUP_MISSING_COMPONENTS')${LH_COLOR_RESET}"
        echo ""
        
        if lh_confirm_action "$(lh_msg 'DOCKER_SETUP_INSTALL_PROMPT')" "n"; then
            install_docker_components "$docker_installed" "$docker_compose_installed"
        else
            lh_log_msg "INFO" "$(lh_msg 'DOCKER_SETUP_INSTALL_DECLINED')"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_SETUP_INSTALL_DECLINED')${LH_COLOR_RESET}"
        fi
    else
        echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DOCKER_SETUP_ALL_INSTALLED')${LH_COLOR_RESET}"
        
        # Check Docker service status
        check_docker_service_status
    fi
}

# Function for installing Docker components
function install_docker_components() {
    local docker_installed="$1"
    local docker_compose_installed="$2"
    
    lh_print_header "$(lh_msg 'DOCKER_SETUP_INSTALL_TITLE')"
    
    # Install Docker if needed
    if [ "$docker_installed" = false ]; then
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_SETUP_INSTALLING_DOCKER')${LH_COLOR_RESET}"
        install_docker
        if [ $? -eq 0 ]; then
            echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DOCKER_SETUP_DOCKER_INSTALLED')${LH_COLOR_RESET}"
            docker_installed=true
        else
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'DOCKER_SETUP_DOCKER_INSTALL_FAILED')${LH_COLOR_RESET}"
            return 1
        fi
    fi
    
    # Install Docker Compose if needed
    if [ "$docker_compose_installed" = false ]; then
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_SETUP_INSTALLING_COMPOSE')${LH_COLOR_RESET}"
        install_docker_compose
        if [ $? -eq 0 ]; then
            echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DOCKER_SETUP_COMPOSE_INSTALLED')${LH_COLOR_RESET}"
        else
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'DOCKER_SETUP_COMPOSE_INSTALL_FAILED')${LH_COLOR_RESET}"
        fi
    fi
    
    # Post-Installation Setup
    if [ "$docker_installed" = true ]; then
        post_install_setup
    fi
}

# Function for Docker installation
function install_docker() {
    lh_log_msg "INFO" "$(lh_msg 'DOCKER_SETUP_STARTING_DOCKER_INSTALL')"
    
    case "$LH_PKG_MANAGER" in
        "pacman"|"yay")
            echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_SETUP_INSTALL_ARCH')${LH_COLOR_RESET}"
            $LH_SUDO_CMD pacman -S --noconfirm docker
            ;;
        "apt")
            echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_SETUP_INSTALL_DEBIAN')${LH_COLOR_RESET}"
            $LH_SUDO_CMD apt update
            $LH_SUDO_CMD apt install -y docker.io
            ;;
        "dnf")
            echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_SETUP_INSTALL_FEDORA')${LH_COLOR_RESET}"
            $LH_SUDO_CMD dnf install -y docker
            ;;
        "zypper")
            echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_SETUP_INSTALL_OPENSUSE')${LH_COLOR_RESET}"
            $LH_SUDO_CMD zypper install -y docker
            ;;
        *)
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'DOCKER_SETUP_UNSUPPORTED_PKG_MANAGER'): $LH_PKG_MANAGER${LH_COLOR_RESET}"
            lh_log_msg "ERROR" "$(lh_msg 'DOCKER_SETUP_UNSUPPORTED_PKG_MANAGER'): $LH_PKG_MANAGER"
            echo -e "${LH_COLOR_WARNING}$(lh_msg 'DOCKER_SETUP_MANUAL_INSTALL_HINT')${LH_COLOR_RESET}"
            return 1
            ;;
    esac
    
    return $?
}

# Function for Docker Compose installation
function install_docker_compose() {
    lh_log_msg "INFO" "$(lh_msg 'DOCKER_SETUP_STARTING_COMPOSE_INSTALL')"
    
    # First check if Docker Compose Plugin is available (newer method)
    if command -v docker >/dev/null 2>&1; then
        case "$LH_PKG_MANAGER" in
            "pacman"|"yay")
                echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_SETUP_INSTALL_COMPOSE_ARCH')${LH_COLOR_RESET}"
                $LH_SUDO_CMD pacman -S --noconfirm docker-compose
                ;;
            "apt")
                echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_SETUP_INSTALL_COMPOSE_DEBIAN')${LH_COLOR_RESET}"
                $LH_SUDO_CMD apt update
                $LH_SUDO_CMD apt install -y docker-compose-plugin docker-compose
                ;;
            "dnf")
                echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_SETUP_INSTALL_COMPOSE_FEDORA')${LH_COLOR_RESET}"
                $LH_SUDO_CMD dnf install -y docker-compose
                ;;
            "zypper")
                echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_SETUP_INSTALL_COMPOSE_OPENSUSE')${LH_COLOR_RESET}"
                $LH_SUDO_CMD zypper install -y docker-compose
                ;;
            *)
                echo -e "${LH_COLOR_WARNING}$(lh_msg 'DOCKER_SETUP_COMPOSE_MANUAL_INSTALL')${LH_COLOR_RESET}"
                install_docker_compose_manual
                return $?
                ;;
        esac
    else
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'DOCKER_SETUP_DOCKER_REQUIRED_FOR_COMPOSE')${LH_COLOR_RESET}"
        return 1
    fi
    
    return $?
}

# Function for manual Docker Compose installation
function install_docker_compose_manual() {
    echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_SETUP_COMPOSE_DOWNLOAD')${LH_COLOR_RESET}"
    
    # Get latest version from GitHub
    local compose_version
    if command -v curl >/dev/null 2>&1; then
        compose_version=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d'"' -f4)
    elif command -v wget >/dev/null 2>&1; then
        compose_version=$(wget -qO- https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d'"' -f4)
    else
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'DOCKER_SETUP_NO_DOWNLOAD_TOOL')${LH_COLOR_RESET}"
        return 1
    fi
    
    if [ -z "$compose_version" ]; then
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'DOCKER_SETUP_VERSION_DETECTION_FAILED')${LH_COLOR_RESET}"
        compose_version="v2.24.6"  # Fallback version
    fi
    
    echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_SETUP_DOWNLOADING_VERSION'): $compose_version${LH_COLOR_RESET}"
    
    # Download and installation
    local download_url="https://github.com/docker/compose/releases/download/${compose_version}/docker-compose-$(uname -s)-$(uname -m)"
    
    if command -v curl >/dev/null 2>&1; then
        $LH_SUDO_CMD curl -L "$download_url" -o /usr/local/bin/docker-compose
    elif command -v wget >/dev/null 2>&1; then
        $LH_SUDO_CMD wget -O /usr/local/bin/docker-compose "$download_url"
    else
        return 1
    fi
    
    if [ $? -eq 0 ]; then
        $LH_SUDO_CMD chmod +x /usr/local/bin/docker-compose
        echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DOCKER_SETUP_COMPOSE_DOWNLOAD_SUCCESS')${LH_COLOR_RESET}"
        return 0
    else
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'DOCKER_SETUP_COMPOSE_DOWNLOAD_FAILED')${LH_COLOR_RESET}"
        return 1
    fi
}

# Function for post-installation setup
function post_install_setup() {
    lh_print_header "$(lh_msg 'DOCKER_SETUP_POST_INSTALL_TITLE')"
    
    # Enable and start Docker service
    echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_SETUP_ENABLING_SERVICE')${LH_COLOR_RESET}"
    
    if command -v systemctl >/dev/null 2>&1; then
        $LH_SUDO_CMD systemctl enable docker
        $LH_SUDO_CMD systemctl start docker
        
        if systemctl is-active --quiet docker; then
            echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DOCKER_SETUP_SERVICE_STARTED')${LH_COLOR_RESET}"
        else
            echo -e "${LH_COLOR_WARNING}$(lh_msg 'DOCKER_SETUP_SERVICE_START_FAILED')${LH_COLOR_RESET}"
        fi
    fi
    
    # Add user to Docker group
    if [ -n "$SUDO_USER" ]; then
        local target_user="$SUDO_USER"
    elif [ -n "$USER" ] && [ "$USER" != "root" ]; then
        local target_user="$USER"
    else
        local target_user=$(whoami)
    fi
    
    if [ "$target_user" != "root" ]; then
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_SETUP_ADDING_USER_TO_GROUP'): $target_user${LH_COLOR_RESET}"
        $LH_SUDO_CMD usermod -aG docker "$target_user"
        
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'DOCKER_SETUP_LOGOUT_REQUIRED')${LH_COLOR_RESET}"
    fi
}

# Function for checking Docker service status
function check_docker_service_status() {
    echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_SETUP_CHECKING_SERVICE')${LH_COLOR_RESET}"
    
    if command -v systemctl >/dev/null 2>&1; then
        if systemctl is-active --quiet docker; then
            echo -e "${LH_COLOR_SUCCESS}✓ $(lh_msg 'DOCKER_SETUP_SERVICE_RUNNING')${LH_COLOR_RESET}"
        else
            echo -e "${LH_COLOR_WARNING}⚠ $(lh_msg 'DOCKER_SETUP_SERVICE_NOT_RUNNING')${LH_COLOR_RESET}"
            
            if lh_confirm_action "$(lh_msg 'DOCKER_SETUP_START_SERVICE_PROMPT')" "y"; then
                $LH_SUDO_CMD systemctl start docker
                if systemctl is-active --quiet docker; then
                    echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DOCKER_SETUP_SERVICE_STARTED')${LH_COLOR_RESET}"
                else
                    echo -e "${LH_COLOR_ERROR}$(lh_msg 'DOCKER_SETUP_SERVICE_START_FAILED')${LH_COLOR_RESET}"
                fi
            fi
        fi
        
        if systemctl is-enabled --quiet docker; then
            echo -e "${LH_COLOR_SUCCESS}✓ $(lh_msg 'DOCKER_SETUP_SERVICE_ENABLED')${LH_COLOR_RESET}"
        else
            echo -e "${LH_COLOR_WARNING}⚠ $(lh_msg 'DOCKER_SETUP_SERVICE_NOT_ENABLED')${LH_COLOR_RESET}"
            
            if lh_confirm_action "$(lh_msg 'DOCKER_SETUP_ENABLE_SERVICE_PROMPT')" "y"; then
                $LH_SUDO_CMD systemctl enable docker
                echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DOCKER_SETUP_SERVICE_ENABLED_SUCCESS')${LH_COLOR_RESET}"
            fi
        fi
    else
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'DOCKER_SETUP_NO_SYSTEMCTL')${LH_COLOR_RESET}"
    fi
}

# Main function
function main() {
    lh_print_header "$(lh_msg 'DOCKER_SETUP_MAIN_TITLE')"
    
    echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_SETUP_DESCRIPTION')${LH_COLOR_RESET}"
    echo ""
    
    check_docker_installation
    
    echo ""
    lh_log_msg "INFO" "$(lh_msg 'DOCKER_SETUP_MODULE_COMPLETED')"
}

# Execute module
main
