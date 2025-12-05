#!/bin/bash
#
# lang/en/modules/network_tools.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: MIT
#
# English language strings for the network tools module

[[ ! -v MSG_EN ]] && declare -A MSG_EN

# Menu entries
MSG_EN[NETWORK_TOOLS_TITLE]="Network Tools"
MSG_EN[NETWORK_TOOLS_STATUS_DASHBOARD]="Status dashboard (interfaces, addresses, carrier)"
MSG_EN[NETWORK_TOOLS_CONNECTIVITY_CHECKS]="Connectivity checks"
MSG_EN[NETWORK_TOOLS_ROUTING_DNS]="Routing and DNS view"
MSG_EN[NETWORK_TOOLS_SERVICE_HEALTH]="Service health overview"
MSG_EN[NETWORK_TOOLS_RESTART_MANAGER]="Restart network services (reuse restart module)"
MSG_EN[NETWORK_TOOLS_CLEAR_DNS]="Clear DNS cache"
MSG_EN[NETWORK_TOOLS_BACK_TO_MAIN]="Back to main menu"
MSG_EN[NETWORK_TOOLS_PRESS_KEY_CONTINUE]="Press any key to continue..."

# Status dashboard strings
MSG_EN[NETWORK_STATUS_SECTION_TITLE]="Interface Status Overview"
MSG_EN[NETWORK_STATUS_NONE]="None"
MSG_EN[NETWORK_STATUS_UNKNOWN]="Unknown"
MSG_EN[NETWORK_STATUS_IP_CMD_MISSING]="The command 'ip' is not available. Please install the 'iproute2' package."
MSG_EN[NETWORK_STATUS_CONN_NMCLI_UNKNOWN]="Unknown connection"
MSG_EN[NETWORK_STATUS_INTERFACE_HEADER]="Interface: %s"
MSG_EN[NETWORK_STATUS_STATE]="State: %s"
MSG_EN[NETWORK_STATUS_MAC]="MAC address: %s"
MSG_EN[NETWORK_STATUS_CARRIER]="Carrier: %s"
MSG_EN[NETWORK_STATUS_IPV4]="IPv4:"
MSG_EN[NETWORK_STATUS_IPV6]="IPv6:"
MSG_EN[NETWORK_STATUS_CONNECTION]="Connection: %s"
MSG_EN[NETWORK_STATUS_CARRIER_UP]="Up"
MSG_EN[NETWORK_STATUS_CARRIER_DOWN]="Down"
MSG_EN[NETWORK_STATUS_CARRIER_UNKNOWN]="Unknown"
MSG_EN[NETWORK_STATUS_CONN_NMCLI]="%s (%s, connection: %s)"
MSG_EN[NETWORK_STATUS_CONN_WIRELESS]="Wireless (iw)"
MSG_EN[NETWORK_STATUS_CONN_WIRED]="Wired"
MSG_EN[NETWORK_STATUS_NO_INTERFACES]="No network interfaces detected."

# Connectivity checks
MSG_EN[NETWORK_CONNECTIVITY_HEADER]="Connectivity Checks"
MSG_EN[NETWORK_CONNECTIVITY_PING_MISSING]="The command 'ping' is not available."
MSG_EN[NETWORK_CONNECTIVITY_GATEWAY_SUCCESS]="Default gateway %s reachable."
MSG_EN[NETWORK_CONNECTIVITY_GATEWAY_FAIL]="Default gateway %s is NOT reachable."
MSG_EN[NETWORK_CONNECTIVITY_GATEWAY_NONE]="Default route without explicit gateway."
MSG_EN[NETWORK_CONNECTIVITY_NO_DEFAULT_ROUTE]="No default route configured."
MSG_EN[NETWORK_CONNECTIVITY_PING_SUCCESS]="Ping to %s succeeded."
MSG_EN[NETWORK_CONNECTIVITY_PING_FAIL]="Ping to %s failed."
MSG_EN[NETWORK_CONNECTIVITY_RESOLUTION_SUCCESS]="Hostname %s resolves to: %s"
MSG_EN[NETWORK_CONNECTIVITY_RESOLUTION_FAIL]="Hostname %s could not be resolved."
MSG_EN[NETWORK_CONNECTIVITY_SUMMARY_OK_TITLE]="Connectivity summary"
MSG_EN[NETWORK_CONNECTIVITY_SUMMARY_OK_BODY]="All configured connectivity checks completed successfully."
MSG_EN[NETWORK_CONNECTIVITY_SUMMARY_WARN_TITLE]="Connectivity summary"
MSG_EN[NETWORK_CONNECTIVITY_SUMMARY_WARN_BODY]="One or more connectivity checks failed. Please review the details above."

# Routing and DNS view
MSG_EN[NETWORK_ROUTING_HEADER]="Routing Overview"
MSG_EN[NETWORK_ROUTING_DEFAULT_ROUTE]="Default route: %s"
MSG_EN[NETWORK_ROUTING_NO_DEFAULT]="No default route present."
MSG_EN[NETWORK_ROUTING_TABLE_HEADER]="Routing table (main):"
MSG_EN[NETWORK_DNS_HEADER]="Resolver Information"
MSG_EN[NETWORK_DNS_RESOLV_CONF_MESSAGE]="Using /etc/resolv.conf as resolver source:"
MSG_EN[NETWORK_DNS_NO_INFO]="No resolver information available."

# Service health
MSG_EN[NETWORK_SERVICE_HEADER]="Network Service Health"
MSG_EN[NETWORK_SERVICE_NO_SYSTEMCTL]="systemctl is not available on this system."
MSG_EN[NETWORK_SERVICE_STATUS_FOR]="Service status: %s"
MSG_EN[NETWORK_SERVICE_INACTIVE]="Service %s is installed but currently inactive or failed."
MSG_EN[NETWORK_SERVICE_NOT_FOUND]="Service %s not found on this system."

# Restart delegation
MSG_EN[NETWORK_RESTART_DELEGATED_FAIL]="The restart module could not restart the selected services."

# DNS cache clearing
MSG_EN[NETWORK_CLEAR_DNS_HEADER]="DNS Cache Clearing"
MSG_EN[NETWORK_CLEAR_DNS_RESOLVED_OK]="Flushed systemd-resolved DNS cache."
MSG_EN[NETWORK_CLEAR_DNS_RESOLVED_FAIL]="Failed to flush systemd-resolved DNS cache."
MSG_EN[NETWORK_CLEAR_DNS_DNSMASQ_OK]="Restarted dnsmasq to refresh DNS cache."
MSG_EN[NETWORK_CLEAR_DNS_DNSMASQ_FAIL]="Failed to restart dnsmasq."
MSG_EN[NETWORK_CLEAR_DNS_NSCD_OK]="Invalidated NSCD hosts cache."
MSG_EN[NETWORK_CLEAR_DNS_NSCD_FAIL]="Failed to invalidate NSCD hosts cache."
MSG_EN[NETWORK_CLEAR_DNS_RNDC_OK]="Flushed BIND (rndc) DNS cache."
MSG_EN[NETWORK_CLEAR_DNS_RNDC_FAIL]="Failed to flush BIND (rndc) DNS cache."
MSG_EN[NETWORK_CLEAR_DNS_RNDC_SKIP]="BIND (rndc) tools detected but service not active; skipped."
MSG_EN[NETWORK_CLEAR_DNS_NO_ACTION]="No known DNS cache service detected or commands failed."
