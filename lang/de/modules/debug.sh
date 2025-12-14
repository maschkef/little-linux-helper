#!/bin/bash
#
# lang/de/modules/debug.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: Apache-2.0
#
# German language strings for debug module

[[ ! -v MSG_DE ]] && declare -A MSG_DE

MSG_DE[DEBUG_MODULE_NAME]="System-Debug-Bericht"
MSG_DE[DEBUG_MODULE_DESC]="Erstellt einen detaillierten Systembericht zur Fehlerbehebung."
MSG_DE[DEBUG_SECTION_BASIC]="Grundlegende Systeminformationen"
MSG_DE[DEBUG_SECTION_HARDWARE]="Hardware-Ressourcen"
MSG_DE[DEBUG_SECTION_LOGS]="System- und Anwendungsprotokolle"
MSG_DE[DEBUG_STARTING]="Erstelle Debug-Bericht unter: %s"
MSG_DE[DEBUG_COMPLETE]="Erstellung des Debug-Berichts erfolgreich abgeschlossen."
MSG_DE[DEBUG_REPORT_CREATED]="Debug-Bericht bereit"
MSG_DE[DEBUG_REVIEW_HINT]="Bitte überprüfen Sie die Datei, bevor Sie sie teilen."
MSG_DE[DEBUG_VIEW_NOW]="Möchten Sie den Bericht jetzt ansehen?"
