<!--
File: docs/advanced_log_analyzer.md
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
-->

## Script: `scripts/advanced_log_analyzer.py` - Advanced Log File Analysis

**1. Purpose:**
This Python script provides advanced analysis capabilities for various log file formats, including syslog, journald (text export), and Apache access logs. It can identify common patterns, extract key information, generate statistics, and highlight errors. It is designed to be called by other modules, such as `mod_logs.sh`, to process log data.

**2. Invocation & Dependencies:**

*   **Invocation:**
    The script is executed from the command line, typically via a `python3` interpreter. It's intended to be called by shell scripts within the Little Linux Helper project.
    Example: `python3 advanced_log_analyzer.py <log_file_path> [options]`

*   **Command-Line Arguments:**
    The script uses `argparse` to handle command-line arguments:
    *   `log_file`: (Positional) Path to the log file to be analyzed.
    *   `--format {syslog,journald,apache,auto}`: Specifies the log file format. Defaults to `auto`.
    *   `--top <int>`: Number of top entries (e.g., errors, IPs) to display. Defaults to `10`.
    *   `--summary`: If present, only a general summary of the log file is displayed.
    *   `--errors`: If present, only detected error entries are displayed.

*   **Python Module Dependencies:**
    *   `sys`: For system-specific parameters and functions (e.g., `sys.exit`, `sys.stderr`).
    *   `re`: For regular expression operations, crucial for parsing log lines.
    *   `os`: For OS-dependent functionalities like file path checking (`os.path.isfile`).
    *   `argparse`: For parsing command-line arguments.
    *   `collections.Counter`: For efficiently counting occurrences of items (e.g., IP addresses, error messages).

**3. Core Functionality / Workflow:**

1.  **Argument Parsing:** The script starts by parsing the command-line arguments provided using `parse_arguments()`.
2.  **File Validation:** It checks if the specified `log_file` exists and is a file.
3.  **Log Format Detection/Selection:**
    *   If `format` is `auto`, `detect_log_format()` is called to attempt to identify the log type based on patterns in the first few lines.
    *   If detection fails or a specific format is provided, that format is used. A fallback to 'syslog' occurs if auto-detection is inconclusive.
4.  **Log Parsing:** Based on the determined `log_format_to_use`:
    *   `parse_syslog()`: For 'syslog' or 'journald' (as journald currently delegates to syslog).
    *   `parse_apache()`: For 'apache' logs.
    *   These functions read the log file line by line, apply regular expressions to extract structured data, and identify error entries. They return a list of all parsed entries and a separate list of error entries.
5.  **Log Analysis:** The `analyze_log()` function takes the parsed entries, error entries, and command-line options to generate and print the analysis report to standard output.
    *   If no entries are parsed, a message is printed, and the script may exit.
6.  **Output Display:** The analysis results are printed to the console.

**4. Key Functions:**

*   **`parse_arguments()`**
    *   **Purpose:** Defines and parses command-line arguments using the `argparse` module.
    *   **Returns:** An `argparse.Namespace` object containing the parsed arguments.

*   **`detect_log_format(log_file)`**
    *   **Purpose:** Attempts to automatically determine the log file format by reading the first 10 lines and matching them against predefined regular expression patterns for Apache and Syslog/Journald.
    *   **Mechanism:** Counts matches for each pattern. Prefers Apache if it has more matches than Syslog and at least one match. Otherwise, prefers Syslog if it has matches.
    *   **Returns:** A string ('apache', 'syslog') representing the detected format, or `None` if the file is not found. Defaults to 'syslog' as a fallback if no clear pattern emerges.

*   **`parse_syslog(log_file)`**
    *   **Purpose:** Parses log files assumed to be in a Syslog-like or standard journald text export format.
    *   **Mechanism:**
        *   Reads the file line by line (UTF-8 encoding, ignores errors).
        *   Uses a primary regular expression to capture `timestamp`, `hostname`, `program` (stripping PID), and `message`.
        *   Includes a secondary regex for kernel messages that might not fit the primary pattern, assigning 'localhost' as hostname and 'kernel' as program.
        *   Identifies error entries by searching for keywords (e.g., "error", "fail", "crit", "warn") case-insensitively within the `message` field.
    *   **Returns:** A tuple `(entries, error_entries)`, where `entries` is a list of dictionaries (each representing a log line) and `error_entries` is a sub-list containing only error-related entries.

*   **`parse_journald(log_file)`**
    *   **Purpose:** Intended to parse journald log files exported to text.
    *   **Current Behavior:** This function currently prints a notice to `stderr` indicating that journald logs are treated like syslog files and then directly calls `parse_syslog(log_file)`.
    *   **Returns:** Same as `parse_syslog()`.

*   **`parse_apache(log_file)`**
    *   **Purpose:** Parses Apache access log files (Common or Combined Log Format).
    *   **Mechanism:**
        *   Reads the file line by line (UTF-8 encoding, ignores errors).
        *   Uses a regular expression to capture `ip`, `timestamp`, `request`, `status` (HTTP status code), `size`, `referer` (optional), and `user_agent` (optional).
        *   Converts `size` from '-' to `0` (integer).
        *   Identifies error entries if the HTTP `status` code starts with '4' (client errors) or '5' (server errors).
    *   **Returns:** A tuple `(entries, error_entries)`, similar to `parse_syslog()`.

*   **`analyze_log(entries, error_entries, top_count, summary_only, errors_only, log_format)`**
    *   **Purpose:** Performs the core analysis of the parsed log data and prints the results.
    *   **Workflow:**
        1.  If `errors_only` is true:
            *   Prints the top `top_count` error entries (formatted based on `log_format`).
            *   Exits.
        2.  Prints general statistics: total entries, total errors, error percentage.
        3.  If `summary_only` is true:
            *   Exits.
        4.  **Detailed Analysis (if not summary_only or errors_only):**
            *   **Hourly Distribution:** Counts entries per hour of the day based on timestamps.
            *   **Top Programs/Services (Syslog/Journald):** If applicable, shows the `top_count` most frequent program names.
            *   **Top Error Messages/Status Codes:**
                *   For Apache: Shows `top_count` most common error status codes.
                *   For Syslog/Journald: Shows `top_count` most frequent error messages (exact message content).
            *   **Apache-Specific Analysis:**
                *   Top `top_count` IP Addresses.
                *   Distribution of all HTTP Status Codes.
    *   **Output:** Prints formatted analysis results to standard output.

*   **`main()`**
    *   **Purpose:** The main driver function for the script.
    *   **Workflow:**
        1.  Calls `parse_arguments()`.
        2.  Checks if the log file exists.
        3.  Determines the log format to use (auto-detection or specified).
        4.  Calls the appropriate parsing function (`parse_syslog`, `parse_journald`, `parse_apache`).
        5.  If entries are found, calls `analyze_log()` to process and display results.
        6.  Handles cases where no usable entries are found.

**5. Output Format:**

The script prints its analysis to standard output. The output is structured with headers for different sections.
*   **Error Output (`--errors`):** Lists individual error log lines, formatted differently for Apache (timestamp, IP, status, request) vs. Syslog/Journald (timestamp, host, program, message).
*   **Summary Output (`--summary`):** Shows total entries, error count, and error percentage.
*   **Full Analysis (default):**
    *   General Statistics (as in summary).
    *   Hourly Distribution: "Stunde HH: X Einträge".
    *   Top Programs (Syslog/Journald): "Program: X Einträge".
    *   Top Error Messages/Status Codes:
        *   Apache Status: "Status XXX: Y Mal".
        *   Syslog Messages: "Yx: Error message snippet...".
    *   Top IPs (Apache): "IP_Address: X Anfragen".
    *   Status Code Distribution (Apache): "Status XXX: Y Anfragen".

**6. Special Considerations:**

*   **Encoding:** The script attempts to read log files using `UTF-8` encoding. If decoding errors occur, problematic characters are ignored (`errors='ignore'`). This might lead to loss of information for non-UTF-8 encoded logs or logs with mixed encodings.
*   **Log Format Detection:** The `detect_log_format()` function relies on patterns in the first 10 lines. This may not be accurate for all log files, especially if the initial lines are atypical or if the log format is not one of the explicitly supported/detected ones.
*   **Journald Parsing:** Currently, `parse_journald()` is an alias for `parse_syslog()`. This assumes that journald logs exported to text are in a syslog-compatible format. For structured journald exports (e.g., JSON), this parser would be inadequate.
*   **Error Detection:**
    *   For Syslog/Journald, error detection is keyword-based (e.g., "error", "fail", "warn"). This might miss some errors or incorrectly flag entries if keywords are used in a non-error context. The list of keywords is `error|fail|crit|alert|emerg|warn(ing)?`.
    *   For Apache, error detection is based on HTTP status codes (4xx and 5xx).
*   **Performance:** The script processes files line by line, which is generally memory-efficient. However, extensive use of regular expressions on very large files can be CPU-intensive.
*   **Regex Complexity:** The regular expressions used for parsing are central to the script's functionality. Changes to log formats might require updating these expressions, which can be complex.
*   **No External Command Dependencies:** The script relies only on standard Python libraries, making it portable as long as a Python 3 interpreter is available.
*   **Language:** Output messages and comments in the script are in German.
*   **Fallback Behavior:** If automatic log format detection is uncertain, it defaults to 'syslog'. If parsing fails to yield entries, it reports that no usable entries were found.