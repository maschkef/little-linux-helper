#!/usr/bin/env python3
# little-linux-helper/scripts/advanced_log_analyzer.py
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: MIT
#
# This script is part of the 'little-linux-helper' collection.
# Licensed under the MIT License. See the LICENSE file in the project root for more information.
#
# Skript für erweiterte Log-Analyse

import sys
import re
import os
import argparse
from collections import Counter

def parse_arguments():
    """Parst die Kommandozeilenargumente."""
    parser = argparse.ArgumentParser(description='Erweiterte Analyse von Logdateien.')
    parser.add_argument('log_file', help='Pfad zur zu analysierenden Logdatei.')
    parser.add_argument('--format', choices=['syslog', 'journald', 'apache', 'auto'], default='auto',
                        help='Format der Logdatei (Standard: auto).')
    parser.add_argument('--top', type=int, default=10,
                        help='Anzahl der Top-Einträge, die angezeigt werden sollen (Standard: 10).')
    parser.add_argument('--summary', action='store_true',
                        help='Nur eine allgemeine Zusammenfassung anzeigen.')
    parser.add_argument('--errors', action='store_true',
                        help='Nur erkannte Fehlereinträge anzeigen.')
    return parser.parse_args()

def detect_log_format(log_file):
    """
    Versucht, das Logformat automatisch anhand der ersten paar Zeilen zu erkennen.
    """
    try:
        with open(log_file, 'r', encoding='utf-8', errors='ignore') as f:
            first_lines = [f.readline() for _ in range(10)] # Lese bis zu 10 Zeilen
    except FileNotFoundError:
        return None # Datei nicht gefunden, kann Format nicht erkennen

    # Typische Muster für verschiedene Logformate
    # Apache: Beginnt oft mit einer IP-Adresse
    apache_pattern = r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}'
    # Syslog/Journald: Beginnt oft mit Monatsname (abgekürzt), Tag, Zeit
    syslog_journald_pattern = r'^[A-Z][a-z]{2}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2}'
    # Journald kann auch spezifischere Muster haben, aber für Text-Export ist Syslog-ähnlich oft der Fall
    # journald_specific_pattern = r'-- Logs begin at ... and end at ... --' # Kopfzeile von journalctl

    # Zähle Übereinstimmungen für jedes Muster
    apache_matches = 0
    syslog_matches = 0

    for line in first_lines:
        if not line.strip(): # Leere Zeilen ignorieren
            continue
        if re.match(apache_pattern, line):
            apache_matches += 1
        if re.match(syslog_journald_pattern, line):
            syslog_matches += 1

    if apache_matches > syslog_matches and apache_matches > 0:
        return 'apache'
    elif syslog_matches > 0: # Syslog/Journald sind oft ähnlich im Textformat
        # Hier könnte man feiner unterscheiden, wenn nötig.
        # Für den Moment nehmen wir an, dass journalctl-Exporte syslog-ähnlich sind.
        # Man könnte auch nach spezifischen Journald-Markern suchen.
        return 'syslog' # Oder 'journald', je nach Präferenz bei Unklarheit

    return 'syslog' # Fallback, wenn nichts klar erkannt wird

def parse_syslog(log_file):
    """Parst Syslog-ähnliche Logdateien."""
    entries = []
    error_entries = []
    # Typisches Syslog-Format: Mon Tag HH:MM:SS hostname program[pid]: message
    # Dieses Muster ist recht allgemein gehalten.
    pattern = re.compile(
        r'^(?P<timestamp>[A-Z][a-z]{2}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2})\s+'
        r'(?P<hostname>\S+)\s+'
        r'(?P<program>[^[]+(?:\[\d+\])?):\s+' # Programmname, optional mit PID
        r'(?P<message>.*)$'
    )
    # Ein alternatives Muster für Zeilen ohne explizites Programm oder Hostname (z.B. Kernel-Meldungen)
    kernel_pattern = re.compile(
        r'^(?P<timestamp>[A-Z][a-z]{2}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2})\s+'
        r'(?P<message>kernel:.*)$' # Oft beginnen Kernel-Meldungen so
    )


    with open(log_file, 'r', encoding='utf-8', errors='ignore') as f:
        for line_number, line_content in enumerate(f, 1):
            line_content = line_content.strip()
            if not line_content:
                continue

            match = pattern.match(line_content)
            if match:
                entry = match.groupdict()
                entry['program'] = entry['program'].split('[')[0] # PID entfernen
                entries.append(entry)
                if re.search(r'\b(error|fail|crit|alert|emerg|warn(ing)?)\b', entry['message'], re.IGNORECASE):
                    error_entries.append(entry)
            else:
                match_kernel = kernel_pattern.match(line_content)
                if match_kernel:
                    data = match_kernel.groupdict()
                    entry = {
                        'timestamp': data['timestamp'],
                        'hostname': 'localhost', # Annahme
                        'program': 'kernel',
                        'message': data['message'].split('kernel: ', 1)[-1]
                    }
                    entries.append(entry)
                    if re.search(r'\b(error|fail|crit|alert|emerg|warn(ing)?)\b', entry['message'], re.IGNORECASE):
                        error_entries.append(entry)
                # else:
                #     print(f"Zeile {line_number} nicht geparst (Syslog): {line_content[:100]}", file=sys.stderr)


    return entries, error_entries

def parse_journald(log_file):
    """
    Parst Journald-Logdateien, die als Text exportiert wurden.
    HINWEIS: Diese Funktion behandelt journald-Logs aktuell wie syslog-Logs.
    Sie geht davon aus, dass die Eingabe von journalctl (ohne spezielle Formatierungsoptionen)
    syslog-ähnlich ist. Für eine tiefere Analyse von strukturierten journald-Logs
    (z.B. JSON-Format) wäre eine dedizierte Parsing-Logik notwendig.
    """
    # Im Moment verwenden wir dieselbe Logik wie für Syslog,
    # da `mod_logs.sh` journalctl-Ausgaben in eine Textdatei umleitet,
    # die oft syslog-ähnlich formatiert ist.
    print("Hinweis: Journald-Logs werden wie Syslog-Dateien behandelt.", file=sys.stderr)
    return parse_syslog(log_file)

def parse_apache(log_file):
    """Parst Apache Access Log-Dateien (Common oder Combined Log Format)."""
    entries = []
    error_entries = []
    # Combined Log Format (häufiger)
    # %h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\"
    # Beispiel: 127.0.0.1 - frank [10/Oct/2000:13:55:36 -0700] "GET /apache_pb.gif HTTP/1.0" 200 2326 "http://www.example.com/start.html" "Mozilla/4.08 [en] (Win98; I ;Nav)"
    # Vereinfachtes Muster, das die wichtigsten Teile erfasst:
    pattern = re.compile(
        r'^(?P<ip>\S+)\s+'                  # IP-Adresse
        r'\S+\s+'                           # %l (identd)
        r'\S+\s+'                           # %u (user)
        r'\[(?P<timestamp>[^\]]+)\]\s+'     # Zeitstempel in eckigen Klammern
        r'"(?P<request>[^"]*)"\s+'          # Request-Zeile in Anführungszeichen
        r'(?P<status>\d{3})\s+'             # HTTP-Statuscode (3 Ziffern)
        r'(?P<size>\S+)'                    # Größe der Antwort (kann '-' sein)
        r'(?:\s+"(?P<referer>[^"]*)"\s+'    # Referer (optional)
        r'"(?P<user_agent>[^"]*)")?'        # User-Agent (optional, wenn Referer da ist)
    )

    with open(log_file, 'r', encoding='utf-8', errors='ignore') as f:
        for line_number, line_content in enumerate(f, 1):
            line_content = line_content.strip()
            if not line_content:
                continue

            match = pattern.match(line_content)
            if match:
                entry = match.groupdict()
                # Konvertiere '-' bei size zu 0 für einfachere Verarbeitung
                entry['size'] = 0 if entry['size'] == '-' else int(entry['size'])
                entries.append(entry)
                if entry['status'].startswith(('4', '5')): # Client- und Server-Fehler
                    error_entries.append(entry)
            # else:
            #     print(f"Zeile {line_number} nicht geparst (Apache): {line_content[:100]}", file=sys.stderr)
    return entries, error_entries

def analyze_log(entries, error_entries, top_count=10, summary_only=False, errors_only=False, log_format="unknown"):
    """Führt die Analyse der geparsten Logeinträge durch und gibt die Ergebnisse aus."""
    if not entries:
        print("Keine Logeinträge zum Analysieren gefunden.")
        return

    # Allgemeine Statistiken (immer anzeigen, außer bei --errors only, wenn keine Fehler da sind)
    total_entries = len(entries)
    total_errors = len(error_entries)
    error_percentage = (total_errors / total_entries) * 100 if total_entries > 0 else 0

    if errors_only:
        if error_entries:
            print(f"\n=== {min(top_count, len(error_entries))} von {len(error_entries)} Fehlereinträgen ===")
            for i, entry in enumerate(error_entries):
                if i >= top_count:
                    break
                if log_format == 'apache':
                    print(f"{entry.get('timestamp', '')} | IP: {entry.get('ip', '')} | Status: {entry.get('status', '')} | Request: {entry.get('request', '')[:80]}")
                else: # syslog, journald
                    print(f"{entry.get('timestamp', '')} | Host: {entry.get('hostname', '')} | Prog: {entry.get('program', '')} | Msg: {entry.get('message', '')[:100]}")
        else:
            print("Keine Fehlereinträge gefunden.")
        return # Bei --errors ist hier Schluss

    print(f"\n=== Allgemeine Statistiken ===")
    print(f"Gesamtzahl der Einträge: {total_entries}")
    print(f"Anzahl der Fehlereinträge: {total_errors}")
    print(f"Fehlerrate: {error_percentage:.2f}%")

    if summary_only:
        return # Bei --summary ist hier Schluss

    # --- Detaillierte Analyse (wenn nicht summary_only oder errors_only) ---

    # Zeitliche Verteilung (Stunden)
    print("\n=== Zeitliche Verteilung (Stunde) ===")
    hour_distribution = Counter()
    for entry in entries:
        ts = entry.get('timestamp', '')
        # Syslog/Journald: 'Mon Tag HH:MM:SS' oder Apache: 'DD/Mon/YYYY:HH:MM:SS zone'
        hour_match_syslog = re.search(r'(\d{2}):\d{2}:\d{2}', ts)
        hour_match_apache = re.search(r':(\d{2}):\d{2}:\d{2}', ts) # Apache Zeitformat

        if hour_match_syslog:
            hour = int(hour_match_syslog.group(1))
            hour_distribution[hour] += 1
        elif hour_match_apache:
            hour = int(hour_match_apache.group(1))
            hour_distribution[hour] += 1

    if hour_distribution:
        for hour in sorted(hour_distribution.keys()):
            print(f"Stunde {hour:02d}: {hour_distribution[hour]:>5} Einträge")
    else:
        print("Keine Zeitstempel für stündliche Verteilung gefunden.")

    # Top Programme/Services (für Syslog/Journald)
    if log_format in ['syslog', 'journald'] and any('program' in e for e in entries):
        print(f"\n=== Top {top_count} Programme/Dienste ===")
        program_counter = Counter(e['program'] for e in entries if 'program' in e)
        for program, count in program_counter.most_common(top_count):
            print(f"{program:<30}: {count:>5} Einträge")

    # Top Fehlermeldungen (wenn Fehler vorhanden)
    if error_entries:
        print(f"\n=== Top {top_count} Fehlermeldungen/Statuscodes ===")
        if log_format == 'apache':
            # Bei Apache sind die Statuscodes und die Requests interessant
            error_status_counter = Counter(e['status'] for e in error_entries)
            print(f"  --- Nach Statuscode ---")
            for status, count in error_status_counter.most_common(top_count):
                print(f"  Status {status}: {count:>5} Mal")
            # Man könnte auch die häufigsten fehlerhaften Requests anzeigen
            # error_request_counter = Counter(e['request'] for e in error_entries)
            # print(f"  --- Nach Request (Auszug) ---")
            # for req, count in error_request_counter.most_common(top_count):
            #    print(f"  {count}x: {req[:80]}")
        else: # Syslog/Journald
            # Gruppiere ähnliche Fehlermeldungen (vereinfacht)
            # Dies ist eine Herausforderung, da Fehlermeldungen sehr variabel sein können.
            # Ein einfacher Ansatz: Zähle die exakten Nachrichten.
            message_counter = Counter(e['message'] for e in error_entries if 'message' in e)
            for message, count in message_counter.most_common(top_count):
                print(f"{count:>3}x: {message[:120]}{'...' if len(message) > 120 else ''}")

    # Apache-spezifische Analyse
    if log_format == 'apache':
        print(f"\n=== Top {top_count} IP-Adressen (Apache) ===")
        ip_counter = Counter(e['ip'] for e in entries if 'ip' in e)
        for ip, count in ip_counter.most_common(top_count):
            print(f"{ip:<20}: {count:>5} Anfragen")

        print(f"\n=== HTTP-Statuscode-Verteilung (Apache) ===")
        status_counter = Counter(e['status'] for e in entries if 'status' in e)
        for status, count in sorted(status_counter.items()):
            print(f"Status {status}: {count:>5} Anfragen")

def main():
    """Hauptfunktion des Skripts."""
    args = parse_arguments()

    if not os.path.isfile(args.log_file):
        print(f"Fehler: Die Logdatei '{args.log_file}' wurde nicht gefunden oder ist keine Datei.", file=sys.stderr)
        sys.exit(1)

    print(f"Analysiere Logdatei: {args.log_file}")

    log_format_to_use = args.format
    if log_format_to_use == 'auto':
        detected_format = detect_log_format(args.log_file)
        if detected_format:
            log_format_to_use = detected_format
            print(f"Automatisch erkanntes Logformat: {log_format_to_use}")
        else:
            print("Logformat konnte nicht automatisch erkannt werden. Versuche 'syslog'.", file=sys.stderr)
            log_format_to_use = 'syslog' # Fallback

    entries = []
    error_entries = []

    if log_format_to_use == 'syslog':
        entries, error_entries = parse_syslog(args.log_file)
    elif log_format_to_use == 'journald':
        entries, error_entries = parse_journald(args.log_file)
    elif log_format_to_use == 'apache':
        entries, error_entries = parse_apache(args.log_file)
    else:
        # Sollte durch argparse choices nicht passieren, aber sicher ist sicher
        print(f"Fehler: Unbekanntes Logformat '{log_format_to_use}'.", file=sys.stderr)
        sys.exit(1)

    if not entries and not error_entries: # error_entries könnten auch ohne entries existieren, wenn nur Fehler geparst wurden
        print(f"Keine verwertbaren Einträge in '{args.log_file}' im Format '{log_format_to_use}' gefunden.")
        # sys.exit(0) # Kein Fehler, aber auch nichts zu tun
        return


    analyze_log(entries, error_entries,
                top_count=args.top,
                summary_only=args.summary,
                errors_only=args.errors,
                log_format=log_format_to_use)

if __name__ == "__main__":
    main()
