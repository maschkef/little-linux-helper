#!/bin/bash
#
# modules/mod_network.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: MIT
#
# This script is part of the 'little-linux-helper' collection.
# Licensed under the MIT License. See the LICENSE file in the project root for more information.
#
# Module providing diagnostic and maintenance tools for networking

# Load common library
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

# Complete initialization when run directly (not via help_master.sh)
if [[ -z "${LH_INITIALIZED:-}" ]]; then
    lh_load_general_config
    lh_initialize_logging
    lh_detect_package_manager
    lh_finalize_initialization
    export LH_INITIALIZED=1
fi

# Load translations if not already present
if [[ -z "${MSG[NETWORK_TOOLS_TITLE]:-}" ]]; then
    lh_load_language_module "network_tools"
    lh_load_language_module "common"
    lh_load_language_module "lib"
fi

lh_log_active_sessions_debug "$(lh_msg 'MENU_NETWORK_TOOLS')"
lh_begin_module_session "mod_network" "$(lh_msg 'MENU_NETWORK_TOOLS')" "$(lh_msg 'LIB_SESSION_ACTIVITY_MENU')"

function lh_network_format_list() {
    local -n __items=$1
    if ((${#__items[@]} == 0)); then
        printf '%s' "$(lh_msg 'NETWORK_STATUS_NONE')"
        return 0
    fi
    local formatted=""
    local item
    for item in "${__items[@]}"; do
        if [[ -n "$formatted" ]]; then
            formatted+=", "
        fi
        formatted+="$item"
    done
    printf '%s' "$formatted"
}

function network_tools_status_dashboard() {
    lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION' "$(lh_msg 'NETWORK_TOOLS_STATUS_DASHBOARD')")"
    lh_print_header "$(lh_msg 'NETWORK_STATUS_SECTION_TITLE')"

    if ! command -v ip >/dev/null 2>&1; then
        lh_log_msg "ERROR" "ip command not available"
        lh_print_boxed_message \
            --preset danger \
            "$(lh_msg 'ERROR')" \
            "$(lh_msg 'NETWORK_STATUS_IP_CMD_MISSING')"
        return 1
    fi

    declare -A nmcli_devices=()
    if command -v nmcli >/dev/null 2>&1; then
        while IFS=: read -r device type state connection; do
            [[ -z "$device" || "$device" == "DEVICE" ]] && continue
            nmcli_devices["$device"]="$type|$state|${connection:-$(lh_msg 'NETWORK_STATUS_CONN_NMCLI_UNKNOWN')}"
        done < <(nmcli -t device status 2>/dev/null)
    fi

    declare -A wireless_devices=()
    if command -v iw >/dev/null 2>&1; then
        while read -r line; do
            if [[ $line == Interface* ]]; then
                local iface="${line#Interface }"
                wireless_devices["$iface"]=1
            fi
        done < <(iw dev 2>/dev/null)
    fi

    local interfaces_found=false
    while IFS= read -r link_line; do
        interfaces_found=true

        local remainder="${link_line#*: }"
        local iface="${remainder%%:*}"
        iface="${iface%%@*}"
        iface="${iface// /}"

        [[ -n "$iface" ]] || continue

        local state="UNKNOWN"
        if [[ $remainder =~ state\ ([A-Z0-9_]+) ]]; then
            state="${BASH_REMATCH[1]}"
        fi

        local mac_address=""
        if [[ -r "/sys/class/net/$iface/address" ]]; then
            mac_address="$(<"/sys/class/net/$iface/address")"
        else
            mac_address="$(lh_msg 'NETWORK_STATUS_UNKNOWN')"
        fi

        local carrier_status
        if [[ -r "/sys/class/net/$iface/carrier" ]]; then
            if [[ $(<"/sys/class/net/$iface/carrier") -eq 1 ]]; then
                carrier_status="$(lh_msg 'NETWORK_STATUS_CARRIER_UP')"
            else
                carrier_status="$(lh_msg 'NETWORK_STATUS_CARRIER_DOWN')"
            fi
        else
            carrier_status="$(lh_msg 'NETWORK_STATUS_CARRIER_UNKNOWN')"
        fi

        local connection_info
        if [[ -n "${nmcli_devices[$iface]:-}" ]]; then
            IFS='|' read -r nm_type nm_state nm_connection <<<"${nmcli_devices[$iface]}"
            connection_info="$(lh_msg 'NETWORK_STATUS_CONN_NMCLI' "$nm_type" "$nm_state" "$nm_connection")"
        elif [[ -n "${wireless_devices[$iface]:-}" ]]; then
            connection_info="$(lh_msg 'NETWORK_STATUS_CONN_WIRELESS')"
        else
            connection_info="$(lh_msg 'NETWORK_STATUS_CONN_WIRED')"
        fi

        local ipv4_addrs=()
        while IFS= read -r addr_line; do
            local ip
            ip=$(printf '%s\n' "$addr_line" | awk '{print $4}')
            [[ -n "$ip" ]] && ipv4_addrs+=("$ip")
        done < <(ip -o -4 addr show dev "$iface" 2>/dev/null)

        local ipv6_addrs=()
        while IFS= read -r addr_line; do
            local ip
            ip=$(printf '%s\n' "$addr_line" | awk '{print $4}')
            [[ -n "$ip" ]] && ipv6_addrs+=("$ip")
        done < <(ip -o -6 addr show dev "$iface" 2>/dev/null)

        echo -e "${LH_COLOR_BOLD_CYAN}$(lh_msg 'NETWORK_STATUS_INTERFACE_HEADER' "$iface")${LH_COLOR_RESET}"
        echo -e "  $(lh_msg 'NETWORK_STATUS_STATE' "$state")"
        echo -e "  $(lh_msg 'NETWORK_STATUS_MAC' "$mac_address")"
        echo -e "  $(lh_msg 'NETWORK_STATUS_CARRIER' "$carrier_status")"
        printf '  %s ' "$(lh_msg 'NETWORK_STATUS_IPV4')"
        lh_network_format_list ipv4_addrs
        echo ""
        printf '  %s ' "$(lh_msg 'NETWORK_STATUS_IPV6')"
        lh_network_format_list ipv6_addrs
        echo ""
        echo -e "  $(lh_msg 'NETWORK_STATUS_CONNECTION' "$connection_info")"
        echo ""
    done < <(ip -o link show 2>/dev/null)

    if ! $interfaces_found; then
        lh_log_msg "WARN" "No network interfaces detected"
        lh_print_boxed_message \
            --preset warning \
            "$(lh_msg 'WARNING')" \
            "$(lh_msg 'NETWORK_STATUS_NO_INTERFACES')"
    fi
}

function network_tools_connectivity_checks() {
    lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION' "$(lh_msg 'NETWORK_TOOLS_CONNECTIVITY_CHECKS')")"
    lh_print_header "$(lh_msg 'NETWORK_CONNECTIVITY_HEADER')"

    if ! command -v ip >/dev/null 2>&1; then
        lh_log_msg "ERROR" "ip command not available"
        lh_print_boxed_message \
            --preset danger \
            "$(lh_msg 'ERROR')" \
            "$(lh_msg 'NETWORK_STATUS_IP_CMD_MISSING')"
        return 1
    fi

    if ! command -v ping >/dev/null 2>&1; then
        lh_log_msg "ERROR" "ping command not available"
        lh_print_boxed_message \
            --preset danger \
            "$(lh_msg 'ERROR')" \
            "$(lh_msg 'NETWORK_CONNECTIVITY_PING_MISSING')"
        return 1
    fi

    local all_success=true
    local default_route
    default_route="$(ip route show default 2>/dev/null | head -n 1)"

    if [[ -n "$default_route" ]]; then
        local default_gateway=""
        if [[ $default_route =~ via\ ([^[:space:]]+) ]]; then
            default_gateway="${BASH_REMATCH[1]}"
        fi

        if [[ -n "$default_gateway" ]]; then
            if ping -c 2 -W 2 "$default_gateway" >/dev/null 2>&1; then
                lh_log_msg "INFO" "Gateway $default_gateway reachable"
                echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'NETWORK_CONNECTIVITY_GATEWAY_SUCCESS' "$default_gateway")${LH_COLOR_RESET}"
            else
                lh_log_msg "WARN" "Gateway $default_gateway not reachable"
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'NETWORK_CONNECTIVITY_GATEWAY_FAIL' "$default_gateway")${LH_COLOR_RESET}"
                all_success=false
            fi
        else
            lh_log_msg "WARN" "Default route has no explicit gateway"
            echo -e "${LH_COLOR_WARNING}$(lh_msg 'NETWORK_CONNECTIVITY_GATEWAY_NONE')${LH_COLOR_RESET}"
        fi
    else
        lh_log_msg "WARN" "No default route configured"
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'NETWORK_CONNECTIVITY_NO_DEFAULT_ROUTE')${LH_COLOR_RESET}"
        all_success=false
    fi

    local ip_targets=("1.1.1.1" "8.8.8.8")
    local host_targets=("cloudflare.com" "google.com")

    local target
    for target in "${ip_targets[@]}"; do
        if ping -c 2 -W 2 "$target" >/dev/null 2>&1; then
            lh_log_msg "INFO" "Ping success to $target"
            echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'NETWORK_CONNECTIVITY_PING_SUCCESS' "$target")${LH_COLOR_RESET}"
        else
            lh_log_msg "WARN" "Ping failure to $target"
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'NETWORK_CONNECTIVITY_PING_FAIL' "$target")${LH_COLOR_RESET}"
            all_success=false
        fi
    done

    local host
    for host in "${host_targets[@]}"; do
        local resolved
        resolved="$(getent ahosts "$host" 2>/dev/null | awk '{print $1}' | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
        if [[ -n "$resolved" ]]; then
            lh_log_msg "INFO" "$host resolves to $resolved"
            echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'NETWORK_CONNECTIVITY_RESOLUTION_SUCCESS' "$host" "$resolved")${LH_COLOR_RESET}"
        else
            lh_log_msg "WARN" "$host failed to resolve"
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'NETWORK_CONNECTIVITY_RESOLUTION_FAIL' "$host")${LH_COLOR_RESET}"
            all_success=false
        fi
    done

    if $all_success; then
        lh_print_boxed_message \
            --preset success \
            "$(lh_msg 'NETWORK_CONNECTIVITY_SUMMARY_OK_TITLE')" \
            "$(lh_msg 'NETWORK_CONNECTIVITY_SUMMARY_OK_BODY')"
    else
        lh_print_boxed_message \
            --preset warning \
            "$(lh_msg 'NETWORK_CONNECTIVITY_SUMMARY_WARN_TITLE')" \
            "$(lh_msg 'NETWORK_CONNECTIVITY_SUMMARY_WARN_BODY')"
    fi
}

function network_tools_routing_dns_view() {
    lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION' "$(lh_msg 'NETWORK_TOOLS_ROUTING_DNS')")"
    lh_print_header "$(lh_msg 'NETWORK_ROUTING_HEADER')"

    if ! command -v ip >/dev/null 2>&1; then
        lh_log_msg "ERROR" "ip command not available"
        lh_print_boxed_message \
            --preset danger \
            "$(lh_msg 'ERROR')" \
            "$(lh_msg 'NETWORK_STATUS_IP_CMD_MISSING')"
        return 1
    fi

    local default_route
    default_route="$(ip route show default 2>/dev/null | head -n 1)"
    if [[ -n "$default_route" ]]; then
        echo -e "${LH_COLOR_INFO}$(lh_msg 'NETWORK_ROUTING_DEFAULT_ROUTE' "$default_route")${LH_COLOR_RESET}"
    else
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'NETWORK_ROUTING_NO_DEFAULT')${LH_COLOR_RESET}"
    fi

    echo ""
    echo -e "${LH_COLOR_BOLD_CYAN}$(lh_msg 'NETWORK_ROUTING_TABLE_HEADER')${LH_COLOR_RESET}"
    if command -v ip >/dev/null 2>&1; then
        ip route show table main 2>/dev/null
    else
        lh_print_boxed_message \
            --preset danger \
            "$(lh_msg 'ERROR')" \
            "$(lh_msg 'NETWORK_STATUS_IP_CMD_MISSING')"
    fi

    echo ""
    lh_print_header "$(lh_msg 'NETWORK_DNS_HEADER')"
    if command -v resolvectl >/dev/null 2>&1; then
        resolvectl status 2>/dev/null
    elif command -v systemd-resolve >/dev/null 2>&1; then
        systemd-resolve --status 2>/dev/null
    elif [[ -f /etc/resolv.conf ]]; then
        echo -e "${LH_COLOR_INFO}$(lh_msg 'NETWORK_DNS_RESOLV_CONF_MESSAGE')${LH_COLOR_RESET}"
        cat /etc/resolv.conf
    else
        lh_print_boxed_message \
            --preset warning \
            "$(lh_msg 'WARNING')" \
            "$(lh_msg 'NETWORK_DNS_NO_INFO')"
    fi
}

function network_tools_service_health() {
    lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION' "$(lh_msg 'NETWORK_TOOLS_SERVICE_HEALTH')")"
    lh_print_header "$(lh_msg 'NETWORK_SERVICE_HEADER')"

    if ! command -v systemctl >/dev/null 2>&1; then
        lh_log_msg "WARN" "systemctl not found"
        lh_print_boxed_message \
            --preset warning \
            "$(lh_msg 'WARNING')" \
            "$(lh_msg 'NETWORK_SERVICE_NO_SYSTEMCTL')"
        return 1
    fi

    local services=(
        "NetworkManager.service"
        "systemd-networkd.service"
        "wpa_supplicant.service"
        "systemd-resolved.service"
        "connman.service"
    )

    local svc
    for svc in "${services[@]}"; do
        local unit_name="$svc"
        echo -e "${LH_COLOR_BOLD_CYAN}$(lh_msg 'NETWORK_SERVICE_STATUS_FOR' "$unit_name")${LH_COLOR_RESET}"
        local load_state
        load_state="$(systemctl show -p LoadState --value "$unit_name" 2>/dev/null || true)"

        if [[ "$load_state" == "loaded" ]]; then
            local active_state
            active_state="$(systemctl show -p ActiveState --value "$unit_name" 2>/dev/null || true)"
            systemctl status "$unit_name" --no-pager --lines=5 || true
            if [[ "$active_state" != "active" ]]; then
                echo -e "${LH_COLOR_WARNING}$(lh_msg 'NETWORK_SERVICE_INACTIVE' "$unit_name")${LH_COLOR_RESET}"
            fi
        else
            echo -e "${LH_COLOR_WARNING}$(lh_msg 'NETWORK_SERVICE_NOT_FOUND' "$unit_name")${LH_COLOR_RESET}"
        fi
        echo ""
    done
}

function network_tools_restart_services() {
    lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION' "$(lh_msg 'NETWORK_TOOLS_RESTART_MANAGER')")"
    lh_log_msg "INFO" "Delegating to restart module for network services"

    if bash "$LH_ROOT_DIR/modules/mod_restarts.sh" --network-only; then
        lh_log_msg "INFO" "Restart module completed for network services"
    else
        lh_log_msg "ERROR" "Restart module reported failure for network services"
        lh_print_boxed_message \
            --preset danger \
            "$(lh_msg 'ERROR')" \
            "$(lh_msg 'NETWORK_RESTART_DELEGATED_FAIL')"
    fi
}

function network_tools_clear_dns_cache() {
    lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION' "$(lh_msg 'NETWORK_TOOLS_CLEAR_DNS')")"
    lh_print_header "$(lh_msg 'NETWORK_CLEAR_DNS_HEADER')"

    local action_performed=false
    local systemctl_available=false
    if command -v systemctl >/dev/null 2>&1; then
        systemctl_available=true
    fi

    if ( $systemctl_available && systemctl is-active --quiet systemd-resolved.service ) || command -v resolvectl >/dev/null 2>&1; then
        if $LH_SUDO_CMD resolvectl flush-caches >/dev/null 2>&1; then
            echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'NETWORK_CLEAR_DNS_RESOLVED_OK')${LH_COLOR_RESET}"
            action_performed=true
        elif command -v systemd-resolve >/dev/null 2>&1 && $LH_SUDO_CMD systemd-resolve --flush-caches >/dev/null 2>&1; then
            echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'NETWORK_CLEAR_DNS_RESOLVED_OK')${LH_COLOR_RESET}"
            action_performed=true
        else
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'NETWORK_CLEAR_DNS_RESOLVED_FAIL')${LH_COLOR_RESET}"
        fi
    fi

    if $systemctl_available && systemctl is-active --quiet dnsmasq.service; then
        if $LH_SUDO_CMD systemctl restart dnsmasq.service >/dev/null 2>&1; then
            echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'NETWORK_CLEAR_DNS_DNSMASQ_OK')${LH_COLOR_RESET}"
            action_performed=true
        else
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'NETWORK_CLEAR_DNS_DNSMASQ_FAIL')${LH_COLOR_RESET}"
        fi
    fi

    if $systemctl_available && systemctl is-active --quiet nscd.service; then
        if $LH_SUDO_CMD nscd --invalidate=hosts >/dev/null 2>&1; then
            echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'NETWORK_CLEAR_DNS_NSCD_OK')${LH_COLOR_RESET}"
            action_performed=true
        else
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'NETWORK_CLEAR_DNS_NSCD_FAIL')${LH_COLOR_RESET}"
        fi
    fi

    if command -v rndc >/dev/null 2>&1; then
        local bind_service_active=""
        if $systemctl_available; then
            local bind_services=("named.service" "bind9.service")
            local svc
            for svc in "${bind_services[@]}"; do
                if systemctl is-active --quiet "$svc"; then
                    bind_service_active="$svc"
                    break
                fi
            done
        fi

        if [[ -n "$bind_service_active" ]]; then
            if $LH_SUDO_CMD rndc flush >/dev/null 2>&1; then
                echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'NETWORK_CLEAR_DNS_RNDC_OK')${LH_COLOR_RESET}"
                action_performed=true
            else
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'NETWORK_CLEAR_DNS_RNDC_FAIL')${LH_COLOR_RESET}"
            fi
        else
            echo -e "${LH_COLOR_INFO}$(lh_msg 'NETWORK_CLEAR_DNS_RNDC_SKIP')${LH_COLOR_RESET}"
        fi
    fi

    if ! $action_performed; then
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'NETWORK_CLEAR_DNS_NO_ACTION')${LH_COLOR_RESET}"
    fi
}

function network_tools_menu() {
    while true; do
        lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_MENU')"
        lh_print_header "$(lh_msg 'NETWORK_TOOLS_TITLE')"

        lh_print_menu_item 1 "$(lh_msg 'NETWORK_TOOLS_STATUS_DASHBOARD')"
        lh_print_menu_item 2 "$(lh_msg 'NETWORK_TOOLS_CONNECTIVITY_CHECKS')"
        lh_print_menu_item 3 "$(lh_msg 'NETWORK_TOOLS_ROUTING_DNS')"
        lh_print_menu_item 4 "$(lh_msg 'NETWORK_TOOLS_SERVICE_HEALTH')"
        lh_print_menu_item 5 "$(lh_msg 'NETWORK_TOOLS_RESTART_MANAGER')"
        lh_print_menu_item 6 "$(lh_msg 'NETWORK_TOOLS_CLEAR_DNS')"
        lh_print_gui_hidden_menu_item 0 "$(lh_msg 'NETWORK_TOOLS_BACK_TO_MAIN')"
        echo ""

        lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_WAITING')"
        local choice
        read -r -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'CHOOSE_OPTION')${LH_COLOR_RESET} ")" choice

        case $choice in
            1)
                network_tools_status_dashboard
                ;;
            2)
                network_tools_connectivity_checks
                ;;
            3)
                network_tools_routing_dns_view
                ;;
            4)
                network_tools_service_health
                ;;
            5)
                network_tools_restart_services
                ;;
            6)
                network_tools_clear_dns_cache
                ;;
            0)
                if lh_gui_mode_active; then
                    lh_log_msg "WARN" "Invalid selection in GUI mode: $choice"
                    echo -e "${LH_COLOR_ERROR}$(lh_msg 'INVALID_SELECTION')${LH_COLOR_RESET}"
                    lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_WAITING')"
                    continue
                fi
                lh_log_msg "INFO" "Leaving network tools module"
                return 0
                ;;
            *)
                lh_log_msg "WARN" "Invalid selection: $choice"
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'INVALID_SELECTION')${LH_COLOR_RESET}"
                ;;
        esac

        lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_WAITING')"

        echo ""
        lh_press_any_key 'NETWORK_TOOLS_PRESS_KEY_CONTINUE'
        echo ""
    done
}

network_tools_menu
exit $?
