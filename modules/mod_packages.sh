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

    if [ -z "$LH_PKG_MANAGER" ]; then
        lh_log_msg "ERROR" "Kein unterstützter Paketmanager gefunden."
        echo "Fehler: Kein unterstützter Paketmanager gefunden."
        return 1
    fi

    echo "Es wird die Systemaktualisierung mit $LH_PKG_MANAGER durchgeführt."

    local auto_confirm=false
    if lh_confirm_action "Soll die Aktualisierung ohne weitere Bestätigung durchgeführt werden?" "n"; then
        auto_confirm=true
    fi

    echo "Beginne mit der Aktualisierung..."

    case $LH_PKG_MANAGER in
        pacman)
            if $auto_confirm; then
                $LH_SUDO_CMD pacman -Syu --noconfirm
            else
                $LH_SUDO_CMD pacman -Syu
            fi
            ;;
        apt)
            echo "Aktualisiere Paketquellen..."
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
        yay)
            if $auto_confirm; then
                yay -Syu --noconfirm
            else
                yay -Syu
            fi
            ;;
        *)
            lh_log_msg "ERROR" "Unbekannter Paketmanager: $LH_PKG_MANAGER"
            echo "Fehler: Unbekannter Paketmanager: $LH_PKG_MANAGER"
            return 1
            ;;
    esac

    local update_status=$?
    if [ $update_status -eq 0 ]; then
        lh_log_msg "INFO" "Systemaktualisierung erfolgreich abgeschlossen."
        echo "Systemaktualisierung erfolgreich abgeschlossen."

        # Schleife durch alle erkannten alternativen Paketmanager
        for alt_manager in "${LH_ALT_PKG_MANAGERS[@]}"; do
            echo ""
            if lh_confirm_action "Möchten Sie auch $alt_manager-Pakete aktualisieren?" "n"; then
                pkg_update_alternative "$alt_manager" "$auto_confirm"
            fi
        done
    else
        lh_log_msg "ERROR" "Systemaktualisierung fehlgeschlagen mit Fehlercode: $update_status"
        echo "Fehler: Systemaktualisierung fehlgeschlagen mit Fehlercode: $update_status"
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
            echo "Aktualisiere Flatpak-Pakete..."
            if [ "$auto_confirm" = "true" ]; then
                flatpak update -y
            else
                flatpak update
            fi
            ;;
        snap)
            echo "Aktualisiere Snap-Pakete..."
            $LH_SUDO_CMD snap refresh
            ;;
        nix)
            echo "Aktualisiere Nix-Pakete..."
            if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
                source "$HOME/.nix-profile/etc/profile.d/nix.sh"
            fi
            nix-env -u
            ;;
        appimage)
            echo "AppImage-Updates müssen manuell durchgeführt werden."
            echo "Bitte überprüfen Sie Ihre AppImage-Anwendungen:"
            if [ -d "$HOME/.local/bin" ]; then
                find "$HOME/.local/bin" -name "*.AppImage" -print
            fi
            echo "Weitere AppImage-Speicherorte können manuell überprüft werden."
            ;;
        *)
            lh_log_msg "WARN" "Unbekannter alternativer Paketmanager: $alt_manager"
            echo "Warnung: Unbekannter alternativer Paketmanager: $alt_manager"
            ;;
    esac
}

# Funktion zum Suchen und Entfernen von Waisenpaketen
function pkg_find_orphans() {
    lh_print_header "Nicht mehr benötigte Pakete suchen"

    if [ -z "$LH_PKG_MANAGER" ]; then
        lh_log_msg "ERROR" "Kein unterstützter Paketmanager gefunden."
        echo "Fehler: Kein unterstützter Paketmanager gefunden."
        return 1
    fi

    echo "Suche nach nicht mehr benötigten Paketen..."
    local orphaned_packages=""

    case $LH_PKG_MANAGER in
        pacman)
            orphaned_packages=$(pacman -Qdtq)
            if [ -n "$orphaned_packages" ]; then
                echo "Folgende Pakete sind Waisenpakete und können entfernt werden:"
                echo "--------------------------"
                echo "$orphaned_packages"
                echo "--------------------------"

                if lh_confirm_action "Möchten Sie diese Pakete entfernen?" "n"; then
                    $LH_SUDO_CMD pacman -Rns $orphaned_packages
                    lh_log_msg "INFO" "Waisenpakete wurden entfernt."
                else
                    lh_log_msg "INFO" "Entfernung der Waisenpakete abgebrochen."
                fi
            else
                echo "Keine Waisenpakete gefunden."
                lh_log_msg "INFO" "Keine Waisenpakete gefunden."
            fi
            ;;
        apt)
            echo "Überprüfung nicht mehr benötigter Pakete (apt autoremove):"
            echo "--------------------------"
            $LH_SUDO_CMD apt autoremove --dry-run
            echo "--------------------------"

            if lh_confirm_action "Möchten Sie diese Pakete entfernen?" "n"; then
                $LH_SUDO_CMD apt autoremove -y
                lh_log_msg "INFO" "Nicht mehr benötigte Pakete wurden entfernt."
            else
                lh_log_msg "INFO" "Entfernung nicht mehr benötigter Pakete abgebrochen."
            fi
            ;;
        dnf)
            echo "Überprüfung nicht mehr benötigter Pakete (dnf autoremove):"
            echo "--------------------------"
            $LH_SUDO_CMD dnf autoremove --assumeno
            echo "--------------------------"

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
                echo "Folgende Pakete sind Waisenpakete und können entfernt werden:"
                echo "--------------------------"
                echo "$orphaned_packages"
                echo "--------------------------"

                if lh_confirm_action "Möchten Sie diese Pakete entfernen?" "n"; then
                    yay -Rns $orphaned_packages
                    lh_log_msg "INFO" "Waisenpakete wurden entfernt."
                else
                    lh_log_msg "INFO" "Entfernung der Waisenpakete abgebrochen."
                fi
            else
                echo "Keine Waisenpakete gefunden."
                lh_log_msg "INFO" "Keine Waisenpakete gefunden."
            fi
            ;;
        *)
            lh_log_msg "ERROR" "Unbekannter Paketmanager: $LH_PKG_MANAGER"
            echo "Fehler: Unbekannter Paketmanager: $LH_PKG_MANAGER"
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
            echo "Suche nach ungenutzten Flatpak-Laufzeitumgebungen..."
            if flatpak list --columns=application,runtime | grep -q 'runtime'; then
                echo "--------------------------"
                flatpak list --columns=application,runtime | grep 'runtime'
                echo "--------------------------"

                if lh_confirm_action "Möchten Sie ungenutzte Flatpak-Laufzeitumgebungen entfernen?" "n"; then
                    flatpak uninstall --unused -y
                    lh_log_msg "INFO" "Ungenutzte Flatpak-Laufzeitumgebungen wurden entfernt."
                fi
            else
                echo "Keine ungenutzten Flatpak-Laufzeitumgebungen gefunden."
            fi
            ;;
        snap)
            echo "Überprüfe alte Snap-Pakete..."
            local old_snaps=$(snap list --all | awk '{if($2 != "Revision") print $1}' | sort | uniq -d)
            if [ -n "$old_snaps" ]; then
                echo "Folgende Snaps haben alte Revisionen, die entfernt werden können:"
                echo "--------------------------"
                for snap_name in $old_snaps; do
                    snap list "$snap_name" --all
                done
                echo "--------------------------"

                if lh_confirm_action "Möchten Sie alte Snap-Revisionen entfernen?" "n"; then
                    for snap_name in $old_snaps; do
                        $LH_SUDO_CMD snap remove "$snap_name" --revision=$(snap list "$snap_name" --all | awk 'NR>1 {print $3}' | sort -rn | tail -n +2 | head -1)
                    done
                    lh_log_msg "INFO" "Alte Snap-Revisionen wurden entfernt."
                fi
            else
                echo "Keine alten Snap-Revisionen gefunden."
            fi
            ;;
        nix)
            echo "Garbage Collection für Nix-Pakete..."
            if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
                source "$HOME/.nix-profile/etc/profile.d/nix.sh"
            fi

            if nix-collect-garbage --dry-run 2>/dev/null | grep -q "will be freed:"; then
                echo "--------------------------"
                nix-collect-garbage --dry-run
                echo "--------------------------"

                if lh_confirm_action "Möchten Sie die Garbage Collection für Nix durchführen?" "n"; then
                    nix-collect-garbage
                    lh_log_msg "INFO" "Nix Garbage Collection durchgeführt."
                fi
            else
                echo "Keine nicht mehr benötigten Nix-Pakete gefunden."
            fi
            ;;
        appimage)
            echo "AppImages müssen manuell überprüft werden."
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
        echo "Fehler: Kein unterstützter Paketmanager gefunden."
        return 1
    fi

    echo "Der Paket-Cache enthält heruntergeladene Pakete, die Speicherplatz belegen."
    echo "Das Bereinigen ist sicher, kann aber bei erneuter Installation gleicher Pakete zu erneutem Download führen."

    if ! lh_confirm_action "Möchten Sie den Paket-Cache bereinigen?" "n"; then
        lh_log_msg "INFO" "Bereinigung des Paket-Caches abgebrochen."
        return 0
    fi

    echo "Bereinige Paket-Cache..."

    case $LH_PKG_MANAGER in
        pacman)
            # Bietet verschiedene Optionen zur Cache-Bereinigung
            echo "Wählen Sie die Bereinigungsoption:"
            echo "1. Nur nicht installierte Pakete entfernen (behält installierte Versionen)"
            echo "2. Alle Pakete außer den 3 neuesten Versionen entfernen"
            echo "3. Alles bereinigen (vollständige Bereinigung)"

            read -p "Option (1-3): " clean_option

            case $clean_option in
                1)
                    $LH_SUDO_CMD pacman -Sc
                    ;;
                2)
                    if command -v paccache >/dev/null 2>&1; then
                        $LH_SUDO_CMD paccache -r
                    else
                        echo "paccache nicht gefunden. Installiere pacman-contrib..."
                        $LH_SUDO_CMD pacman -S --noconfirm pacman-contrib
                        $LH_SUDO_CMD paccache -r
                    fi
                    ;;
                3)
                    $LH_SUDO_CMD pacman -Scc
                    ;;
                *)
                    echo "Ungültige Option. Verwende Option 1."
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
            echo "Wählen Sie die Bereinigungsoption:"
            echo "1. Nur nicht installierte Pakete entfernen (behält installierte Versionen)"
            echo "2. Alles bereinigen (vollständige Bereinigung)"
            echo "3. AUR-Build-Verzeichnisse bereinigen"

            read -p "Option (1-3): " clean_option

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
                    echo "Ungültige Option. Verwende Option 1."
                    yay -Sc
                    ;;
            esac
            ;;
        *)
            lh_log_msg "ERROR" "Unbekannter Paketmanager: $LH_PKG_MANAGER"
            echo "Fehler: Unbekannter Paketmanager: $LH_PKG_MANAGER"
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
    echo "Paket-Cache wurde bereinigt."
}

# Funktion zum Bereinigen des Caches alternativer Paketmanager
function pkg_clean_cache_alternative() {
    local alt_manager="$1"

    case $alt_manager in
        flatpak)
            echo "Bereinige Flatpak-Cache..."
            # Entferne nicht mehr benötigte Dateien
            if command -v flatpak >/dev/null 2>&1; then
                rm -rf ~/.local/share/flatpak/.ostree/repo/objects/*.*.filez 2>/dev/null
                lh_log_msg "INFO" "Flatpak-Cache wurde bereinigt."
            fi
            ;;
        snap)
            echo "Snap-Cache wird automatisch von SnapD verwaltet."
            echo "Für eine tiefgreifende Bereinigung können Sie 'sudo snap set system snapshots.automatic.retention=no' verwenden."
            ;;
        nix)
            echo "Bereinige Nix-Cache..."
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
            echo "AppImage-Cache ist minimal und muss nicht bereinigt werden."
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
        echo "Fehler: Kein unterstützter Paketmanager gefunden."
        return 1
    fi

    local package=$(lh_ask_for_input "Geben Sie den Namen oder ein Suchbegriff für das Paket ein")

    if [ -z "$package" ]; then
        echo "Keine Eingabe. Operation abgebrochen."
        return 1
    fi

    echo "Suche nach Paketen mit '$package'..."

    case $LH_PKG_MANAGER in
        pacman)
            $LH_SUDO_CMD pacman -Ss "$package"

            local install_pkg=$(lh_ask_for_input "Geben Sie den genauen Namen des zu installierenden Pakets ein (oder 'abbrechen')")

            if [ "$install_pkg" = "abbrechen" ]; then
                echo "Installation abgebrochen."
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
                echo "Installation abgebrochen."
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
                echo "Installation abgebrochen."
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
                echo "Installation abgebrochen."
                return 0
            fi

            if lh_confirm_action "Möchten Sie $install_pkg installieren?" "y"; then
                yay -S "$install_pkg"
            fi
            ;;
        *)
            lh_log_msg "ERROR" "Unbekannter Paketmanager: $LH_PKG_MANAGER"
            echo "Fehler: Unbekannter Paketmanager: $LH_PKG_MANAGER"
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
    echo "Verfügbare alternative Paketquellen:"
    local counter=1
    for alt_manager in "${LH_ALT_PKG_MANAGERS[@]}"; do
        echo "$counter. $alt_manager"
        ((counter++))
    done
    echo "0. Zurück"

    read -p "Wählen Sie eine Paketquelle (0-$((${#LH_ALT_PKG_MANAGERS[@]}))): " choice

    if [ "$choice" -eq 0 ]; then
        return 0
    fi

    if [ "$choice" -gt 0 ] && [ "$choice" -le ${#LH_ALT_PKG_MANAGERS[@]} ]; then
        local selected_manager="${LH_ALT_PKG_MANAGERS[$((choice-1))]}"

        case $selected_manager in
            flatpak)
                echo "Suche in Flatpak nach '$package'..."
                if flatpak search "$package" | grep -q .; then
                    flatpak search "$package"

                    local install_pkg=$(lh_ask_for_input "Geben Sie die genaue Anwendungs-ID ein (oder 'abbrechen')")

                    if [ "$install_pkg" != "abbrechen" ]; then
                        if lh_confirm_action "Möchten Sie $install_pkg von Flatpak installieren?" "y"; then
                            flatpak install "$install_pkg"
                        fi
                    fi
                else
                    echo "Keine Flatpak-Pakete für '$package' gefunden."
                fi
                ;;
            snap)
                echo "Suche in Snap nach '$package'..."
                snap find "$package"

                local install_pkg=$(lh_ask_for_input "Geben Sie den genauen Snap-Namen ein (oder 'abbrechen')")

                if [ "$install_pkg" != "abbrechen" ]; then
                    if lh_confirm_action "Möchten Sie $install_pkg von Snap installieren?" "y"; then
                        $LH_SUDO_CMD snap install "$install_pkg"
                    fi
                fi
                ;;
            nix)
                echo "Suche in Nix nach '$package'..."
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
                echo "Für AppImages empfehlen wir direkte Downloads von den Anbieter-Websites."
                echo "Ein zentrales Repository wie https://appimage.github.io/apps/ kann hilfreich sein."
                ;;
            *)
                lh_log_msg "WARN" "Unbekannter alternativer Paketmanager: $selected_manager"
                ;;
        esac
    else
        echo "Ungültige Auswahl."
    fi
}

# Funktion zum Anzeigen installierter Pakete
function pkg_list_installed() {
    lh_print_header "Installierte Pakete anzeigen"

    if [ -z "$LH_PKG_MANAGER" ]; then
        lh_log_msg "ERROR" "Kein unterstützter Paketmanager gefunden."
        echo "Fehler: Kein unterstützter Paketmanager gefunden."
        return 1
    fi

    echo "Wie möchten Sie die installierten Pakete anzeigen?"
    echo "1. Alle installierten Pakete auflisten"
    echo "2. Nach installierten Paketen suchen"
    echo "3. Nur kürzlich installierte Pakete anzeigen"
    echo "4. Installierte Pakete aus alternativen Quellen anzeigen"
    echo "5. Abbrechen"

    read -p "Option (1-5): " list_option

    case $list_option in
        1)
            case $LH_PKG_MANAGER in
                pacman)
                    echo "Alle installierten Pakete:"
                    pacman -Q | less
                    ;;
                apt)
                    echo "Alle installierten Pakete:"
                    dpkg-query -l | less
                    ;;
                dnf)
                    echo "Alle installierten Pakete:"
                    dnf list installed | less
                    ;;
                yay)
                    echo "Alle installierten Pakete (reguläre Repositorien):"
                    pacman -Q | less

                    if lh_confirm_action "Möchten Sie auch die AUR-Pakete separat auflisten?" "y"; then
                        echo "Installierte AUR-Pakete:"
                        pacman -Qm | less
                    fi
                    ;;
                *)
                    lh_log_msg "ERROR" "Unbekannter Paketmanager: $LH_PKG_MANAGER"
                    echo "Fehler: Unbekannter Paketmanager: $LH_PKG_MANAGER"
                    return 1
                    ;;
            esac
            ;;
        2)
            local search_term=$(lh_ask_for_input "Geben Sie einen Suchbegriff ein")

            if [ -z "$search_term" ]; then
                echo "Keine Eingabe. Operation abgebrochen."
                return 1
            fi

            case $LH_PKG_MANAGER in
                pacman)
                    echo "Installierte Pakete, die '$search_term' enthalten:"
                    pacman -Q | grep -i "$search_term"
                    ;;
                apt)
                    echo "Installierte Pakete, die '$search_term' enthalten:"
                    dpkg-query -l | grep -i "$search_term"
                    ;;
                dnf)
                    echo "Installierte Pakete, die '$search_term' enthalten:"
                    dnf list installed | grep -i "$search_term"
                    ;;
                yay)
                    echo "Installierte Pakete, die '$search_term' enthalten:"
                    pacman -Q | grep -i "$search_term"
                    ;;
                *)
                    lh_log_msg "ERROR" "Unbekannter Paketmanager: $LH_PKG_MANAGER"
                    echo "Fehler: Unbekannter Paketmanager: $LH_PKG_MANAGER"
                    return 1
                    ;;
            esac
            ;;
        3)
            case $LH_PKG_MANAGER in
                pacman)
                    if command -v expac >/dev/null 2>&1; then
                        echo "Kürzlich installierte Pakete (letzte 20):"
                        expac --timefmt='%Y-%m-%d %T' '%l\t%n' | sort -r | head -n 20
                    else
                        echo "expac ist nicht installiert. Installiere jetzt..."
                        $LH_SUDO_CMD pacman -S --noconfirm expac
                        echo "Kürzlich installierte Pakete (letzte 20):"
                        expac --timefmt='%Y-%m-%d %T' '%l\t%n' | sort -r | head -n 20
                    fi
                    ;;
                apt)
                    echo "Kürzlich installierte Pakete:"
                    grep " install " /var/log/dpkg.log | tail -n 20
                    ;;
                dnf)
                    echo "Kürzlich installierte Pakete:"
                    dnf history | head -n 20
                    ;;
                yay)
                    if command -v expac >/dev/null 2>&1; then
                        echo "Kürzlich installierte Pakete (letzte 20):"
                        expac --timefmt='%Y-%m-%d %T' '%l\t%n' | sort -r | head -n 20
                    else
                        echo "expac ist nicht installiert. Installiere jetzt..."
                        $LH_SUDO_CMD pacman -S --noconfirm expac
                        echo "Kürzlich installierte Pakete (letzte 20):"
                        expac --timefmt='%Y-%m-%d %T' '%l\t%n' | sort -r | head -n 20
                    fi
                    ;;
                *)
                    lh_log_msg "ERROR" "Unbekannter Paketmanager: $LH_PKG_MANAGER"
                    echo "Fehler: Unbekannter Paketmanager: $LH_PKG_MANAGER"
                    return 1
                    ;;
            esac
            ;;
        4)
            pkg_list_installed_alternative
            ;;
        5)
            echo "Operation abgebrochen."
            return 0
            ;;
        *)
            echo "Ungültige Option. Operation abgebrochen."
            return 1
            ;;
    esac
}

# Funktion zum Anzeigen installierter Pakete aus alternativen Quellen
function pkg_list_installed_alternative() {
    if [ ${#LH_ALT_PKG_MANAGERS[@]} -eq 0 ]; then
        echo "Keine alternativen Paketmanager gefunden."
        return 0
    fi

    echo ""
    echo "Verfügbare alternative Paketquellen:"
    local counter=1
    for alt_manager in "${LH_ALT_PKG_MANAGERS[@]}"; do
        echo "$counter. $alt_manager"
        ((counter++))
    done
    echo "0. Zurück"

    read -p "Wählen Sie eine Paketquelle (0-$((${#LH_ALT_PKG_MANAGERS[@]}))): " choice

    if [ "$choice" -eq 0 ]; then
        return 0
    fi

    if [ "$choice" -gt 0 ] && [ "$choice" -le ${#LH_ALT_PKG_MANAGERS[@]} ]; then
        local selected_manager="${LH_ALT_PKG_MANAGERS[$((choice-1))]}"

        echo ""
        case $selected_manager in
            flatpak)
                echo "Installierte Flatpak-Anwendungen:"
                echo "--------------------------------"
                flatpak list --app | less
                echo ""
                echo "Installierte Flatpak-Laufzeiten:"
                echo "--------------------------------"
                flatpak list --runtime | less
                ;;
            snap)
                echo "Installierte Snap-Pakete:"
                echo "------------------------"
                snap list | less
                ;;
            nix)
                echo "Installierte Nix-Pakete:"
                echo "-----------------------"
                if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
                    source "$HOME/.nix-profile/etc/profile.d/nix.sh"
                fi
                nix-env -q | less
                ;;
            appimage)
                echo "Gefundene AppImages:"
                echo "-------------------"
                if [ -d "$HOME/.local/bin" ]; then
                    find "$HOME/.local/bin" -name "*.AppImage" -printf '%p\t%TY-%Tm-%Td %TH:%TM\n' | sort
                fi
                echo ""
                echo "Hinweis: Es können AppImages an anderen Orten installiert sein."
                ;;
            *)
                lh_log_msg "WARN" "Unbekannter alternativer Paketmanager: $selected_manager"
                ;;
        esac
    else
        echo "Ungültige Auswahl."
    fi
}

# Funktion zum Anzeigen des Paketmanager-Logs
function pkg_show_logs() {
    lh_print_header "Paketmanager-Logs anzeigen"

    if [ -z "$LH_PKG_MANAGER" ]; then
        lh_log_msg "ERROR" "Kein unterstützter Paketmanager gefunden."
        echo "Fehler: Kein unterstützter Paketmanager gefunden."
        return 1
    fi

    case $LH_PKG_MANAGER in
        pacman)
            if [ -f /var/log/pacman.log ]; then
                echo "Letzte 50 Einträge des pacman-Logs:"
                echo "--------------------------"
                tail -n 50 /var/log/pacman.log
                echo "--------------------------"

                if lh_confirm_action "Möchten Sie nach einem bestimmten Paket im Log suchen?" "n"; then
                    local package=$(lh_ask_for_input "Geben Sie den Namen des Pakets ein")
                    echo "Einträge für $package:"
                    echo "--------------------------"
                    grep "$package" /var/log/pacman.log | tail -n 50
                    echo "--------------------------"
                fi
            else
                echo "Die Logdatei /var/log/pacman.log wurde nicht gefunden."
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
                echo "Keine apt/dpkg-Logs gefunden."
                return 1
            fi

            echo "Verfügbare Logs:"
            for ((i=0; i<${#apt_logs[@]}; i++)); do
                echo "$((i+1)). ${apt_logs[$i]}"
            done

            read -p "Wählen Sie ein Log (1-${#apt_logs[@]}): " log_choice

            if ! [[ "$log_choice" =~ ^[0-9]+$ ]] || [ "$log_choice" -lt 1 ] || [ "$log_choice" -gt ${#apt_logs[@]} ]; then
                echo "Ungültige Auswahl."
                return 1
            fi

            local selected_log="${apt_logs[$((log_choice-1))]}"
            echo "Letzte 50 Einträge von $selected_log:"
            echo "--------------------------"
            tail -n 50 "$selected_log"
            echo "--------------------------"

            if lh_confirm_action "Möchten Sie nach einem bestimmten Paket im Log suchen?" "n"; then
                local package=$(lh_ask_for_input "Geben Sie den Namen des Pakets ein")
                echo "Einträge für $package:"
                echo "--------------------------"
                grep "$package" "$selected_log" | tail -n 50
                echo "--------------------------"
            fi
            ;;
        dnf)
            if [ -d /var/log/dnf ]; then
                echo "DNF-Logdateien:"
                ls -la /var/log/dnf/

                if lh_confirm_action "Möchten Sie die neueste Logdatei anzeigen?" "y"; then
                    local newest_log=$(ls -t /var/log/dnf/dnf.log* | head -n 1)
                    echo "Letzte 50 Einträge von $newest_log:"
                    echo "--------------------------"
                    tail -n 50 "$newest_log"
                    echo "--------------------------"
                fi

                if lh_confirm_action "Möchten Sie nach einem bestimmten Paket im Log suchen?" "n"; then
                    local package=$(lh_ask_for_input "Geben Sie den Namen des Pakets ein")
                    echo "Einträge für $package:"
                    echo "--------------------------"
                    grep "$package" /var/log/dnf/dnf.log* | tail -n 50
                    echo "--------------------------"
                fi
            else
                echo "Keine DNF-Logs gefunden in /var/log/dnf."
            fi
            ;;
        yay)
            # yay verwendet auch pacman.log für reguläre Pakete
            if [ -f /var/log/pacman.log ]; then
                echo "Letzte 50 Einträge des pacman-Logs:"
                echo "--------------------------"
                tail -n 50 /var/log/pacman.log
                echo "--------------------------"

                if lh_confirm_action "Möchten Sie nach einem bestimmten Paket im Log suchen?" "n"; then
                    local package=$(lh_ask_for_input "Geben Sie den Namen des Pakets ein")
                    echo "Einträge für $package:"
                    echo "--------------------------"
                    grep "$package" /var/log/pacman.log | tail -n 50
                    echo "--------------------------"
                fi
            else
                echo "Die Logdatei /var/log/pacman.log wurde nicht gefunden."
            fi
            ;;
        *)
            lh_log_msg "ERROR" "Unbekannter Paketmanager: $LH_PKG_MANAGER"
            echo "Fehler: Unbekannter Paketmanager: $LH_PKG_MANAGER"
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
    echo "Verfügbare alternative Paketquellen:"
    local counter=1
    for alt_manager in "${LH_ALT_PKG_MANAGERS[@]}"; do
        echo "$counter. $alt_manager"
        ((counter++))
    done
    echo "0. Zurück"

    read -p "Wählen Sie eine Paketquelle (0-$((${#LH_ALT_PKG_MANAGERS[@]}))): " choice

    if [ "$choice" -eq 0 ]; then
        return 0
    fi

    if [ "$choice" -gt 0 ] && [ "$choice" -le ${#LH_ALT_PKG_MANAGERS[@]} ]; then
        local selected_manager="${LH_ALT_PKG_MANAGERS[$((choice-1))]}"

        echo ""
        case $selected_manager in
            flatpak)
                echo "Flatpak Aktivitätslogs:"
                echo "----------------------"
                if journalctl --no-pager -u flatpak-system-helper 2>/dev/null | grep -q .; then
                    journalctl --no-pager -u flatpak-system-helper -n 50
                else
                    echo "Keine systemweiten Flatpak-Logs verfügbar."
                fi
                echo ""
                echo "Letzte Flatpak-Befehle:"
                if [ -f "$HOME/.var/app/*/data/flatpak/.local/state/flatpak/history" ]; then
                    find "$HOME/.var/app" -name "*history*" | while read -r history_file; do
                        if [ -f "$history_file" ]; then
                            echo "Historie aus $history_file:"
                            tail -n 10 "$history_file"
                        fi
                    done
                fi
                ;;
            snap)
                echo "Snap-Logs:"
                echo "---------"
                if journalctl --no-pager -u snapd 2>/dev/null | grep -q .; then
                    journalctl --no-pager -u snapd -n 50
                else
                    echo "Keine Snap-Logs via journalctl verfügbar."
                fi
                echo ""
                # Snap-spezifische Logs
                if [ -d /var/log/snappy ]; then
                    echo "Snap-System-Logs:"
                    ls -la /var/log/snappy/
                fi
                ;;
            nix)
                echo "Nix Aktivitätslogs:"
                echo "------------------"
                # Nix-Daemon Logs
                if journalctl --no-pager -u nix-daemon 2>/dev/null | grep -q .; then
                    journalctl --no-pager -u nix-daemon -n 50
                else
                    echo "Keine Nix-Daemon-Logs verfügbar."
                fi
                echo ""
                # Benutzer-spezifische Nix-Logs
                if [ -d "$HOME/.nix-defexpr/channels" ]; then
                    echo "Nix-Channel-Geschichte:"
                    find "$HOME/.nix-defexpr" -name "*generation*" | while read -r gen_file; do
                        if [ -f "$gen_file" ]; then
                            echo "Generation: $gen_file"
                            cat "$gen_file"
                        fi
                    done
                fi
                ;;
            appimage)
                echo "AppImages haben keine zentralen Logs."
                echo "Überprüfen Sie individuelle Anwendungslogs in:"
                echo "  - ~/.local/share/applications/"
                echo "  - ~/.cache/"
                echo "  - Anwendungsspezifische Verzeichnisse"
                ;;
            *)
                lh_log_msg "WARN" "Unbekannter alternativer Paketmanager: $selected_manager"
                ;;
        esac
    else
        echo "Ungültige Auswahl."
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
            echo "Erkannte alternative Paketquellen: ${LH_ALT_PKG_MANAGERS[*]}"
            echo ""
        fi

        read -p "Wählen Sie eine Option: " option

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
                echo "Ungültige Auswahl. Bitte versuchen Sie es erneut."
                ;;
        esac

        # Kurze Pause, damit Benutzer die Ausgabe lesen kann
        echo ""
        read -p "Drücken Sie eine Taste, um fortzufahren..." -n1 -s
        echo ""
    done
}

# Modul starten
package_management_menu
exit $?
