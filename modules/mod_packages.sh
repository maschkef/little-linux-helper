#!/bin/bash
#
# little-linux-helper/modules/mod_packages.sh
# Copyright (c) 2025 wuldorf
# SPDX-License-Identifier: MIT
#
# This script is part of the 'little-linux-helper' collection.
# Licensed under the MIT License. See the LICENSE file in the project root for more information.
#
# Modul für Paketverwaltung und System-Updates

# Laden der gemeinsamen Bibliothek
source "$(dirname "$0")/../lib/lib_common.sh"
lh_detect_package_manager
lh_detect_alternative_managers

# Funktion für Systemaktualisierung
function pkg_system_update() {
    lh_print_header "Systemaktualisierung"

    local auto_confirm=false
    if lh_confirm_action "Soll die Aktualisierung ohne weitere Bestätigung durchgeführt werden?" "n"; then
        auto_confirm=true
    fi

    # Spezifische Logik für Garuda Linux, falls 'garuda-update' existiert
    if command -v garuda-update >/dev/null 2>&1; then
        echo -e "${LH_COLOR_INFO}Spezialbehandlung für Garuda Linux: 'garuda-update' wird verwendet.${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}Beginne mit der Aktualisierung...${LH_COLOR_RESET}"

        if $auto_confirm; then
            garuda-update --noconfirm
        else
            garuda-update
        fi
        local garuda_update_status=$?

        if [ $garuda_update_status -eq 0 ]; then
            lh_log_msg "INFO" "Systemaktualisierung mit garuda-update erfolgreich abgeschlossen."
            echo -e "${LH_COLOR_SUCCESS}Systemaktualisierung erfolgreich abgeschlossen.${LH_COLOR_RESET}"
            
            # Bietet an, auch alternative Paketmanager zu aktualisieren.
            for alt_manager in "${LH_ALT_PKG_MANAGERS[@]}"; do
                echo ""
                if lh_confirm_action "Möchten Sie auch $alt_manager-Pakete aktualisieren?" "n"; then
                    pkg_update_alternative "$alt_manager" "$auto_confirm"
                fi
            done

            if lh_confirm_action "Möchten Sie nach nicht mehr benötigten Paketen suchen?" "y"; then
                pkg_find_orphans
            fi
            return 0 # Erfolgreich beendet
        else
            lh_log_msg "WARN" "garuda-update fehlgeschlagen (Code: $garuda_update_status). Versuche Fallback auf Standard-Paketmanager."
            echo -e "${LH_COLOR_WARNING}Warnung: 'garuda-update' ist fehlgeschlagen. Versuche Fallback...${LH_COLOR_RESET}"
            # Fährt mit dem regulären Update-Prozess fort
        fi
    fi

    # Spezifische Logik für immutable Distros wie Fedora Silverblue
    if command -v rpm-ostree >/dev/null 2>&1; then
        echo -e "${LH_COLOR_INFO}Spezialbehandlung für immutable Distribution (rpm-ostree) wird verwendet.${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}Beginne mit der Aktualisierung...${LH_COLOR_RESET}"

        $LH_SUDO_CMD rpm-ostree upgrade
        local rpm_ostree_status=$?

        if [ $rpm_ostree_status -eq 0 ]; then
            lh_log_msg "INFO" "Systemaktualisierung mit rpm-ostree erfolgreich abgeschlossen."
            echo -e "${LH_COLOR_SUCCESS}Systemaktualisierung erfolgreich abgeschlossen.${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}Ein Neustart ist erforderlich, um das Update anzuwenden.${LH_COLOR_RESET}"

            # Schleife durch alle erkannten alternativen Paketmanager, da rpm-ostree diese nicht abdeckt
            for alt_manager in "${LH_ALT_PKG_MANAGERS[@]}"; do
                echo ""
                if lh_confirm_action "Möchten Sie auch $alt_manager-Pakete aktualisieren?" "n"; then
                    pkg_update_alternative "$alt_manager" "$auto_confirm"
                fi
            done

            # Kein pkg_find_orphans für rpm-ostree, da es anders funktioniert.
            return 0 # Erfolgreich beendet
        else
            lh_log_msg "ERROR" "rpm-ostree upgrade fehlgeschlagen (Code: $rpm_ostree_status)."
            echo -e "${LH_COLOR_ERROR}Fehler: 'rpm-ostree upgrade' ist fehlgeschlagen.${LH_COLOR_RESET}"
            return 1 # Kein Fallback möglich/sinnvoll
        fi
    fi

    if [ -z "$LH_PKG_MANAGER" ]; then
        lh_log_msg "ERROR" "Kein unterstützter Paketmanager gefunden."
        echo -e "${LH_COLOR_ERROR}Fehler: Kein unterstützter Paketmanager gefunden.${LH_COLOR_RESET}"
        return 1
    fi

    echo -e "${LH_COLOR_INFO}Es wird die Systemaktualisierung mit $LH_PKG_MANAGER durchgeführt.${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_INFO}Beginne mit der Aktualisierung...${LH_COLOR_RESET}"

    case $LH_PKG_MANAGER in
        pacman)
            if $auto_confirm; then
                $LH_SUDO_CMD pacman -Syu --noconfirm
            else
                $LH_SUDO_CMD pacman -Syu
            fi
            ;;
        apt)
            echo -e "${LH_COLOR_INFO}Aktualisiere Paketquellen...${LH_COLOR_RESET}"
            $LH_SUDO_CMD apt update

            if $auto_confirm; then
                $LH_SUDO_CMD apt upgrade -y
            else
                $LH_SUDO_CMD apt upgrade
            fi
            ;;
        dnf)
            if $auto_confirm; then
                $LH_SUDO_CMD dnf upgrade --refresh -y
            else
                $LH_SUDO_CMD dnf upgrade --refresh
            fi
            ;;
        zypper)
            echo -e "${LH_COLOR_INFO}Aktualisiere Paketquellen...${LH_COLOR_RESET}"
            if $auto_confirm; then
                $LH_SUDO_CMD zypper --non-interactive refresh
                $LH_SUDO_CMD zypper --non-interactive up
            else
                $LH_SUDO_CMD zypper refresh
                $LH_SUDO_CMD zypper up
            fi
            ;;
        yay)
            if $auto_confirm; then
                yay -Syu --noconfirm
            else
                yay -Syu
            fi
            ;;
        *)
            lh_log_msg "ERROR" "Unbekannter Paketmanager: $LH_PKG_MANAGER"
            echo -e "${LH_COLOR_ERROR}Fehler: Unbekannter Paketmanager: $LH_PKG_MANAGER${LH_COLOR_RESET}"
            return 1
            ;;
    esac

    local update_status=$?
    if [ $update_status -eq 0 ]; then
        lh_log_msg "INFO" "Systemaktualisierung erfolgreich abgeschlossen." # lh_log_msg handles its own color
        echo -e "${LH_COLOR_SUCCESS}Systemaktualisierung erfolgreich abgeschlossen.${LH_COLOR_RESET}"

        # Schleife durch alle erkannten alternativen Paketmanager
        for alt_manager in "${LH_ALT_PKG_MANAGERS[@]}"; do
            echo ""
            if lh_confirm_action "Möchten Sie auch $alt_manager-Pakete aktualisieren?" "n"; then
                pkg_update_alternative "$alt_manager" "$auto_confirm"
            fi
        done
    else
        lh_log_msg "ERROR" "Systemaktualisierung fehlgeschlagen mit Fehlercode: $update_status"
        echo -e "${LH_COLOR_ERROR}Fehler: Systemaktualisierung fehlgeschlagen mit Fehlercode: $update_status${LH_COLOR_RESET}"
    fi

    # Angebot für zusätzliche Operationen nach dem Update
    if [ $update_status -eq 0 ] && lh_confirm_action "Möchten Sie nach nicht mehr benötigten Paketen suchen?" "y"; then
        pkg_find_orphans
    fi
}

# Funktion zum Aktualisieren alternativer Paketmanager
function pkg_update_alternative() {
    local alt_manager="$1"
    local auto_confirm="${2:-false}"

    case $alt_manager in
        flatpak)
            echo -e "${LH_COLOR_INFO}Aktualisiere Flatpak-Pakete...${LH_COLOR_RESET}"
            if [ "$auto_confirm" = "true" ]; then
                flatpak update -y
            else
                flatpak update
            fi
            ;;
        snap)
            echo -e "${LH_COLOR_INFO}Aktualisiere Snap-Pakete...${LH_COLOR_RESET}"
            $LH_SUDO_CMD snap refresh
            ;;
        nix)
            echo -e "${LH_COLOR_INFO}Aktualisiere Nix-Pakete...${LH_COLOR_RESET}"
            if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
                source "$HOME/.nix-profile/etc/profile.d/nix.sh"
            fi
            nix-env -u
            ;;
        appimage)
            echo -e "${LH_COLOR_INFO}AppImage-Updates müssen manuell durchgeführt werden.${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}Bitte überprüfen Sie Ihre AppImage-Anwendungen:${LH_COLOR_RESET}"
            if [ -d "$HOME/.local/bin" ]; then
                find "$HOME/.local/bin" -name "*.AppImage" -print
            fi
            echo -e "${LH_COLOR_INFO}Weitere AppImage-Speicherorte können manuell überprüft werden.${LH_COLOR_RESET}"
            ;;
        *)
            lh_log_msg "WARN" "Unbekannter alternativer Paketmanager: $alt_manager"
            echo -e "${LH_COLOR_WARNING}Warnung: Unbekannter alternativer Paketmanager: $alt_manager${LH_COLOR_RESET}"
            ;;
    esac
}

# Funktion zum Suchen und Entfernen von Waisenpaketen
function pkg_find_orphans() {
    lh_print_header "Nicht mehr benötigte Pakete suchen"

    if [ -z "$LH_PKG_MANAGER" ]; then
        lh_log_msg "ERROR" "Kein unterstützter Paketmanager gefunden."
        echo -e "${LH_COLOR_ERROR}Fehler: Kein unterstützter Paketmanager gefunden.${LH_COLOR_RESET}"
        return 1
    fi

    echo -e "${LH_COLOR_INFO}Suche nach nicht mehr benötigten Paketen...${LH_COLOR_RESET}"
    local orphaned_packages=""

    case $LH_PKG_MANAGER in
        pacman)
            orphaned_packages=$(pacman -Qdtq)
            if [ -n "$orphaned_packages" ]; then
                echo -e "${LH_COLOR_INFO}Folgende Pakete sind Waisenpakete und können entfernt werden:${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                echo "$orphaned_packages"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

                if lh_confirm_action "Möchten Sie diese Pakete entfernen?" "n"; then
                    $LH_SUDO_CMD pacman -Rns $orphaned_packages
                    lh_log_msg "INFO" "Waisenpakete wurden entfernt."
                else
                    lh_log_msg "INFO" "Entfernung der Waisenpakete abgebrochen."
                fi
            else
                echo -e "${LH_COLOR_INFO}Keine Waisenpakete gefunden.${LH_COLOR_RESET}"
                lh_log_msg "INFO" "Keine Waisenpakete gefunden."
            fi
            ;;
        apt)
            echo -e "${LH_COLOR_INFO}Überprüfung nicht mehr benötigter Pakete (apt autoremove):${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
            $LH_SUDO_CMD apt autoremove --dry-run
            echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

            if lh_confirm_action "Möchten Sie diese Pakete entfernen?" "n"; then
                $LH_SUDO_CMD apt autoremove -y
                lh_log_msg "INFO" "Nicht mehr benötigte Pakete wurden entfernt."
            else
                lh_log_msg "INFO" "Entfernung nicht mehr benötigter Pakete abgebrochen."
            fi
            ;;
        dnf)
            echo -e "${LH_COLOR_INFO}Überprüfung nicht mehr benötigter Pakete (dnf autoremove):${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
            $LH_SUDO_CMD dnf autoremove --assumeno
            echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

            if lh_confirm_action "Möchten Sie diese Pakete entfernen?" "n"; then
                $LH_SUDO_CMD dnf autoremove -y
                lh_log_msg "INFO" "Nicht mehr benötigte Pakete wurden entfernt."
            else
                lh_log_msg "INFO" "Entfernung nicht mehr benötigter Pakete abgebrochen."
            fi
            ;;
        yay)
            orphaned_packages=$(yay -Qtdq)
            if [ -n "$orphaned_packages" ]; then
                echo -e "${LH_COLOR_INFO}Folgende Pakete sind Waisenpakete und können entfernt werden:${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                echo "$orphaned_packages"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

                if lh_confirm_action "Möchten Sie diese Pakete entfernen?" "n"; then
                    yay -Rns $orphaned_packages
                    lh_log_msg "INFO" "Waisenpakete wurden entfernt."
                else
                    lh_log_msg "INFO" "Entfernung der Waisenpakete abgebrochen."
                fi
            else
                echo -e "${LH_COLOR_INFO}Keine Waisenpakete gefunden.${LH_COLOR_RESET}"
                lh_log_msg "INFO" "Keine Waisenpakete gefunden."
            fi
            ;;
        *)
            lh_log_msg "ERROR" "Unbekannter Paketmanager: $LH_PKG_MANAGER"
            echo -e "${LH_COLOR_ERROR}Fehler: Unbekannter Paketmanager: $LH_PKG_MANAGER${LH_COLOR_RESET}"
            return 1
            ;;
    esac

    # Suche nach Waisenpaketen in alternativen Paketmanagern
    for alt_manager in "${LH_ALT_PKG_MANAGERS[@]}"; do
        if lh_confirm_action "Möchten Sie auch nicht mehr benötigte $alt_manager-Pakete suchen?" "n"; then
            pkg_find_orphans_alternative "$alt_manager"
        fi
    done

    # Zusätzliche Optionen für Paketbereinigung
    if lh_confirm_action "Möchten Sie den Paket-Cache bereinigen?" "n"; then
        pkg_clean_cache
    fi
}

# Funktion zum Finden von Waisenpaketen alternativer Paketmanager
function pkg_find_orphans_alternative() {
    local alt_manager="$1"

    case $alt_manager in
        flatpak)
            echo -e "${LH_COLOR_INFO}Suche nach ungenutzten Flatpak-Laufzeitumgebungen...${LH_COLOR_RESET}"
            if flatpak list --columns=application,runtime | grep -q 'runtime'; then
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                flatpak list --columns=application,runtime | grep 'runtime'
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

                if lh_confirm_action "Möchten Sie ungenutzte Flatpak-Laufzeitumgebungen entfernen?" "n"; then
                    flatpak uninstall --unused -y
                    lh_log_msg "INFO" "Ungenutzte Flatpak-Laufzeitumgebungen wurden entfernt."
                fi
            else
                echo -e "${LH_COLOR_INFO}Keine ungenutzten Flatpak-Laufzeitumgebungen gefunden.${LH_COLOR_RESET}"
            fi
            ;;
        snap)
            echo -e "${LH_COLOR_INFO}Überprüfe alte Snap-Pakete...${LH_COLOR_RESET}"
            local old_snaps=$(snap list --all | awk '{if($2 != "Revision") print $1}' | sort | uniq -d)
            if [ -n "$old_snaps" ]; then
                echo -e "${LH_COLOR_INFO}Folgende Snaps haben alte Revisionen, die entfernt werden können:${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                for snap_name in $old_snaps; do
                    snap list "$snap_name" --all
                done
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

                if lh_confirm_action "Möchten Sie alte Snap-Revisionen entfernen?" "n"; then
                    for snap_name in $old_snaps; do
                        $LH_SUDO_CMD snap remove "$snap_name" --revision=$(snap list "$snap_name" --all | awk 'NR>1 {print $3}' | sort -rn | tail -n +2 | head -1)
                    done
                    lh_log_msg "INFO" "Alte Snap-Revisionen wurden entfernt."
                fi
            else
                echo -e "${LH_COLOR_INFO}Keine alten Snap-Revisionen gefunden.${LH_COLOR_RESET}"
            fi
            ;;
        nix)
            echo -e "${LH_COLOR_INFO}Garbage Collection für Nix-Pakete...${LH_COLOR_RESET}"
            if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
                source "$HOME/.nix-profile/etc/profile.d/nix.sh"
            fi

            if nix-collect-garbage --dry-run 2>/dev/null | grep -q "will be freed:"; then
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                nix-collect-garbage --dry-run
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

                if lh_confirm_action "Möchten Sie die Garbage Collection für Nix durchführen?" "n"; then
                    nix-collect-garbage
                    lh_log_msg "INFO" "Nix Garbage Collection durchgeführt."
                fi
            else
                echo -e "${LH_COLOR_INFO}Keine nicht mehr benötigten Nix-Pakete gefunden.${LH_COLOR_RESET}"
            fi
            ;;
        appimage)
            echo -e "${LH_COLOR_INFO}AppImages müssen manuell überprüft werden.${LH_COLOR_RESET}"
            ;;
        *)
            lh_log_msg "WARN" "Unbekannter alternativer Paketmanager: $alt_manager"
            ;;
    esac
}

# Funktion zur Bereinigung des Paket-Caches
function pkg_clean_cache() {
    lh_print_header "Paket-Cache bereinigen"

    if [ -z "$LH_PKG_MANAGER" ]; then
        lh_log_msg "ERROR" "Kein unterstützter Paketmanager gefunden."
        echo -e "${LH_COLOR_ERROR}Fehler: Kein unterstützter Paketmanager gefunden.${LH_COLOR_RESET}"
        return 1
    fi

    echo -e "${LH_COLOR_INFO}Der Paket-Cache enthält heruntergeladene Pakete, die Speicherplatz belegen.${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_INFO}Das Bereinigen ist sicher, kann aber bei erneuter Installation gleicher Pakete zu erneutem Download führen.${LH_COLOR_RESET}"

    if ! lh_confirm_action "Möchten Sie den Paket-Cache bereinigen?" "n"; then
        lh_log_msg "INFO" "Bereinigung des Paket-Caches abgebrochen."
        return 0
    fi

    echo -e "${LH_COLOR_INFO}Bereinige Paket-Cache...${LH_COLOR_RESET}"

    case $LH_PKG_MANAGER in
        pacman)
            # Bietet verschiedene Optionen zur Cache-Bereinigung
            echo -e "${LH_COLOR_PROMPT}Wählen Sie die Bereinigungsoption:${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_MENU_NUMBER}1.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Nur nicht installierte Pakete entfernen (behält installierte Versionen)${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_MENU_NUMBER}2.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Alle Pakete außer den 3 neuesten Versionen entfernen${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_MENU_NUMBER}3.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Alles bereinigen (vollständige Bereinigung)${LH_COLOR_RESET}"

            read -p "$(echo -e "${LH_COLOR_PROMPT}Option (1-3): ${LH_COLOR_RESET}")" clean_option

            case $clean_option in
                1)
                    $LH_SUDO_CMD pacman -Sc
                    ;;
                2)
                    if command -v paccache >/dev/null 2>&1; then
                        $LH_SUDO_CMD paccache -r
                    else
                        echo -e "${LH_COLOR_INFO}paccache nicht gefunden. Installiere pacman-contrib...${LH_COLOR_RESET}"
                        $LH_SUDO_CMD pacman -S --noconfirm pacman-contrib
                        $LH_SUDO_CMD paccache -r
                    fi
                    ;;
                3)
                    $LH_SUDO_CMD pacman -Scc
                    ;;
                *)
                    echo -e "${LH_COLOR_WARNING}Ungültige Option. Verwende Option 1.${LH_COLOR_RESET}"
                    $LH_SUDO_CMD pacman -Sc
                    ;;
            esac
            ;;
        apt)
            $LH_SUDO_CMD apt clean
            $LH_SUDO_CMD apt autoclean
            ;;
        dnf)
            $LH_SUDO_CMD dnf clean all
            ;;
        yay)
            # Bietet ähnliche Optionen wie bei pacman
            echo -e "${LH_COLOR_PROMPT}Wählen Sie die Bereinigungsoption:${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_MENU_NUMBER}1.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Nur nicht installierte Pakete entfernen (behält installierte Versionen)${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_MENU_NUMBER}2.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Alles bereinigen (vollständige Bereinigung)${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_MENU_NUMBER}3.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}AUR-Build-Verzeichnisse bereinigen${LH_COLOR_RESET}"

            read -p "$(echo -e "${LH_COLOR_PROMPT}Option (1-3): ${LH_COLOR_RESET}")" clean_option

            case $clean_option in
                1)
                    yay -Sc
                    ;;
                2)
                    yay -Scc
                    ;;
                3)
                    yay -Scca
                    ;;
                *)
                    echo -e "${LH_COLOR_WARNING}Ungültige Option. Verwende Option 1.${LH_COLOR_RESET}"
                    yay -Sc
                    ;;
            esac
            ;;
        *)
            lh_log_msg "ERROR" "Unbekannter Paketmanager: $LH_PKG_MANAGER"
            echo -e "${LH_COLOR_ERROR}Fehler: Unbekannter Paketmanager: $LH_PKG_MANAGER${LH_COLOR_RESET}"
            return 1
            ;;
    esac

    # Cache alternativer Paketmanager bereinigen
    for alt_manager in "${LH_ALT_PKG_MANAGERS[@]}"; do
        if lh_confirm_action "Möchten Sie auch den $alt_manager-Cache bereinigen?" "n"; then
            pkg_clean_cache_alternative "$alt_manager"
        fi
    done

    lh_log_msg "INFO" "Paket-Cache wurde bereinigt."
    echo -e "${LH_COLOR_SUCCESS}Paket-Cache wurde bereinigt.${LH_COLOR_RESET}"
}

# Funktion zum Bereinigen des Caches alternativer Paketmanager
function pkg_clean_cache_alternative() {
    local alt_manager="$1"

    case $alt_manager in
        flatpak)
            echo -e "${LH_COLOR_INFO}Bereinige Flatpak-Cache...${LH_COLOR_RESET}"
            # Entferne nicht mehr benötigte Dateien
            if command -v flatpak >/dev/null 2>&1; then
                rm -rf ~/.local/share/flatpak/.ostree/repo/objects/*.*.filez 2>/dev/null
                lh_log_msg "INFO" "Flatpak-Cache wurde bereinigt."
            fi
            ;;
        snap)
            echo -e "${LH_COLOR_INFO}Snap-Cache wird automatisch von SnapD verwaltet.${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}Für eine tiefgreifende Bereinigung können Sie 'sudo snap set system snapshots.automatic.retention=no' verwenden.${LH_COLOR_RESET}"
            ;;
        nix)
            echo -e "${LH_COLOR_INFO}Bereinige Nix-Cache...${LH_COLOR_RESET}"
            if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
                source "$HOME/.nix-profile/etc/profile.d/nix.sh"
            fi

            if command -v nix-collect-garbage >/dev/null 2>&1; then
                nix-collect-garbage -d
                lh_log_msg "INFO" "Nix-Store wurde bereinigt."
            fi

            # Optional: Optimierung des Nix-Stores
            if lh_confirm_action "Möchten Sie auch den Nix-Store optimieren?" "n"; then
                nix-store --optimise
                lh_log_msg "INFO" "Nix-Store wurde optimiert."
            fi
            ;;
        appimage)
            echo -e "${LH_COLOR_INFO}AppImage-Cache ist minimal und muss nicht bereinigt werden.${LH_COLOR_RESET}"
            ;;
        *)
            lh_log_msg "WARN" "Unbekannter alternativer Paketmanager: $alt_manager"
            ;;
    esac
}

# Funktion zum Suchen und Installieren von Paketen
function pkg_search_install() {
    lh_print_header "Pakete suchen und installieren"

    if [ -z "$LH_PKG_MANAGER" ]; then
        lh_log_msg "ERROR" "Kein unterstützter Paketmanager gefunden."
        echo -e "${LH_COLOR_ERROR}Fehler: Kein unterstützter Paketmanager gefunden.${LH_COLOR_RESET}"
        return 1
    fi

    local package=$(lh_ask_for_input "Geben Sie den Namen oder ein Suchbegriff für das Paket ein")

    if [ -z "$package" ]; then
        echo -e "${LH_COLOR_INFO}Keine Eingabe. Operation abgebrochen.${LH_COLOR_RESET}"
        return 1
    fi

    echo -e "${LH_COLOR_INFO}Suche nach Paketen mit '$package'...${LH_COLOR_RESET}"

    case $LH_PKG_MANAGER in
        pacman)
            $LH_SUDO_CMD pacman -Ss "$package"
            local install_pkg=$(lh_ask_for_input "Geben Sie den genauen Namen des zu installierenden Pakets ein (oder 'abbrechen')")

            if [ "$install_pkg" = "abbrechen" ]; then
                echo -e "${LH_COLOR_INFO}Installation abgebrochen.${LH_COLOR_RESET}"
                return 0
            fi

            if lh_confirm_action "Möchten Sie $install_pkg installieren?" "y"; then
                $LH_SUDO_CMD pacman -S "$install_pkg"
            fi
            ;;
        apt)
            $LH_SUDO_CMD apt search "$package"
            local install_pkg=$(lh_ask_for_input "Geben Sie den genauen Namen des zu installierenden Pakets ein (oder 'abbrechen')")

            if [ "$install_pkg" = "abbrechen" ]; then
                echo -e "${LH_COLOR_INFO}Installation abgebrochen.${LH_COLOR_RESET}"
                return 0
            fi

            if lh_confirm_action "Möchten Sie $install_pkg installieren?" "y"; then
                $LH_SUDO_CMD apt install "$install_pkg"
            fi
            ;;
        dnf)
            $LH_SUDO_CMD dnf search "$package"
            local install_pkg=$(lh_ask_for_input "Geben Sie den genauen Namen des zu installierenden Pakets ein (oder 'abbrechen')")

            if [ "$install_pkg" = "abbrechen" ]; then
                echo -e "${LH_COLOR_INFO}Installation abgebrochen.${LH_COLOR_RESET}"
                return 0
            fi

            if lh_confirm_action "Möchten Sie $install_pkg installieren?" "y"; then
                $LH_SUDO_CMD dnf install "$install_pkg"
            fi
            ;;
        yay)
            yay -Ss "$package"
            local install_pkg=$(lh_ask_for_input "Geben Sie den genauen Namen des zu installierenden Pakets ein (oder 'abbrechen')")

            if [ "$install_pkg" = "abbrechen" ]; then
                echo -e "${LH_COLOR_INFO}Installation abgebrochen.${LH_COLOR_RESET}"
                return 0
            fi

            if lh_confirm_action "Möchten Sie $install_pkg installieren?" "y"; then
                yay -S "$install_pkg"
            fi
            ;;
        *)
            lh_log_msg "ERROR" "Unbekannter Paketmanager: $LH_PKG_MANAGER"
            echo -e "${LH_COLOR_ERROR}Fehler: Unbekannter Paketmanager: $LH_PKG_MANAGER${LH_COLOR_RESET}"
            return 1
            ;;
    esac

    # Option, auch in alternativen Paketmanagern zu suchen
    if [ ${#LH_ALT_PKG_MANAGERS[@]} -gt 0 ]; then
        echo ""
        if lh_confirm_action "Möchten Sie auch in alternativen Paketquellen suchen?" "n"; then
            pkg_search_install_alternative "$package"
        fi
    fi
}

# Funktion zum Suchen und Installieren in alternativen Paketquellen
function pkg_search_install_alternative() {
    local package="$1"

    echo ""
    echo -e "${LH_COLOR_INFO}Verfügbare alternative Paketquellen:${LH_COLOR_RESET}"
    local counter=1
    for alt_manager in "${LH_ALT_PKG_MANAGERS[@]}"; do
        echo -e "${LH_COLOR_MENU_NUMBER}$counter.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$alt_manager${LH_COLOR_RESET}"
        ((counter++))
    done
    echo -e "${LH_COLOR_MENU_NUMBER}0.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Zurück${LH_COLOR_RESET}"

    read -p "$(echo -e "${LH_COLOR_PROMPT}Wählen Sie eine Paketquelle (0-$((${#LH_ALT_PKG_MANAGERS[@]}))): ${LH_COLOR_RESET}")" choice

    if [ "$choice" -eq 0 ]; then
        return 0
    fi

    if [ "$choice" -gt 0 ] && [ "$choice" -le ${#LH_ALT_PKG_MANAGERS[@]} ]; then
        local selected_manager="${LH_ALT_PKG_MANAGERS[$((choice-1))]}"

        case $selected_manager in
            flatpak)
                echo -e "${LH_COLOR_INFO}Suche in Flatpak nach '$package'...${LH_COLOR_RESET}"
                if flatpak search "$package" | grep -q .; then
                    flatpak search "$package"

                    local install_pkg=$(lh_ask_for_input "Geben Sie die genaue Anwendungs-ID ein (oder 'abbrechen')")

                    if [ "$install_pkg" != "abbrechen" ]; then
                        if lh_confirm_action "Möchten Sie $install_pkg von Flatpak installieren?" "y"; then
                            flatpak install "$install_pkg"
                        fi
                    fi
                else
                    echo -e "${LH_COLOR_INFO}Keine Flatpak-Pakete für '$package' gefunden.${LH_COLOR_RESET}"
                fi
                ;;
            snap)
                echo -e "${LH_COLOR_INFO}Suche in Snap nach '$package'...${LH_COLOR_RESET}"
                snap find "$package"

                local install_pkg=$(lh_ask_for_input "Geben Sie den genauen Snap-Namen ein (oder 'abbrechen')")

                if [ "$install_pkg" != "abbrechen" ]; then
                    if lh_confirm_action "Möchten Sie $install_pkg von Snap installieren?" "y"; then
                        $LH_SUDO_CMD snap install "$install_pkg"
                    fi
                fi
                ;;
            nix)
                echo -e "${LH_COLOR_INFO}Suche in Nix nach '$package'...${LH_COLOR_RESET}"
                if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
                    source "$HOME/.nix-profile/etc/profile.d/nix.sh"
                fi

                nix search nixpkgs "$package"

                local install_pkg=$(lh_ask_for_input "Geben Sie den genauen Nix-Paketnamen ein (oder 'abbrechen')")

                if [ "$install_pkg" != "abbrechen" ]; then
                    if lh_confirm_action "Möchten Sie $install_pkg von Nix installieren?" "y"; then
                        nix-env -iA "nixpkgs.$install_pkg"
                    fi
                fi
                ;;
            appimage)
                echo -e "${LH_COLOR_INFO}Für AppImages empfehlen wir direkte Downloads von den Anbieter-Websites.${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_INFO}Ein zentrales Repository wie https://appimage.github.io/apps/ kann hilfreich sein.${LH_COLOR_RESET}"
                ;;
            *)
                lh_log_msg "WARN" "Unbekannter alternativer Paketmanager: $selected_manager"
                ;;
        esac
    else
        echo -e "${LH_COLOR_ERROR}Ungültige Auswahl.${LH_COLOR_RESET}"
    fi
}

# Funktion zum Anzeigen installierter Pakete
function pkg_list_installed() {
    lh_print_header "Installierte Pakete anzeigen"
    if [ -z "$LH_PKG_MANAGER" ]; then
        lh_log_msg "ERROR" "Kein unterstützter Paketmanager gefunden."
        echo -e "${LH_COLOR_ERROR}Fehler: Kein unterstützter Paketmanager gefunden.${LH_COLOR_RESET}"
        return 1
    fi

    echo -e "${LH_COLOR_PROMPT}Wie möchten Sie die installierten Pakete anzeigen?${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_MENU_NUMBER}1.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Alle installierten Pakete auflisten${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_MENU_NUMBER}2.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Nach installierten Paketen suchen${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_MENU_NUMBER}3.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Nur kürzlich installierte Pakete anzeigen${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_MENU_NUMBER}4.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Installierte Pakete aus alternativen Quellen anzeigen${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_MENU_NUMBER}5.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Abbrechen${LH_COLOR_RESET}"

    read -p "$(echo -e "${LH_COLOR_PROMPT}Option (1-5): ${LH_COLOR_RESET}")" list_option

    case $list_option in
        1)
            case $LH_PKG_MANAGER in
                pacman)
                    echo -e "${LH_COLOR_INFO}Alle installierten Pakete:${LH_COLOR_RESET}"
                    pacman -Q | less
                    ;;
                apt)
                    echo -e "${LH_COLOR_INFO}Alle installierten Pakete:${LH_COLOR_RESET}"
                    dpkg-query -l | less
                    ;;
                dnf)
                    echo -e "${LH_COLOR_INFO}Alle installierten Pakete:${LH_COLOR_RESET}"
                    dnf list installed | less
                    ;;
                yay)
                    echo -e "${LH_COLOR_INFO}Alle installierten Pakete (reguläre Repositorien):${LH_COLOR_RESET}"
                    pacman -Q | less

                    if lh_confirm_action "Möchten Sie auch die AUR-Pakete separat auflisten?" "y"; then
                        echo -e "${LH_COLOR_INFO}Installierte AUR-Pakete:${LH_COLOR_RESET}"
                        pacman -Qm | less
                    fi
                    ;;
                *)
                    lh_log_msg "ERROR" "Unbekannter Paketmanager: $LH_PKG_MANAGER"
                    echo -e "${LH_COLOR_ERROR}Fehler: Unbekannter Paketmanager: $LH_PKG_MANAGER${LH_COLOR_RESET}"
                    return 1
                    ;;
            esac
            ;;
        2)
            local search_term=$(lh_ask_for_input "Geben Sie einen Suchbegriff ein")
            if [ -z "$search_term" ]; then
                echo -e "${LH_COLOR_INFO}Keine Eingabe. Operation abgebrochen.${LH_COLOR_RESET}"
                return 1
            fi

            case $LH_PKG_MANAGER in
                pacman)
                    echo -e "${LH_COLOR_INFO}Installierte Pakete, die '$search_term' enthalten:${LH_COLOR_RESET}"
                    pacman -Q | grep -i "$search_term"
                    ;;
                apt)
                    echo -e "${LH_COLOR_INFO}Installierte Pakete, die '$search_term' enthalten:${LH_COLOR_RESET}"
                    dpkg-query -l | grep -i "$search_term"
                    ;;
                dnf)
                    echo -e "${LH_COLOR_INFO}Installierte Pakete, die '$search_term' enthalten:${LH_COLOR_RESET}"
                    dnf list installed | grep -i "$search_term"
                    ;;
                yay)
                    echo -e "${LH_COLOR_INFO}Installierte Pakete, die '$search_term' enthalten:${LH_COLOR_RESET}"
                    pacman -Q | grep -i "$search_term"
                    ;;
                *)
                    lh_log_msg "ERROR" "Unbekannter Paketmanager: $LH_PKG_MANAGER"
                    echo -e "${LH_COLOR_ERROR}Fehler: Unbekannter Paketmanager: $LH_PKG_MANAGER${LH_COLOR_RESET}"
                    return 1
                    ;;
            esac
            ;;
        3)
            case $LH_PKG_MANAGER in
                pacman)
                    if command -v expac >/dev/null 2>&1; then
                        echo -e "${LH_COLOR_INFO}Kürzlich installierte Pakete (letzte 20):${LH_COLOR_RESET}"
                        expac --timefmt='%Y-%m-%d %T' '%l\t%n' | sort -r | head -n 20
                    else
                        echo -e "${LH_COLOR_INFO}expac ist nicht installiert. Installiere jetzt...${LH_COLOR_RESET}"
                        $LH_SUDO_CMD pacman -S --noconfirm expac
                        echo -e "${LH_COLOR_INFO}Kürzlich installierte Pakete (letzte 20):${LH_COLOR_RESET}"
                        expac --timefmt='%Y-%m-%d %T' '%l\t%n' | sort -r | head -n 20
                    fi
                    ;;
                apt)
                    echo "Kürzlich installierte Pakete:"
                    grep " install " /var/log/dpkg.log | tail -n 20
                    ;;
                dnf)
                    echo -e "${LH_COLOR_INFO}Kürzlich installierte Pakete:${LH_COLOR_RESET}"
                    dnf history | head -n 20
                    ;;
                yay)
                    if command -v expac >/dev/null 2>&1; then
                        echo -e "${LH_COLOR_INFO}Kürzlich installierte Pakete (letzte 20):${LH_COLOR_RESET}"
                        expac --timefmt='%Y-%m-%d %T' '%l\t%n' | sort -r | head -n 20
                    else
                        echo -e "${LH_COLOR_INFO}expac ist nicht installiert. Installiere jetzt...${LH_COLOR_RESET}"
                        $LH_SUDO_CMD pacman -S --noconfirm expac
                        echo -e "${LH_COLOR_INFO}Kürzlich installierte Pakete (letzte 20):${LH_COLOR_RESET}"
                        expac --timefmt='%Y-%m-%d %T' '%l\t%n' | sort -r | head -n 20
                    fi
                    ;;
                *)
                    lh_log_msg "ERROR" "Unbekannter Paketmanager: $LH_PKG_MANAGER"
                    echo -e "${LH_COLOR_ERROR}Fehler: Unbekannter Paketmanager: $LH_PKG_MANAGER${LH_COLOR_RESET}"
                    return 1
                    ;;
            esac
            ;;
        4)
            pkg_list_installed_alternative
            ;;
        5)
            echo -e "${LH_COLOR_INFO}Operation abgebrochen.${LH_COLOR_RESET}"
            return 0
            ;;
        *)
            echo -e "${LH_COLOR_ERROR}Ungültige Option. Operation abgebrochen.${LH_COLOR_RESET}"
            return 1
            ;;
    esac
}

# Funktion zum Anzeigen installierter Pakete aus alternativen Quellen
function pkg_list_installed_alternative() {
    if [ ${#LH_ALT_PKG_MANAGERS[@]} -eq 0 ]; then
        echo -e "${LH_COLOR_INFO}Keine alternativen Paketmanager gefunden.${LH_COLOR_RESET}"
        return 0
    fi

    echo ""
    echo -e "${LH_COLOR_INFO}Verfügbare alternative Paketquellen:${LH_COLOR_RESET}"
    local counter=1
    for alt_manager in "${LH_ALT_PKG_MANAGERS[@]}"; do
        echo -e "${LH_COLOR_MENU_NUMBER}$counter.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$alt_manager${LH_COLOR_RESET}"
        ((counter++))
    done
    echo -e "${LH_COLOR_MENU_NUMBER}0.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Zurück${LH_COLOR_RESET}"

    read -p "$(echo -e "${LH_COLOR_PROMPT}Wählen Sie eine Paketquelle (0-$((${#LH_ALT_PKG_MANAGERS[@]}))): ${LH_COLOR_RESET}")" choice

    if [ "$choice" -eq 0 ]; then
        return 0
    fi

    if [ "$choice" -gt 0 ] && [ "$choice" -le ${#LH_ALT_PKG_MANAGERS[@]} ]; then
        local selected_manager="${LH_ALT_PKG_MANAGERS[$((choice-1))]}"

        echo ""
        case $selected_manager in
            flatpak)
                echo -e "${LH_COLOR_INFO}Installierte Flatpak-Anwendungen:${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------------${LH_COLOR_RESET}"
                flatpak list --app | less
                echo ""
                echo -e "${LH_COLOR_INFO}Installierte Flatpak-Laufzeiten:${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------------${LH_COLOR_RESET}"
                flatpak list --runtime | less
                ;;
            snap)
                echo -e "${LH_COLOR_INFO}Installierte Snap-Pakete:${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}------------------------${LH_COLOR_RESET}"
                snap list | less
                ;;
            nix)
                echo -e "${LH_COLOR_INFO}Installierte Nix-Pakete:${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}-----------------------${LH_COLOR_RESET}"
                if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
                    source "$HOME/.nix-profile/etc/profile.d/nix.sh"
                fi
                nix-env -q | less
                ;;
            appimage)
                echo -e "${LH_COLOR_INFO}Gefundene AppImages:${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}-------------------${LH_COLOR_RESET}"
                if [ -d "$HOME/.local/bin" ]; then
                    find "$HOME/.local/bin" -name "*.AppImage" -printf '%p\t%TY-%Tm-%Td %TH:%TM\n' | sort
                fi
                echo ""
                echo -e "${LH_COLOR_INFO}Hinweis: Es können AppImages an anderen Orten installiert sein.${LH_COLOR_RESET}"
                ;;
            *)
                lh_log_msg "WARN" "Unbekannter alternativer Paketmanager: $selected_manager"
                ;;
        esac
    else
        echo -e "${LH_COLOR_ERROR}Ungültige Auswahl.${LH_COLOR_RESET}"
    fi
}

# Funktion zum Anzeigen des Paketmanager-Logs
function pkg_show_logs() {
    lh_print_header "Paketmanager-Logs anzeigen"
    if [ -z "$LH_PKG_MANAGER" ]; then
        lh_log_msg "ERROR" "Kein unterstützter Paketmanager gefunden."
        echo -e "${LH_COLOR_ERROR}Fehler: Kein unterstützter Paketmanager gefunden.${LH_COLOR_RESET}"
        return 1
    fi

    case $LH_PKG_MANAGER in
        pacman)
            if [ -f /var/log/pacman.log ]; then
                echo -e "${LH_COLOR_INFO}Letzte 50 Einträge des pacman-Logs:${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                tail -n 50 /var/log/pacman.log
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

                if lh_confirm_action "Möchten Sie nach einem bestimmten Paket im Log suchen?" "n"; then
                    local package=$(lh_ask_for_input "Geben Sie den Namen des Pakets ein")
                    echo -e "${LH_COLOR_INFO}Einträge für $package:${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                    grep "$package" /var/log/pacman.log | tail -n 50
                    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                fi
            else
                echo -e "${LH_COLOR_WARNING}Die Logdatei /var/log/pacman.log wurde nicht gefunden.${LH_COLOR_RESET}"
            fi
            ;;
        apt)
            local apt_logs=()
            if [ -f /var/log/apt/history.log ]; then
                apt_logs+=("/var/log/apt/history.log")
            fi
            if [ -f /var/log/apt/term.log ]; then
                apt_logs+=("/var/log/apt/term.log")
            fi
            if [ -f /var/log/dpkg.log ]; then
                apt_logs+=("/var/log/dpkg.log")
            fi

            if [ ${#apt_logs[@]} -eq 0 ]; then
                echo -e "${LH_COLOR_WARNING}Keine apt/dpkg-Logs gefunden.${LH_COLOR_RESET}"
                return 1
            fi

            echo -e "${LH_COLOR_INFO}Verfügbare Logs:${LH_COLOR_RESET}"
            for ((i=0; i<${#apt_logs[@]}; i++)); do
                echo -e "${LH_COLOR_MENU_NUMBER}$((i+1)).${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}${apt_logs[$i]}${LH_COLOR_RESET}"
            done

            read -p "$(echo -e "${LH_COLOR_PROMPT}Wählen Sie ein Log (1-${#apt_logs[@]}): ${LH_COLOR_RESET}")" log_choice

            if ! [[ "$log_choice" =~ ^[0-9]+$ ]] || [ "$log_choice" -lt 1 ] || [ "$log_choice" -gt ${#apt_logs[@]} ]; then
                echo -e "${LH_COLOR_ERROR}Ungültige Auswahl.${LH_COLOR_RESET}"
                return 1
            fi

            local selected_log="${apt_logs[$((log_choice-1))]}"
            echo -e "${LH_COLOR_INFO}Letzte 50 Einträge von $selected_log:${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
            tail -n 50 "$selected_log"
            echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

            if lh_confirm_action "Möchten Sie nach einem bestimmten Paket im Log suchen?" "n"; then
                local package=$(lh_ask_for_input "Geben Sie den Namen des Pakets ein")
                echo -e "${LH_COLOR_INFO}Einträge für $package:${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                grep "$package" "$selected_log" | tail -n 50
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
            fi
            ;;
        dnf)
            if [ -d /var/log/dnf ]; then
                echo -e "${LH_COLOR_INFO}DNF-Logdateien:${LH_COLOR_RESET}"
                ls -la /var/log/dnf/

                if lh_confirm_action "Möchten Sie die neueste Logdatei anzeigen?" "y"; then
                    local newest_log=$(ls -t /var/log/dnf/dnf.log* | head -n 1)
                    echo -e "${LH_COLOR_INFO}Letzte 50 Einträge von $newest_log:${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                    tail -n 50 "$newest_log"
                    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                fi

                if lh_confirm_action "Möchten Sie nach einem bestimmten Paket im Log suchen?" "n"; then
                    local package=$(lh_ask_for_input "Geben Sie den Namen des Pakets ein")
                    echo -e "${LH_COLOR_INFO}Einträge für $package:${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                    grep "$package" /var/log/dnf/dnf.log* | tail -n 50
                    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                fi
            else
                echo -e "${LH_COLOR_WARNING}Keine DNF-Logs gefunden in /var/log/dnf.${LH_COLOR_RESET}"
            fi
            ;;
        yay)
            # yay verwendet auch pacman.log für reguläre Pakete
            if [ -f /var/log/pacman.log ]; then
                echo -e "${LH_COLOR_INFO}Letzte 50 Einträge des pacman-Logs:${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                tail -n 50 /var/log/pacman.log
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

                if lh_confirm_action "Möchten Sie nach einem bestimmten Paket im Log suchen?" "n"; then
                    local package=$(lh_ask_for_input "Geben Sie den Namen des Pakets ein")
                    echo -e "${LH_COLOR_INFO}Einträge für $package:${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                    grep "$package" /var/log/pacman.log | tail -n 50
                    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                fi
            else
                echo -e "${LH_COLOR_WARNING}Die Logdatei /var/log/pacman.log wurde nicht gefunden.${LH_COLOR_RESET}"
            fi
            ;;
        *)
            lh_log_msg "ERROR" "Unbekannter Paketmanager: $LH_PKG_MANAGER"
            echo -e "${LH_COLOR_ERROR}Fehler: Unbekannter Paketmanager: $LH_PKG_MANAGER${LH_COLOR_RESET}"
            return 1
            ;;
    esac

    # Option für Logs alternativer Paketmanager
    if [ ${#LH_ALT_PKG_MANAGERS[@]} -gt 0 ]; then
        echo ""
        if lh_confirm_action "Möchten Sie auch Logs alternativer Paketmanager anzeigen?" "n"; then
            pkg_show_logs_alternative
        fi
    fi
}

# Funktion zum Anzeigen von Logs alternativer Paketmanager
function pkg_show_logs_alternative() {
    echo ""
    echo -e "${LH_COLOR_INFO}Verfügbare alternative Paketquellen:${LH_COLOR_RESET}"
    local counter=1
    for alt_manager in "${LH_ALT_PKG_MANAGERS[@]}"; do
        echo -e "${LH_COLOR_MENU_NUMBER}$counter.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$alt_manager${LH_COLOR_RESET}"
        ((counter++))
    done
    echo -e "${LH_COLOR_MENU_NUMBER}0.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Zurück${LH_COLOR_RESET}"

    read -p "$(echo -e "${LH_COLOR_PROMPT}Wählen Sie eine Paketquelle (0-$((${#LH_ALT_PKG_MANAGERS[@]}))): ${LH_COLOR_RESET}")" choice

    if [ "$choice" -eq 0 ]; then
        return 0
    fi

    if [ "$choice" -gt 0 ] && [ "$choice" -le ${#LH_ALT_PKG_MANAGERS[@]} ]; then
        local selected_manager="${LH_ALT_PKG_MANAGERS[$((choice-1))]}"

        echo ""
        case $selected_manager in
            flatpak)
                echo -e "${LH_COLOR_INFO}Flatpak Aktivitätslogs:${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}----------------------${LH_COLOR_RESET}"
                if journalctl --no-pager -u flatpak-system-helper 2>/dev/null | grep -q .; then
                    journalctl --no-pager -u flatpak-system-helper -n 50
                else
                    echo -e "${LH_COLOR_INFO}Keine systemweiten Flatpak-Logs verfügbar.${LH_COLOR_RESET}"
                fi
                echo ""
                echo -e "${LH_COLOR_INFO}Letzte Flatpak-Befehle:${LH_COLOR_RESET}"
                if [ -f "$HOME/.var/app/*/data/flatpak/.local/state/flatpak/history" ]; then
                    find "$HOME/.var/app" -name "*history*" | while read -r history_file; do
                        if [ -f "$history_file" ]; then
                            echo -e "${LH_COLOR_INFO}Historie aus $history_file:${LH_COLOR_RESET}"
                            tail -n 10 "$history_file"
                        fi
                    done
                fi
                ;;
            snap)
                echo -e "${LH_COLOR_INFO}Snap-Logs:${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}---------${LH_COLOR_RESET}"
                if journalctl --no-pager -u snapd 2>/dev/null | grep -q .; then
                    journalctl --no-pager -u snapd -n 50
                else
                    echo -e "${LH_COLOR_INFO}Keine Snap-Logs via journalctl verfügbar.${LH_COLOR_RESET}"
                fi
                echo ""
                # Snap-spezifische Logs
                if [ -d /var/log/snappy ]; then
                    echo -e "${LH_COLOR_INFO}Snap-System-Logs:${LH_COLOR_RESET}"
                    ls -la /var/log/snappy/
                fi
                ;;
            nix)
                echo -e "${LH_COLOR_INFO}Nix Aktivitätslogs:${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}------------------${LH_COLOR_RESET}"
                # Nix-Daemon Logs
                if journalctl --no-pager -u nix-daemon 2>/dev/null | grep -q .; then
                    journalctl --no-pager -u nix-daemon -n 50
                else
                    echo -e "${LH_COLOR_INFO}Keine Nix-Daemon-Logs verfügbar.${LH_COLOR_RESET}"
                fi
                echo ""
                # Benutzer-spezifische Nix-Logs
                if [ -d "$HOME/.nix-defexpr/channels" ]; then
                    echo -e "${LH_COLOR_INFO}Nix-Channel-Geschichte:${LH_COLOR_RESET}"
                    find "$HOME/.nix-defexpr" -name "*generation*" | while read -r gen_file; do
                        if [ -f "$gen_file" ]; then
                            echo -e "${LH_COLOR_INFO}Generation: $gen_file${LH_COLOR_RESET}"
                            cat "$gen_file"
                        fi
                    done
                fi
                ;;
            appimage)
                echo -e "${LH_COLOR_INFO}AppImages haben keine zentralen Logs.${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_INFO}Überprüfen Sie individuelle Anwendungslogs in:${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_INFO}  - ~/.local/share/applications/${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_INFO}  - ~/.cache/${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_INFO}  - Anwendungsspezifische Verzeichnisse${LH_COLOR_RESET}"
                ;;
            *)
                lh_log_msg "WARN" "Unbekannter alternativer Paketmanager: $selected_manager"
                ;;
        esac
    else
        echo -e "${LH_COLOR_ERROR}Ungültige Auswahl.${LH_COLOR_RESET}"
    fi
}

# Hauptfunktion des Moduls: Untermenü anzeigen und Aktionen steuern
function package_management_menu() {
    # Sicherstellen, dass der Paketmanager erkannt wurde
    if [ -z "$LH_PKG_MANAGER" ]; then
        lh_detect_package_manager
    fi

    # Alternative Paketmanager bei Start erkennen, falls nicht bereits geschehen
    if [ ${#LH_ALT_PKG_MANAGERS[@]} -eq 0 ]; then
        lh_detect_alternative_managers
    fi

    while true; do
        lh_print_header "Paketverwaltung & Updates"

        lh_print_menu_item 1 "Systemaktualisierung"
        lh_print_menu_item 2 "Nicht mehr benötigte Pakete suchen"
        lh_print_menu_item 3 "Paket-Cache bereinigen"
        lh_print_menu_item 4 "Pakete suchen und installieren"
        lh_print_menu_item 5 "Installierte Pakete anzeigen"
        lh_print_menu_item 6 "Paketmanager-Logs anzeigen"
        lh_print_menu_item 0 "Zurück zum Hauptmenü"
        echo ""

        # Zeige erkannte alternative Paketmanager
        if [ ${#LH_ALT_PKG_MANAGERS[@]} -gt 0 ]; then
            echo -e "${LH_COLOR_INFO}Erkannte alternative Paketquellen: ${LH_ALT_PKG_MANAGERS[*]}${LH_COLOR_RESET}"
            echo ""
        fi

        read -p "$(echo -e "${LH_COLOR_PROMPT}Wählen Sie eine Option: ${LH_COLOR_RESET}")" option
        
        case $option in
            1)
                pkg_system_update
                ;;
            2)
                pkg_find_orphans
                ;;
            3)
                pkg_clean_cache
                ;;
            4)
                pkg_search_install
                ;;
            5)
                pkg_list_installed
                ;;
            6)
                pkg_show_logs
                ;;
            0)
                lh_log_msg "INFO" "Zurück zum Hauptmenü."
                return 0
                ;;
            *)
                lh_log_msg "WARN" "Ungültige Auswahl: $option"
                echo -e "${LH_COLOR_ERROR}Ungültige Auswahl. Bitte versuchen Sie es erneut.${LH_COLOR_RESET}"
                ;;
        esac

        # Kurze Pause, damit Benutzer die Ausgabe lesen kann
        echo ""
        read -p "$(echo -e "${LH_COLOR_INFO}Drücken Sie eine Taste, um fortzufahren...${LH_COLOR_RESET}")" -n1 -s
        echo ""
    done
}

# Modul starten
package_management_menu
exit $?
