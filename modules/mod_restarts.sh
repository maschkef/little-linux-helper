#!/bin/bash
#
# little-linux-helper/modules/mod_restarts.sh
# Copyright (c) 2025 wuldorf
# SPDX-License-Identifier: MIT
#
# This script is part of the 'little-linux-helper' collection.
# Licensed under the MIT License. See the LICENSE file in the project root for more information.
#
# Modul für Neustart-Funktionen von Diensten und Desktop-Umgebungen

# Laden der gemeinsamen Bibliothek
source "$(dirname "$0")/../lib/lib_common.sh"
lh_detect_package_manager

# Funktion zum Neustart des Login-Managers
function restart_login_manager_action() {
    lh_log_msg "INFO" "Login Manager wird neu gestartet..."
    local DM_SERVICE=""
    local INIT_SYSTEM=""

    # Bestimme das Init-System
    if command -v systemctl >/dev/null && systemctl is-active --quiet systemd; then
        INIT_SYSTEM="systemd"
    elif pidof upstart > /dev/null 2>&1; then # Heutzutage selten
        INIT_SYSTEM="upstart"
    elif [ -f /etc/init.d/cron ]; then # Grobe Annahme für SysVinit
        INIT_SYSTEM="sysvinit"
    else
        INIT_SYSTEM="unknown"
    fi
    lh_log_msg "INFO" "Erkanntes Init-System: $INIT_SYSTEM"

    # Finde den aktuellen Display Manager Dienst (systemd)
    if [ "$INIT_SYSTEM" = "systemd" ]; then
        if [ -L /etc/systemd/system/display-manager.service ]; then
            DM_SERVICE=$(basename "$(readlink -f /etc/systemd/system/display-manager.service)")
            lh_log_msg "INFO" "Display Manager Service (via systemd link): $DM_SERVICE"
        else
            # Versuche gängige Display Manager, falls der Link nicht existiert oder nicht standardmäßig ist
            local common_dms=("sddm" "gdm" "gdm3" "lightdm" "lxdm" "mdm")
            for dm in "${common_dms[@]}"; do
                if systemctl is-active --quiet "${dm}.service" || systemctl list-unit-files --type=service | grep -q "^${dm}.service"; then
                    DM_SERVICE="${dm}.service"
                    lh_log_msg "INFO" "Display Manager Service (gefunden durch Testen): $DM_SERVICE"
                    break
                fi
            done
        fi
    fi

    # Fallback für SysVinit oder wenn systemd-Methode fehlschlägt
    if [ -z "$DM_SERVICE" ] && [ -f /etc/X11/default-display-manager ]; then
        local dm_path=$(cat /etc/X11/default-display-manager)
        DM_SERVICE=$(basename "$dm_path") # z.B. /usr/sbin/gdm3 -> gdm3
        lh_log_msg "INFO" "Display Manager (via /etc/X11/default-display-manager): $DM_SERVICE"
    fi

    if [ -z "$DM_SERVICE" ]; then
        lh_log_msg "ERROR" "Konnte den Display Manager nicht eindeutig identifizieren."
        lh_log_msg "ERROR" "Bitte manuell prüfen und ggf. den Dienstnamen anpassen."
        # Fallback auf einen sehr gängigen Namen, falls alles andere fehlschlägt (letzter Versuch)
        if [ "$INIT_SYSTEM" = "systemd" ]; then
            DM_SERVICE="gdm.service" # oder sddm.service, je nach Präferenz
            lh_log_msg "INFO" "Versuche Fallback auf $DM_SERVICE..."
        fi
    fi

    if [ -z "$DM_SERVICE" ]; then
        lh_log_msg "ERROR" "Neustart des Login Managers abgebrochen."
        return 1
    fi

    # Entferne .service Endung für SysVinit/Upstart Kommandos
    local DM_NAME=${DM_SERVICE%.service}

    # Warnung und Bestätigung vor dem Neustart
    echo "WARNUNG: Der Neustart des Login-Managers beendet alle laufenden Benutzersitzungen!"
    echo "Stellen Sie sicher, dass Sie alle wichtigen Daten gespeichert haben."

    if ! lh_confirm_action "Möchten Sie den Login-Manager ($DM_NAME) wirklich neu starten?" "n"; then
        lh_log_msg "INFO" "Neustart des Login-Managers abgebrochen."
        return 0
    fi

    lh_log_msg "INFO" "Versuche Neustart von '$DM_NAME' (Dienst: '$DM_SERVICE')..."
    case $INIT_SYSTEM in
        systemd)
            if ! systemctl list-units --full -all | grep -q "$DM_SERVICE"; then
                lh_log_msg "ERROR" "Dienst $DM_SERVICE existiert nicht oder konnte nicht gefunden werden."
                return 1
            fi
            if $LH_SUDO_CMD systemctl restart "$DM_SERVICE"; then
                lh_log_msg "INFO" "Login Manager ($DM_SERVICE) erfolgreich via systemctl neu gestartet."
            else
                lh_log_msg "ERROR" "FEHLER beim Neustart des Login Managers ($DM_SERVICE) via systemctl."
                return 1
            fi
            ;;
        upstart) # Selten heutzutage
            if $LH_SUDO_CMD service "$DM_NAME" restart; then
                 lh_log_msg "INFO" "Login Manager ($DM_NAME) erfolgreich via upstart neu gestartet."
            else
                 lh_log_msg "ERROR" "FEHLER beim Neustart des Login Managers ($DM_NAME) via upstart."
                 return 1
            fi
            ;;
        sysvinit) # Ebenfalls seltener für DMs
            if [ -f "/etc/init.d/$DM_NAME" ]; then
                if $LH_SUDO_CMD /etc/init.d/"$DM_NAME" restart; then
                    lh_log_msg "INFO" "Login Manager ($DM_NAME) erfolgreich via SysVinit neu gestartet."
                else
                    lh_log_msg "ERROR" "FEHLER beim Neustart des Login Managers ($DM_NAME) via SysVinit."
                    return 1
                fi
            else
                lh_log_msg "ERROR" "FEHLER: Init-Skript /etc/init.d/$DM_NAME nicht gefunden."
                return 1
            fi
            ;;
        *)
            lh_log_msg "ERROR" "FEHLER: Unbekanntes oder nicht unterstütztes Init-System: $INIT_SYSTEM. Manueller Neustart erforderlich."
            return 1
            ;;
    esac

    return 0
}

# Funktion zum Neustart des Sound-Systems
# Verbesserte Audio-Neustart-Funktion für mod_restarts.sh

function restart_sound_system_action() {
    lh_log_msg "INFO" "Versuche, das Sound-System neu zu starten..."
    local sound_restarted=false

    # Benutzerinfos ermitteln
    lh_get_target_user_info
    if [ $? -ne 0 ]; then
        lh_log_msg "WARN" "Konnte Benutzerkontext nicht ermitteln, versuche trotzdem Sound-System-Neustart."
    fi

    local TARGET_USER="${LH_TARGET_USER_INFO[TARGET_USER]}"
    local USER_XDG_RUNTIME_DIR="${LH_TARGET_USER_INFO[USER_XDG_RUNTIME_DIR]}"

    # Verbesserte Erkennung des Audio-Systems
    local has_pipewire=false
    local has_pulseaudio=false
    local has_alsa=false

    # PipeWire prüfen
    if lh_run_command_as_target_user "systemctl --user --quiet is-active pipewire.service" >/dev/null 2>&1 || \
       lh_run_command_as_target_user "pgrep -x pipewire" >/dev/null 2>&1; then
        has_pipewire=true
        lh_log_msg "INFO" "PipeWire-Dienst ist aktiv."
    fi

    # PulseAudio prüfen (nur wenn PipeWire nicht erkannt wurde)
    if ! $has_pipewire && (lh_run_command_as_target_user "pgrep -x pulseaudio" >/dev/null 2>&1); then
        has_pulseaudio=true
        lh_log_msg "INFO" "PulseAudio ist aktiv."
    fi

    # ALSA immer prüfen
    if command -v alsactl >/dev/null 2>&1; then
        has_alsa=true
        lh_log_msg "INFO" "ALSA ist verfügbar."
    fi

    echo "Erkannte Audio-Komponenten:"
    if $has_pipewire; then echo "- PipeWire"; fi
    if $has_pulseaudio; then echo "- PulseAudio"; fi
    if $has_alsa; then echo "- ALSA"; fi

    # PipeWire (bevorzugt, da es oft PulseAudio als Kompatibilitätsschicht mitbringt)
    if $has_pipewire; then
        lh_log_msg "INFO" "Starte PipeWire-Dienste neu..."
        echo "Starte PipeWire-Dienste neu..."

        local standard_services="pipewire.service pipewire-pulse.service wireplumber.service"
        local pipewire_services=""

        # Temporäre Datei für die Roh-Ausgabe des Befehls
        local tmpfile=$(mktemp)

        # Führe den Befehl aus und leite die Ausgabe in tmpfile.
        # Diese Ausgabe könnte Debug-Informationen von lh_run_command_as_target_user enthalten.
        lh_run_command_as_target_user "systemctl --user list-units --state=active 'pipewire*' 'wireplumber*' 2>/dev/null | grep '\.service' | awk '{print \$1}'" > "$tmpfile"

        # Extrahiere nur Zeilen, die auf '.service' enden, aus tmpfile.
        # Dies filtert die Debug-Zeilen von lh_run_command_as_target_user heraus.
        local extracted_services
        extracted_services=$(grep '\.service$' "$tmpfile")

        if [ -n "$extracted_services" ]; then
            # Konvertiere die newline-separierte Liste in eine space-separierte Liste.
            # Und entferne mögliche Leerzeichen am Ende.
            pipewire_services=$(echo "$extracted_services" | tr '\n' ' ' | sed 's/ *$//')
            lh_log_msg "INFO" "Gefundene aktive PipeWire-Dienste: $pipewire_services"
        else
            pipewire_services="$standard_services"
            lh_log_msg "INFO" "Keine aktiven PipeWire-Dienste über systemctl gefunden (oder Filterung fehlgeschlagen), versuche Standarddienste: $standard_services"
            # Optional: Zusätzliches Logging, falls tmpfile Inhalt hatte, aber nichts gefiltert wurde
            if [ -s "$tmpfile" ]; then
                lh_log_msg "DEBUG" "tmpfile enthielt Daten, aber keine '.service'-Einträge nach Filterung."
                # Um den Inhalt von tmpfile zu loggen (mit Vorsicht bei potenziell großen oder sensiblen Daten):
                # (IFSOLD="$IFS"; IFS=$'\n'; for line in $(cat "$tmpfile"); do lh_log_msg "DEBUG" "tmpfile raw: $line"; done; IFS="$IFSOLD")
            fi
        fi

        # Temporäre Datei löschen
        rm -f "$tmpfile"

        # Jeden Dienst EINZELN neu starten
        local restart_failed=false
        for service in $pipewire_services; do
            # Stelle sicher, dass 'service' kein leerer String ist, falls $pipewire_services leer ist
            if [ -z "$service" ]; then
                continue
            fi
            lh_log_msg "INFO" "Starte $service neu..."
            if ! lh_run_command_as_target_user "systemctl --user restart $service" >/dev/null 2>&1; then
                lh_log_msg "WARN" "Fehler beim Neustart von $service"
                restart_failed=true
            else
                lh_log_msg "INFO" "$service erfolgreich neu gestartet"
            fi
        done

        if ! $restart_failed; then
            lh_log_msg "INFO" "PipeWire-Dienste wurden erfolgreich neu gestartet."
            echo "PipeWire-Dienste wurden erfolgreich neu gestartet."
            sound_restarted=true
        else
            lh_log_msg "WARN" "Fehler beim Neustart der PipeWire-Dienste via systemctl. Versuche manuellen Neustart..."
            echo "Fehler beim Neustart über systemd. Versuche alternativen Neustart..."

            # Prozesse beenden (ignoriere Fehler mit || true)
            lh_run_command_as_target_user "pkill -e pipewire || true" 2>/dev/null
            lh_run_command_as_target_user "pkill -e wireplumber || true" 2>/dev/null
            sleep 2

            # Zweiter Versuch: manuelles Starten der einzelnen Dienste
            local manual_restart_success=true
            for service in $standard_services; do
                if ! lh_run_command_as_target_user "systemctl --user start $service" >/dev/null 2>&1; then
                    lh_log_msg "WARN" "Fehler beim manuellen Start von $service"
                    manual_restart_success=false
                else
                    lh_log_msg "INFO" "$service manuell gestartet"
                fi
            done

            if $manual_restart_success; then
                lh_log_msg "INFO" "PipeWire erfolgreich manuell neu gestartet."
                echo "PipeWire wurde manuell neu gestartet."
                sound_restarted=true
            else
                # Dritter Versuch: direkter Start der Programme
                lh_log_msg "INFO" "Versuche direkten Start der PipeWire-Programme..."
                if lh_run_command_as_target_user "command -v pipewire >/dev/null" && \
                   lh_run_command_as_target_user "pipewire >/dev/null 2>&1 & disown" && \
                   (! lh_run_command_as_target_user "command -v pipewire-pulse >/dev/null" || \
                    lh_run_command_as_target_user "pipewire-pulse >/dev/null 2>&1 & disown") && \
                   (! lh_run_command_as_target_user "command -v wireplumber >/dev/null" || \
                    lh_run_command_as_target_user "wireplumber >/dev/null 2>&1 & disown"); then
                    sleep 2
                    if lh_run_command_as_target_user "pgrep -x pipewire >/dev/null 2>&1"; then
                        lh_log_msg "INFO" "PipeWire-Programme erfolgreich manuell gestartet."
                        echo "PipeWire wurde mit direktem Aufruf neu gestartet."
                        sound_restarted=true
                    else
                        lh_log_msg "ERROR" "Konnte PipeWire nicht manuell neu starten."
                        echo "Fehler: Konnte PipeWire nicht manuell neu starten."
                    fi
                else
                    lh_log_msg "ERROR" "Konnte PipeWire-Programme nicht starten."
                    echo "Fehler: Konnte PipeWire-Programme nicht starten."
                fi
            fi
        fi
    fi

    # PulseAudio (falls PipeWire nicht aktiv ist)
    if ! $sound_restarted && $has_pulseaudio; then
        lh_log_msg "INFO" "Starte PulseAudio neu..."
        echo "Starte PulseAudio neu..."

        # Trennen von 'und'-Befehlen für bessere Fehlerbehandlung
        lh_run_command_as_target_user "pulseaudio -k" >/dev/null 2>&1
        sleep 2
        if lh_run_command_as_target_user "pulseaudio --start" >/dev/null 2>&1; then
            lh_log_msg "INFO" "PulseAudio wurde erfolgreich neu gestartet."
            echo "PulseAudio wurde erfolgreich neu gestartet."
            sound_restarted=true
        else
            lh_log_msg "ERROR" "Fehler beim Neustart von PulseAudio."
            echo "Fehler: Konnte PulseAudio nicht neu starten."
        fi
    fi

    # ALSA (falls nötig oder als letzte Instanz)
    if (! $sound_restarted || $has_pipewire || $has_pulseaudio) && $has_alsa; then
        lh_log_msg "INFO" "Lade ALSA-Einstellungen neu..."
        echo "Lade ALSA-Einstellungen neu..."

        local alsa_success=false

        if $LH_SUDO_CMD alsactl restore >/dev/null 2>&1; then
            lh_log_msg "INFO" "ALSA-Einstellungen wiederhergestellt."
            alsa_success=true

            # ALSA-Dienste neu starten
            if $LH_SUDO_CMD systemctl try-restart alsa-restore.service alsa-state.service >/dev/null 2>&1; then
                lh_log_msg "INFO" "ALSA-Dienste (via systemctl) neu gestartet."
                echo "ALSA-Dienste wurden neu gestartet."
            elif command -v amixer >/dev/null; then
                # Master-Kanal umschalten als Reset-Methode
                lh_run_command_as_target_user "amixer -q set Master toggle && sleep 1 && amixer -q set Master toggle" >/dev/null 2>&1
                lh_log_msg "INFO" "ALSA-Mixer zurückgesetzt."
                echo "ALSA-Mixer wurde zurückgesetzt."
            else
                lh_log_msg "INFO" "ALSA-Einstellungen wiederhergestellt."
                echo "ALSA-Einstellungen wurden wiederhergestellt."
            fi
        else
            lh_log_msg "WARN" "Fehler beim Wiederherstellen der ALSA-Einstellungen."

            # Trotzdem versuchen, die Dienste neu zu starten
            if $LH_SUDO_CMD systemctl try-restart alsa-restore.service alsa-state.service >/dev/null 2>&1; then
                lh_log_msg "INFO" "ALSA-Dienste wurden dennoch neu gestartet."
                echo "ALSA-Dienste wurden neu gestartet."
                alsa_success=true
            fi
        fi

        # Wenn ALSA erfolgreich war und vorher nichts geklappt hat
        if $alsa_success && ! $sound_restarted; then
            sound_restarted=true
        fi
    fi

    # Überprüfen, ob irgendein Sound-System neu gestartet wurde
    if ! $sound_restarted; then
        lh_log_msg "ERROR" "Kein bekanntes und aktives Sound-System konnte neu gestartet werden."
        echo "Fehler: Es konnte kein aktives Sound-System gefunden oder neu gestartet werden."
        return 1
    else
        lh_log_msg "INFO" "Sound-System wurde neu gestartet."
        echo "Sound-System wurde erfolgreich neu gestartet."
        return 0
    fi
}

# Funktion zum Neustart der Desktop-Umgebung
function restart_desktop_environment_action() {
    lh_log_msg "INFO" "Versuche, die Desktop-Umgebung neu zu starten..."

    # Benutzerinfos ermitteln
    lh_get_target_user_info
    if [ $? -ne 0 ]; then
        lh_log_msg "ERROR" "Konnte keinen Desktop-Benutzer ermitteln. Abbruch."
        echo "Fehler: Konnte keinen Desktop-Benutzer ermitteln. Der Neustart ist nicht möglich."
        return 1
    fi

    local TARGET_USER="${LH_TARGET_USER_INFO[TARGET_USER]}"
    local USER_DISPLAY="${LH_TARGET_USER_INFO[USER_DISPLAY]}"
    local USER_XDG_RUNTIME_DIR="${LH_TARGET_USER_INFO[USER_XDG_RUNTIME_DIR]}"
    local USER_DBUS_SESSION_BUS_ADDRESS="${LH_TARGET_USER_INFO[USER_DBUS_SESSION_BUS_ADDRESS]}"

    if [ -z "$USER_DISPLAY" ] || [ -z "$USER_XDG_RUNTIME_DIR" ] || [ ! -d "$USER_XDG_RUNTIME_DIR" ] || [ -z "$USER_DBUS_SESSION_BUS_ADDRESS" ]; then
        lh_log_msg "WARN" "Notwendige Umgebungsvariablen (DISPLAY, XDG_RUNTIME_DIR, DBUS_SESSION_BUS_ADDRESS) konnten nicht vollständig zuverlässig ermittelt werden."
        lh_log_msg "WARN" "USER_DISPLAY: $USER_DISPLAY"
        lh_log_msg "WARN" "USER_XDG_RUNTIME_DIR: $USER_XDG_RUNTIME_DIR"
        lh_log_msg "WARN" "USER_DBUS_SESSION_BUS_ADDRESS: $USER_DBUS_SESSION_BUS_ADDRESS"
        lh_log_msg "WARN" "Neustart der Desktop-Umgebung könnte mit Einschränkungen funktionieren."
    fi

    # Desktop-Umgebung ermitteln
    # Verwende eine temporäre Datei, um die Ausgabe zu speichern
    DESKTOP_ENVIRONMENT_TMP=$(mktemp)
    lh_run_command_as_target_user "printenv XDG_CURRENT_DESKTOP 2>/dev/null" > "$DESKTOP_ENVIRONMENT_TMP"
    DESKTOP_ENVIRONMENT=$(cat "$DESKTOP_ENVIRONMENT_TMP" | tr '[:upper:]' '[:lower:]')
    rm -f "$DESKTOP_ENVIRONMENT_TMP"

    # Stellen Sie sicher, dass Sie nur die eigentliche Desktop-Umgebung bekommen
    # Reinige die Ausgabe von Debug-Meldungen
    DESKTOP_ENVIRONMENT=$(echo "$DESKTOP_ENVIRONMENT" | grep -v "^\[" | tail -n 1)

    if [ -z "$DESKTOP_ENVIRONMENT" ]; then
        if lh_run_command_as_target_user "pgrep plasmashell" >/dev/null; then
            DESKTOP_ENVIRONMENT="kde"
        elif lh_run_command_as_target_user "pgrep gnome-shell" >/dev/null; then
            DESKTOP_ENVIRONMENT="gnome"
        elif lh_run_command_as_target_user "pgrep xfce4-session" >/dev/null; then
            DESKTOP_ENVIRONMENT="xfce"
        elif lh_run_command_as_target_user "pgrep cinnamon-session" >/dev/null; then
            DESKTOP_ENVIRONMENT="cinnamon"
        elif lh_run_command_as_target_user "pgrep mate-session" >/dev/null; then
            DESKTOP_ENVIRONMENT="mate"
        fi
        lh_log_msg "INFO" "XDG_CURRENT_DESKTOP nicht direkt ermittelbar, heuristisch erkannt: $DESKTOP_ENVIRONMENT"
    else
        lh_log_msg "INFO" "Erkannte Desktop-Umgebung (XDG_CURRENT_DESKTOP für $TARGET_USER): $DESKTOP_ENVIRONMENT"
    fi

    if [ -z "$DESKTOP_ENVIRONMENT" ]; then
        lh_log_msg "ERROR" "Desktop-Umgebung konnte nicht ermittelt werden."
        echo "Fehler: Desktop-Umgebung konnte nicht ermittelt werden."
        return 1
    fi

    # Warnung und Bestätigung vor dem Neustart
    echo "WARNUNG: Der Neustart der Desktop-Umgebung ($DESKTOP_ENVIRONMENT) kann laufende Anwendungen beeinträchtigen!"
    echo "Es wird empfohlen, alle wichtigen Daten vor dem Neustart zu speichern."

    if ! lh_confirm_action "Möchten Sie die Desktop-Umgebung ($DESKTOP_ENVIRONMENT) wirklich neu starten?" "n"; then
        lh_log_msg "INFO" "Neustart der Desktop-Umgebung abgebrochen."
        return 0
    fi

    # Option für Neustart-Typ wählen
    echo "Wählen Sie den Neustart-Typ:"
    echo "1. Sanfter Neustart (versucht, Anwendungen nicht zu beenden)"
    echo "2. Harter Neustart (beendet ggf. Desktop-Komponenten erzwungen)"
    read -p "Wählen Sie eine Option (1-2): " restart_type

    case $DESKTOP_ENVIRONMENT in
        kde|plasma)
            lh_log_msg "INFO" "KDE Plasma wird für Benutzer '$TARGET_USER' neu gestartet..."
            local kquit_cmd=""
            local kstart_cmd=""
            local plasmashell_restarted=false

            # Prüfe Verfügbarkeit der Plasma 6 Werkzeuge (kquitapp, kstart)
            if lh_run_command_as_target_user "command -v kquitapp" >/dev/null && lh_run_command_as_target_user "command -v kstart" >/dev/null; then
                lh_log_msg "INFO" "Plasma 6 Werkzeuge (kquitapp, kstart) gefunden."
                kquit_cmd="kquitapp"
                kstart_cmd="kstart"
            # Prüfe Verfügbarkeit der Plasma 5 Werkzeuge (kquitapp5, kstart5)
            elif lh_run_command_as_target_user "command -v kquitapp5" >/dev/null && lh_run_command_as_target_user "command -v kstart5" >/dev/null; then
                lh_log_msg "INFO" "Plasma 5 Werkzeuge (kquitapp5, kstart5) gefunden."
                kquit_cmd="kquitapp5"
                kstart_cmd="kstart5"
            else
                lh_log_msg "WARN" "Weder Plasma 5 noch Plasma 6 kquit/kstart Werkzeuge gefunden. Versuche direkten plasmashell Neustart."
            fi

            # Neustart-Methode abhängig von der Auswahl
            if [ "$restart_type" = "1" ] && [ -n "$kquit_cmd" ]; then  # Sanfter Neustart mit kquit/kstart
                # Versuch 1: systemd user service (sauberster Weg)
                if lh_run_command_as_target_user "systemctl --user is-active --quiet plasma-plasmashell.service" && \
                   lh_run_command_as_target_user "systemctl --user restart plasma-plasmashell.service"; then
                    lh_log_msg "INFO" "plasmashell Dienst erfolgreich via systemctl --user neu gestartet."
                    plasmashell_restarted=true
                else
                    lh_log_msg "WARN" "Neustart von plasma-plasmashell.service via systemctl --user ist fehlgeschlagen."

                    # Versuch 2: Graceful shutdown mit kquit_cmd
                    lh_log_msg "INFO" "Versuche graceful shutdown mit '$kquit_cmd plasmashell'..."
                    if lh_run_command_as_target_user "$kquit_cmd plasmashell"; then
                        lh_log_msg "INFO" "'$kquit_cmd plasmashell' erfolgreich ausgeführt. Warte kurz..."
                        sleep 3

                        # Prüfen, ob plasmashell beendet wurde
                        if ! lh_run_command_as_target_user "pgrep plasmashell" >/dev/null; then
                            lh_log_msg "INFO" "plasmashell wurde nach '$kquit_cmd' erfolgreich beendet."

                            # Starte plasmashell neu
                            lh_log_msg "INFO" "Starte neue Instanz mit '$kstart_cmd plasmashell'..."
                            lh_run_command_as_target_user "nohup $kstart_cmd plasmashell >/dev/null 2>&1 &"
                            lh_log_msg "INFO" "Befehl zum Neustart von plasmashell (via $kstart_cmd) wurde ausgeführt."
                            plasmashell_restarted=true
                        else
                            lh_log_msg "WARN" "plasmashell läuft noch nach '$kquit_cmd'. Versuche sanften Kill."
                            lh_run_command_as_target_user "killall -q plasmashell"
                            sleep 1

                            # Starte plasmashell neu
                            lh_run_command_as_target_user "nohup $kstart_cmd plasmashell >/dev/null 2>&1 &"
                            lh_log_msg "INFO" "Befehl zum Neustart von plasmashell wurde ausgeführt."
                            plasmashell_restarted=true
                        fi
                    else
                        lh_log_msg "ERROR" "'$kquit_cmd plasmashell' ist fehlgeschlagen."
                    fi
                fi
            else
                # Harter Neustart oder kein kquit/kstart
                lh_log_msg "INFO" "Führe harten Neustart von plasmashell durch..."

                # Beende plasmashell
                lh_run_command_as_target_user "killall -q plasmashell"
                sleep 1

                # Falls es noch läuft, mit härteren Methoden versuchen
                if lh_run_command_as_target_user "pgrep plasmashell" >/dev/null; then
                    lh_log_msg "WARN" "plasmashell läuft noch nach killall, versuche pkill..."
                    lh_run_command_as_target_user "pkill plasmashell"
                    sleep 1
                fi

                # Als letzten Ausweg SIGKILL verwenden
                if lh_run_command_as_target_user "pgrep plasmashell" >/dev/null; then
                    lh_log_msg "WARN" "plasmashell läuft immer noch, versuche härteren Kill (-9)..."
                    lh_run_command_as_target_user "pkill -9 plasmashell"
                    sleep 1
                fi

                # Starte plasmashell neu
                if ! lh_run_command_as_target_user "pgrep plasmashell" >/dev/null; then
                    lh_log_msg "INFO" "Alte plasmashell Instanz(en) beendet. Starte neue Instanz..."
                    if [ -n "$kstart_cmd" ]; then
                        lh_run_command_as_target_user "nohup $kstart_cmd plasmashell >/dev/null 2>&1 &"
                    else
                        lh_run_command_as_target_user "nohup plasmashell >/dev/null 2>&1 &"
                    fi
                    lh_log_msg "INFO" "Befehl zum Neustart von plasmashell wurde ausgeführt."
                    plasmashell_restarted=true
                else
                    lh_log_msg "ERROR" "Konnte plasmashell nicht beenden. Neustart abgebrochen."
                fi
            fi

            if ! $plasmashell_restarted; then
                 lh_log_msg "ERROR" "KDE Plasma konnte nicht zuverlässig neu gestartet werden."
                 echo "Fehler: KDE Plasma konnte nicht neu gestartet werden."
                 return 1
            fi
            ;;

        gnome)
            lh_log_msg "INFO" "GNOME Shell wird für Benutzer '$TARGET_USER' neu gestartet..."
            # XDG_SESSION_TYPE ermitteln
            local SESSION_TYPE=$(lh_run_command_as_target_user "printenv XDG_SESSION_TYPE 2>/dev/null")

            if [ "$SESSION_TYPE" = "wayland" ]; then
                lh_log_msg "INFO" "GNOME unter Wayland erkannt."

                if [ "$restart_type" = "1" ]; then  # Sanfter Neustart
                    lh_log_msg "INFO" "Versuche sanften Neustart via dbus..."
                    if lh_run_command_as_target_user "dbus-send --type=method_call --dest=org.gnome.Shell /org/gnome/Shell org.gnome.Shell.Eval string:\"Meta.restart('Shell Neustart angefordert')\""; then
                        lh_log_msg "INFO" "Befehl an GNOME Shell (Wayland) gesendet, um einen Neustart zu versuchen."
                    else
                        lh_log_msg "ERROR" "Konnte keinen sicheren Neustartbefehl für GNOME unter Wayland finden/ausführen."
                        echo "Warnung: GNOME unter Wayland kann nicht zuverlässig neu gestartet werden."
                        echo "Ein Ab- und Anmelden ist die empfohlene Methode für einen vollständigen Neustart."
                    fi
                else
                    # Harter Neustart
                    lh_log_msg "WARN" "Harter Neustart von GNOME unter Wayland ist riskant und kann die Sitzung beenden."
                    echo "Warnung: Ein harter Neustart von GNOME unter Wayland kann die gesamte Sitzung beenden!"
                    if lh_confirm_action "Möchten Sie trotzdem fortfahren?" "n"; then
                        # Versuchen, gnome-shell mit erzwungener Beendung neu zu starten
                        lh_run_command_as_target_user "killall -q gnome-shell"
                        lh_log_msg "INFO" "Befehl zum Beenden von gnome-shell ausgeführt. Dies führt wahrscheinlich zum Ende der Sitzung."
                    else
                        lh_log_msg "INFO" "Harter Neustart von GNOME unter Wayland abgebrochen."
                        return 0
                    fi
                fi
            else  # X11
                if [ "$restart_type" = "1" ]; then  # Sanfter Neustart
                    # Versuche systemd user service, falls vorhanden
                    if lh_run_command_as_target_user "systemctl --user is-active --quiet gnome-shell-x11.service" && \
                       lh_run_command_as_target_user "systemctl --user restart gnome-shell-x11.service"; then
                        lh_log_msg "INFO" "GNOME Shell (X11) Dienst erfolgreich neu gestartet."
                    else
                        lh_log_msg "INFO" "GNOME Shell (X11) Dienst nicht gefunden/aktiv, versuche 'killall -HUP gnome-shell'..."
                        # Traditioneller Weg für X11
                        if lh_run_command_as_target_user "pkill -HUP gnome-shell"; then
                             lh_log_msg "INFO" "SIGHUP an gnome-shell gesendet."
                        else
                             lh_log_msg "ERROR" "FEHLER: SIGHUP an gnome-shell konnte nicht gesendet werden."
                        fi
                    fi
                else
                    # Harter Neustart
                    lh_log_msg "INFO" "Führe harten Neustart von GNOME Shell (X11) durch..."
                    lh_run_command_as_target_user "killall gnome-shell"
                    sleep 1
                    lh_run_command_as_target_user "nohup gnome-shell --replace >/dev/null 2>&1 &"
                    lh_log_msg "INFO" "Befehl 'gnome-shell --replace' ausgeführt."
                fi
            fi
            ;;
        xfce)
            lh_log_msg "INFO" "XFCE (xfce4-panel und xfwm4) wird für Benutzer '$TARGET_USER' neu gestartet..."
            if [ "$restart_type" = "1" ]; then  # Sanfter Neustart
                lh_run_command_as_target_user "nohup xfce4-panel --restart >/dev/null 2>&1 &"
                lh_run_command_as_target_user "nohup xfwm4 --replace >/dev/null 2>&1 &"
            else
                # Harter Neustart
                lh_run_command_as_target_user "killall xfce4-panel xfwm4"
                sleep 1
                lh_run_command_as_target_user "nohup xfce4-panel >/dev/null 2>&1 &"
                lh_run_command_as_target_user "nohup xfwm4 >/dev/null 2>&1 &"
            fi
            lh_log_msg "INFO" "Befehle zum Neustart von xfce4-panel und xfwm4 wurden ausgeführt."
            ;;

        cinnamon)
            lh_log_msg "INFO" "Cinnamon wird für Benutzer '$TARGET_USER' neu gestartet..."
            if [ "$restart_type" = "1" ]; then  # Sanfter Neustart
                # Cinnamon Extensions zuerst neu laden
                if lh_run_command_as_target_user "dbus-send --session --dest=org.Cinnamon.LookingGlass --type=method_call /org/Cinnamon/LookingGlass org.Cinnamon.LookingGlass.ReloadExtension string:' όλους ' int32:0"; then
                     lh_log_msg "INFO" "Cinnamon Erweiterungen neu geladen (simuliert teilweisen Neustart)."
                fi
                # Für einen vollständigeren Neustart:
                lh_run_command_as_target_user "nohup cinnamon --replace >/dev/null 2>&1 &"
            else
                # Harter Neustart
                lh_run_command_as_target_user "killall cinnamon"
                sleep 1
                lh_run_command_as_target_user "nohup cinnamon --replace >/dev/null 2>&1 &"
            fi
            lh_log_msg "INFO" "Befehl 'cinnamon --replace' ausgeführt."
            ;;

        mate)
            lh_log_msg "INFO" "MATE (mate-panel und marco) wird für Benutzer '$TARGET_USER' neu gestartet..."
            if [ "$restart_type" = "1" ]; then  # Sanfter Neustart
                lh_run_command_as_target_user "nohup mate-panel --replace >/dev/null 2>&1 &"
                lh_run_command_as_target_user "nohup marco --replace >/dev/null 2>&1 &"
            else
                # Harter Neustart
                lh_run_command_as_target_user "killall mate-panel marco"
                sleep 1
                lh_run_command_as_target_user "nohup mate-panel >/dev/null 2>&1 &"
                lh_run_command_as_target_user "nohup marco >/dev/null 2>&1 &"
            fi
            lh_log_msg "INFO" "Befehle zum Neustart von mate-panel und marco wurden ausgeführt."
            ;;

        lxde)
            lh_log_msg "INFO" "LXDE (lxpanel) wird für Benutzer '$TARGET_USER' neu gestartet..."
            if [ "$restart_type" = "1" ]; then  # Sanfter Neustart
                if lh_run_command_as_target_user "lxpanelctl restart"; then
                     lh_log_msg "INFO" "lxpanelctl restart erfolgreich."
                else
                     lh_log_msg "WARN" "lxpanelctl restart fehlgeschlagen. Versuche manuellen Kill und Start."
                     lh_run_command_as_target_user "killall lxpanel"
                     sleep 1
                     lh_run_command_as_target_user "nohup lxpanel >/dev/null 2>&1 &"
                fi
            else
                # Harter Neustart
                lh_run_command_as_target_user "killall lxpanel openbox"
                sleep 1
                lh_run_command_as_target_user "nohup lxpanel >/dev/null 2>&1 &"
                lh_run_command_as_target_user "nohup openbox >/dev/null 2>&1 &"
            fi
            lh_log_msg "INFO" "Versuch, lxpanel neu zu starten durchgeführt."
            ;;

        lxqt)
            lh_log_msg "INFO" "LXQt (lxqt-panel) wird für Benutzer '$TARGET_USER' neu gestartet..."
            if [ "$restart_type" = "1" ]; then  # Sanfter Neustart
                lh_run_command_as_target_user "killall lxqt-panel"
                sleep 1
                lh_run_command_as_target_user "nohup lxqt-panel >/dev/null 2>&1 &"
            else
                # Harter Neustart
                lh_run_command_as_target_user "killall lxqt-panel"
                sleep 1
                lh_run_command_as_target_user "nohup lxqt-panel >/dev/null 2>&1 &"
            fi
            lh_log_msg "INFO" "Versuch, lxqt-panel neu zu starten (kill & start)."
            ;;

        *)
            lh_log_msg "ERROR" "Unbekannte oder nicht direkt unterstützte Desktop-Umgebung: '$DESKTOP_ENVIRONMENT'."
            echo "Fehler: Desktop-Umgebung '$DESKTOP_ENVIRONMENT' wird nicht direkt unterstützt."
            return 1
            ;;
    esac

    echo "Neustart der Desktop-Umgebung wurde durchgeführt."
    return 0
}

# Funktion zum Neustart der Netzwerkdienste
function restart_network_services_action() {
    lh_log_msg "INFO" "Netzwerkdienste werden überprüft..."
    local services_to_consider=()
    local active_services_names=() # Nur Namen für die Anzeige

    # Überprüfe gängige Netzwerk-Manager
    if command -v nmcli >/dev/null && systemctl is-active --quiet NetworkManager.service; then
        services_to_consider+=("NetworkManager.service")
        active_services_names+=("NetworkManager")
        lh_log_msg "INFO" "NetworkManager ist aktiv."
    fi
    if systemctl is-active --quiet systemd-networkd.service; then
        services_to_consider+=("systemd-networkd.service")
        active_services_names+=("systemd-networkd")
        lh_log_msg "INFO" "systemd-networkd ist aktiv."
    fi
    # dhcpcd wird manchmal zusätzlich oder alternativ verwendet
    if systemctl is-active --quiet dhcpcd.service; then
        services_to_consider+=("dhcpcd.service")
        active_services_names+=("dhcpcd (als Dienst)")
        lh_log_msg "INFO" "dhcpcd.service ist aktiv."
    elif pgrep dhcpcd >/dev/null; then # Falls dhcpcd läuft, aber nicht als systemd service
        lh_log_msg "INFO" "dhcpcd Prozess läuft, aber nicht als systemd Dienst. Neustart komplexer."
    fi
    # systemd-resolved für DNS
    if systemctl is-active --quiet systemd-resolved.service; then
        services_to_consider+=("systemd-resolved.service")
        active_services_names+=("systemd-resolved (DNS)")
        lh_log_msg "INFO" "systemd-resolved ist aktiv."
    fi
    # Veraltet, aber zur Vollständigkeit: 'networking' service auf Debian/Ubuntu-basierten Systemen ohne NetworkManager
    if [ -f /etc/init.d/networking ] && ! systemctl is-active --quiet NetworkManager.service && ! systemctl is-active --quiet systemd-networkd.service; then
         if systemctl is-active --quiet networking.service; then # systemd wrapper
            services_to_consider+=("networking.service")
            active_services_names+=("networking (traditionell via systemd)")
            lh_log_msg "INFO" "networking.service ist aktiv."
         else # Direkter init.d Aufruf (sehr alt)
            lh_log_msg "INFO" "Traditionelles /etc/init.d/networking Skript gefunden, aber nicht via systemd aktiv."
         fi
    fi

    if [ ${#services_to_consider[@]} -eq 0 ]; then
        lh_log_msg "WARN" "Keine primären unterstützten Netzwerkdienste aktiv oder erkannt, die einfach neugestartet werden können."
        # Fallback: Versuche 'networking' Service, falls vorhanden (Debian/Ubuntu-Stil)
        if $LH_SUDO_CMD systemctl restart networking >/dev/null 2>&1; then
             lh_log_msg "INFO" "Fallback: 'networking' Dienst neugestartet."
             echo "Networking-Dienst wurde neu gestartet."
        else
             lh_log_msg "ERROR" "Auch Fallback-Neustart von 'networking' nicht erfolgreich oder Dienst nicht vorhanden."
             echo "Es konnten keine Netzwerkdienste gefunden werden, die neugestartet werden können."
        fi
        return
    fi

    lh_print_header "Erkannte aktive Netzwerkdienste"

    for i in "${!active_services_names[@]}"; do
        lh_print_menu_item $((i+1)) "${active_services_names[$i]}"
    done

    lh_print_menu_item $(( ${#active_services_names[@]} + 1 )) "Alle oben genannten neu starten"
    lh_print_menu_item $(( ${#active_services_names[@]} + 2 )) "Abbrechen"
    echo ""

    local net_choice
    read -p "Wählen Sie einen Dienst zum Neustarten (1-$(( ${#active_services_names[@]} + 2 ))): " net_choice

    if ! [[ "$net_choice" =~ ^[0-9]+$ ]] || [ "$net_choice" -lt 1 ] || [ "$net_choice" -gt $(( ${#services_to_consider[@]} + 2 )) ]; then
        lh_log_msg "WARN" "Ungültige Auswahl."
        echo "Ungültige Auswahl."
        return
    fi

    if [ "$net_choice" -eq $(( ${#services_to_consider[@]} + 2 )) ]; then
        lh_log_msg "INFO" "Neustart der Netzwerkdienste abgebrochen."
        echo "Neustart der Netzwerkdienste abgebrochen."
        return
    fi

    local services_to_restart=()
    if [ "$net_choice" -eq $(( ${#services_to_consider[@]} + 1 )) ]; then # Alle neu starten
        services_to_restart=("${services_to_consider[@]}")
        lh_log_msg "INFO" "Alle erkannten Netzwerkdienste werden neu gestartet..."
    else
        services_to_restart+=("${services_to_consider[$((net_choice-1))]}")
        lh_log_msg "INFO" "${active_services_names[$((net_choice-1))]} wird neu gestartet..."
    fi

    # Warnung und Bestätigung vor dem Neustart
    echo "WARNUNG: Der Neustart von Netzwerkdiensten kann aktive Verbindungen unterbrechen!"

    if ! lh_confirm_action "Möchten Sie fortfahren?" "n"; then
        lh_log_msg "INFO" "Neustart der Netzwerkdienste abgebrochen."
        echo "Neustart der Netzwerkdienste abgebrochen."
        return
    fi

    local all_successful=true
    for service in "${services_to_restart[@]}"; do
        lh_log_msg "INFO" "Starte Neustart von $service..."
        if $LH_SUDO_CMD systemctl restart "$service"; then
            lh_log_msg "INFO" "$service erfolgreich neu gestartet."
            # Kurze Pause, um dem Dienst Zeit zum Initialisieren zu geben, bevor der nächste ggf. davon abhängt
            sleep 1
        else
            lh_log_msg "ERROR" "FEHLER beim Neustart von $service."
            all_successful=false
        fi
    done

    if $all_successful; then
        lh_log_msg "INFO" "Ausgewählte Netzwerkdienste erfolgreich neu gestartet."
        echo "Ausgewählte Netzwerkdienste wurden erfolgreich neu gestartet."
    else
        lh_log_msg "WARN" "Mindestens ein Netzwerkdienst konnte nicht erfolgreich neu gestartet werden."
        echo "Mindestens ein Netzwerkdienst konnte nicht erfolgreich neu gestartet werden."
    fi
}

# Hauptfunktion des Moduls: Untermenü anzeigen und Aktionen steuern
function restart_module_menu() {
    while true; do
        lh_print_header "Dienste & Desktop Neustart-Optionen"

        lh_print_menu_item 1 "Login Manager neu starten (Alle Userprozesse werden beendet!)"
        lh_print_menu_item 2 "Sound-System neu starten"
        lh_print_menu_item 3 "Desktop-Umgebung neu starten"
        lh_print_menu_item 4 "Netzwerkdienste neu starten"
        lh_print_menu_item 0 "Zurück zum Hauptmenü"
        echo ""

        read -p "Wählen Sie eine Option: " option

        case $option in
            1)
                restart_login_manager_action
                ;;
            2)
                restart_sound_system_action
                ;;
            3)
                restart_desktop_environment_action
                ;;
            4)
                restart_network_services_action
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
restart_module_menu
exit $?
