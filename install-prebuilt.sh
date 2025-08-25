#!/bin/bash
#
# install-prebuilt.sh
# Installation script for pre-built Little Linux Helper GUI releases
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: MIT
#
# This script downloads and installs the latest pre-built release
# No Node.js/npm required - everything is ready to run!

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# GitHub repository information
GITHUB_USER="maschkef"
GITHUB_REPO="little-linux-helper"
INSTALL_DIR="/opt/little-linux-helper-gui"

echo -e "${BLUE}=== Little Linux Helper GUI - Pre-built Installation ===${NC}"
echo -e "${BLUE}This will install the GUI component using pre-built releases${NC}"
echo

# Function to detect architecture
detect_architecture() {
    local arch
    arch=$(uname -m)
    
    case "$arch" in
        x86_64|amd64)
            echo "amd64"
            ;;
        aarch64|arm64)
            echo "arm64"
            ;;
        armv7l|armhf)
            echo "armv7"
            ;;
        i386|i686)
            echo "i386"
            ;;
        *)
            echo -e "${RED}❌ Unsupported architecture: $arch${NC}" >&2
            echo -e "${YELLOW}Supported architectures: x86_64, aarch64, armv7l${NC}" >&2
            exit 1
            ;;
    esac
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}❌ This script must be run as root for system installation${NC}" >&2
        echo -e "${YELLOW}💡 Run: sudo $0${NC}" >&2
        exit 1
    fi
}

# Function to get latest release info (including pre-releases)
get_latest_release() {
    local api_url="https://api.github.com/repos/$GITHUB_USER/$GITHUB_REPO/releases"
    local release_info
    
    echo -e "${BLUE}🔍 Checking for latest release (including pre-releases)...${NC}"
    
    if command -v curl >/dev/null 2>&1; then
        release_info=$(curl -s "$api_url")
    elif command -v wget >/dev/null 2>&1; then
        release_info=$(wget -qO- "$api_url")
    else
        echo -e "${RED}❌ Neither curl nor wget found. Please install one of them.${NC}" >&2
        exit 1
    fi
    
    # Check if API request was successful
    if echo "$release_info" | grep -q '"message": "Not Found"'; then
        echo -e "${RED}❌ No releases found for this repository.${NC}" >&2
        echo -e "${YELLOW}💡 Please check manually: https://github.com/$GITHUB_USER/$GITHUB_REPO/releases${NC}" >&2
        echo -e "${YELLOW}💡 Make sure you have published at least one release.${NC}" >&2
        exit 1
    fi
    
    # Extract tag name and download URL from the first (most recent) release
    local tag_name=$(echo "$release_info" | grep -m1 '"tag_name"' | cut -d'"' -f4)
    local download_url=$(echo "$release_info" | grep -m1 '"browser_download_url".*little-linux-helper-gui-'$1'\.tar\.gz"' | cut -d'"' -f4)
    
    if [ -z "$tag_name" ] || [ -z "$download_url" ]; then
        echo -e "${RED}❌ Could not find release information for architecture: $1${NC}" >&2
        echo -e "${YELLOW}💡 Please check manually: https://github.com/$GITHUB_USER/$GITHUB_REPO/releases${NC}" >&2
        exit 1
    fi
    
    echo -e "${GREEN}✅ Found release: $tag_name${NC}"
    echo "$download_url"
}

# Function to download and extract
download_and_install() {
    local download_url="$1"
    local arch="$2"
    local temp_dir="/tmp/little-linux-helper-gui-install"
    local archive_name="little-linux-helper-gui-$arch.tar.gz"
    
    echo -e "${BLUE}📥 Downloading release...${NC}"
    
    # Clean up any existing temp directory
    rm -rf "$temp_dir"
    mkdir -p "$temp_dir"
    cd "$temp_dir"
    
    # Download
    if command -v curl >/dev/null 2>&1; then
        curl -L -o "$archive_name" "$download_url"
    else
        wget -O "$archive_name" "$download_url"
    fi
    
    echo -e "${BLUE}📦 Extracting archive...${NC}"
    tar -xzf "$archive_name"
    
    # Find extracted directory
    local extracted_dir=$(find . -maxdepth 1 -type d -name "little-linux-helper-gui-*" | head -n1)
    if [ -z "$extracted_dir" ]; then
        echo -e "${RED}❌ Could not find extracted directory${NC}" >&2
        exit 1
    fi
    
    echo -e "${BLUE}📁 Installing to $INSTALL_DIR...${NC}"
    
    # Remove old installation if exists
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}⚠️  Removing existing installation...${NC}"
        rm -rf "$INSTALL_DIR"
    fi
    
    # Create install directory and copy files
    mkdir -p "$INSTALL_DIR"
    cp -r "$extracted_dir"/* "$INSTALL_DIR"/
    
    # Make binary executable
    chmod +x "$INSTALL_DIR/little-linux-helper-gui"
    
    # Clean up
    cd /
    rm -rf "$temp_dir"
    
    echo -e "${GREEN}✅ Installation completed!${NC}"
}

# Function to create system service (optional)
create_service() {
    read -p "Do you want to create a systemd service? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}📝 Creating systemd service...${NC}"
        
        cat > /etc/systemd/system/little-linux-helper-gui.service << EOF
[Unit]
Description=Little Linux Helper GUI
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/little-linux-helper-gui
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

        systemctl daemon-reload
        echo -e "${GREEN}✅ Service created!${NC}"
        echo -e "${YELLOW}💡 To enable auto-start: sudo systemctl enable little-linux-helper-gui${NC}"
        echo -e "${YELLOW}💡 To start now: sudo systemctl start little-linux-helper-gui${NC}"
    fi
}

# Function to create desktop entry (if desktop environment detected)
create_desktop_entry() {
    if [ -d "/usr/share/applications" ] && [ "$DISPLAY" != "" ]; then
        read -p "Do you want to create a desktop entry? (y/N): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}🖥️  Creating desktop entry...${NC}"
            
            cat > /usr/share/applications/little-linux-helper-gui.desktop << EOF
[Desktop Entry]
Name=Little Linux Helper GUI
Comment=System maintenance and management tool
Exec=$INSTALL_DIR/little-linux-helper-gui
Icon=utilities-system-monitor
Terminal=false
Type=Application
Categories=System;Settings;
EOF

            echo -e "${GREEN}✅ Desktop entry created!${NC}"
        fi
    fi
}

# Main installation process
main() {
    echo -e "${BLUE}🔍 Detecting system architecture...${NC}"
    local arch=$(detect_architecture)
    echo -e "${GREEN}✅ Architecture detected: $arch${NC}"
    
    check_root
    
    local download_url=$(get_latest_release "$arch")
    
    download_and_install "$download_url" "$arch"
    
    create_service
    create_desktop_entry
    
    echo
    echo -e "${GREEN}🎉 Installation completed successfully!${NC}"
    echo
    echo -e "${BLUE}How to use:${NC}"
    echo -e "  • Manual start: ${YELLOW}cd $INSTALL_DIR && ./little-linux-helper-gui${NC}"
    echo -e "  • Open in browser: ${YELLOW}http://localhost:3000${NC}"
    echo
    echo -e "${BLUE}Files installed to: ${YELLOW}$INSTALL_DIR${NC}"
    echo
    echo -e "${GREEN}Enjoy your Little Linux Helper GUI! 🐧${NC}"
}

# Run main function
main "$@"
