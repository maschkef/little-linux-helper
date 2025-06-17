## Project Description: Little Linux Helper

This document describes the core components of the "Little Linux Helper" project, based on the files `help_master.sh` and `lib_common.sh`. It aims to enable developers and ai to understand the structure, global variables, and available functions to extend or modify the project without needing to study the source code of the described files in detail.
The primary goal of this project is to be as compatible as possible across a wide range of Linux distributions. Compatibility with other operating systems like macOS or native Windows is not a target; however, functionality within Windows Subsystem for Linux (WSL) environments is desirable where reasonably achievable.
 
### 1. The Main File: `help_master.sh`

`help_master.sh` is the main entry script for the Little Linux Helper. It is responsible for initializing the environment, loading common functions, and presenting the main menu through which the various helper modules are accessed.

**Purpose:**
- Starting point of the program.
- Setting basic shell options (`set -e`, `set -o pipefail`).
- Determining and exporting the project root directory (`LH_ROOT_DIR`).
- Loading common library functions from `lib_common.sh`.
- Executing basic library initialization functions (logging, root check, package manager detection).
- Displaying the main menu.
- Controlling navigation to different module scripts based on user input.
- Providing a function to collect debug information.

**Initialization Flow:**
1.  `set -e`: Exits the script immediately if a command fails with a non-zero exit code.
2.  `set -o pipefail`: Ensures that the exit code of a pipe is that of the last command to return non-zero.
3.  `export LH_ROOT_DIR`: Determines the directory where `help_master.sh` is located and sets it as `LH_ROOT_DIR`, making it globally available.
4.  `source "$LH_ROOT_DIR/lib/lib_common.sh"`: Loads all functions and variables from the common library into the current shell environment.
5.  `lh_initialize_logging`: Initializes the logging system (see description in `lib_common.sh`).
6.  `lh_check_root_privileges`: Checks for root privileges and sets `LH_SUDO_CMD` (see description in `lib_common.sh`).
7.  `lh_detect_package_manager`: Detects the primary package manager and sets `LH_PKG_MANAGER` (see description in `lib_common.sh`).
8.  `lh_detect_alternative_managers`: Detects alternative package managers and sets `LH_ALT_PKG_MANAGERS` (see description in `lib_common.sh`).
9.  `lh_finalize_initialization`: Executes final library initialization steps, particularly loading the backup configuration and exporting important variables (see description in `lib_common.sh`).

**Main Menu and Navigation:**
After initialization, the script enters an infinite loop that displays the main menu.
- It uses the library functions `lh_print_header` and `lh_print_menu_item` for formatting the output.
- User input is captured with `read`.
- A `case` statement branches to different actions based on the input:
    - Calling external module scripts (`mod_restarts.sh`, `mod_system_info.sh`, etc.) using `bash <path_to_module_script>`. The modules run in a sub-shell but have access to exported variables.
    - Calling the internal function `create_debug_bundle`.
    - Exiting the script when '0' is entered.
- After executing an option, a pause is introduced (`read -p ...`) to give the user time to read the output.

**Internal Functions:**
*   `create_debug_bundle()`
    *   **Purpose:** Collects important system and log information into a single file for debugging.
    *   **Dependencies (Library):** `lh_print_header`, `lh_log_msg`, `lh_confirm_action`.
    *   **Dependencies (System Commands):** `date`, `hostname`, `whoami`, `cat`, `uname`, `lscpu`, `grep`, `free`, `df`, `journalctl`, `tail`, `ps`, `ip`, `ss`, `netstat`, `less`.
    *   **Side Effects:**
        - Creates a file in the `$LH_LOG_DIR` directory with a name based on date and hostname (format: `debug_report_HOSTNAME_YYYYMMDD-HHMM.txt`).
        - Writes various system information (OS, kernel, CPU, memory, disk), package manager info, log excerpts (system, Xorg), running processes, network info, and desktop environment info into this file.
        - Outputs status messages to the console and the main log (`$LH_LOG_FILE`).
        - Optionally offers the user to view the created file with `less` (`lh_confirm_action`).
    *   **Usage:** Called directly from the main menu.

### 2. The Library File: `lib/lib_common.sh`

`lib_common.sh` contains a collection of global variables and reusable functions that can be used by `help_master.sh` and all module scripts. It serves as a central hub for common logic and configuration.

**Purpose:**
- Define and initialize global variables that store the state and configuration of the helper.
- Provide utility functions for logging, system checks, user interaction, package manager handling, and more.
- Encapsulate complex logic such as determining the target user for GUI interactions.

**Global Variables:**
The following variables are defined in `lib_common.sh`. Those marked as "Exported" are made available to module scripts because `help_master.sh` calls `lh_finalize_initialization` (which exports them) before running the modules as sub-processes. Modules inherit these exported variables. Other global variables (not explicitly exported) become available within modules when they `source lib_common.sh`.

- `LH_ROOT_DIR`: Absolute path to the project's main directory. Dynamically determined if not already set.
- `LH_LOG_DIR_BASE`: Absolute path to the base log directory (e.g., `$LH_ROOT_DIR/logs`).
- `LH_LOG_DIR`: Absolute path to the current monthly log directory (e.g., `$LH_ROOT_DIR/logs/2025-06`).
- `LH_CONFIG_DIR`: Absolute path to the configuration directory (`$LH_ROOT_DIR/config`).
- `LH_BACKUP_CONFIG_FILE`: Absolute path to the backup configuration file (`$LH_CONFIG_DIR/backup.conf`).
- `LH_LOG_FILE`: Absolute path to the current main log file. Set by `lh_initialize_logging`.
- `LH_SUDO_CMD`: Contains the string 'sudo' if the script is not run as root, otherwise empty. Set by `lh_check_root_privileges`.
- `LH_PKG_MANAGER`: The detected primary package manager (e.g., 'pacman', 'apt', 'dnf'). Set by `lh_detect_package_manager`.
 `LH_ALT_PKG_MANAGERS`: An array of detected alternative package managers (e.g., 'flatpak', 'snap'). Set by `lh_detect_alternative_managers`. (Modules should call `lh_detect_alternative_managers()` after sourcing `lib_common.sh` to ensure this array is correctly populated in their context, see Section 3.)
- `LH_TARGET_USER_INFO`: An associative array storing information about the target user for GUI interactions. Populated by `lh_get_target_user_info`. Contains keys like `TARGET_USER`, `USER_DISPLAY`, `USER_XDG_RUNTIME_DIR`, `USER_DBUS_SESSION_BUS_ADDRESS`, `USER_XAUTHORITY`.
- `LH_BACKUP_ROOT_DEFAULT`: Default value for the root directory of backups.
- `LH_BACKUP_DIR_DEFAULT`: Default value for the backup subdirectory (relative to `LH_BACKUP_ROOT`).
- `LH_TEMP_SNAPSHOT_DIR_DEFAULT`: Default value for the temporary snapshot directory (absolute).
- `LH_TIMESHIFT_BASE_DIR_DEFAULT`: Default value for the Timeshift base directory (absolute).
- `LH_RETENTION_BACKUP_DEFAULT`: Default value for the number of backups to retain.
- `LH_BACKUP_LOG_BASENAME_DEFAULT`: Default basename for the backup log file (e.g., "backup.log").
- `LH_BACKUP_ROOT`: Currently configured value for the root directory of backups. Set by `lh_load_backup_config`.
- `LH_BACKUP_DIR`: Currently configured value for the backup subdirectory. Set by `lh_load_backup_config`.
- `LH_TEMP_SNAPSHOT_DIR`: Currently configured value for the temporary snapshot directory. Set by `lh_load_backup_config`.
- `LH_TIMESHIFT_BASE_DIR`: Currently configured value for the Timeshift base directory. Set by `lh_load_backup_config`.
- `LH_RETENTION_BACKUP`: Currently configured value for the number of backups to retain. Set by `lh_load_backup_config`.
- `LH_BACKUP_LOG_BASENAME`: Currently configured basename for the backup log file. Set by `lh_load_backup_config`.
- `LH_BACKUP_LOG`: Absolute path to the timestamped backup log file for the current run. Set by `lh_load_backup_config`. (e.g., `<LH_LOG_DIR>/250609-1630_backup.log`)
- `package_names_pacman`, `package_names_apt`, `package_names_dnf`: Associative arrays mapping program names to package names for specific package managers. Used by `lh_map_program_to_package`.

**Color Variables and Usage:**
`lib_common.sh` defines a set of ANSI escape code variables for colored terminal output. These are exported by `lh_finalize_initialization` and can be used in modules.

- **Basic Colors:** `LH_COLOR_RED`, `LH_COLOR_GREEN`, `LH_COLOR_YELLOW`, `LH_COLOR_BLUE`, `LH_COLOR_MAGENTA`, `LH_COLOR_CYAN`, `LH_COLOR_WHITE`, `LH_COLOR_BLACK`.
- **Bold Colors:** `LH_COLOR_BOLD_RED`, `LH_COLOR_BOLD_GREEN`, etc.
- **Reset Code:** `LH_COLOR_RESET` (crucial to end coloring).
- **Semantic Aliases:** For consistent UI, use aliases like:
    - `LH_COLOR_HEADER` (for titles)
    - `LH_COLOR_MENU_NUMBER` (for menu item numbers)
    - `LH_COLOR_MENU_TEXT` (for menu item descriptions)
    - `LH_COLOR_PROMPT` (for user input prompts)
    - `LH_COLOR_SUCCESS` (for success messages)
    - `LH_COLOR_ERROR` (for error messages)
    - `LH_COLOR_WARNING` (for warning messages)
    - `LH_COLOR_INFO` (for informational messages)
    - `LH_COLOR_SEPARATOR` (for visual separators like "----")
- **Usage:** Use with `echo -e` or `printf`. Always end a colored string with `${LH_COLOR_RESET}` to prevent color bleeding. Example: `echo -e "${LH_COLOR_ERROR}This is an error.${LH_COLOR_RESET}"`
- **Library Integration:** Many library functions like `lh_print_header`, `lh_print_menu_item`, `lh_log_msg`, `lh_confirm_action`, and `lh_ask_for_input` already incorporate these colors for their output. When using these functions, manual color application is often not needed for their standard output.

**Functions:**
*   `lh_initialize_logging()`
    *   **Purpose:** Sets up the logging system.
    *   **Dependencies:** `date`, `mkdir`, `touch`, `lh_log_msg`.
    *   **Side Effects:**
        - Creates the monthly log directory (`$LH_LOG_DIR`) if it doesn't exist (e.g., `.../logs/YYYY-MM`).
        - Sets the global variable `LH_LOG_FILE` to a path in the format `$LH_LOG_DIR/YYMMDD-HHMM_maintenance_script.log`.
        - Creates the `$LH_LOG_FILE` file if it doesn't exist.
        - Writes an info message to the log.
    *   **Usage:** Should be called once at the beginning of the main script.

*   `lh_load_backup_config()`
    *   **Purpose:** Loads the backup configuration from the `$LH_BACKUP_CONFIG_FILE` file or uses default values.
    *   **Dependencies:** `source`, `basename`, `lh_log_msg`.
    *   **Side Effects:**
        - Sets the global variables `LH_BACKUP_ROOT`, `LH_BACKUP_DIR`, `LH_TEMP_SNAPSHOT_DIR`, `LH_TIMESHIFT_BASE_DIR`, `LH_RETENTION_BACKUP`, and `LH_BACKUP_LOG_BASENAME`.
        - If the configuration file exists, the `CFG_LH_*` variables defined there are read and override the default values.
        - Sets the global variable `LH_BACKUP_LOG` to a timestamped path within the current monthly log directory (`$LH_LOG_DIR`).
        - Writes info messages to the log.
    *   **Usage:** Should be called once during initialization.

*   `lh_save_backup_config()`
    *   **Purpose:** Saves the current values of the backup configuration variables to the `$LH_BACKUP_CONFIG_FILE` file.
    *   **Dependencies:** `mkdir`, `echo`, `basename`, `lh_log_msg`.
    *   **Side Effects:**
        - Creates the `$LH_CONFIG_DIR` directory if it doesn't exist.
        - Writes the current values of `LH_BACKUP_ROOT`, `LH_BACKUP_DIR`, `LH_TEMP_SNAPSHOT_DIR`, `LH_TIMESHIFT_BASE_DIR`, `LH_RETENTION_BACKUP`, and `LH_BACKUP_LOG_BASENAME` to the configuration file.
        - Overwrites the file if it exists.
        - Writes an info message to the log.
    *   **Usage:** Can be called by modules that modify the backup configuration.

*   `lh_log_msg(level, message)`
    *   **Purpose:** Writes a formatted log message.
    *   **Parameters:**
        - `$1` (`level`): The log level (e.g., "INFO", "WARN", "ERROR", "DEBUG").
        - `$2` (`message`): The actual log message.
    *   **Dependencies:** `date`, `echo`.
    *   **Side Effects:**
        - Formats the message with a timestamp and level.
        - Outputs the formatted message to standard output (console).
        - Appends the formatted message to the `$LH_LOG_FILE` file if this variable is set and the file exists.
    *   **Usage:** Should be used for all output that needs to appear on the console and be logged.

*   `lh_check_root_privileges()`
    *   **Purpose:** Checks if the script is run as root.
    *   **Dependencies:** `EUID`, `lh_log_msg`.
    *   **Side Effects:**
        - Sets the global variable `LH_SUDO_CMD` to 'sudo' if the current user is not root (`EUID != 0`), otherwise to an empty string.
        - Writes an info message to the log.
    *   **Usage:** Should be called once during initialization. `LH_SUDO_CMD` can then be used before commands requiring root privileges (e.g., `$LH_SUDO_CMD apt update`).

*   `lh_backup_log(level, message)`
    *   **Purpose:** Writes a formatted log message specifically to the current, timestamped backup log file (`$LH_BACKUP_LOG`).
    *   **Parameters:**
        - `$1` (`level`): The log level.
        - `$2` (`message`): The log message.
    *   **Dependencies:** `date`, `touch`, `echo`, `tee`.
    *   **Side Effects:**
        - Creates the `$LH_BACKUP_LOG` file if it doesn't exist.
        - Formats the message with a timestamp and level.
        - Outputs the formatted message to standard output (console).
        - Appends the formatted message to the `$LH_BACKUP_LOG` file.
    *   **Usage:** Should be used for all log messages specifically related to backup operations.

*   `lh_get_filesystem_type(path)`
    *   **Purpose:** Determines the filesystem type of a given path.
    *   **Parameters:**
        - `$1` (`path`): The path (file or directory) whose filesystem type is to be determined.
    *   **Dependencies:** `df`, `tail`, `awk`.
    *   **Output:** Prints the filesystem type as a string to standard output (e.g., "ext4", "btrfs", "xfs").
    *   **Usage:** Useful for performing filesystem-specific operations.

*   `lh_cleanup_old_backups(backup_dir, retention_count, pattern)`
    *   **Purpose:** Removes old directories or files based on a pattern in a given directory, retaining a specified number of the newest ones.
    *   **Parameters:**
        - `$1` (`backup_dir`): The directory to clean up.
        - `$2` (`retention_count`): The number of newest items to retain (default: 10).
        - `$3` (`pattern`): A shell pattern (glob) identifying the items to be cleaned (e.g., `snapshot_*`).
    *   **Dependencies:** `ls`, `sort`, `tail`, `read`, `rm`, `lh_log_msg`.
    *   **Side Effects:**
        - Deletes directories/files matching the pattern that are older than the `retention_count` newest ones.
        - Writes info messages to the log about removed items.
    *   **Usage:** Useful for implementing backup retention policies.

*   `lh_detect_package_manager()`
    *   **Purpose:** Detects the system's primary package manager.
    *   **Dependencies:** `command -v`, `lh_log_msg`.
    *   **Side Effects:**
        - Sets the global variable `LH_PKG_MANAGER` to 'yay', 'pacman', 'apt', or 'dnf', depending on which command is found first. If none are found, the variable remains empty.
        - Writes an info message to the log.
    *   **Usage:** Should be called once during initialization. `LH_PKG_MANAGER` is used by other functions (e.g., `lh_check_command`, `lh_map_program_to_package`).

*   `lh_detect_alternative_managers()`
    *   **Purpose:** Detects alternative package managers like Flatpak, Snap, Nix, or AppImage.
    *   **Dependencies:** `command -v`, `find`, `grep`, `lh_log_msg`.
    *   **Side Effects:**
        - Populates the global array `LH_ALT_PKG_MANAGERS` with the names of the found managers.
        - Writes an info message to the log.
    *   **Usage:** Should be called once during initialization. `LH_ALT_PKG_MANAGERS` can be used to provide the user with information about installed alternative systems.

*   `lh_map_program_to_package(program_name)`
    *   **Purpose:** Maps a program name to the corresponding package name for the detected package manager.
    *   **Parameters:**
        - `$1` (`program_name`): The name of the program (e.g., "smartctl").
    *   **Dependencies:** `lh_detect_package_manager` (if `LH_PKG_MANAGER` is not yet set), the global associative arrays `package_names_*`.
    *   **Output:** Prints the package name to standard output. If no mapping is found, the original program name is returned.
    *   **Usage:** Primarily used by `lh_check_command` to find the correct package name for installation.

*   `lh_check_command(command_name, install_prompt_if_missing, is_python_script)`
    *   **Purpose:** Checks if a command or Python script exists. Optionally offers to install the associated package if the command is missing.
    *   **Parameters:**
        - `$1` (`command_name`): The name of the command to check or the path to the Python script.
        - `$2` (`install_prompt_if_missing`): Optional, 'true' or 'false'. If 'true' (default), the user is asked if the package should be installed if the command is missing.
        - `$3` (`is_python_script`): Optional, 'true' or 'false'. If 'true', checks if Python3 is installed and if the file `$command_name` exists.
    *   **Dependencies:** `command -v`, `read`, `tr`, `case`, `$LH_SUDO_CMD`, `$LH_PKG_MANAGER`, `lh_map_program_to_package`, `lh_log_msg`.
    *   **Return Value:** Returns 0 if the command/script was found or successfully installed. Returns 1 if the command/script is missing and could not be installed or installation was declined.
    *   **Side Effects:**
        - Outputs warnings/errors to the console and log.
        - May prompt the user for installation (`read`).
        - May execute package manager commands with `sudo` to install packages.
    *   **Usage:** Should be called before executing external commands to ensure necessary programs are available.

*   `lh_confirm_action(prompt_message, default_choice)`
    *   **Purpose:** Asks the user a yes/no question and waits for confirmation.
    *   **Parameters:**
        - `$1` (`prompt_message`): The question to ask the user.
        - `$2` (`default_choice`): Optional, 'y' or 'n'. The default choice if the user just presses Enter (default: 'n').
    *   **Dependencies:** `read`, `echo`, `tr`.
    *   **Return Value:** Returns 0 if the user answers yes (y, yes, j, ja). Returns 1 if the user answers no or the default choice is no and Enter was pressed.
    *   **Usage:** For interactive decisions requiring confirmation.

*   `lh_ask_for_input(prompt_message, validation_regex, error_message)`
    *   **Purpose:** Prompts the user for input and optionally validates it against a regular expression.
    *   **Parameters:**
        - `$1` (`prompt_message`): The message to display as a prompt.
        - `$2` (`validation_regex`): Optional, a regular expression to validate the input. If empty, any input is accepted.
        - `$3` (`error_message`): Optional, the error message to display for invalid input (default: "Invalid input. Please try again.").
    *   **Dependencies:** `read`, `echo`.
    *   **Output:** Prints the user-entered (and validated) string to standard output.
    *   **Usage:** For safely querying user input that must conform to a specific format.

*   `lh_get_target_user_info()`
    *   **Purpose:** Determines information about the user of the active graphical session (desktop user) to execute commands in their context.
    *   **Dependencies:** `loginctl`, `sudo`, `ps`, `grep`, `awk`, `head`, `cut`, `id`, `env`, `who`, `sed`, `basename`, `tr`, `cat`, `lh_log_msg`.
    *   **Side Effects:**
        - Populates the global associative array `LH_TARGET_USER_INFO` with the keys `TARGET_USER`, `USER_DISPLAY`, `USER_XDG_RUNTIME_DIR`, `USER_DBUS_SESSION_BUS_ADDRESS`, `USER_XAUTHORITY`.
        - Uses various methods (loginctl, SUDO_USER, USER, ps, who) to find the user.
        - Tries to determine the necessary environment variables (DISPLAY, XDG_RUNTIME_DIR, DBUS_SESSION_BUS_ADDRESS, XAUTHORITY) from the target user's environment or uses default fallback paths.
        - Writes info/warning messages to the log.
    *   **Return Value:** Returns 0 if a target user could be determined, 1 otherwise.
    *   **Usage:** Must be called before `lh_run_command_as_target_user`. The determined information is cached.

*   `lh_run_command_as_target_user(command_to_run)`
    *   **Purpose:** Executes a given shell command in the context of the determined target user, including necessary environment variables for GUI interactions.
    *   **Parameters:**
        - `$1` (`command_to_run`): The shell command as a string to be executed.
    *   **Dependencies:** `lh_get_target_user_info`, `sudo`, `sh -c`.
    *   **Return Value:** Returns the exit code of the executed command.
    *   **Side Effects:** Executes the command as the user stored in `LH_TARGET_USER_INFO[TARGET_USER]`, with the environment variables stored there. Writes debug messages to the log.
    *   **Usage:** For executing commands that need to run in the context of the desktop user (e.g., GUI notifications, commands accessing their home directory).

*   `lh_send_notification(type, title, message, urgency)`
    *   **Purpose:** Sends a desktop notification to the determined graphical session user.
    *   **Parameters:**
        - `$1` (`type`): Notification type ("success", "error", "warning", "info"). Used for icons and default urgency.
        - `$2` (`title`): The title of the notification.
        - `$3` (`message`): The body text of the notification.
        - `$4` (`urgency`): Optional. Urgency level ("low", "normal", "critical"). If omitted, it's inferred from the type.
    *   **Dependencies:** `lh_get_target_user_info`, `lh_run_command_as_target_user`. System commands like `notify-send`, `zenity`, `kdialog`.
    *   **Return Value:** Returns 0 on success, 1 on failure (e.g., no target user or no notification tool found).
    *   **Side Effects:** Tries to send a notification using available tools (`notify-send`, `zenity`, `kdialog`) in the context of the target user. Logs the success or failure.
    *   **Usage:** To provide non-interactive feedback to the desktop user about the result of a long-running or background task.

*   `lh_check_notification_tools()`
    *   **Purpose:** Checks for available desktop notification tools, reports their status, and offers to install them.
    *   **Dependencies:** `lh_get_target_user_info`, `lh_run_command_as_target_user`, `lh_confirm_action`, package manager commands.
    *   **Return Value:** Returns 0 if at least one tool is available, 1 otherwise.
    *   **Side Effects:** Prints the status of available tools to the console. May prompt the user to install missing tools (`libnotify-bin`/`libnotify`, `zenity`). May offer to send a test notification.
    *   **Usage:** Can be used in a settings or diagnostics module to ensure the notification system is working.

*   `lh_print_header(title)`
    *   **Purpose:** Prints a formatted header with a title.
    *   **Parameters:**
        - `$1` (`title`): The text for the header.
    *   **Dependencies:** `echo`.
    *   **Side Effects:** Prints the formatted header to standard output.
    *   **Usage:** For structuring console output, e.g., for menus or sections.

*   `lh_print_menu_item(number, text)`
    *   **Purpose:** Prints a formatted menu item.
    *   **Parameters:**
        - `$1` (`number`): The number of the menu item.
        - `$2` (`text`): The text of the menu item.
    *   **Dependencies:** `printf`.
    *   **Side Effects:** Prints the formatted menu item to standard output.
    *   **Usage:** For creating menus.

*   `lh_finalize_initialization()`
    *   **Purpose:** Executes final initialization steps and exports important variables and functions.
    *   **Dependencies:** `lh_load_backup_config`, `export`.
    *   **Side Effects:**
        - Calls `lh_load_backup_config`.
        - Exports several key global variables such as `LH_LOG_DIR`, `LH_LOG_FILE`, `LH_SUDO_CMD`, all `LH_BACKUP_*` variables, and color variables, making them available in the environment of sub-shells (the module scripts).
        - **Exports the functions** `lh_send_notification` and `lh_check_notification_tools` using `export -f`, making them directly callable by module scripts.
    *   **Usage:** Should be called once at the end of the initialization sequence in the main script.

### 3. Interaction and Extension

The project is modular. `help_master.sh` is the coordinator that loads the common library `lib_common.sh` and passes control to separate module scripts (like `mod_restarts.sh`, `mod_disk.sh`, etc.).

New modules can be created by adding a new script in the `modules/` directory. This script should also call `source "$LH_ROOT_DIR/lib/lib_common.sh"` to gain access to all global variables and functions.

To integrate a new module into the main menu, `help_master.sh` needs to be edited:
1.  Add a new `lh_print_menu_item` call in the main menu.
2.  Add a new `case` branch in the `case` statement that links the chosen number to the path of the new module script (e.g., `bash "$LH_ROOT_DIR/modules/my_new_module.sh"`).

Modules should utilize the functions from `lib_common.sh`, especially for logging (`lh_log_msg`, `lh_backup_log`), user interaction (`lh_confirm_action`, `lh_ask_for_input`), system checks (`lh_check_command`), package manager interactions (`$LH_SUDO_CMD`, `$LH_PKG_MANAGER`), executing commands in the user context (`lh_run_command_as_target_user`), and sending desktop notifications (`lh_send_notification`).

Global variables set and exported by `help_master.sh` (e.g., `LH_ROOT_DIR`, `LH_LOG_FILE` via `lh_finalize_initialization`) are available in the environment of module scripts.

However, for variables like `LH_PKG_MANAGER` and the array `LH_ALT_PKG_MANAGERS`, which are determined by detection functions (`lh_detect_package_manager`, `lh_detect_alternative_managers`), there's a subtlety. If a module sources `lib_common.sh` (which is standard practice to access library functions), this can affect how these specific variables are seen. Sourcing might re-declare them (potentially as empty) as defined in `lib_common.sh`'s global scope, shadowing any inherited values.

Therefore, to ensure these variables are correctly populated within a module's execution context:
- Modules needing `LH_PKG_MANAGER` (e.g., for package installation prompts via `lh_check_command` or direct package manager interactions) should explicitly call `lh_detect_package_manager()` immediately after sourcing `lib_common.sh`.
- Modules needing `LH_ALT_PKG_MANAGERS` (e.g., for interacting with Flatpak, Snap, etc.) should explicitly call `lh_detect_alternative_managers()` immediately after sourcing `lib_common.sh`.
This makes the module self-sufficient in setting up these specific configurations as needed, avoiding potential issues with variable shadowing or complex array exports.
Variables defined only within a function in `lib_common.sh` (without `export`) are only visible within that function.

### 4. External Dependencies (System Commands)

The project uses a number of standard Linux commands. Some of the most important ones are:
- `sudo`: For operations requiring root privileges.
- `date`: For timestamps in logs and filenames.
- `mkdir`, `touch`, `rm`: For filesystem operations (creating/deleting directories/files).
- `echo`, `printf`: For output to the console and files.
- `tee`: For simultaneous output to console and file (used in `lh_backup_log`).
- `df`, `ls`, `sort`, `tail`, `head`, `find`: For filesystem and file operations, listing, sorting, filtering.
- `awk`, `cut`, `grep`, `tr`, `sed`, `basename`: For text processing and parsing command outputs.
- `command -v`: For checking if a command exists.
- `ps`: For listing running processes.
- `ip`, `ss`, `netstat`: For network information.
- `journalctl`: For reading the systemd journal.
- `less`: For viewing text files.
- `read`: For reading user input.
- `uname`, `lscpu`, `free`, `cat` (e.g. for `/etc/os-release`, `/proc/*`): For general system information.
- `id`: For retrieving user IDs.
- `env`: For displaying environment variables.
- `basename`, `dirname`, `pwd`, `cd`: For path manipulations.
- `sh -c`: For executing commands via a shell (especially in `lh_run_command_as_target_user`).
- Package manager commands (`pacman`, `yay`, `apt`, `dnf`) and alternative managers (`flatpak`, `snap`, `nix-env`, `appimagetool`): For package management and detection.
- `loginctl`: For querying session information (requires root privileges).
- **Notification tools:** `notify-send` (from `libnotify` or similar), `zenity`, `kdialog` for desktop notifications.
It is important to ensure these commands are available on the target system, or to use the `lh_check_command` or `lh_check_notification_tools` functions to check dependencies and offer installation if necessary.

This document should provide a solid foundation for understanding the functionality of `help_master.sh` and `lib_common.sh` and for starting to develop further modules or adapt existing functions.

### 5. Licensing

The "Little Linux Helper" project is licensed under the MIT License.

**Copyright (c) 2025 wuldorf**
**SPDX-License-Identifier: MIT**

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the `LICENSE` file in the project root for more information.

**Guideline for New Files:**
All new source code files (shell scripts, documentation, etc.) contributed to this project should include a license header at the beginning of the file, similar to the one found in existing scripts. This header should clearly state:
- The file path relative to the project root.
- The copyright notice (e.g., `Copyright (c) <YEAR> <COPYRIGHT_HOLDER>`).
- The SPDX License Identifier (`SPDX-License-Identifier: MIT`).
- A reference to the main `LICENSE` file in the project root.
This practice ensures consistency and legal clarity across the entire project.