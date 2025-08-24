#!/bin/bash
#
# German translations for GUI launcher
#
[[ ! -v MSG_DE ]] && declare -A MSG_DE

# Error messages
MSG_DE[GUI_LAUNCHER_UNKNOWN_OPTION]="Unbekannte Option: %s"
MSG_DE[GUI_LAUNCHER_HELP_HINT]="Verwenden Sie -h oder --help für Nutzungsinformationen."
MSG_DE[GUI_LAUNCHER_DIR_NOT_FOUND]="GUI-Verzeichnis nicht gefunden: %s"
MSG_DE[GUI_LAUNCHER_GUI_NOT_INSTALLED]="Bitte stellen Sie sicher, dass die GUI ordnungsgemäß installiert ist."
MSG_DE[GUI_LAUNCHER_CHECKING_DEPS]="Prüfe GUI-Abhängigkeiten..."
MSG_DE[GUI_LAUNCHER_DEPS_MISSING]="Fehlende Abhängigkeiten für das Erstellen der GUI."
MSG_DE[GUI_LAUNCHER_BUILD_SCRIPT_MISSING]="Build-Skript nicht gefunden: %s"
MSG_DE[GUI_LAUNCHER_BUILD_SCRIPT_UNAVAILABLE]="Bitte stellen Sie sicher, dass das GUI-Build-Skript verfügbar ist."
MSG_DE[GUI_LAUNCHER_SETUP_FAILED]="Setup fehlgeschlagen. Bitte prüfen Sie die Fehlermeldungen oben."
MSG_DE[GUI_LAUNCHER_BUILD_FAILED]="Build fehlgeschlagen. Bitte prüfen Sie die Fehlermeldungen oben."

# Status messages
MSG_DE[GUI_LAUNCHER_REBUILDING]="GUI wird wie angefordert neu erstellt..."
MSG_DE[GUI_LAUNCHER_NOT_BUILT]="GUI ist noch nicht erstellt."
MSG_DE[GUI_LAUNCHER_BUILD_NEEDED]="Die GUI muss erstellt werden, bevor sie gestartet werden kann."
MSG_DE[GUI_LAUNCHER_BUILD_QUESTION]="Möchten Sie sie jetzt erstellen? [j/N]: "
MSG_DE[GUI_LAUNCHER_BUILD_CANCELLED]="Build abgebrochen. GUI kann nicht ohne vorherige Erstellung gestartet werden."
MSG_DE[GUI_LAUNCHER_BUILDING]="GUI wird erstellt..."
MSG_DE[GUI_LAUNCHER_SETUP_RUNNING]="Initiale Einrichtung läuft..."
MSG_DE[GUI_LAUNCHER_BUILD_COMPLETED]="Build erfolgreich abgeschlossen!"
MSG_DE[GUI_LAUNCHER_STARTING]="Little Linux Helper GUI wird gestartet..."
MSG_DE[GUI_LAUNCHER_NETWORK_WARNING1]="WARNUNG: Netzwerk-Modus aktiviert - GUI wird von anderen Rechnern aus zugänglich sein"
MSG_DE[GUI_LAUNCHER_NETWORK_WARNING2]="WARNUNG: Stellen Sie sicher, dass Ihre Firewall ordnungsgemäß konfiguriert ist"
MSG_DE[GUI_LAUNCHER_ACCESS_NETWORK]="Die GUI wird vom Netzwerk aus zugänglich sein (prüfen Sie die Konsolenausgabe für den aktuellen Port)"
MSG_DE[GUI_LAUNCHER_ACCESS_LOCAL]="Die GUI wird lokal zugänglich sein (prüfen Sie die Konsolenausgabe für den aktuellen Port)"
MSG_DE[GUI_LAUNCHER_STOP_HINT]="Drücken Sie Strg+C, um den GUI-Server zu stoppen."

# Firewall messages
MSG_DE[GUI_LAUNCHER_FW_OPENING]="Öffne Firewall für Port %s/%s (falls eine unterstützte Firewall aktiv ist)..."
MSG_DE[GUI_LAUNCHER_FW_FIREWALLD_SUCCESS]="firewalld: %s/%s geöffnet"
MSG_DE[GUI_LAUNCHER_FW_FIREWALLD_FAILED]="firewalld: Hinzufügen von %s/%s fehlgeschlagen"
MSG_DE[GUI_LAUNCHER_FW_FIREWALLD_NOT_RUNNING]="firewalld erkannt, aber nicht aktiv; überspringe."
MSG_DE[GUI_LAUNCHER_FW_UFW_SUCCESS]="ufw: %s/%s erlaubt"
MSG_DE[GUI_LAUNCHER_FW_UFW_FAILED]="ufw: Erlauben von %s/%s fehlgeschlagen"
MSG_DE[GUI_LAUNCHER_FW_IPTABLES_EXISTS]="iptables: Regel bereits vorhanden für %s/%s"
MSG_DE[GUI_LAUNCHER_FW_IPTABLES_SUCCESS]="iptables: ACCEPT-Regel für %s/%s hinzugefügt (nicht persistent)"
MSG_DE[GUI_LAUNCHER_FW_IPTABLES_PERSISTENT]="Erwägen Sie das Speichern der Regeln (z.B. iptables-persistent) falls nötig."
MSG_DE[GUI_LAUNCHER_FW_IPTABLES_FAILED]="iptables: Hinzufügen der Regel für %s/%s fehlgeschlagen"
MSG_DE[GUI_LAUNCHER_FW_NO_TOOL]="Kein unterstütztes Firewall-Tool erkannt (firewalld/ufw/iptables)."
MSG_DE[GUI_LAUNCHER_FW_CLOSING]="Schließe Firewall für Port %s/%s..."
MSG_DE[GUI_LAUNCHER_FW_FIREWALLD_CLOSE_SUCCESS]="firewalld: %s/%s geschlossen"
MSG_DE[GUI_LAUNCHER_FW_FIREWALLD_CLOSE_FAILED]="firewalld: Entfernen von %s/%s fehlgeschlagen"
MSG_DE[GUI_LAUNCHER_FW_UFW_CLOSE_SUCCESS]="ufw: Erlaubnisregel für %s/%s entfernt"
MSG_DE[GUI_LAUNCHER_FW_UFW_CLOSE_FAILED]="ufw: Entfernen der Regel für %s/%s fehlgeschlagen"
MSG_DE[GUI_LAUNCHER_FW_IPTABLES_CLOSE_SUCCESS]="iptables: ACCEPT-Regel für %s/%s entfernt"
MSG_DE[GUI_LAUNCHER_FW_IPTABLES_CLOSE_FAILED]="iptables: Entfernen der Regel für %s/%s fehlgeschlagen"
MSG_DE[GUI_LAUNCHER_FW_IPTABLES_NO_RULE]="iptables: keine Regel gefunden für %s/%s"
MSG_DE[GUI_LAUNCHER_FW_CLEANUP]="Räume Firewall-Regel auf..."
MSG_DE[GUI_LAUNCHER_FW_AUTO_REMOVE]="Firewall-Regel wird automatisch entfernt, wenn die GUI stoppt."
