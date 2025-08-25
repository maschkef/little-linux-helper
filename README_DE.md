# Little Linux Helper

## Beschreibung

<img src="gui/web/public/header-logo.svg" alt="Little Linux Helper" width="350" height="350" align="right" style="margin-left: 20px; margin-top: 10px;">

Little Linux Helper ist eine umfassende Sammlung von Bash-Skripten, die entwickelt wurden, um verschiedene Systemadministrations-, Diagnose- und Wartungsaufgaben unter Linux zu vereinfachen. Es bietet sowohl ein traditionelles kommandozeilen-basiertes menügeführtes Interface als auch eine moderne webbasierte GUI für einfachen Zugriff auf eine Vielzahl von Werkzeugen und Funktionen.

Eine detailliertere technische englische Dokumentation der einzelnen Module und Kernkomponenten befindet sich im `docs`-Verzeichnis, 
diese wurde mitunter erstellt um einer KI den kontext eines modules bzw einer Datei zu geben ohne dieses selbst komplett lesen zu müssen und kontext zusparen.
Die `docs/CLI_DEVELOPER_GUIDE.md` enthält alle Informationen zu `lib/lib_common.sh` und `help_master.sh` die benötigt werden um ein neues Modul zu erstellen. 
Hinweis: Die ursprüngliche `lib_common.sh` wurde zur besseren Organisation in mehrere spezialisierte Bibliotheken aufgeteilt (z.B. `lib_colors.sh`, `lib_i18n.sh`, `lib_notifications.sh`, etc.), aber `lib_common.sh` bleibt der Haupteinstiegspunkt und lädt alle anderen Kern-Bibliotheken automatisch. Zusätzlich ist `lib_btrfs.sh` eine spezialisierte Bibliothek, die ausschließlich von BTRFS-Modulen verwendet wird und nicht Teil des Kern-Bibliothekssystems ist.

Meine Umgebung ist i.d.R. Arch (hauptsystem) oder Debian (diverse Dienste auf meinem Proxmox - daher auch die docker-Anteile), entsprechend kann es unter anderen Distributionen noch unbekannte Probleme geben, auch wenn ich versuche, alles kompatibel zu halten.

<br clear="right">

> **🎯 Projekt-Status:**
> - **Dokumentation**: Umfassende technische Dokumentation ist im `docs/` Verzeichnis für alle Module und Kernkomponenten verfügbar
> - **GUI-Interface**: Vollständige Internationalisierung (Englisch/Deutsch) mit fehlerresistentem Übersetzungssystem und umfassenden Hilfeinhalten
> - **BTRFS-Module**: Erweiterte BTRFS-Backup- und -Restore-Module mit atomaren Operationen, inkrementellen Backup-Ketten und umfassenden Sicherheitsfeatures
> - **Modulare Architektur**: Klare Trennung der Backup-Typen in spezialisierte Module (BTRFS, TAR, RSYNC) mit einheitlicher Dispatcher-Schnittstelle
> - **Test-Status**: Backup-Funktionen sind gut getestet und stabil; Restore-Funktionen sind implementiert, benötigen aber umfassende Tests vor Produktionseinsatz
> - **Update**: das btrfs backup module muss (erneut) getestet werden

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

* **Systemkompatibilität:**
    * Hauptsächliche Testumgebung: Arch Linux (Hauptsystem) und Debian (Proxmox-Services)
    * Andere Distributionen können unbekannte Kompatibilitätsprobleme haben, obwohl die Skripte für breite Kompatibilität entwickelt wurden
    * Einige Features erfordern spezifische Paketmanager oder Systemtools

* **Erweiterte Log-Analyse (`scripts/advanced_log_analyzer.py`):**
    * Bekannte Einschränkungen bezüglich Log-Format-Erkennung und Zeichenkodierung
    * Komplexe reguläre Ausdrücke können nicht alle Log-Varianten handhaben
    * Siehe `docs/tools/doc_advanced_log_analyzer.md` für detaillierte Einschränkungen und Nutzungshinweise

* **Modul-spezifische Einschränkungen:**
    * **BTRFS-Operationen**: Erfordert BTRFS-Dateisystem und entsprechende Berechtigungen
    * **Docker-Security**: Scan-Tiefe und -Genauigkeit hängen von der Komplexität der Compose-Dateien ab
    * **Hardware-Monitoring**: Temperatursensoren erfordern `lm-sensors` und entsprechende Hardware-Unterstützung

</details>

## Funktionen

Das Projekt bietet zwei Schnittstellen für den Zugriff auf seine Funktionalität:

### 🖥️ **Kommandozeilen-Interface (CLI)**
Das Hauptskript `help_master.sh` dient als zentraler CLI-Einstiegspunkt und bietet Zugriff auf alle Module über ein traditionelles menügeführtes Interface.

### 🌐 **Graphische Benutzeroberfläche (GUI)**
Eine moderne webbasierte GUI ist über `gui_launcher.sh` verfügbar und bietet:
- **Webbasierte Oberfläche**: Moderne React-Frontend mit responsivem Design, zugänglich über Webbrowser
- **Multi-Session-Unterstützung**: Unbegrenzte gleichzeitige Modul-Sitzungen mit Session-Dropdown-Verwaltung
- **Echtzeit-Terminal**: Integrierte Terminal-Anzeige mit ANSI-Farbunterstützung und interaktiver Eingabebehandlung
- **Erweiterte Sitzungsverwaltung**: Sitzungsumschaltung, Status-Anzeigen, Ausgabe-Erhaltung und individuelle Sitzungskontrolle
- **Modul-Navigation**: Kategorisierte Seitenleiste mit individuellen "Start"-Schaltflächen und intuitiver Modul-Auswahl (ausblendbar)
- **Erweiterte Dokumentations-System**: Dual-Modus-Dokumentation mit modulgebundenen Docs und unabhängigem Dokumenten-Browser
- **Dokumenten-Browser**: Kategorisierte Navigation durch alle Dokumentation mit zusammenklappbaren Gruppen und Suche
- **Panel-Kontroll-System**: Ein-/Ausblenden von Modul-Seitenleiste, Terminal-Panels, Hilfe und Docs für optimales Leseerlebnis
- **Vollbild-Lesemodus**: Alle Panels außer Dokumentation ausblenden für maximalen Leseplatz
- **Multi-Panel-Layout**: Größenveränderbare Panels mit flexiblen Ein-/Ausblenden-Kontrollen für optimale Arbeitsbereich-Organisation
- **Sicherheits-Features**: Standardmäßig nur Localhost-Bindung mit optionalem Netzwerkzugriff über Kommandozeile
- **Konfigurierbare Netzwerkeinstellungen**: Port- und Host-Konfiguration über `config/general.conf` oder Kommandozeilen-Argumente
- **Erweiterte Funktionen**: PTY-Integration für authentische Terminal-Erfahrung, WebSocket-Kommunikation für Echtzeit-Updates
- **Fehlerresistente Gestaltung**: Fehlende Übersetzungsschlüssel zeigen Fallback-Inhalt anstatt die Anwendung zum Absturz zu bringen
- **Umfassendes Hilfesystem**: Kontextsensitive Hilfe mit detaillierter Modulführung und Nutzungshinweisen

Die GUI behält vollständige Kompatibilität mit allen CLI-Funktionen bei und bietet gleichzeitig eine verbesserte Benutzererfahrung mit leistungsstarken Multi-Session-Funktionen und **vollständiger Internationalisierungsunterstützung (Deutsch/Englisch)** mit dynamischem Sprachwechsel.

<details>
<summary>GUI-Konfiguration & Verwendung:</summary>

```bash
# GUI-Launcher (Empfohlen):
./gui_launcher.sh              # Standard: sicherer localhost
./gui_launcher.sh -n           # Netzwerkzugriff aktivieren (-n Kurzform)
./gui_launcher.sh -n -f        # Netzwerkzugriff mit Firewall-Port-Öffnung
./gui_launcher.sh -p 8080      # Benutzerdefinierten Port (Kurzform)
./gui_launcher.sh --port 8080  # Benutzerdefinierten Port (Langform)
./gui_launcher.sh -n -p 80 -f  # Netzwerkzugriff auf benutzerdefiniertem Port mit Firewall
./gui_launcher.sh -b -n        # Erstellen und mit Netzwerkzugriff ausführen
./gui_launcher.sh -h           # Umfassende Hilfe

# Benutzerdefinierte Konfiguration via config/general.conf:
CFG_LH_GUI_PORT="3000"        # Standard-Port setzen
CFG_LH_GUI_HOST="localhost"   # Bindung setzen (localhost/0.0.0.0)
CFG_LH_GUI_FIREWALL_RESTRICTION="local"  # IP-Beschränkungen für Firewall-Öffnung

# Direkte Binary-Ausführung:
./little-linux-helper-gui -p 8080             # Benutzerdefinierten Port (Kurzform)
./little-linux-helper-gui --port 8080         # Benutzerdefinierten Port (Langform)
./little-linux-helper-gui -n                  # Netzwerkzugriff aktivieren (-n Kurzform)
./little-linux-helper-gui --network -p 80     # Netzwerkzugriff auf Port 80
./little-linux-helper-gui -h                  # Nutzungsinformationen anzeigen (Kurzform)
./little-linux-helper-gui --help              # Nutzungsinformationen anzeigen (Langform)
```

Die GUI behält vollständige Kompatibilität mit allen CLI-Funktionen bei und bietet gleichzeitig eine verbesserte Benutzererfahrung mit leistungsstarken Multi-Session-Funktionen.

</details>

---

Beide Schnittstellen bieten Zugriff auf folgende Module:

<details>
<summary>🔄 Wiederherstellung & Neustarts (<code>mod_restarts.sh</code>)</summary>

* Neustart des Login-Managers (Display Manager).
* Neustart des Sound-Systems (PipeWire, PulseAudio, ALSA).
* Neustart der Desktop-Umgebung (KDE, GNOME, XFCE, Cinnamon, MATE, LXDE, LXQt).
* Neustart von Netzwerkdiensten (NetworkManager, systemd-networkd, dhcpcd, systemd-resolved).

</details>

<details>
<summary>💾 Backup & Wiederherstellung</summary>

* **Einheitlicher Backup-Dispatcher** (`modules/backup/mod_backup.sh`):
    * Zentrale Dispatcher-Schnittstelle für alle Backup-Typen
    * Gemeinsame Konfigurationsverwaltung und Status-Berichterstattung für alle Backup-Methoden
    * Umfassende Status-Übersicht für BTRFS-, TAR- und RSYNC-Backups

* **BTRFS Snapshot Backup & Restore** (`modules/backup/mod_btrfs_backup.sh`, `modules/backup/mod_btrfs_restore.sh`):
    * **Erweiterte Features**: Atomare Backup-Operationen, received_uuid-Schutz, inkrementelle Kettenvalidierung
    * **Erweiterte BTRFS-Bibliothek** (`lib/lib_btrfs.sh`): Spezialisierte Bibliothek, die kritische BTRFS-Limitationen mit echten atomaren Mustern löst
    * **Dynamische Subvolume-Unterstützung**: Erkennt automatisch BTRFS-Subvolumes aus der Systemkonfiguration (`/etc/fstab`, `/proc/mounts`) und unterstützt manuelle Konfiguration für `@`, `@home`, `@var`, `@opt` und andere @-prefixierte Subvolumes mit optionaler Quellbewahrung
    * **Inkrementelle Backups**: Intelligente Parent-Erkennung, automatisches Fallback und umfassende Ketten-Integritätsvalidierung
    * **Restore-Funktionen**: Vollständige Systemwiederherstellung, individuelle Subvolume-Wiederherstellung, Ordner-Level-Wiederherstellung und Bootloader-Integration *(Hinweis: Restore-Funktionen sind implementiert, benötigen aber umfassende Tests)*
    * **Sicherheitsfeatures**: Live-Umgebungs-Erkennung, Dateisystem-Gesundheitsprüfung, Rollback-Funktionen und Dry-Run-Unterstützung
    * **Detaillierte Dokumentation**: Siehe `docs/mod/doc_btrfs_backup.md`, `docs/mod/doc_btrfs_restore.md` und `docs/lib/doc_btrfs.md`

* **TAR Archiv Backup & Restore** (`modules/backup/mod_backup_tar.sh`, `modules/backup/mod_restore_tar.sh`):
    * **Flexible Backup-Optionen**: Nur Home, Systemkonfiguration, vollständiges System oder benutzerdefinierte Verzeichnisauswahl
    * **Intelligente Ausschlüsse**: Eingebaute System-Ausschlüsse, benutzer-konfigurierbare Muster und interaktive Ausschluss-Verwaltung
    * **Archiv-Verwaltung**: Komprimierte `.tar.gz` Archive mit automatischer Bereinigung und Aufbewahrungsrichtlinien
    * **Sichere Wiederherstellung**: Mehrere Zieloptionen mit Sicherheitswarnungen und Bestätigungsabfragen
    * **Dokumentation**: Siehe `docs/mod/doc_backup_tar.md` und `docs/mod/doc_restore_tar.md`

* **RSYNC Inkrementelle Backup & Restore** (`modules/backup/mod_backup_rsync.sh`, `modules/backup/mod_restore_rsync.sh`):
    * **Inkrementelle Intelligenz**: Speicher-effiziente Backups mit Hardlink-Optimierung über `--link-dest`
    * **Backup-Typen**: Vollbackups und inkrementelle Backups mit automatischer Parent-Erkennung
    * **Erweiterte Optionen**: Umfassende RSYNC-Konfiguration mit atomaren Operationen und Fortschrittsüberwachung
    * **Flexible Wiederherstellung**: Echtzeit-Fortschrittsüberwachung und vollständige Verzeichnisbaum-Wiederherstellung
    * **Dokumentation**: Siehe `docs/mod/doc_backup_rsync.md` und `docs/mod/doc_restore_rsync.md`

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
            * Verwendung von `:latest`-Image-Tags oder Images ohne spezifische Versionierung. (In der `config/docker.conf.example` im standard deaktiviert.)
            * Konfiguration von Containern mit `privileged: true`.
            * Einbindung kritischer Host-Pfade als Volumes (z.B. `/`, `/etc`, `/var/run/docker.sock`). (Wird derzeit nicht in der zusammenfassung mit ausgegeben.)
            * Auf `0.0.0.0` exponierte Ports, die Dienste für alle Netzwerkschnittstellen verfügbar machen.
            * Verwendung potenziell gefährlicher Linux-Capabilities (z.B. `SYS_ADMIN`, `NET_ADMIN`).
            * Deaktivierte Sicherheitsoptionen wie `apparmor:unconfined` oder `seccomp:unconfined`.
            * Vorkommen von bekannten Standardpasswörtern in Umgebungsvariablen.
            * Direkte Einbettung sensitiver Daten (z.B. API-Keys, Tokens) anstelle von Umgebungsvariablen. (funktioniert aktuell nicht wirklich)
        * Optional kann eine Liste der aktuell laufenden Docker-Container angezeigt werden. (In der `config/docker.conf.example` im standard deaktiviert.)
        * Stellt eine Zusammenfassung der gefundenen potenziellen Probleme mit Empfehlungen bereit.

</details>

<details>
<summary>🐳 Docker-Verwaltung</summary>

* **Docker Container Management (`mod_docker.sh`)**:
    * Container-Status-Überwachung und -Verwaltung.
    * Docker-Systeminformationen und Ressourcennutzung.
    * Container-Log-Zugriff und -Analyse.
    * Netzwerk- und Volume-Verwaltung.
* **Docker Setup & Installation (`mod_docker_setup.sh`)**:
    * Automatisierte Docker-Installation über Distributionen hinweg.
    * Docker Compose Setup und Konfiguration.
    * Benutzer-Berechtigungskonfiguration für Docker-Zugriff.
    * System-Service-Konfiguration und Startup.

</details>

<details>
<summary>🔋 Energieverwaltung & Systemsteuerung</summary>

* **Energieverwaltung (`mod_energy.sh`)**:
    * Energieprofilverwaltung (Performance, Balanced, Power-Saver).
    * Standby/Suspend-Kontrolle mit zeitgesteuerter Inhibit-Funktionalität.
    * Bildschirmhelligkeitssteuerung.
    * Schnellaktionen zur Wiederherstellung der Standby-Funktionalität.

</details>

<details>
<summary>✨ Spezialfunktionen</summary>

* Sammeln wichtiger Debug-Informationen in einer Datei.

</details>

## Internationalisierung

<details>
<summary>🌍 Mehrsprachige Unterstützung</summary>

Little Linux Helper unterstützt mehrere Sprachen für die Benutzeroberfläche. Das Internationalisierungssystem ermöglicht eine konsistente und benutzerfreundliche Erfahrung in verschiedenen Sprachen.

**Unterstützte Sprachen:**
* **Deutsch (de)**: Vollständige Übersetzungsunterstützung für alle Module
* **Englisch (en)**: Vollständige Übersetzungsunterstützung für alle Module (Standardsprache und Fallback)
* **Spanisch (es)**: Nur vereinzelte interne Übersetzungen (Log-Einträge, etc.), praktisch unbrauchbar
* **Französisch (fr)**: Nur vereinzelte interne Übersetzungen (Log-Einträge, etc.), praktisch unbrauchbar

**Sprachauswahl:**
* **Automatische Erkennung**: Das System erkennt automatisch die Systemsprache basierend auf Umgebungsvariablen (`LANG`, `LC_ALL`, `LC_MESSAGES`)
* **Manuelle Konfiguration**: Die Sprache kann in der Datei `config/general.conf` mit der Einstellung `CFG_LH_LANG` festgelegt werden
* **Fallback-Mechanismus**: Bei fehlenden Übersetzungen oder nicht unterstützten Sprachen wird automatisch auf Englisch zurückgegriffen

**Konfiguration der Sprache:**
```bash
# In config/general.conf
CFG_LH_LANG="auto"    # Automatische Systemsprache-Erkennung
CFG_LH_LANG="de"      # Deutsch
CFG_LH_LANG="en"      # Englisch
CFG_LH_LANG="es"      # Spanisch (praktisch unbrauchbar, nur interne Meldungen)
CFG_LH_LANG="fr"      # Französisch (praktisch unbrauchbar, nur interne Meldungen)
```

**Technische Details:**
* Alle Benutzertexte werden über das `lh_msg()` System abgerufen
* Übersetzungsdateien befinden sich im `lang/` Verzeichnis, organisiert nach Sprachcodes
* Das System lädt zuerst Englisch als Fallback-Basis und überschreibt dann mit der gewünschten Sprache
* Fehlende Übersetzungsschlüssel werden automatisch protokolliert und als `[SCHLÜSSEL]` angezeigt

</details>

## Anforderungen

<details>
<summary>📋 Anforderungen</summary>

### Kern-Anforderungen:
* Bash-Shell
* Standard Linux-Dienstprogramme (wie `grep`, `awk`, `sed`, `find`, `df`, `lsblk`, `ip`, `ps`, `free`, `tar`, `rsync`, `btrfs-progs` etc.)
* Einige Funktionen erfordern möglicherweise Root-Rechte und werden ggf. `sudo` verwenden.

### GUI-Anforderungen (optional):
* **Vorkompilierte Releases**: Keine zusätzlichen Anforderungen - sofort einsatzbereit!
* **Aus Quellcode erstellen**: 
  * **Go** (1.18 oder neuer) für Backend-Server-Kompilierung
  * **Node.js** (18 oder neuer) und **npm** für Frontend-Entwicklung und -Erstellung
  * **Webbrowser** für den Zugriff auf die GUI-Oberfläche
  * Zusätzliche System-Abhängigkeiten: `github.com/gofiber/fiber/v2`, `github.com/gofiber/websocket/v2`, `github.com/creack/pty` (automatisch installiert)

### Optionale Abhängigkeiten:
Für spezifische Funktionen werden zusätzliche Pakete benötigt, die das Skript bei Bedarf zu installieren versucht:
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

### 📦 **Vorkompilierte Releases (Empfohlen)**

**Ab v0.4.0 sind vorkompilierte GUI-Releases verfügbar**, die die Notwendigkeit von Node.js/npm auf Benutzersystemen eliminieren:

#### Schnell-Installation:
```bash
# Laden und Ausführen des automatischen Installers
curl -L https://raw.githubusercontent.com/maschkef/little-linux-helper/main/install-prebuilt.sh | sudo bash
```

#### Manueller Download:
1. Gehe zu [GitHub Releases](https://github.com/maschkef/little-linux-helper/releases)
2. Lade das Paket für deine Architektur herunter:
   - **AMD64** - Die meisten modernen 64-Bit-Systeme (Intel/AMD-Prozessoren)
   - **ARM64** - Raspberry Pi 4, moderne ARM-Server
   - **ARMv7** - Raspberry Pi 2/3, ältere ARM-Geräte
3. Extrahiere und führe aus:
   ```bash
   tar -xzf little-linux-helper-gui-<arch>.tar.gz
   cd little-linux-helper-gui-<arch>
   ./start-gui.sh
   ```

**Systemanforderungen (Vorkompiliert):**
- Jede Linux-Distribution
- Kein Node.js, npm oder Go erforderlich!
- Sofort einsatzbereit

#### Warum vorkompilierte Releases?

**Der Wechsel zu automatisierten vorkompilierten Releases wurde durchgeführt, um Kompatibilitätsprobleme zu lösen:**
- **Problem**: Frühere Versionen erforderten, dass Nutzer die GUI auf ihren Systemen mit `npm install` und `npm run build` erstellen
- **Problem**: Moderne Build-Tools (wie Vite 7.x) erfordern neuere Node.js-Versionen als in stabilen Linux-Distributionen verfügbar
- **Lösung**: GitHub Actions erstellen jetzt die GUI mit den neuesten Tools und stellen gebrauchsfertige Pakete bereit
- **Vorteil**: Maximale Linux-Distributions-Kompatibilität ohne Kompromisse bei modernen Entwicklungstools

---

### 🛠️ **Aus Quellcode erstellen (Fortgeschrittene Nutzer)**

#### CLI-Installation:
1. Klone das Repository oder lade die Skripte herunter.
2. Stelle sicher, dass das Hauptskript `help_master.sh` ausführbar ist:
    ```bash
    chmod +x help_master.sh
    ```
3. Führe die CLI-Oberfläche aus:
    ```bash
    ./help_master.sh
    ```

#### GUI Selbst-Erstellen (Entwicklung/Erweitert):
**Hinweis**: Die GUI-Komponenten werden automatisch in vorkompilierten Releases erstellt. Das Selbst-Erstellen ist nur für Entwicklung oder Anpassungen erforderlich.

**Anforderungen:**
* **Go** (1.18 oder neuer) für Backend-Server-Kompilierung
* **Node.js** (18 oder neuer) und **npm** für Frontend-Entwicklung und -Erstellung
* **Webbrowser** für den Zugriff auf die GUI-Oberfläche

**Build-Prozess:**
1. Stelle sicher, dass Go (1.18+) und Node.js (18+) auf deinem System installiert sind.
2. Mache den GUI-Launcher ausführbar:
    ```bash
    chmod +x gui_launcher.sh
    ```
3. Starte die GUI-Oberfläche:
    ```bash
    ./gui_launcher.sh
    ```
4. Die GUI wird automatisch:
   - Abhängigkeiten beim ersten Start einrichten
   - Die Anwendung bei Bedarf erstellen
   - Den Webserver auf `http://localhost:3000` starten
   - Deinen Standard-Webbrowser zur Oberfläche öffnen

**GUI-Entwicklungsmodus:**
Für Entwicklung mit Hot-Reload-Funktionen:
```bash
cd gui/
./setup.sh    # Einmalige Einrichtung
./dev.sh      # Entwicklungsserver starten
```

#### Welche Version solltest du wählen?

| Anwendungsfall | Empfohlene Version | Warum |
|----------------|-------------------|-------|
| **Allgemeine Nutzung** | Vorkompiliertes Release (neueste) | Sofort einsatzbereit, keine Abhängigkeiten, maximale Kompatibilität |
| **Stabile Produktion** | Warte auf v1.0.0 | Aktuell sind alle Releases Pre-releases/Beta |
| **Entwicklung** | Aus Quellcode erstellen | Zugriff auf neueste Änderungen, Entwicklungstools |
| **Anpassung** | Aus Quellcode erstellen | GUI modifizieren, benutzerdefinierte Builds |
| **Ältere Systeme** | Vorkompiliertes Release | Kein modernes Node.js/Go auf Zielsystem erforderlich |

**Wichtig**: Die **CLI-Funktionalität ist völlig unabhängig** und funktioniert auf jedem System mit Bash. Die GUI ist eine optionale Erweiterung, die auf dem CLI-System aufbaut.

</details>

## Konfiguration

<details>
<summary>⚙️ Konfigurationsdateien</summary>

Little Linux Helper verwendet Konfigurationsdateien, um bestimmte Aspekte seines Verhaltens anzupassen. Diese Dateien befinden sich im Verzeichnis `config/`.

Beim ersten Start des Hauptskripts (`help_master.sh`) werden automatisch Standard-Konfigurationsdateien erstellt, falls diese noch nicht vorhanden sind. Dies geschieht, indem Vorlagedateien mit der Endung `.example` (z.B. `backup.conf.example`) in ihre aktiven Gegenstücke ohne das Suffix (z.B. `backup.conf`) kopiert werden.

**Wichtig:** Du wirst beim ersten Erstellen einer Konfigurationsdatei darauf hingewiesen. Es wird empfohlen, diese neu erstellten `.conf`-Dateien zu überprüfen und gegebenenfalls an deine spezifischen Bedürfnisse anzupassen.

Aktuell werden Konfigurationsdateien für folgende Module verwendet:
*   **Allgemeine Einstellungen (`help_master.sh`)**: Sprache, Logging-Verhalten und andere grundlegende Einstellungen (`config/general.conf`).
*   **Backup & Wiederherstellung (`modules/backup/mod_backup.sh`, `modules/backup/mod_btrfs_backup.sh`, `modules/backup/mod_btrfs_restore.sh`)**: Einstellungen für Backup-Pfade, Aufbewahrungsrichtlinien etc. (`config/backup.conf`).
*   **Docker Security Überprüfung (`mod_security.sh`)**: Einstellungen für Suchpfade, zu überspringende Warnungen etc. (`config/docker.conf`).

</details>

## Module Übersicht

<details>
<summary>📦 Module Übersicht</summary>

Das Projekt ist in Module unterteilt, um die Funktionalität zu organisieren:

* **`lib/lib_common.sh`**: Das Herzstück des Projekts. Enthält zentrale, von allen Modulen genutzte Funktionen wie:
    *  Ein einheitliches Logging-System.
    * Funktionen zur Befehlsüberprüfung und automatischen Installation von Abhängigkeiten.
    * Standardisierte Benutzerinteraktionen (Ja/Nein-Fragen, Eingabeaufforderungen).
    * Die Erkennung von Systemkomponenten (Paketmanager, etc.).
    * Verwaltung von farbiger Terminalausgabe für eine bessere Lesbarkeit.
    * Komplexe Logik zur Ermittlung des aktiven Desktop-Benutzers.
    * Die Fähigkeit, **Desktop-Benachrichtigungen** an den Benutzer zu senden.
    * **Kern-Bibliothekssystem**: Lädt automatisch spezialisierte Bibliothekskomponenten (`lib_colors.sh`, `lib_i18n.sh`, `lib_ui.sh`, etc.).
* **`lib/lib_btrfs.sh`**: **Spezialisierte BTRFS-Bibliothek** (nicht Teil des Kern-Bibliothekssystems). Stellt erweiterte BTRFS-spezifische Funktionen für atomare Backup-Operationen, inkrementelle Kettenvalidierung und umfassende BTRFS-Sicherheitsmechanismen bereit. Wird ausschließlich von BTRFS-Modulen verwendet und muss explizit eingebunden werden.
* **`modules/mod_restarts.sh`**: Bietet Optionen zum Neustarten von Diensten und der Desktop-Umgebung.
* **`modules/backup/mod_backup.sh`**: Einheitlicher Backup-Dispatcher mit zentraler Schnittstelle für alle Backup-Typen (BTRFS, TAR, RSYNC).
* **`modules/backup/mod_btrfs_backup.sh`**: BTRFS-spezifische Backup-Funktionen (Snapshots, Transfer, Integritätsprüfung, Marker, Bereinigung, Status, uvm.). Verwendet `lib_btrfs.sh` für erweiterte BTRFS-Operationen.
* **`modules/backup/mod_btrfs_restore.sh`**: BTRFS-spezifische Restore-Funktionen (komplettes System, einzelne Subvolumes, Ordner und Dry-Run). Verwendet `lib_btrfs.sh` für atomare Restore-Operationen.
* **`modules/backup/mod_backup_tar.sh`**: TAR-Archiv-Backup-Funktionalität mit mehreren Backup-Typen und intelligentem Ausschluss-Management.
* **`modules/backup/mod_restore_tar.sh`**: TAR-Archiv-Wiederherstellung mit Sicherheitsfeatures und flexiblen Zieloptionen.
* **`modules/backup/mod_backup_rsync.sh`**: RSYNC inkrementelle Backups mit Hardlink-Optimierung und umfassender Konfiguration.
* **`modules/backup/mod_restore_rsync.sh`**: RSYNC Backup-Wiederherstellung mit Echtzeit-Fortschrittsüberwachung und vollständiger Verzeichnisbaum-Wiederherstellung.
* **`modules/mod_system_info.sh`**: Zeigt detaillierte Systeminformationen an.
* **`modules/mod_disk.sh`**: Werkzeuge zur Festplattenanalyse und -wartung.
* **`modules/mod_logs.sh`**: Analyse von System- und Anwendungsprotokollen.
* **`modules/mod_packages.sh`**: Paketverwaltung, Systemaktualisierung, Bereinigung.
* **`modules/mod_security.sh`**: Sicherheitsüberprüfungen, Docker-Security, Netzwerk, Rootkit-Check.
* **`modules/mod_docker.sh`**: Docker-Container-Management und -Überwachung.
* **`modules/mod_docker_setup.sh`**: Docker-Installation und Setup-Automatisierung.
* **`modules/mod_energy.sh`**: Energieverwaltung und Stromverwaltungsfunktionen (Energieprofile, Standby-Kontrolle, Helligkeit).

</details>

## Protokollierung

<details>
<summary>📜 Protokollierung (Logging)</summary>

Alle Aktionen werden in Log-Dateien protokolliert, um die Nachverfolgung und Fehlerbehebung zu erleichtern.

* **Speicherort:** Die Log-Dateien werden im Unterverzeichnis `logs` innerhalb des Projektverzeichnisses erstellt. Für jeden Monat wird ein eigener Unterordner angelegt (z.B. `logs/2025-06`).
* **Dateinamen:** Allgemeine Logdateien erhalten einen Zeitstempel, wann das Skript gestartet wurde. Backup- und Restore-spezifische Protokolle werden ebenfalls mit einem Zeitstempel versehen, um jede Sitzung separat zu erfassen.

</details>

## Kontakt

Bei Fragen, Anregungen oder Problemen mit diesem Projekt können Sie mich gerne kontaktieren:

📧 **E-Mail:** [maschkef-git@pm.me](mailto:maschkef-git@pm.me)
