#!/bin/bash
#
# lang/de/docker_setup.sh
# Copyright (c) 2025 wuldorf
# SPDX-License-Identifier: MIT
#
# This script is part of the 'little-linux-helper' collection.
# Licensed under the MIT License. See the LICENSE file in the project root for more information.
#
# Deutsche Übersetzungen für das Docker Setup Modul

[[ ! -v MSG_DE ]] && declare -A MSG_DE

# Docker Setup Haupttitel
MSG_DE[DOCKER_SETUP_TITLE]="Docker Installation & Setup"
MSG_DE[DOCKER_SETUP_CHECK_TITLE]="Docker Installation überprüfen"

# Docker Installation Status
MSG_DE[DOCKER_SETUP_DOCKER_FOUND]="Docker ist installiert"
MSG_DE[DOCKER_SETUP_DOCKER_NOT_FOUND]="Docker ist nicht installiert"
MSG_DE[DOCKER_SETUP_COMPOSE_FOUND]="Docker Compose ist verfügbar"
MSG_DE[DOCKER_SETUP_DOCKER_COMPOSE_FOUND]="Docker Compose ist verfügbar"
MSG_DE[DOCKER_SETUP_COMPOSE_NOT_FOUND]="Docker Compose ist nicht verfügbar"
MSG_DE[DOCKER_SETUP_DOCKER_COMPOSE_NOT_FOUND]="Docker Compose ist nicht verfügbar"
MSG_DE[DOCKER_SETUP_DOCKER_VERSION]="Docker Version:"
MSG_DE[DOCKER_SETUP_COMPOSE_VERSION]="Docker Compose Version:"

# Docker Service Status
MSG_DE[DOCKER_SETUP_SERVICE_RUNNING]="Docker Service läuft"
MSG_DE[DOCKER_SETUP_SERVICE_NOT_RUNNING]="Docker Service läuft nicht"
MSG_DE[DOCKER_SETUP_SERVICE_ENABLED]="Docker Service ist aktiviert (Autostart)"
MSG_DE[DOCKER_SETUP_SERVICE_DISABLED]="Docker Service ist deaktiviert"

# Docker Benutzer und Berechtigungen
MSG_DE[DOCKER_SETUP_USER_IN_GROUP]="Aktueller Benutzer ist in der Docker-Gruppe"
MSG_DE[DOCKER_SETUP_USER_NOT_IN_GROUP]="Aktueller Benutzer ist nicht in der Docker-Gruppe"
MSG_DE[DOCKER_SETUP_GROUP_EXISTS]="Docker-Gruppe existiert"
MSG_DE[DOCKER_SETUP_GROUP_NOT_EXISTS]="Docker-Gruppe existiert nicht"

# Docker Installation Menü
MSG_DE[DOCKER_SETUP_MENU_INSTALL_DOCKER]="Docker installieren"
MSG_DE[DOCKER_SETUP_MENU_INSTALL_COMPOSE]="Docker Compose installieren"
MSG_DE[DOCKER_SETUP_MENU_START_SERVICE]="Docker Service starten"
MSG_DE[DOCKER_SETUP_MENU_ENABLE_SERVICE]="Docker Service aktivieren (Autostart)"
MSG_DE[DOCKER_SETUP_MENU_ADD_USER]="Aktuellen Benutzer zur Docker-Gruppe hinzufügen"
MSG_DE[DOCKER_SETUP_MENU_COMPLETE_SETUP]="Vollständige Docker-Installation durchführen"
MSG_DE[DOCKER_SETUP_MENU_UNINSTALL]="Docker deinstallieren"
MSG_DE[DOCKER_SETUP_MENU_BACK]="Zurück zum Docker-Menü"

# Docker Installation Nachrichten
MSG_DE[DOCKER_SETUP_INSTALLING_DOCKER]="Docker wird installiert..."
MSG_DE[DOCKER_SETUP_INSTALLING_COMPOSE]="Docker Compose wird installiert..."
MSG_DE[DOCKER_SETUP_DOCKER_INSTALLED]="Docker wurde erfolgreich installiert"
MSG_DE[DOCKER_SETUP_COMPOSE_INSTALLED]="Docker Compose wurde erfolgreich installiert"
MSG_DE[DOCKER_SETUP_INSTALLATION_FAILED]="Installation fehlgeschlagen"

# Docker Service Operationen
MSG_DE[DOCKER_SETUP_STARTING_SERVICE]="Docker Service wird gestartet..."
MSG_DE[DOCKER_SETUP_SERVICE_STARTED]="Docker Service wurde gestartet"
MSG_DE[DOCKER_SETUP_SERVICE_START_FAILED]="Docker Service konnte nicht gestartet werden"
MSG_DE[DOCKER_SETUP_ENABLING_SERVICE]="Docker Service wird aktiviert..."
MSG_DE[DOCKER_SETUP_SERVICE_ENABLED_SUCCESS]="Docker Service wurde aktiviert"
MSG_DE[DOCKER_SETUP_SERVICE_ENABLE_FAILED]="Docker Service konnte nicht aktiviert werden"

# Benutzergruppen-Operationen
MSG_DE[DOCKER_SETUP_ADDING_USER_TO_GROUP]="Benutzer wird zur Docker-Gruppe hinzugefügt..."
MSG_DE[DOCKER_SETUP_USER_ADDED_TO_GROUP]="Benutzer wurde zur Docker-Gruppe hinzugefügt"
MSG_DE[DOCKER_SETUP_USER_ADD_FAILED]="Benutzer konnte nicht zur Docker-Gruppe hinzugefügt werden"
MSG_DE[DOCKER_SETUP_LOGOUT_REQUIRED]="Bitte melden Sie sich ab und wieder an, damit die Gruppenänderungen wirksam werden."

# Vollständige Installation
MSG_DE[DOCKER_SETUP_COMPLETE_INSTALLATION]="Vollständige Docker-Installation"
MSG_DE[DOCKER_SETUP_COMPLETE_DESCRIPTION]="Dies installiert Docker, Docker Compose, startet den Service und fügt den Benutzer zur Docker-Gruppe hinzu."
MSG_DE[DOCKER_SETUP_COMPLETE_CONFIRM]="Vollständige Docker-Installation durchführen?"
MSG_DE[DOCKER_SETUP_COMPLETE_SUCCESS]="Docker-Installation erfolgreich abgeschlossen"
MSG_DE[DOCKER_SETUP_COMPLETE_PARTIAL]="Docker-Installation teilweise erfolgreich"

# Docker Deinstallation
MSG_DE[DOCKER_SETUP_UNINSTALL_TITLE]="Docker deinstallieren"
MSG_DE[DOCKER_SETUP_UNINSTALL_WARNING]="WARNUNG: Dies entfernt Docker und alle Container, Images und Volumes!"
MSG_DE[DOCKER_SETUP_UNINSTALL_CONFIRM]="Sind Sie sicher, dass Sie Docker deinstallieren möchten?"
MSG_DE[DOCKER_SETUP_UNINSTALLING]="Docker wird deinstalliert..."
MSG_DE[DOCKER_SETUP_UNINSTALL_SUCCESS]="Docker wurde erfolgreich deinstalliert"
MSG_DE[DOCKER_SETUP_UNINSTALL_FAILED]="Docker-Deinstallation fehlgeschlagen"

# Distributionsspezifische Nachrichten
MSG_DE[DOCKER_SETUP_DISTRO_DETECTED]="Erkannte Distribution:"
MSG_DE[DOCKER_SETUP_DISTRO_NOT_SUPPORTED]="Diese Distribution wird möglicherweise nicht vollständig unterstützt"
MSG_DE[DOCKER_SETUP_USING_PACKAGE_MANAGER]="Verwendeter Paketmanager:"

# Fehler- und Warnmeldungen
MSG_DE[DOCKER_SETUP_ERROR_ROOT_REQUIRED]="Root-Berechtigung erforderlich für diese Operation"
MSG_DE[DOCKER_SETUP_ERROR_PACKAGE_MANAGER]="Paketmanager konnte nicht erkannt werden"
MSG_DE[DOCKER_SETUP_ERROR_NETWORK]="Netzwerkfehler beim Herunterladen"
MSG_DE[DOCKER_SETUP_ERROR_PERMISSION]="Berechtigungsfehler"

# Installationsmethoden
MSG_DE[DOCKER_SETUP_METHOD_REPOSITORY]="Installation über offizielle Repository"
MSG_DE[DOCKER_SETUP_METHOD_PACKAGE]="Installation über Systempaket"
MSG_DE[DOCKER_SETUP_METHOD_SCRIPT]="Installation über Installationsskript"

# Test und Validierung
MSG_DE[DOCKER_SETUP_TESTING_INSTALLATION]="Installation wird getestet..."
MSG_DE[DOCKER_SETUP_TEST_SUCCESS]="Docker-Installation funktioniert korrekt"
MSG_DE[DOCKER_SETUP_TEST_FAILED]="Docker-Installation-Test fehlgeschlagen"
MSG_DE[DOCKER_SETUP_RUNNING_HELLO_WORLD]="Hello-World Container wird ausgeführt..."

# Hilfreiche Hinweise
MSG_DE[DOCKER_SETUP_HINT_FIREWALL]="Hinweis: Stellen Sie sicher, dass Ihre Firewall Docker-Traffic erlaubt"
MSG_DE[DOCKER_SETUP_HINT_REBOOT]="Hinweis: Ein Neustart kann nach der Installation erforderlich sein"
MSG_DE[DOCKER_SETUP_HINT_DOCUMENTATION]="Weitere Informationen finden Sie in der Docker-Dokumentation"

# Erweiterte Docker Setup Übersetzungen

# Installation
MSG_DE[DOCKER_SETUP_INSTALL_TITLE]="Docker Installation"
MSG_DE[DOCKER_SETUP_INSTALL_DOCKER]="Docker installieren"
MSG_DE[DOCKER_SETUP_INSTALL_COMPOSE]="Docker Compose installieren"
MSG_DE[DOCKER_SETUP_INSTALL_BOTH]="Docker und Docker Compose installieren"
MSG_DE[DOCKER_SETUP_INSTALL_SUCCESS]="Installation erfolgreich"
MSG_DE[DOCKER_SETUP_INSTALL_FAILED]="Installation fehlgeschlagen"

# Betriebssystem-spezifisch
MSG_DE[DOCKER_SETUP_DETECTING_OS]="Erkenne Betriebssystem..."
MSG_DE[DOCKER_SETUP_OS_DETECTED]="Betriebssystem erkannt: %s"
MSG_DE[DOCKER_SETUP_OS_UNSUPPORTED]="Nicht unterstütztes Betriebssystem"
MSG_DE[DOCKER_SETUP_DISTRO_SPECIFIC]="Verwende distributionsspezifische Installation"

# Services
MSG_DE[DOCKER_SETUP_SERVICE_START]="Docker-Service starten"
MSG_DE[DOCKER_SETUP_SERVICE_ENABLE]="Docker-Service aktivieren"
MSG_DE[DOCKER_SETUP_SERVICE_STATUS]="Docker-Service Status"

# Benutzergruppen
MSG_DE[DOCKER_SETUP_USER_GROUP]="Benutzer zur docker-Gruppe hinzufügen"
MSG_DE[DOCKER_SETUP_USER_ADDED]="Benutzer zur docker-Gruppe hinzugefügt"
MSG_DE[DOCKER_SETUP_USER_LOGOUT_REQUIRED]="Bitte loggen Sie sich aus und wieder ein, damit die Änderungen wirksam werden"

# Erweiterte Menüoptionen
MSG_DE[DOCKER_SETUP_MENU_INSTALL_DOCKER]="Nur Docker installieren"
MSG_DE[DOCKER_SETUP_MENU_INSTALL_COMPOSE]="Nur Docker Compose installieren"
MSG_DE[DOCKER_SETUP_MENU_INSTALL_BOTH]="Docker und Docker Compose installieren"
MSG_DE[DOCKER_SETUP_MENU_UNINSTALL]="Docker deinstallieren"
MSG_DE[DOCKER_SETUP_MENU_SERVICE_MANAGE]="Docker-Service verwalten"

# Deinstallation
MSG_DE[DOCKER_SETUP_UNINSTALL_TITLE]="Docker Deinstallation"
MSG_DE[DOCKER_SETUP_UNINSTALL_CONFIRM]="Sind Sie sicher, dass Sie Docker deinstallieren möchten?"
MSG_DE[DOCKER_SETUP_UNINSTALL_SUCCESS]="Docker erfolgreich deinstalliert"
MSG_DE[DOCKER_SETUP_UNINSTALL_FAILED]="Deinstallation fehlgeschlagen"

# Fehler und Warnungen
MSG_DE[DOCKER_SETUP_ERROR_PERMISSION]="Berechtigung verweigert. Sind Sie root oder haben sudo-Rechte?"
MSG_DE[DOCKER_SETUP_ERROR_NETWORK]="Netzwerkfehler. Bitte überprüfen Sie Ihre Internetverbindung."
MSG_DE[DOCKER_SETUP_WARNING_EXPERIMENTAL]="Warnung: Diese Installation ist experimentell"
MSG_DE[DOCKER_SETUP_WARNING_BETA]="Warnung: Dies ist eine Beta-Version"

# Version-Info
MSG_DE[DOCKER_SETUP_VERSION_DOCKER]="Docker Version: %s"
MSG_DE[DOCKER_SETUP_VERSION_COMPOSE]="Docker Compose Version: %s"
MSG_DE[DOCKER_SETUP_VERSION_CHECK]="Versionen überprüfen"

# Weitere fehlende Übersetzungen für Docker Setup

# Installation und Prompts
MSG_DE[DOCKER_SETUP_MISSING_COMPONENTS]="Fehlende Docker-Komponenten erkannt"
MSG_DE[DOCKER_SETUP_INSTALL_PROMPT]="Möchten Sie die fehlenden Komponenten installieren?"
MSG_DE[DOCKER_SETUP_INSTALL_DECLINED]="Installation abgelehnt"
MSG_DE[DOCKER_SETUP_ALL_INSTALLED]="Alle Docker-Komponenten sind installiert"

# Installation Prozess
MSG_DE[DOCKER_SETUP_INSTALLING_DOCKER]="Installiere Docker..."
MSG_DE[DOCKER_SETUP_DOCKER_INSTALLED]="Docker erfolgreich installiert"
MSG_DE[DOCKER_SETUP_DOCKER_INSTALL_FAILED]="Docker-Installation fehlgeschlagen"
MSG_DE[DOCKER_SETUP_INSTALLING_COMPOSE]="Installiere Docker Compose..."
MSG_DE[DOCKER_SETUP_COMPOSE_INSTALLED]="Docker Compose erfolgreich installiert"
MSG_DE[DOCKER_SETUP_COMPOSE_INSTALL_FAILED]="Docker Compose-Installation fehlgeschlagen"

# Installation Details
MSG_DE[DOCKER_SETUP_STARTING_DOCKER_INSTALL]="Starte Docker-Installation"
MSG_DE[DOCKER_SETUP_INSTALL_ARCH]="Installiere Docker für Arch Linux"
MSG_DE[DOCKER_SETUP_INSTALL_DEBIAN]="Installiere Docker für Debian/Ubuntu"
MSG_DE[DOCKER_SETUP_INSTALL_FEDORA]="Installiere Docker für Fedora"
MSG_DE[DOCKER_SETUP_INSTALL_OPENSUSE]="Installiere Docker für openSUSE"
MSG_DE[DOCKER_SETUP_UNSUPPORTED_PKG_MANAGER]="Nicht unterstützter Paketmanager"
MSG_DE[DOCKER_SETUP_MANUAL_INSTALL_HINT]="Bitte installieren Sie Docker manuell von https://docs.docker.com/get-docker/"

# Docker Compose Installation Details
MSG_DE[DOCKER_SETUP_STARTING_COMPOSE_INSTALL]="Starte Docker Compose-Installation"
MSG_DE[DOCKER_SETUP_INSTALL_COMPOSE_ARCH]="Installiere Docker Compose für Arch Linux"
MSG_DE[DOCKER_SETUP_INSTALL_COMPOSE_DEBIAN]="Installiere Docker Compose für Debian/Ubuntu"
MSG_DE[DOCKER_SETUP_INSTALL_COMPOSE_FEDORA]="Installiere Docker Compose für Fedora"
MSG_DE[DOCKER_SETUP_INSTALL_COMPOSE_OPENSUSE]="Installiere Docker Compose für openSUSE"
MSG_DE[DOCKER_SETUP_COMPOSE_MANUAL_INSTALL]="Versuche manuelle Docker Compose-Installation"
MSG_DE[DOCKER_SETUP_DOCKER_REQUIRED_FOR_COMPOSE]="Docker muss installiert sein, bevor Docker Compose installiert werden kann"

# Manuelle Installation
MSG_DE[DOCKER_SETUP_COMPOSE_DOWNLOAD]="Lade Docker Compose herunter"
MSG_DE[DOCKER_SETUP_NO_DOWNLOAD_TOOL]="Kein Download-Tool (curl oder wget) verfügbar"
MSG_DE[DOCKER_SETUP_VERSION_DETECTION_FAILED]="Versionserkennung fehlgeschlagen, verwende Fallback-Version"
MSG_DE[DOCKER_SETUP_DOWNLOADING_VERSION]="Lade Version herunter"
MSG_DE[DOCKER_SETUP_COMPOSE_DOWNLOAD_SUCCESS]="Docker Compose erfolgreich heruntergeladen"
MSG_DE[DOCKER_SETUP_COMPOSE_DOWNLOAD_FAILED]="Docker Compose-Download fehlgeschlagen"

# Post-Installation
MSG_DE[DOCKER_SETUP_POST_INSTALL_TITLE]="Post-Installation Setup"
MSG_DE[DOCKER_SETUP_ENABLING_SERVICE]="Aktiviere und starte Docker-Service"
MSG_DE[DOCKER_SETUP_SERVICE_STARTED]="Docker-Service erfolgreich gestartet"
MSG_DE[DOCKER_SETUP_SERVICE_START_FAILED]="Docker-Service konnte nicht gestartet werden"
MSG_DE[DOCKER_SETUP_ADDING_USER_TO_GROUP]="Füge Benutzer zur docker-Gruppe hinzu"
MSG_DE[DOCKER_SETUP_LOGOUT_REQUIRED]="Bitte melden Sie sich ab und wieder an, damit die Gruppenänderungen wirksam werden."

# Service Management
MSG_DE[DOCKER_SETUP_CHECKING_SERVICE]="Überprüfe Docker-Service Status"
MSG_DE[DOCKER_SETUP_SERVICE_NOT_ENABLED]="Docker-Service ist nicht aktiviert (kein Autostart)"
MSG_DE[DOCKER_SETUP_START_SERVICE_PROMPT]="Docker-Service jetzt starten?"
MSG_DE[DOCKER_SETUP_ENABLE_SERVICE_PROMPT]="Docker-Service für Autostart aktivieren?"
MSG_DE[DOCKER_SETUP_SERVICE_ENABLED_SUCCESS]="Docker-Service erfolgreich aktiviert"
MSG_DE[DOCKER_SETUP_NO_SYSTEMCTL]="systemctl nicht verfügbar"

# Hauptmodul
MSG_DE[DOCKER_SETUP_MAIN_TITLE]="Docker Installation & Setup"
MSG_DE[DOCKER_SETUP_DESCRIPTION]="Dieses Modul überprüft Ihre Docker-Installation und kann fehlende Komponenten installieren"
MSG_DE[DOCKER_SETUP_MODULE_COMPLETED]="Docker Setup Modul abgeschlossen"
