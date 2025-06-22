#!/bin/bash
#
# little-linux-helper/lang/en/system_info.sh
# Copyright (c) 2025 wuldorf
# SPDX-License-Identifier: MIT
#
# English language strings for system_info module

# Conditional declaration for module files
[[ ! -v MSG_EN ]] && declare -A MSG_EN

# Menu items and headers
MSG_EN[SYSINFO_MENU_TITLE]="System Information"
MSG_EN[SYSINFO_MENU_OS_KERNEL]="Operating System & Kernel"
MSG_EN[SYSINFO_MENU_CPU]="CPU Details"
MSG_EN[SYSINFO_MENU_RAM]="RAM Usage"
MSG_EN[SYSINFO_MENU_PCI]="PCI Devices"
MSG_EN[SYSINFO_MENU_USB]="USB Devices"
MSG_EN[SYSINFO_MENU_DISK_OVERVIEW]="Disk Overview"
MSG_EN[SYSINFO_MENU_TOP_PROCESSES]="Top Processes (CPU/RAM)"
MSG_EN[SYSINFO_MENU_NETWORK]="Network Configuration"
MSG_EN[SYSINFO_MENU_SENSORS]="Temperatures/Sensors"
MSG_EN[SYSINFO_MENU_BACK]="Back to Main Menu"

# Headers
MSG_EN[SYSINFO_HEADER_OS_KERNEL]="Operating System & Kernel"
MSG_EN[SYSINFO_HEADER_CPU]="CPU Details"
MSG_EN[SYSINFO_HEADER_RAM]="RAM Usage"
MSG_EN[SYSINFO_HEADER_PCI]="PCI Devices"
MSG_EN[SYSINFO_HEADER_USB]="USB Devices"
MSG_EN[SYSINFO_HEADER_DISK_OVERVIEW]="Disk Overview"
MSG_EN[SYSINFO_HEADER_TOP_PROCESSES]="Top Processes"
MSG_EN[SYSINFO_HEADER_NETWORK]="Network Configuration"
MSG_EN[SYSINFO_HEADER_SENSORS]="Temperatures/Sensors"

# OS & Kernel
MSG_EN[SYSINFO_OS_LABEL]="Operating System:"
MSG_EN[SYSINFO_OS_NOT_AVAILABLE]="OS release information not available."
MSG_EN[SYSINFO_KERNEL_VERSION]="Kernel Version:"
MSG_EN[SYSINFO_SYSTEM_UPTIME]="System uptime:"

# CPU
MSG_EN[SYSINFO_CPU_FROM_PROC]="CPU information from /proc/cpuinfo:"
MSG_EN[SYSINFO_CPU_NOT_AVAILABLE]="CPU information not available."

# RAM
MSG_EN[SYSINFO_RAM_USAGE]="Memory usage overview:"
MSG_EN[SYSINFO_RAM_DETAILS]="Detailed memory information:"

# PCI Devices
MSG_EN[SYSINFO_PCI_DEVICES]="PCI devices overview:"
MSG_EN[SYSINFO_PCI_NOT_AVAILABLE]="PCI information not available. Install 'pciutils' for detailed information."

# USB Devices
MSG_EN[SYSINFO_USB_DEVICES]="USB devices overview:"
MSG_EN[SYSINFO_USB_NOT_AVAILABLE]="USB information not available. Install 'usbutils' for detailed information."

# Disk Overview
MSG_EN[SYSINFO_DISK_MOUNTED]="Mounted filesystems:"
MSG_EN[SYSINFO_DISK_BLOCK_DEVICES]="Block devices:"

# Top Processes
MSG_EN[SYSINFO_TOP_CPU_PROCESSES]="Top 10 processes by CPU usage:"
MSG_EN[SYSINFO_TOP_RAM_PROCESSES]="Top 10 processes by RAM usage:"

# Network
MSG_EN[SYSINFO_NETWORK_INTERFACES]="Network interfaces:"
MSG_EN[SYSINFO_NETWORK_ROUTING]="Routing table:"
MSG_EN[SYSINFO_NETWORK_CONNECTIONS]="Active network connections:"

# Sensors
MSG_EN[SYSINFO_SENSORS_TEMP]="Temperature and sensor information:"
MSG_EN[SYSINFO_SENSORS_NOT_AVAILABLE]="Sensor information not available. Install 'lm-sensors' for detailed information."
MSG_EN[SYSINFO_SENSORS_INSTALL_PROMPT]="Would you like to install 'lm-sensors' for temperature monitoring?"

# General messages
MSG_EN[SYSINFO_BACK_TO_MAIN_MENU]="Back to main menu."
MSG_EN[SYSINFO_INVALID_SELECTION_TRY_AGAIN]="Invalid selection. Please try again."

# PCI Device prompts and messages
MSG_EN[SYSINFO_PCI_BASIC_LIST]="Basic list of PCI devices:"
MSG_EN[SYSINFO_PCI_DETAILED_PROMPT]="Would you like to display detailed information about PCI devices (more verbose)?"
MSG_EN[SYSINFO_PCI_DETAILED_INFO]="Detailed information about PCI devices:"
MSG_EN[SYSINFO_PCI_NOT_INSTALLED]="lspci is not installed and could not be installed."

# USB Device prompts and messages
MSG_EN[SYSINFO_USB_BASIC_LIST]="Basic list of USB devices:"
MSG_EN[SYSINFO_USB_DETAILED_PROMPT]="Would you like to display detailed information about USB devices (more verbose)?"
MSG_EN[SYSINFO_USB_DETAILED_INFO]="Detailed information about USB devices:"
MSG_EN[SYSINFO_USB_NOT_INSTALLED]="lsusb is not installed and could not be installed."

# Disk overview messages
MSG_EN[SYSINFO_DISK_BLOCK_DEVICES_LABEL]="Block devices and filesystems (lsblk):"
MSG_EN[SYSINFO_DISK_MOUNTED_FILESYSTEMS]="Currently mounted filesystems (df):"

# Top processes messages
MSG_EN[SYSINFO_TOP_CPU_LABEL]="Top 10 processes by CPU usage:"
MSG_EN[SYSINFO_TOP_MEMORY_LABEL]="Top 10 processes by memory usage:"
MSG_EN[SYSINFO_TOP_REALTIME_PROMPT]="Would you like to run 'top' to monitor processes in real time?"

# Network configuration messages
MSG_EN[SYSINFO_NETWORK_INTERFACES_LABEL]="Network interfaces (ip addr):"
MSG_EN[SYSINFO_NETWORK_ROUTING_LABEL]="Routing table (ip route):"
MSG_EN[SYSINFO_NETWORK_CONNECTIONS_LABEL]="Active network connections (ss):"
MSG_EN[SYSINFO_NETWORK_HOSTNAME_DNS]="Hostname and DNS settings:"
MSG_EN[SYSINFO_NETWORK_HOSTNAME_LABEL]="Hostname:"
MSG_EN[SYSINFO_NETWORK_DNS_SERVERS]="DNS servers:"

# Sensors messages
MSG_EN[SYSINFO_SENSORS_OUTPUT]="Sensor output:"
MSG_EN[SYSINFO_SENSORS_NOT_INSTALLED]="The program 'sensors' is not installed and could not be installed."
MSG_EN[SYSINFO_SENSORS_KERNEL_THERMAL]="Kernel Thermal Zone temperatures:"
MSG_EN[SYSINFO_SENSORS_ZONE_LABEL]="Zone %s:"
