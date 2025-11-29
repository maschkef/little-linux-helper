<!--
File: docs/mod/doc_network.md
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
-->

## Module: `modules/mod_network.sh` - Network Diagnostics & Tools

**1. Purpose:**  
Deliver a one-stop troubleshooting hub for network connectivity. The module surfaces interface health, routing and name-resolution visibility, active service state, connectivity probes, DNS cache maintenance, and quick hand-off to the restart subsystem so that common diagnostics stay in one workflow.

**2. Initialization & Dependencies:**
- **Library bootstrap:** Resolves `LIB_COMMON_PATH` relative to the module and sources `lib_common.sh`. If the library is missing the module aborts early (and returns instead of `exit` when sourced).
- **Runtime initialization:** When launched directly (not from the main helper), it performs the standard stack: `lh_load_general_config`, `lh_initialize_logging`, `lh_detect_package_manager`, and `lh_finalize_initialization`. The module then marks `LH_INITIALIZED` to prevent duplicate setup.
- **Localization:** Loads the `network_tools`, `common`, and `lib` language packs on demand so all strings map to translated `MSG[...]` entries.
- **Session registry:** Announces itself through `lh_log_active_sessions_debug`, creates a session via `lh_begin_module_session`, and continually posts activity updates with `lh_update_module_session`.
- **Key helper primitives:** `lh_print_header`, `lh_print_menu_item`, `lh_print_boxed_message`, `lh_print_gui_hidden_menu_item`, `lh_press_any_key`, `lh_gui_mode_active`, `lh_log_msg`, color constants (e.g., `LH_COLOR_SUCCESS`, `LH_COLOR_WARNING`), plus standard message helpers (`lh_msg`).
- **External commands and files:** `ip`, `nmcli` (optional), `iw` (optional), `/sys/class/net/*`, `ping`, `getent`, `resolvectl`/`systemd-resolve`, `/etc/resolv.conf`, `systemctl`, `dnsmasq`, `nscd`, `rndc`, `iw`, `nmcli`, `bash` for delegation, and `$LH_SUDO_CMD` for privileged cache flushes.

**3. Entry Point & Control Flow — `network_tools_menu()`:**
- Prints the module banner, renders six actionable menu items, and exposes a hidden `0` entry for CLI users returning to the helper root.
- Stores “waiting” and “active” status in the shared session registry for every selection.
- Routes selections to the corresponding handler functions, then uses `lh_press_any_key` for flow control outside GUI mode.
- On exit (`0` in CLI flow) it logs the departure, returns to the caller, and allows `exit $?` at file end to propagate the module status.

**4. Helper: `lh_network_format_list()`:**  
Utility that renders an indexed array (via nameref) into a comma-separated list. The helper safeguards empty arrays by returning the translated “none” string and is reused for IPv4/IPv6 address listings to keep dashboard output tidy.

**5. Functional Areas & Behaviour:**
- **`network_tools_status_dashboard()`**  
  - Requires the `iproute2` tooling; missing binaries emit a boxed danger message and short-circuit.  
  - Iterates over `ip -o link show` to enumerate interfaces, normalizes interface names (drops `@` suffixes), and queries `/sys/class/net/*` for MAC and carrier data.  
  - Augments the base data set with NetworkManager metadata (`nmcli -t device status`) and wireless hints (`iw dev`). Connection summaries switch wording depending on available helpers.  
  - Captures IPv4/IPv6 assignments using `ip -o -4/-6 addr show`, displaying comma-separated lists via `lh_network_format_list`.  
  - Missing interfaces produce a warning box so operators know the scan returned nothing.
- **`network_tools_connectivity_checks()`**  
  - Short-circuits with a fatal warning if `ping` is unavailable, otherwise probes the default gateway and a curated list of public IPs (`1.1.1.1`, `8.8.8.8`).  
  - Extracts the default gateway from `ip route show default` and distinguishes between “no default route,” “route defined but no gateway,” and “reachable gateway.”  
  - Resolves high-resilience hostnames via `getent ahosts`, printing the resolved addresses and marking missing DNS answers as warnings.  
  - Aggregates the run into success or warning summary boxes to present a quick verdict.
- **`network_tools_routing_dns_view()`**  
  - Echoes the detected default route (or a warning when missing) and dumps the main routing table through `ip route show table main`.  
  - Displays DNS resolver state using `resolvectl status` when available, falling back to `systemd-resolve --status`, and finally to rendering `/etc/resolv.conf`. If nothing is available, a boxed warning signals the lack of resolver data.  
  - Shares the header space between routing insights and DNS to keep related context together.
- **`network_tools_service_health()`**  
  - Requires `systemctl`; the helper warns and exits early when systemd tooling is absent.  
  - Inspects five core networking services (`NetworkManager`, `systemd-networkd`, `wpa_supplicant`, `systemd-resolved`, `connman`) and prints compact status snapshots (`systemctl status --no-pager --lines=5`).  
  - Differentiates between inactive-but-installed units and completely missing service definitions to avoid misleading failure noise.
- **`network_tools_restart_services()`**  
  - Delegates restarts to `modules/mod_restarts.sh --network-only`, preserving a single authoritative place for restart and confirmation logic.  
  - Propagates logging around the delegation and emits a danger-styled message when the restart module reports failure.
- **`network_tools_clear_dns_cache()`**  
  - Each cache flush is permission-gated with `$LH_SUDO_CMD` and only attempted when the relevant service reports as active.  
  - Supports `systemd-resolved` (`resolvectl flush-caches` / `systemd-resolve --flush-caches` fallback), `dnsmasq` (service restart), `nscd` (`nscd --invalidate=hosts`), and BIND (`rndc flush`).  
  - Uses per-service success/error messaging and concludes with a global warning if none of the actions executed.  
  - Recognizes when BIND tooling is present but no matching service is active, logging an informational skip instead of an error.

**6. Logging & Session Telemetry:**  
The module consistently logs via `lh_log_msg` for both success/failure cases and uses session updates (`lh_update_module_session`) to surface the currently running task, aligning with observability expectations across other modules.

**7. GUI & Localization Considerations:**  
When `lh_gui_mode_active` is true, the “Back to main menu” option stays hidden and return attempts are treated as invalid selections. `lh_press_any_key` pauses are skipped in GUI contexts, and every user-facing string routes through `lh_msg` so translations in English and German stay in sync with the CLI.

**8. Maintenance & Extension Notes:**  
- Extend the top-level menu by appending new `lh_print_menu_item` calls and mirroring translation keys in the `network_tools` language files (remember to update GUI metadata such as `SubmoduleCount`).  
- Keep connectivity targets short, reliable, and globally reachable to avoid false negatives. If you regionalize the list, document the rationale in comments and translations.  
- Add future cache handlers with the same guard pattern (`systemctl is-active`, command availability checks) to prevent misleading failure reports.  
- Preserve the `lh_network_format_list` helper for any additional list-style output to maintain consistent formatting.
