#!/bin/bash
#
# lang/en/docker_setup.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: MIT
#
# This script is part of the 'little-linux-helper' collection.
# Licensed under the MIT License. See the LICENSE file in the project root for more information.
#
# English translations for Docker Setup Module

[[ ! -v MSG_EN ]] && declare -A MSG_EN

# Docker Setup Main
MSG_EN[DOCKER_SETUP_TITLE]="Docker Installation & Setup"
MSG_EN[DOCKER_SETUP_CHECK_TITLE]="Check Docker Installation"

# Docker Installation Status
MSG_EN[DOCKER_SETUP_DOCKER_FOUND]="Docker is installed"
MSG_EN[DOCKER_SETUP_DOCKER_NOT_FOUND]="Docker is not installed"
MSG_EN[DOCKER_SETUP_COMPOSE_FOUND]="Docker Compose is available"
MSG_EN[DOCKER_SETUP_DOCKER_COMPOSE_FOUND]="Docker Compose is available"
MSG_EN[DOCKER_SETUP_COMPOSE_NOT_FOUND]="Docker Compose is not available"
MSG_EN[DOCKER_SETUP_DOCKER_COMPOSE_NOT_FOUND]="Docker Compose is not available"
MSG_EN[DOCKER_SETUP_DOCKER_VERSION]="Docker Version:"
MSG_EN[DOCKER_SETUP_COMPOSE_VERSION]="Docker Compose Version:"

# Docker Service Status
MSG_EN[DOCKER_SETUP_SERVICE_RUNNING]="Docker service is running"
MSG_EN[DOCKER_SETUP_SERVICE_NOT_RUNNING]="Docker service is not running"
MSG_EN[DOCKER_SETUP_SERVICE_ENABLED]="Docker service is enabled (autostart)"
MSG_EN[DOCKER_SETUP_SERVICE_DISABLED]="Docker service is disabled"

# Installation
MSG_EN[DOCKER_SETUP_INSTALL_TITLE]="Docker Installation"
MSG_EN[DOCKER_SETUP_INSTALL_DOCKER]="Install Docker"
MSG_EN[DOCKER_SETUP_INSTALL_COMPOSE]="Install Docker Compose"
MSG_EN[DOCKER_SETUP_INSTALL_BOTH]="Install Docker and Docker Compose"
MSG_EN[DOCKER_SETUP_INSTALL_SUCCESS]="Installation successful"
MSG_EN[DOCKER_SETUP_INSTALL_FAILED]="Installation failed"

# Operating System Detection
MSG_EN[DOCKER_SETUP_DETECTING_OS]="Detecting operating system..."
MSG_EN[DOCKER_SETUP_OS_DETECTED]="Operating system detected: %s"
MSG_EN[DOCKER_SETUP_OS_UNSUPPORTED]="Unsupported operating system"
MSG_EN[DOCKER_SETUP_DISTRO_SPECIFIC]="Using distribution-specific installation"

# Services
MSG_EN[DOCKER_SETUP_SERVICE_START]="Start Docker service"
MSG_EN[DOCKER_SETUP_SERVICE_ENABLE]="Enable Docker service"
MSG_EN[DOCKER_SETUP_SERVICE_STATUS]="Docker service status"

# User Groups
MSG_EN[DOCKER_SETUP_USER_GROUP]="Add user to docker group"
MSG_EN[DOCKER_SETUP_USER_ADDED]="User added to docker group"
MSG_EN[DOCKER_SETUP_USER_LOGOUT_REQUIRED]="Please log out and log back in for changes to take effect"

# Extended Menu Options
MSG_EN[DOCKER_SETUP_MENU_INSTALL_DOCKER]="Install Docker only"
MSG_EN[DOCKER_SETUP_MENU_INSTALL_COMPOSE]="Install Docker Compose only"
MSG_EN[DOCKER_SETUP_MENU_INSTALL_BOTH]="Install Docker and Docker Compose"
MSG_EN[DOCKER_SETUP_MENU_UNINSTALL]="Uninstall Docker"
MSG_EN[DOCKER_SETUP_MENU_SERVICE_MANAGE]="Manage Docker service"

# Uninstallation
MSG_EN[DOCKER_SETUP_UNINSTALL_TITLE]="Docker Uninstallation"
MSG_EN[DOCKER_SETUP_UNINSTALL_CONFIRM]="Are you sure you want to uninstall Docker?"
MSG_EN[DOCKER_SETUP_UNINSTALL_SUCCESS]="Docker successfully uninstalled"
MSG_EN[DOCKER_SETUP_UNINSTALL_FAILED]="Uninstallation failed"

# Errors and Warnings
MSG_EN[DOCKER_SETUP_ERROR_PERMISSION]="Permission denied. Are you root or do you have sudo privileges?"
MSG_EN[DOCKER_SETUP_ERROR_NETWORK]="Network error. Please check your internet connection."
MSG_EN[DOCKER_SETUP_WARNING_EXPERIMENTAL]="Warning: This installation is experimental"
MSG_EN[DOCKER_SETUP_WARNING_BETA]="Warning: This is a beta version"

# Version Info
MSG_EN[DOCKER_SETUP_VERSION_DOCKER]="Docker Version: %s"
MSG_EN[DOCKER_SETUP_VERSION_COMPOSE]="Docker Compose Version: %s"
MSG_EN[DOCKER_SETUP_VERSION_CHECK]="Check versions"

# Additional missing translations for Docker Setup

# Installation and prompts
MSG_EN[DOCKER_SETUP_MISSING_COMPONENTS]="Missing Docker components detected"
MSG_EN[DOCKER_SETUP_INSTALL_PROMPT]="Would you like to install the missing components?"
MSG_EN[DOCKER_SETUP_INSTALL_DECLINED]="Installation declined"
MSG_EN[DOCKER_SETUP_ALL_INSTALLED]="All Docker components are installed"

# Installation process
MSG_EN[DOCKER_SETUP_INSTALLING_DOCKER]="Installing Docker..."
MSG_EN[DOCKER_SETUP_DOCKER_INSTALLED]="Docker successfully installed"
MSG_EN[DOCKER_SETUP_DOCKER_INSTALL_FAILED]="Docker installation failed"
MSG_EN[DOCKER_SETUP_INSTALLING_COMPOSE]="Installing Docker Compose..."
MSG_EN[DOCKER_SETUP_COMPOSE_INSTALLED]="Docker Compose successfully installed"
MSG_EN[DOCKER_SETUP_COMPOSE_INSTALL_FAILED]="Docker Compose installation failed"

# Installation details
MSG_EN[DOCKER_SETUP_STARTING_DOCKER_INSTALL]="Starting Docker installation"
MSG_EN[DOCKER_SETUP_INSTALL_ARCH]="Installing Docker for Arch Linux"
MSG_EN[DOCKER_SETUP_INSTALL_DEBIAN]="Installing Docker for Debian/Ubuntu"
MSG_EN[DOCKER_SETUP_INSTALL_FEDORA]="Installing Docker for Fedora"
MSG_EN[DOCKER_SETUP_INSTALL_OPENSUSE]="Installing Docker for openSUSE"
MSG_EN[DOCKER_SETUP_UNSUPPORTED_PKG_MANAGER]="Unsupported package manager"
MSG_EN[DOCKER_SETUP_MANUAL_INSTALL_HINT]="Please install Docker manually from https://docs.docker.com/get-docker/"

# Docker Compose installation details
MSG_EN[DOCKER_SETUP_STARTING_COMPOSE_INSTALL]="Starting Docker Compose installation"
MSG_EN[DOCKER_SETUP_INSTALL_COMPOSE_ARCH]="Installing Docker Compose for Arch Linux"
MSG_EN[DOCKER_SETUP_INSTALL_COMPOSE_DEBIAN]="Installing Docker Compose for Debian/Ubuntu"
MSG_EN[DOCKER_SETUP_INSTALL_COMPOSE_FEDORA]="Installing Docker Compose for Fedora"
MSG_EN[DOCKER_SETUP_INSTALL_COMPOSE_OPENSUSE]="Installing Docker Compose for openSUSE"
MSG_EN[DOCKER_SETUP_COMPOSE_MANUAL_INSTALL]="Attempting manual Docker Compose installation"
MSG_EN[DOCKER_SETUP_DOCKER_REQUIRED_FOR_COMPOSE]="Docker must be installed before Docker Compose can be installed"

# Manual installation
MSG_EN[DOCKER_SETUP_COMPOSE_DOWNLOAD]="Downloading Docker Compose"
MSG_EN[DOCKER_SETUP_NO_DOWNLOAD_TOOL]="No download tool (curl or wget) available"
MSG_EN[DOCKER_SETUP_VERSION_DETECTION_FAILED]="Version detection failed, using fallback version"
MSG_EN[DOCKER_SETUP_DOWNLOADING_VERSION]="Downloading version"
MSG_EN[DOCKER_SETUP_COMPOSE_DOWNLOAD_SUCCESS]="Docker Compose successfully downloaded"
MSG_EN[DOCKER_SETUP_COMPOSE_DOWNLOAD_FAILED]="Docker Compose download failed"

# Post-installation
MSG_EN[DOCKER_SETUP_POST_INSTALL_TITLE]="Post-Installation Setup"
MSG_EN[DOCKER_SETUP_ENABLING_SERVICE]="Enabling and starting Docker service"
MSG_EN[DOCKER_SETUP_SERVICE_STARTED]="Docker service successfully started"
MSG_EN[DOCKER_SETUP_SERVICE_START_FAILED]="Docker service could not be started"
MSG_EN[DOCKER_SETUP_ADDING_USER_TO_GROUP]="Adding user to docker group"
MSG_EN[DOCKER_SETUP_LOGOUT_REQUIRED]="Please log out and log back in for the group changes to take effect."

# Service management
MSG_EN[DOCKER_SETUP_CHECKING_SERVICE]="Checking Docker service status"
MSG_EN[DOCKER_SETUP_SERVICE_NOT_ENABLED]="Docker service is not enabled (no autostart)"
MSG_EN[DOCKER_SETUP_START_SERVICE_PROMPT]="Start Docker service now?"
MSG_EN[DOCKER_SETUP_ENABLE_SERVICE_PROMPT]="Enable Docker service for autostart?"
MSG_EN[DOCKER_SETUP_SERVICE_ENABLED_SUCCESS]="Docker service successfully enabled"
MSG_EN[DOCKER_SETUP_NO_SYSTEMCTL]="systemctl not available"

# Main module
MSG_EN[DOCKER_SETUP_MAIN_TITLE]="Docker Installation & Setup"
MSG_EN[DOCKER_SETUP_DESCRIPTION]="This module checks your Docker installation and can install missing components"
MSG_EN[DOCKER_SETUP_MODULE_COMPLETED]="Docker Setup module completed"
