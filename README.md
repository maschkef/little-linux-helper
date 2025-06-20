# Little Linux Helper

## Beschreibung

Little Linux Helper ist eine Sammlung von Bash-Skripten, die entwickelt wurden, um verschiedene Systemadministrations-, Diagnose- und Wartungsaufgaben unter Linux zu vereinfachen. Es bietet ein menügeführtes Interface für einfachen Zugriff auf eine Vielzahl von Werkzeugen und Funktionen.

Eine detailliertere technische englische Dokumentation der einzelnen Module und Kernkomponenten befindet sich im `docs`-Verzeichnis, 
diese wurde mitunter erstellt um einer KI den kontext eines modules bzw einer Datei zu geben ohne dieses selbst komplett lesen zu müssen und kontext zusparen.
Die `docs/PROJECT_DESCRIPTION.md` enthält alle Infomationen zu `lib/lib_common.sh` und `help_master.sh` die benötigt werden um ein neues modul zu erstellen.

Meine Umgebung ist i.d.R. Arch (hauptsystem) oder Debian (diverse Dienste auf meinem Proxmox - daher auch die docker-Anteile), entsprechend kann es unter anderen Distributionen noch unbekannte Probleme geben, auch wenn ich versuche, alles kompatibel zu halten.

<details>
<summary>⚠️ Wichtige Hinweise zur Nutzung</summary>

**Bitte beachte die folgenden Punkte sorgfältig, bevor du die Skripte aus diesem Repository verwendest:**

* **Kein professioneller Programmierer:** Ich bin eigentlich kein Programmierer. Diese Skripte sind als Hobbyprojekt und zum Vereinfachen entstanden. Sie können daher suboptimale Lösungsansätze, Fehler oder ineffiziente Herangehensweisen enthalten.
* **Nutzung auf eigene Gefahr:** Die Verwendung der hier bereitgestellten Skripte erfolgt ausschließlich auf eigene Gefahr. Ich übernehme keinerlei Verantwortung oder Haftung für mögliche Datenverluste, Systeminstabilitäten, Schäden an Hard- oder Software oder jegliche andere direkte oder indirekte Konsequenzen, die aus der Nutzung dieser Skripte resultieren könnten. Es wird dringend empfohlen, vor der Ausführung kritischer Operationen stets Backups deiner wichtigen Daten und deines Systems anzulegen.
* **KI-generierte Inhalte:** Ein erheblicher Teil der Skripte und der begleitenden Dokumentation wurde unter Zuhilfenahme von Künstlicher Intelligenz (KI) erstellt. Obwohl ich mich bemüht habe, die Funktionalität zu testen und die Informationen zu überprüfen, können die Skripte Fehler, unvorhergesehenes Verhalten oder logische Mängel enthalten, die auf den KI-Generierungsprozess zurückzuführen sind. Sei dir dieses Umstands bewusst und überprüfe den Code kritisch, bevor du ihn einsetzt, insbesondere in produktiven oder sensiblen Umgebungen.

</details>

## Lizenz

Dieses Projekt steht unter der MIT-Lizenz. Weitere Informationen findest du in der Datei `LICENSE` im Projektstammverzeichnis.

<details>
<summary>❗ Bekannte Probleme und Einschränkungen</summary>

Hier ist eine Liste von bekannten Problemen, Einschränkungen oder Verhaltensweisen, die dir bei der Nutzung der Skripte auffallen könnten.
* **Backups:**
    * **BTRFS-Backup:** Die BTRFS-Backup- und Restore-Funktionen sind jetzt in den Modulen `mod_btrfs_backup.sh` und `mod_btrfs_restore.sh` ausgelagert. Die anderen Backup-Methoden (TAR, RSYNC) sind weniger intensiv getestet.
* **Erweiterte Log-Analyse (`scripts/advanced_log_analyzer.py`):**
    * Dieses Skript ist weniger intensiv getestet und hat bekannte Einschränkungen bezüglich Log-Format-Erkennung, Zeichenkodierung und der Komplexität seiner regulären Ausdrücke (Details siehe `docs/advanced_log_analyzer.md`).

</details>

## Funktionen

Das Hauptskript `help_master.sh` dient als zentraler Einstiegspunkt und bietet Zugriff auf folgende Module:

<details>
<summary>🔄 Wiederherstellung & Neustarts (<code>mod_restarts.sh</code>)</summary>

* Neustart des Login-Managers (Display Manager).
* Neustart des Sound-Systems (PipeWire, PulseAudio, ALSA).
* Neustart der Desktop-Umgebung (KDE, GNOME, XFCE, Cinnamon, MATE, LXDE, LXQt).
* Neustart von Netzwerkdiensten (NetworkManager, systemd-networkd, dhcpcd, systemd-resolved).

</details>

<details>
<summary>💾 Backup & Wiederherstellung</summary>

* **BTRFS Snapshot Backup & Restore** (`mod_btrfs_backup.sh`, `mod_btrfs_restore.sh`):
    * Erstellung und Verwaltung von Snapshots der Subvolumes `@` und `@home`.
    * Übertragung der Snapshots zum Backup-Ziel mittels `btrfs send/receive`.
    * Integrierte Integritätsprüfung, Marker-Dateien, automatische Bereinigung, manuelles und automatisches Löschen, Statusanzeige und Desktop-Benachrichtigungen.
    * Wiederherstellung kompletter Systeme, einzelner Subvolumes oder einzelner Ordner aus Snapshots – mit Dry-Run-Unterstützung.
    * Ausführliche technische Beschreibung: siehe `docs/mod_btrfs_backup.md` und `docs/mod_btrfs_restore.md`.
* **TAR Archiv Backup & Restore** (`mod_backup.sh`):
    * Erstellung komprimierter TAR-Archive (`.tar.gz`) von ausgewählten Verzeichnissen.
    * Konfigurierbare Ausschlusslisten und Aufbewahrungsrichtlinien.
    * Wiederherstellung an ursprünglichen Ort, temporäres Verzeichnis oder benutzerdefinierten Pfad.
* **RSYNC Backup & Restore** (`mod_backup.sh`):
    * Backups mit `rsync` (Voll- oder inkrementell, mit Hardlinks für Speicherersparnis).
    * Auswahl von Quellverzeichnissen und Ausschlusslisten.
    * Wiederherstellung an ursprünglichen Ort, temporäres Verzeichnis oder benutzerdefinierten Pfad.
* **Backup-Status und -Konfiguration**:
    * Anzeige des aktuellen Backup-Status (Online/Offline, freier Speicherplatz, vorhandene Backups, neueste Backups, Gesamtgröße).
    * Anzeige und Änderung der Backup-Konfiguration (Zielpfad, Verzeichnis, Retention, temporäres Snapshot-Verzeichnis).

</details>

<details>
<summary>💻 Systemdiagnose & Analyse</summary>

* **Systeminformationen anzeigen (`mod_system_info.sh`)**:
    * Anzeige von Betriebssystem- und Kernel-Details.
    * CPU-Informationen.
    * RAM-Auslastung und Speicherstatistik.
    * Auflistung von PCI- und USB-Geräten.
    * Festplattenübersicht (Blockgeräte, Dateisysteme, Mountpunkte).
    * Anzeige der Top-Prozesse nach CPU- und Speicherauslastung.
    * Netzwerkkonfiguration (Schnittstellen, Routen, aktive Verbindungen, Hostname, DNS).
    * Temperaturen und Sensorwerte (erfordert `lm-sensors`).
* **Festplatten-Werkzeuge (`mod_disk.sh`)**:
    * Anzeige eingebundener Laufwerke und Blockgeräte.
    * Auslesen von S.M.A.R.T.-Werten (erfordert `smartmontools`).
    * Prüfung von Dateizugriffen auf Ordner (erfordert `lsof`).
    * Analyse der Festplattenbelegung (mit `df` und optional `ncdu`).
    * Testen der Festplattengeschwindigkeit (erfordert `hdparm`).
    * Überprüfung des Dateisystems (erfordert `fsck`).
    * Prüfung des Festplatten-Gesundheitsstatus (erfordert `smartmontools`).
    * Anzeige der größten Dateien in einem Verzeichnis.
* **Log-Analyse Werkzeuge (`mod_logs.sh`)**:
    * Anzeige von Logs der letzten X Minuten (aktueller und vorheriger Boot, erfordert ggf. `journalctl`).
    * Logs eines bestimmten systemd-Dienstes anzeigen (erfordert `journalctl`).
    * Xorg-Logs anzeigen.
    * dmesg-Ausgabe anzeigen und filtern.
    * Paketmanager-Logs anzeigen (unterstützt pacman, apt, dnf, yay).
    * **Erweiterte Log-Analyse (`scripts/advanced_log_analyzer.py`)**:
        * Führt eine detailliertere Analyse von Logdateien durch (benötigt Python 3, typischerweise als `python3`-Kommando).
        * Unterstützt Formate wie Syslog, Journald (Text-Export) und Apache (Common/Combined), inklusive automatischer Formaterkennung.
        * Zeigt allgemeine Statistiken (Gesamtzahl Einträge, Fehleranzahl, Fehlerrate).
        * Listet häufige Fehlermeldungen oder Fehler-Statuscodes.
        * Analysiert die zeitliche Verteilung von Logeinträgen (z.B. pro Stunde).
        * Identifiziert Top-Quellen (Programme/Dienste bei Syslog, IP-Adressen bei Apache).
        * Bietet Optionen zur Anpassung der Ausgabe (z.B. Anzahl der Top-Einträge, nur Zusammenfassung, nur Fehler).
        * *Hinweis: Dieses Skript bietet erweiterte Funktionen, sollte aber mit Bedacht und Verständnis seiner Funktionsweise eingesetzt werden, insbesondere unter Berücksichtigung der allgemeinen Projekthinweise*.

</details>

<details>
<summary>🛠️ Wartung & Sicherheit</summary>

* **Paketverwaltung & Updates (`mod_packages.sh`)**:
    * Systemaktualisierung (unterstützt pacman, apt, dnf, yay).
    * Aktualisierung alternativer Paketmanager (Flatpak, Snap, Nix).
    * Suchen und Entfernen von verwaisten Paketen.
    * Bereinigung des Paket-Caches.
    * Suchen und Installieren von Paketen.
    * Anzeigen installierter Pakete (inkl. alternativer Quellen).
    * Anzeigen von Paketmanager-Logs.
* **Sicherheitsüberprüfungen (`mod_security.sh`)**:
    * Anzeige offener Netzwerkports (erfordert `ss`, optional `nmap`).
    * Anzeige fehlgeschlagener Anmeldeversuche.
    * System auf Rootkits prüfen (erfordert `rkhunter`, optional `chkrootkit`).
    * Firewall-Status prüfen (UFW, firewalld, iptables).
    * Prüfung auf Sicherheits-Updates.
    * Überprüfung von Kennwort-Richtlinien und Benutzerkonten.
    * **Docker Security Überprüfung**:
        * Analysiert Docker-Compose Dateien (`docker-compose.yml`, `compose.yml`) auf häufige Sicherheitsprobleme.
        * Der Suchpfad für Compose-Dateien, die Suchtiefe und auszuschließende Verzeichnisse sind konfigurierbar.
        * Bietet eine interaktive Konfiguration des Suchpfads, falls der aktuelle Pfad ungültig ist oder geändert werden soll.
        * Führt eine Reihe von Prüfungen durch, darunter:
            * Fehlen von Update-Management-Labels (z.B. für Diun, Watchtower).
            * Unsichere Berechtigungen für `.env`-Dateien.
            * Zu offene Berechtigungen für Verzeichnisse, die Compose-Dateien enthalten.
            * Verwendung von `:latest`-Image-Tags oder Images ohne spezifische Versionierung. (In der `config/docker_security.conf.example` im standard deaktiviert.)
            * Konfiguration von Containern mit `privileged: true`.
            * Einbindung kritischer Host-Pfade als Volumes (z.B. `/`, `/etc`, `/var/run/docker.sock`). (Wird derzeit nicht in der zusammenfassung mit ausgegeben.)
            * Auf `0.0.0.0` exponierte Ports, die Dienste für alle Netzwerkschnittstellen verfügbar machen.
            * Verwendung potenziell gefährlicher Linux-Capabilities (z.B. `SYS_ADMIN`, `NET_ADMIN`).
            * Deaktivierte Sicherheitsoptionen wie `apparmor:unconfined` oder `seccomp:unconfined`.
            * Vorkommen von bekannten Standardpasswörtern in Umgebungsvariablen.
            * Direkte Einbettung sensitiver Daten (z.B. API-Keys, Tokens) anstelle von Umgebungsvariablen. (funktioniert aktuell nicht wirklich)
        * Optional kann eine Liste der aktuell laufenden Docker-Container angezeigt werden. (In der `config/docker_security.conf.example` im standard deaktiviert.)
        * Stellt eine Zusammenfassung der gefundenen potenziellen Probleme mit Empfehlungen bereit.

</details>

<details>
<summary>✨ Spezialfunktionen</summary>

* Sammeln wichtiger Debug-Informationen in einer Datei.

</details>

## Anforderungen

<details>
<summary>📋 Anforderungen</summary>

* Bash-Shell
* Standard Linux-Dienstprogramme (wie `grep`, `awk`, `sed`, `find`, `df`, `lsblk`, `ip`, `ps`, `free`, `tar`, `rsync`, `btrfs-progs` etc.)
* Einige Funktionen erfordern möglicherweise Root-Rechte und werden ggf. `sudo` verwenden.
* Für spezifische Funktionen werden zusätzliche Pakete benötigt, die das Skript bei Bedarf zu installieren versucht:
    * `btrfs-progs` (für BTRFS Backup/Restore)
    * `rsync` (für RSYNC Backup/Restore)
    * `smartmontools` (für S.M.A.R.T.-Werte und Festplatten-Gesundheitsstatus)
    * `lsof` (für Dateizugriff-Prüfung)
    * `hdparm` (für Festplattengeschwindigkeitstest)
    * `ncdu` (für interaktive Festplattenanalyse, optional)
    * `util-linux` (enthält `fsck`)
    * `iproute2` (enthält `ss`)
    * `rkhunter` (für Rootkit-Prüfung)
    * `chkrootkit` (optional, für zusätzliche Rootkit-Prüfung)
    * `lm-sensors` (für Temperatur- und Sensorwerte)
    * `nmap` (optional, für lokalen Port-Scan)
    * **Desktop-Benachrichtigungen:** `libnotify` (stellt `notify-send` bereit), `zenity` oder `kdialog`.
    * Python 3 (typischerweise als `python` oder `python3`-Kommando; für erweiterte Log-Analyse)
    * `pacman-contrib` (für `paccache` auf Arch-basierten Systemen, falls nicht vorhanden)
    * `expac` (für kürzlich installierte Pakete auf Arch-basierten Systemen)

Das Skript versucht, den verwendeten Paketmanager (pacman, yay, apt, dnf) automatisch zu erkennen. Es erkennt auch alternative Paketmanager wie Flatpak, Snap, Nix und AppImage.

</details>

## Installation & Setup

<details>
<summary>🚀 Installation & Setup</summary>

1.  Klone das Repository oder lade die Skripte herunter.
2.  Stelle sicher, dass das Hauptskript `help_master.sh` ausführbar ist:
    ```bash
    chmod +x help_master.sh
    ```

</details>

## Konfiguration

<details>
<summary>⚙️ Konfigurationsdateien</summary>

Little Linux Helper verwendet Konfigurationsdateien, um bestimmte Aspekte seines Verhaltens anzupassen. Diese Dateien befinden sich im Verzeichnis `config/`.

Beim ersten Start des Hauptskripts (`help_master.sh`) werden automatisch Standard-Konfigurationsdateien erstellt, falls diese noch nicht vorhanden sind. Dies geschieht, indem Vorlagedateien mit der Endung `.example` (z.B. `backup.conf.example`) in ihre aktiven Gegenstücke ohne das Suffix (z.B. `backup.conf`) kopiert werden.

**Wichtig:** Du wirst beim ersten Erstellen einer Konfigurationsdatei darauf hingewiesen. Es wird empfohlen, diese neu erstellten `.conf`-Dateien zu überprüfen und gegebenenfalls an deine spezifischen Bedürfnisse anzupassen.

Aktuell werden Konfigurationsdateien für folgende Module verwendet:
*   **Backup & Wiederherstellung (`mod_backup.sh`, `mod_btrfs_backup.sh`, `mod_btrfs_restore.sh`)**: Einstellungen für Backup-Pfade, Aufbewahrungsrichtlinien etc. (`config/backup.conf`).
*   **Docker Security Überprüfung (`mod_security.sh`)**: Einstellungen für Suchpfade, zu überspringende Warnungen etc. (`config/docker_security.conf`).

</details>

## Module Übersicht

<details>
<summary>📦 Module Übersicht</summary>

Das Projekt ist in Module unterteilt, um die Funktionalität zu organisieren:

* ** `lib/lib_common.sh`**: Das Herzstück des Projekts. Enthält zentrale, von allen Modulen genutzte Funktionen wie:
    *  Ein einheitliches Logging-System.
    * Funktionen zur Befehlsüberprüfung und automatischen Installation von Abhängigkeiten.
    * Standardisierte Benutzer interaktionen (Ja/Nein-Fragen, Eingabeaufforderungen).
    * Die Erkennung von Systemkomponenten (Paketmanager, etc .).
    * Verwaltung von farbiger Terminalausgabe für eine bessere Lesbarkeit.
    * Komplexe Logik zur Ermittlung des aktiven Desktop-Ben utzers.
    * Die Fähigkeit, **Desktop-Benachrichtigungen** an den Benutzer zu senden.
* **`modules/mod_restarts.sh`**: Bietet Optionen zum Neustarten von Diensten und der Desktop-Umgebung.
* **`modules/mod_backup.sh`**: Stellt Backup- und Restore-Funktionen mittels TAR und RSYNC bereit.
* **`modules/mod_btrfs_backup.sh`**: BTRFS-spezifische Backup-Funktionen (Snapshots, Transfer, Integritätsprüfung, Marker, Bereinigung, Status, uvm.).
* **`modules/mod_btrfs_restore.sh`**: BTRFS-spezifische Restore-Funktionen (komplettes System, einzelne Subvolumes, Ordner und Dry-Run).
* **`modules/mod_system_info.sh`**: Zeigt detaillierte Systeminformationen an.
* **`modules/mod_disk.sh`**: Werkzeuge zur Festplattenanalyse und -wartung.
* **`modules/mod_logs.sh`**: Analyse von System- und Anwendungsprotokollen.
* **`modules/mod_packages.sh`**: Paketverwaltung, Systemaktualisierung, Bereinigung.
* **`modules/mod_security.sh`**: Sicherheitsüberprüfungen, Docker-Security, Netzwerk, Rootkit-Check.

</details>

## Protokollierung

<details>
<summary>📜 Protokollierung (Logging)</summary>

Alle Aktionen werden in Log-Dateien protokolliert, um die Nachverfolgung und Fehlerbehebung zu erleichtern.

* **Speicherort:** Die Log-Dateien werden im Unterverzeichnis `logs` innerhalb des Projektverzeichnisses erstellt. Für jeden Monat wird ein eigener Unterordner angelegt (z.B. `logs/2025-06`).
* **Dateinamen:** Allgemeine Logdateien erhalten einen Zeitstempel, wann das Skript gestartet wurde. Backup- und Restore-spezifische Protokolle werden ebenfalls mit einem Zeitstempel versehen, um jede Sitzung separat zu erfassen.

</details>
