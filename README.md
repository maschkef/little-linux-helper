# Little Linux Helper

## Beschreibung

Little Linux Helper ist eine Sammlung von Bash-Skripten, die entwickelt wurden, um verschiedene Systemadministrations-, Diagnose- und Wartungsaufgaben unter Linux zu vereinfachen. Es bietet ein menügeführtes Interface für einfachen Zugriff auf eine Vielzahl von Werkzeugen und Funktionen.
Meine Umgebung ist i.d.R. Arch, ensprechend kann es unter anderen distos noch unbekannte Probleme geben, auch wenn ich versuche alles kompatibel zu halten.

<details>
<summary>⚠️ Wichtige Hinweise zur Nutzung</summary>
**Bitte beachte die folgenden Punkte sorgfältig, bevor du die Skripte aus diesem Repository verwendest:**

* **Kein professioneller Programmierer:** Ich bin eigentlich kein Programmierer. Diese Skripte sind als Hobbyprojekt und zum vereinfachen  entstanden. Sie können daher suboptimale Lösungsansätze, Fehler oder Ineffiziente herrangehensweisen enthalten.
* **Nutzung auf eigene Gefahr:** Die Verwendung der hier bereitgestellten Skripte erfolgt ausschließlich auf eigene Gefahr. Ich übernehme keinerlei Verantwortung oder Haftung für mögliche Datenverluste, Systeminstabilitäten, Schäden an Hard- oder Software oder jegliche andere direkte oder indirekte Konsequenzen, die aus der Nutzung dieser Skripte resultieren könnten. Es wird dringend empfohlen, vor der Ausführung kritischer Operationen stets Backups deiner wichtigen Daten und deines Systems anzulegen.
* **KI-generierte Inhalte:** Ein erheblicher Teil der Skripte und der begleitenden Dokumentation wurde unter Zuhilfenahme von Künstlicher Intelligenz (KI) erstellt. Obwohl ich mich bemüht habe, die Funktionalität zu testen und die Informationen zu überprüfen, können die Skripte Fehler, unvorhergesehenes Verhalten oder logische Mängel enthalten, die auf den KI-Generierungsprozess zurückzuführen sind. Sei dir dieses Umstands bewusst und überprüfe den Code kritisch, bevor du ihn einsetzt, insbesondere in produktiven oder sensiblen Umgebungen.
</details>

## Lizenz

Dieses Projekt steht unter der MIT-Lizenz. Weitere Informationen findest du in der Datei `LICENSE` im Projektstammverzeichnis.

<details>
<summary>❗ Bekannte Probleme und Einschränkungen</summary>

## Bekannte Probleme und Einschränkungen
Hier ist eine Liste von bekannten Problemen, Einschränkungen oder Verhaltensweisen, die dir bei der Nutzung der Skripte auffallen könnten.
### Backups (mod_backup.sh):
* BTRFS-Backup: Das Skript konnte nur auf den letzten Snapshot von Timeshift zugreifen, wenn Timeshift gerade lief. Das Skript ist jedoch darauf ausgelegt, bei Bedarf einen eigenen, unabhängigen Snapshot zu erstellen. Aktuell verwende ich Snapper statt Timeshift, weshalb ich das nicht weiter testen kann und selbst auch den unabhänigen Snapshot nutze. Evtl baue ich den Anteil auch noch aus.
* das Backup hat keine Fortschritsanzeige (eher ein schönheitsfehler)
* Für das Backup nutze ich i.d.R. die BTRFS bassierende Funktion, die anderen sind wesentlich weniger getestet
### Erweiterte Log-Analyse (`scripts/advanced_log_analyzer.py`)
* dieses skript ist kaum getestet
</details>

## Funktionen

Das Hauptskript `help_master.sh` dient als zentraler Einstiegspunkt und bietet Zugriff auf folgende Module:

<details>
<summary>🔄 Wiederherstellung & Neustarts (<code>mod_restarts.sh</code>)</summary>

* **Wiederherstellung & Neustarts (`mod_restarts.sh`)**:
    * Neustart des Login-Managers (Display Manager).
    * Neustart des Sound-Systems (PipeWire, PulseAudio, ALSA).
    * Neustart der Desktop-Umgebung (KDE, GNOME, XFCE, Cinnamon, MATE, LXDE, LXQt).
    * Neustart von Netzwerkdiensten (NetworkManager, systemd-networkd, dhcpcd, systemd-resolved).
</details>

<details>
<summary>💾 Backup & Wiederherstellung (<code>mod_backup.sh</code>)</summary>

* **Backup & Wiederherstellung (`mod_backup.sh`)**:
    * **BTRFS Snapshot Backup**:
        * Erstellt Snapshots von `@` und `@home` Subvolumes.
        * Nutzt vorhandene Timeshift-Snapshots oder erstellt direkte Snapshots.
        * Überträgt Snapshots zu einem konfigurierbaren Backup-Ziel.
        * Implementiert eine konfigurierbare Aufbewahrungsrichtlinie (Retention).
        * Bietet zusätzliche Funktionen:
            * **Integritätsprüfung:** Überprüft die Vollständigkeit und Konsistenz von BTRFS-Backups durch Analyse von Metadaten, Log-Dateien und Marker-Dateien. Erkennt unvollständige, beschädigte oder verdächtige Backups.
            * **Manuelles Löschen:** Ermöglicht das gezielte Löschen einzelner oder mehrerer BTRFS-Snapshots mit einer Vorschau der zu löschenden Elemente. Unterstützt verschiedene Auswahlmethoden (einzeln, nach Aufbewahrungsfrist, nach Alter, alle).
            * **Automatische Bereinigung problematischer Backups:** Sucht nach Backups mit Integritätsproblemen und bietet die Möglichkeit, diese automatisch zu entfernen.
            * **Detaillierte Statusanzeige:** Zeigt den Status vorhandener Backups an, inklusive Datum, Größe und Integritätsstatus (OK, unvollständig, verdächtig, beschädigt). Listet erkannte Probleme auf.
            * **Temporäre Snapshots:** Verwendet temporäre Snapshots während des Backup-Prozesses, die nach Abschluss (oder bei Abbruch) automatisch bereinigt werden.
            * **Backup-Marker:** Erstellt Marker-Dateien, um erfolgreiche Backup-Durchläufe zu kennzeichnen und wichtige Metadaten zu speichern (Zeitstempel, Subvolume, Größe, Host).
            * **Erweiterte Fehlermeldungen:** Gibt detailliertere Fehlermeldungen aus, z.B. wenn temporäre Snapshots nicht gelöscht werden können oder verwaiste Snapshots gefunden werden.
            * **Desktop-Benachrichtigungen:** Sendet Benachrichtigungen über den Erfolg oder Misserfolg von Backup-Vorgängen.
        * Erfordert Root-Rechte und `btrfs-progs`.
    * **TAR Archiv Backup**:
        * Erstellt komprimierte TAR-Archive (`.tar.gz`).
        * Auswahlmöglichkeiten für zu sichernde Verzeichnisse (`/home`, `/etc`, gesamtes System, benutzerdefiniert).
        * Konfigurierbare Ausschlusslisten.
        * Implementiert eine konfigurierbare Aufbewahrungsrichtlinie.
    * **RSYNC Backup**:
        * Führt Backups mit `rsync` durch.
        * Optionen für Voll- oder inkrementelle Backups.
        * Auswahlmöglichkeiten für Quellverzeichnisse.
        * Konfigurierbare Ausschlusslisten.
        * Nutzt Hardlinks für inkrementelle Backups zur Speicherplatzersparnis (`--link-dest`).
        * Implementiert eine konfigurierbare Aufbewahrungsrichtlinie.
        * Nutzt temporäre Logdateien, um TAR- und RSYNC-spezifische Meldungen vom Hauptprotokoll zu trennen und die Fehlersuche zu vereinfachen.
    * **Wiederherstellung**:
        * Menügesteuerte Wiederherstellung für BTRFS, TAR und RSYNC Backups.
        * BTRFS-Wiederherstellung für `@home` (überschreibt aktuelles `/home`, erstellt Backup).
        * TAR-Wiederherstellung an ursprünglichen Ort, temporäres Verzeichnis oder benutzerdefinierten Pfad.
        * RSYNC-Wiederherstellung an ursprünglichen Ort, temporäres Verzeichnis oder benutzerdefinierten Pfad.
        * Möglichkeit, ein separates `btrfs-recovery.sh` Skript für komplexere BTRFS-Wiederherstellungen auszuführen.
    * **Backup-Status und -Konfiguration**:
        * Anzeige des aktuellen Backup-Status (Online/Offline, freier Speicherplatz, vorhandene Backups, neuste Backups, Gesamtgröße).
        * Anzeige und Änderung der Backup-Konfiguration (Zielpfad, Verzeichnis, Retention, temporäres Snapshot-Verzeichnis, Timeshift-Basisverzeichnis). Die Konfiguration kann temporär (nur für die aktuelle Sitzung) oder dauerhaft gespeichert werden.
        * Umfasst jetzt die Möglichkeit, den Speicherort für temporäre BTRFS-Snapshots (`LH_TEMP_SNAPSHOT_DIR`) und das Basisverzeichnis für Timeshift (`LH_TIMESHIFT_BASE_DIR`) zu konfigurieren.
</details>

<details>
<summary>💻 Systemdiagnose & Analyse</summary>

* **Systemdiagnose & Analyse**:
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
* **Wartung & Sicherheit**:
    * **Paketverwaltung & Updates (`mod_packages.sh`)**:
        * Systemaktualisierung (unterstützt pacman, apt, dnf, yay).
        * Aktualisierung alternativer Paketmanager (Flatpak, Snap, Nix).
        * Suchen und Entfernen von Waisenpaketen.
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
</details>

<details>
<summary>✨ Spezialfunktionen</summary>
* **Spezialfunktionen**:
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
    * Python 3 (typischerweise als `python3`-Kommando; für erweiterte Log-Analyse)
    * `pacman-contrib` (für `paccache` auf Arch-basierten Systemen, falls nicht vorhanden)
    * `expac` (für kürzlich installierte Pakete auf Arch-basierten Systemen)

Das Skript versucht, den verwendeten Paketmanager (pacman, yay, apt, dnf) automatisch zu erkennen. Es erkennt auch alternative Paketmanager wie Flatpak, Snap und Nix.
</details>

## Installation & Setup

<details>
<summary>🚀 Installation & Setup</summary>
1.  Klone das Repository oder lade die Skripte herunter.
2.  Stelle sicher, dass das Hauptskript `help_master.sh` ausführbar ist:
    ```bash
    chmod +x help_master.sh
    ```

## Module Übersicht

Das Projekt ist in Module unterteilt, um die Funktionalität zu organisieren:

* **`lib/lib_common.sh`**: Das Herzstück des Projekts. Enthält zentrale, von allen Modulen genutzte Funktionen wie:
    * Ein einheitliches Logging-System.
    * Funktionen zur Befehlsüberprüfung und automatischen Installation von Abhängigkeiten.
    * Standardisierte Benutzerinteraktionen (Ja/Nein-Fragen, Eingabeaufforderungen).
    * Die Erkennung von Systemkomponenten (Paketmanager, etc.).
    * Verwaltung von farbiger Terminalausgabe für eine bessere Lesbarkeit.
    * Komplexe Logik zur Ermittlung des aktiven Desktop-Benutzers.
    * Die Fähigkeit, **Desktop-Benachrichtigungen** an den Benutzer zu senden.
* **`modules/mod_restarts.sh`**: Bietet Optionen zum Neustarten von Diensten und der Desktop-Umgebung.
* **`modules/mod_backup.sh`**: Stellt Backup- und Wiederherstellungsfunktionen mittels BTRFS, TAR und RSYNC bereit.
* **`modules/mod_system_info.sh`**: Zeigt detaillierte Systeminformationen an.
* **`modules/mod_disk.sh`**: Enthält Werkzeuge zur Festplattenanalyse und -wartung.
* **`modules/mod_logs.sh`**: Bietet verschiedene Funktionen zur Analyse von System- und Anwendungsprotokollen.
* **`modules/mod_packages.sh`**: Hilft bei der Paketverwaltung, Systemaktualisierungen und der Bereinigung.
* **`modules/mod_security.sh`**: Führt grundlegende Sicherheitsüberprüfungen durch.

## Protokollierung (Logging)

Alle Aktionen werden in Log-Dateien protokolliert, um die Nachverfolgung und Fehlerbehebung zu erleichtern.
* **Speicherort:** Die Log-Dateien werden im Unterverzeichnis `logs` innerhalb des Projektverzeichnisses erstellt. Um die Übersichtlichkeit zu wahren, wird für jeden Monat ein eigener Unterordner angelegt (z.B. `logs/2025-06`).
* **Dateinamen:** Allgemeine Logdateien erhalten einen Zeitstempel, wann das Skript gestartet wurde. Backup-spezifische Protokolle werden ebenfalls mit einem Zeitstempel versehen, um jede Backup-Sitzung separat zu erfassen.