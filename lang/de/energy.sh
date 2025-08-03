#!/bin/bash
#
# little-linux-helper/lang/de/energy.sh
# Copyright (c) 2025 wuldorf
# SPDX-License-Identifier: MIT
#
# Deutsche Übersetzungen für das Energieverwaltungsmodul

# Conditional declaration for module files
[[ ! -v MSG_DE ]] && declare -A MSG_DE

# Menu items and headers
MSG_DE[ENERGY_MENU_TITLE]="Energieverwaltung"
MSG_DE[ENERGY_MENU_DISABLE_SLEEP]="Standy/Ruhezustand temporär deaktivieren"
MSG_DE[ENERGY_MENU_CPU_GOVERNOR]="CPU-Governor Verwaltung"
MSG_DE[ENERGY_MENU_SCREEN_BRIGHTNESS]="Bildschirmhelligkeit steuern"
MSG_DE[ENERGY_MENU_POWER_STATS]="Energiestatistiken & Informationen"

# Headers
MSG_DE[ENERGY_HEADER_DISABLE_SLEEP]="Standby/Ruhezustand deaktivieren"
MSG_DE[ENERGY_HEADER_SLEEP_STATUS]="Standby-Sperren Status"
MSG_DE[ENERGY_HEADER_RESTORE_SLEEP]="Standby-Funktionalität wiederherstellen"
MSG_DE[ENERGY_HEADER_CPU_GOVERNOR]="CPU-Governor Verwaltung"
MSG_DE[ENERGY_HEADER_SCREEN_BRIGHTNESS]="Bildschirmhelligkeit steuern"
MSG_DE[ENERGY_HEADER_POWER_STATS]="Energiestatistiken & Informationen"

# Sleep management
MSG_DE[ENERGY_SLEEP_OPTIONS]="Standby-Deaktivierungsoptionen:"
MSG_DE[ENERGY_SLEEP_UNTIL_SHUTDOWN]="Bis zum nächsten manuellen Herunterfahren deaktivieren"
MSG_DE[ENERGY_SLEEP_FOR_TIME]="Für bestimmte Zeit deaktivieren"
MSG_DE[ENERGY_SLEEP_SHOW_STATUS]="Aktuellen Standby-Sperren Status anzeigen"
MSG_DE[ENERGY_SLEEP_RESTORE]="Standby-Funktionalität wiederherstellen"

MSG_DE[ENERGY_TIME_OPTIONS]="Zeitdauer-Optionen:"
MSG_DE[ENERGY_TIME_30MIN]="30 Minuten"
MSG_DE[ENERGY_TIME_1HOUR]="1 Stunde"
MSG_DE[ENERGY_TIME_2HOURS]="2 Stunden"
MSG_DE[ENERGY_TIME_4HOURS]="4 Stunden"
MSG_DE[ENERGY_TIME_CUSTOM]="Benutzerdefinierte Zeit (in Minuten)"

MSG_DE[ENERGY_UNIT_MINUTES]="Minuten"
MSG_DE[ENERGY_UNIT_HOUR]="Stunde"
MSG_DE[ENERGY_UNIT_HOURS]="Stunden"

MSG_DE[ENERGY_ASK_CUSTOM_MINUTES]="Zeit in Minuten eingeben:"
MSG_DE[ENERGY_ERROR_INVALID_NUMBER]="Bitte geben Sie eine gültige Zahl ein."
MSG_DE[ENERGY_ERROR_NO_TIME_SPECIFIED]="Keine Zeit angegeben."

MSG_DE[ENERGY_CONFIRM_DISABLE_SLEEP_PERMANENT]="Möchten Sie Standby/Ruhezustand bis zum nächsten manuellen Herunterfahren deaktivieren?"
MSG_DE[ENERGY_CONFIRM_DISABLE_SLEEP_TIME]="Möchten Sie Standby/Ruhezustand für %s deaktivieren?"
MSG_DE[ENERGY_CONFIRM_RESTORE_SLEEP]="Möchten Sie die Standby/Ruhezustand-Funktionalität wiederherstellen?"

MSG_DE[ENERGY_SUCCESS_SLEEP_DISABLED_PERMANENT]="Standby/Ruhezustand bis zum nächsten manuellen Herunterfahren deaktiviert."
MSG_DE[ENERGY_SUCCESS_SLEEP_DISABLED_TIME]="Standby/Ruhezustand für %s deaktiviert."
MSG_DE[ENERGY_SUCCESS_SLEEP_RESTORED]="Standby/Ruhezustand-Funktionalität wiederhergestellt."

MSG_DE[ENERGY_INFO_RESTORE_SLEEP]="Um die Standby-Funktionalität wiederherzustellen, verwenden Sie Option 4 in diesem Menü."
MSG_DE[ENERGY_INFO_NO_ACTIVE_INHIBIT]="Keine aktive Standby-Sperre gefunden."
MSG_DE[ENERGY_INFO_NO_TEMP_INHIBIT]="Keine temporäre Standby-Sperre von Little Linux Helper gefunden."

MSG_DE[ENERGY_STATUS_CURRENT_INHIBITS]="Aktuelle Standby-Sperren:"
MSG_DE[ENERGY_STATUS_NO_INHIBITS]="Keine aktiven Standby-Sperren gefunden."
MSG_DE[ENERGY_STATUS_OUR_INHIBIT_ACTIVE]="Little Linux Helper Standby-Sperre aktiv (PID: %s)"
MSG_DE[ENERGY_STATUS_OUR_INHIBIT_INACTIVE]="Little Linux Helper Standby-Sperre nicht aktiv."
MSG_DE[ENERGY_STATUS_OUR_INHIBIT_NONE]="Keine Little Linux Helper Standby-Sperre gefunden."

MSG_DE[ENERGY_INHIBIT_REASON]="Temporäre Standby-Deaktivierung auf Benutzerwunsch"
MSG_DE[ENERGY_INHIBIT_REASON_TIME]="Temporäre Standby-Deaktivierung für %s auf Benutzerwunsch"

MSG_DE[ENERGY_ERROR_NO_SYSTEMD_INHIBIT]="systemd-inhibit Befehl nicht gefunden. Standby-Einstellungen können nicht verwaltet werden."

# CPU Governor
MSG_DE[ENERGY_CPU_CURRENT_GOVERNOR]="Aktueller CPU-Frequenz-Governor:"
MSG_DE[ENERGY_CPU_AVAILABLE_GOVERNORS]="Verfügbare Governors:"
MSG_DE[ENERGY_CPU_NO_AVAILABLE_GOVERNORS]="Informationen über verfügbare Governors nicht gefunden."
MSG_DE[ENERGY_CPU_NO_CPUFREQ]="CPU-Frequenzskalierung ist auf diesem System nicht verfügbar."
MSG_DE[ENERGY_CPU_GOVERNOR_CURRENT]="Aktueller Governor: %s"

MSG_DE[ENERGY_CPU_GOVERNOR_OPTIONS]="CPU-Governor Optionen:"
MSG_DE[ENERGY_CPU_SET_PERFORMANCE]="Performance (maximale Leistung)"
MSG_DE[ENERGY_CPU_SET_POWERSAVE]="Powersave (minimaler Stromverbrauch)"
MSG_DE[ENERGY_CPU_SET_ONDEMAND]="On-demand (dynamische Skalierung)"
MSG_DE[ENERGY_CPU_SET_CONSERVATIVE]="Conservative (graduelle Skalierung)"
MSG_DE[ENERGY_CPU_SET_CUSTOM]="Benutzerdefinierter Governor"

MSG_DE[ENERGY_ASK_CUSTOM_GOVERNOR]="Governor-Name eingeben:"
MSG_DE[ENERGY_CONFIRM_SET_GOVERNOR]="Möchten Sie den CPU-Governor auf '%s' setzen?"

MSG_DE[ENERGY_SUCCESS_GOVERNOR_SET]="CPU-Governor auf '%s' gesetzt."
MSG_DE[ENERGY_ERROR_GOVERNOR_SET_FAILED]="Fehler beim Setzen des CPU-Governors auf '%s'."

MSG_DE[ENERGY_ERROR_NO_CPUPOWER]="cpupower Befehl nicht gefunden. Bitte installieren Sie die cpupower Utilities."

# Screen Brightness
MSG_DE[ENERGY_BRIGHTNESS_CURRENT]="Aktuelle Bildschirmhelligkeit:"
MSG_DE[ENERGY_BRIGHTNESS_INFO_FAILED]="Fehler beim Abrufen der Helligkeitsinformationen."
MSG_DE[ENERGY_BRIGHTNESS_CURRENT_VALUE]="Aktuelle Helligkeit: %s%%"
MSG_DE[ENERGY_BRIGHTNESS_SYSFS_INFO]="Aktuell: %s, Maximum: %s (%s%%)"

MSG_DE[ENERGY_BRIGHTNESS_OPTIONS]="Helligkeitsoptionen:"
MSG_DE[ENERGY_BRIGHTNESS_SET_25]="Auf 25%% setzen"
MSG_DE[ENERGY_BRIGHTNESS_SET_50]="Auf 50%% setzen"
MSG_DE[ENERGY_BRIGHTNESS_SET_75]="Auf 75%% setzen"
MSG_DE[ENERGY_BRIGHTNESS_SET_100]="Auf 100%% setzen"
MSG_DE[ENERGY_BRIGHTNESS_SET_CUSTOM]="Benutzerdefinierter Prozentwert"

MSG_DE[ENERGY_ASK_BRIGHTNESS_PERCENT]="Helligkeits-Prozentsatz eingeben (1-100):"
MSG_DE[ENERGY_ERROR_INVALID_BRIGHTNESS]="Bitte geben Sie eine gültige Zahl zwischen 1 und 100 ein."
MSG_DE[ENERGY_ERROR_BRIGHTNESS_RANGE]="Helligkeitswert muss zwischen 1 und 100 liegen."

MSG_DE[ENERGY_CONFIRM_SET_BRIGHTNESS]="Möchten Sie die Bildschirmhelligkeit auf %s%% setzen?"

MSG_DE[ENERGY_SUCCESS_BRIGHTNESS_SET]="Bildschirmhelligkeit auf %s%% gesetzt."
MSG_DE[ENERGY_ERROR_BRIGHTNESS_SET_FAILED]="Fehler beim Setzen der Bildschirmhelligkeit auf %s%%."

MSG_DE[ENERGY_ERROR_NO_BRIGHTNESS_CONTROL]="Keine Helligkeitssteuerungs-Tools gefunden."
MSG_DE[ENERGY_INFO_BRIGHTNESS_TOOLS]="Bitte installieren Sie: brightnessctl, xbacklight, oder stellen Sie sicher, dass Backlight-Unterstützung verfügbar ist."

# Power Statistics
MSG_DE[ENERGY_STATS_BATTERY_INFO]="Akku-Informationen:"
MSG_DE[ENERGY_STATS_BATTERY_DEVICE]="Akku-Gerät: %s"
MSG_DE[ENERGY_STATS_BATTERY_CAPACITY]="Kapazität"
MSG_DE[ENERGY_STATS_BATTERY_STATUS]="Status"
MSG_DE[ENERGY_STATS_BATTERY_ENERGY]="Energie"
MSG_DE[ENERGY_STATS_NO_BATTERY]="Keine Akku-Geräte gefunden."
MSG_DE[ENERGY_STATS_NO_POWER_SUPPLY]="Stromversorgungs-Informationen nicht verfügbar."

MSG_DE[ENERGY_STATS_AC_ADAPTER]="Netzteil-Status:"
MSG_DE[ENERGY_STATS_AC_CONNECTED]="Netzteil '%s' ist angeschlossen"
MSG_DE[ENERGY_STATS_AC_DISCONNECTED]="Netzteil '%s' ist nicht angeschlossen"
MSG_DE[ENERGY_STATS_NO_AC_ADAPTER]="Keine Netzteil-Informationen gefunden."

MSG_DE[ENERGY_STATS_THERMAL_ZONES]="Temperaturzonen:"
MSG_DE[ENERGY_STATS_NO_THERMAL]="Temperaturzonen-Informationen nicht verfügbar."

# Notifications
MSG_DE[ENERGY_NOTIFICATION_TITLE]="Energieverwaltung"
MSG_DE[ENERGY_NOTIFICATION_SLEEP_DISABLED]="Standby/Ruhezustand deaktiviert"
MSG_DE[ENERGY_NOTIFICATION_SLEEP_DISABLED_TIME]="Standby/Ruhezustand für %s deaktiviert"
MSG_DE[ENERGY_NOTIFICATION_SLEEP_RESTORED]="Standby/Ruhezustand wiederhergestellt"
MSG_DE[ENERGY_NOTIFICATION_GOVERNOR_SET]="CPU-Governor auf %s gesetzt"
MSG_DE[ENERGY_NOTIFICATION_BRIGHTNESS_SET]="Bildschirmhelligkeit auf %s%% gesetzt"

# Log messages
MSG_DE[ENERGY_LOG_DISABLE_SLEEP_START]="Starte Standby-Deaktivierungs-Funktionalität"
MSG_DE[ENERGY_LOG_DISABLING_SLEEP_PERMANENT]="Deaktiviere Standby/Ruhezustand bis zum Herunterfahren"
MSG_DE[ENERGY_LOG_DISABLING_SLEEP_TIME]="Deaktiviere Standby/Ruhezustand für %s"
MSG_DE[ENERGY_LOG_RESTORING_SLEEP]="Stelle Standby-Funktionalität wieder her, beende Prozess %s"
MSG_DE[ENERGY_LOG_SLEEP_DISABLED_PID]="Standby deaktiviert mit Inhibit-Prozess PID: %s"
MSG_DE[ENERGY_LOG_SLEEP_DISABLED_TIME_PID]="Standby für %s deaktiviert mit Inhibit-Prozess PID: %s"
MSG_DE[ENERGY_LOG_SLEEP_RESTORED]="Standby-Funktionalität wiederhergestellt"
MSG_DE[ENERGY_LOG_SETTING_GOVERNOR]="Setze CPU-Governor auf %s"
MSG_DE[ENERGY_LOG_GOVERNOR_SET_SUCCESS]="CPU-Governor erfolgreich auf %s gesetzt"
MSG_DE[ENERGY_LOG_GOVERNOR_SET_FAILED]="Fehler beim Setzen des CPU-Governors auf %s"
MSG_DE[ENERGY_LOG_SETTING_BRIGHTNESS]="Setze Bildschirmhelligkeit auf %s%%"
MSG_DE[ENERGY_LOG_BRIGHTNESS_SET_SUCCESS]="Bildschirmhelligkeit erfolgreich auf %s%% gesetzt"
MSG_DE[ENERGY_LOG_BRIGHTNESS_SET_FAILED]="Fehler beim Setzen der Bildschirmhelligkeit auf %s%%"
MSG_DE[ENERGY_LOG_MODULE_EXIT]="Verlasse Energieverwaltungsmodul"
