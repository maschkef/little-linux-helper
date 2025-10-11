/*
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
*/

package main

import (
	"bufio"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"io/fs"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/creack/pty"
	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/logger"
	"github.com/gofiber/websocket/v2"
	"golang.org/x/sys/unix"
)

type ModuleInfo struct {
	ID             string `json:"id"`
	Name           string `json:"name"`
	Description    string `json:"description"`
	Path           string `json:"path"`
	Category       string `json:"category"`
	Parent         string `json:"parent,omitempty"`          // Parent module ID for submodules
	SubmoduleCount int    `json:"submodule_count,omitempty"` // Number of available submodules
}

type SessionManager struct {
	sessions map[string]*ModuleSession
	mutex    sync.RWMutex
}

type ModuleSession struct {
	ID          string
	Module      string
	ModuleName  string
	CreatedAt   time.Time
	Status      string
	Process     *exec.Cmd
	PTY         *os.File
	Done        chan bool
	Output      chan string
	Buffer      []string
	BufferMutex sync.RWMutex
}

type SessionInfo struct {
	ID         string    `json:"id"`
	Module     string    `json:"module"`
	ModuleName string    `json:"module_name"`
	CreatedAt  time.Time `json:"created_at"`
	Status     string    `json:"status"`
}

type Message struct {
	Type    string      `json:"type"`
	Content interface{} `json:"content"`
}

type StartModuleRequest struct {
	Language string `json:"language"`
}

type DocMetadata struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Description string `json:"description"`
	Filename    string `json:"filename"`
}

var (
	sessionManager = &SessionManager{
		sessions: make(map[string]*ModuleSession),
	}
	lhRootDir      string
	appStartTime   time.Time
	releaseVersion string
)

// Config holds GUI configuration
type Config struct {
	Port       string
	Host       string
	ReleaseTag string
}

// loadConfig reads configuration from config/general.conf
func loadConfig() *Config {
	config := &Config{
		Port:       "3000",      // default port
		Host:       "localhost", // default host (secure)
		ReleaseTag: "",
	}

	configPath := filepath.Join(lhRootDir, "config", "general.conf")
	file, err := os.Open(configPath)
	if err != nil {
		log.Printf("Warning: Could not read config file %s, using defaults: %v", configPath, err)
		return config
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())

		// Skip comments and empty lines
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}

		// Parse key=value pairs
		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			continue
		}

		key := strings.TrimSpace(parts[0])
		value := strings.Trim(strings.TrimSpace(parts[1]), "\"")

		switch key {
		case "CFG_LH_GUI_PORT":
			if value != "" {
				config.Port = value
			}
		case "CFG_LH_GUI_HOST":
			if value != "" {
				config.Host = value
			}
		case "CFG_LH_RELEASE_TAG":
			if value != "" {
				config.ReleaseTag = value
			}
		}
	}

	if err := scanner.Err(); err != nil {
		log.Printf("Warning: Error reading config file: %v", err)
	}

	return config
}

func init() {
	// Get the Little Linux Helper root directory
	executable, err := os.Executable()
	if err != nil {
		log.Fatal("Could not determine executable path:", err)
	}

	// If running from source (go run), the executable will be in a temporary cache directory
	// In this case, use the current working directory to determine the root
	if strings.Contains(executable, "go-build") || strings.Contains(executable, "/tmp/") {
		wd, err := os.Getwd()
		if err != nil {
			log.Fatal("Could not determine working directory:", err)
		}

		// If we're in the gui directory, go up one level
		if filepath.Base(wd) == "gui" {
			lhRootDir = filepath.Dir(wd)
		} else {
			// Otherwise, assume we're already in the root directory
			lhRootDir = wd
		}
	} else {
		// For production builds, check if we're in a release package or development environment
		executableDir := filepath.Dir(executable)

		// If there's a modules/ directory in the same directory as the executable,
		// we're in a release package - use the executable's directory as root
		if _, err := os.Stat(filepath.Join(executableDir, "modules")); err == nil {
			lhRootDir = executableDir
		} else {
			// Otherwise, assume GUI is in gui/ subdirectory (development build)
			lhRootDir = filepath.Dir(executableDir)
		}
	}

	// Set environment variable for the scripts
	os.Setenv("LH_ROOT_DIR", lhRootDir)

	log.Printf("Little Linux Helper root directory: %s", lhRootDir)
}

func main() {
	appStartTime = time.Now()
	// Parse command line flags
	var networkMode = flag.Bool("network", false, "Allow network access (bind to 0.0.0.0 instead of localhost)")
	var networkModeShort = flag.Bool("n", false, "Allow network access (shorthand for --network)")
	var portFlag = flag.String("port", "", "Port to run the server on (overrides config file)")
	var portFlagShort = flag.String("p", "", "Port to run the server on (shorthand for --port)")
	var helpFlag = flag.Bool("help", false, "Show help information")
	var helpFlagShort = flag.Bool("h", false, "Show help information (shorthand for --help)")
	flag.Parse()

	if *helpFlag || *helpFlagShort {
		fmt.Println("Little Linux Helper GUI")
		fmt.Println("\nUsage:")
		fmt.Println("  ./little-linux-helper-gui [options]")
		fmt.Println("\nOptions:")
		fmt.Println("  -n, --network   Allow network access (bind to 0.0.0.0, use with caution)")
		fmt.Println("  -p, --port      Port to run the server on (overrides config)")
		fmt.Println("  -h, --help      Show this help information")
		fmt.Println("\nConfiguration:")
		fmt.Println("  Default settings are read from config/general.conf")
		fmt.Println("  Default port: 3000")
		fmt.Println("  Default binding: localhost (secure)")
		fmt.Println("\nExamples:")
		fmt.Println("  ./little-linux-helper-gui                    # Default: localhost:3000")
		fmt.Println("  ./little-linux-helper-gui --port 8080        # Custom port: localhost:8080")
		fmt.Println("  ./little-linux-helper-gui -p 8080            # Custom port: localhost:8080")
		fmt.Println("  ./little-linux-helper-gui --network          # Network access: 0.0.0.0:3000")
		fmt.Println("  ./little-linux-helper-gui -n                 # Network access: 0.0.0.0:3000")
		fmt.Println("  ./little-linux-helper-gui -n -p 80           # Network access: 0.0.0.0:80")
		return
	}

	// Load configuration
	config := loadConfig()

	// Override port from command line if provided (either -p or --port)
	portValue := *portFlag
	if *portFlagShort != "" {
		portValue = *portFlagShort
	}
	if portValue != "" {
		// Validate port number
		if port, err := strconv.Atoi(portValue); err != nil || port < 1 || port > 65535 {
			log.Fatalf("Invalid port number: %s (must be between 1 and 65535)", portValue)
		}
		config.Port = portValue
	}

	// Override host binding if network flag is set (either -network or -n)
	if *networkMode || *networkModeShort {
		config.Host = "0.0.0.0"
		log.Println("WARNING: Network mode enabled. GUI will be accessible from other machines.")
		log.Println("WARNING: Ensure your firewall is properly configured.")
	}

	// Validate port
	if port, err := strconv.Atoi(config.Port); err != nil || port < 1 || port > 65535 {
		log.Fatalf("Invalid port in config: %s (must be between 1 and 65535)", config.Port)
	}

	releaseVersion = strings.TrimSpace(os.Getenv("LH_RELEASE_VERSION"))
	if releaseVersion == "" && config.ReleaseTag != "" {
		releaseVersion = config.ReleaseTag
	}
	if releaseVersion == "" {
		if output, err := exec.Command("git", "-C", lhRootDir, "describe", "--tags", "--dirty", "--always").Output(); err == nil {
			releaseVersion = strings.TrimSpace(string(output))
		}
	}
	if releaseVersion == "" {
		releaseVersion = "unknown"
	}
	log.Printf("Detected Little Linux Helper release: %s", releaseVersion)

	app := fiber.New(fiber.Config{
		AppName: "Little Linux Helper GUI",
	})

	// Middleware
	app.Use(logger.New())
	// Note: CORS intentionally not enabled in production since we serve the frontend from the same origin.
	// For development, the Vite dev server proxies /api to this backend, avoiding cross-origin requests.

	// Serve static files (React build)
	app.Static("/", "./web/build", fiber.Static{
		Index: "index.html",
	})

	// Serve static documentation assets (e.g., screenshots referenced in Markdown)
	screenshotDir := filepath.Join(lhRootDir, "screenshots")
	if info, err := os.Stat(screenshotDir); err == nil && info.IsDir() {
		app.Static("/screenshots", screenshotDir, fiber.Static{
			Browse:        false,
			CacheDuration: 24 * time.Hour,
		})
	} else {
		log.Printf("Screenshot directory not available at %s: %v", screenshotDir, err)
	}

	// API routes
	api := app.Group("/api")

	// Get available modules
	api.Get("/modules", getModules)

	// Health endpoint
	api.Get("/health", getHealth)

	// Release/version information
	api.Get("/version", getVersion)

	// Get module documentation
	api.Get("/modules/:id/docs", getModuleDocs)

	// Get all available documentation
	api.Get("/docs", getAllDocs)
	api.Get("/docs/unlinked", getUnlinkedDocs)

	// Configuration file management
	api.Get("/config/files", getConfigFiles)
	api.Get("/config/backups", getConfigBackups)
	api.Delete("/config/backups/:backupId", deleteConfigBackup)
	api.Get("/config/:filename", getConfigFile)
	api.Put("/config/:filename", saveConfigFile)
	api.Get("/config/:filename/example", getConfigExample)

	// Start a module session
	api.Post("/modules/:id/start", startModule)

	// Get active sessions
	api.Get("/sessions", getSessions)

	// Send input to module
	api.Post("/sessions/:sessionId/input", sendInput)

	// Stop module session
	api.Delete("/sessions/:sessionId", stopSession)

	// Shutdown server gracefully
	api.Post("/shutdown", shutdownServer)

	// WebSocket for real-time communication
	app.Use("/ws", websocket.New(handleWebSocket))

	// Build listen address
	listenAddr := fmt.Sprintf("%s:%s", config.Host, config.Port)

	// Show security information
	if config.Host == "0.0.0.0" {
		log.Printf("Starting Little Linux Helper GUI on %s (NETWORK ACCESS)", listenAddr)
		log.Printf("GUI accessible at: http://%s:%s and http://localhost:%s", config.Host, config.Port, config.Port)
	} else {
		log.Printf("Starting Little Linux Helper GUI on %s (LOCAL ACCESS ONLY)", listenAddr)
		log.Printf("GUI accessible at: http://localhost:%s", config.Port)
	}

	log.Fatal(app.Listen(listenAddr))
}

// detectLanguage extracts language preference from Accept-Language header or query param
func detectLanguage(c *fiber.Ctx) string {
	// First check for explicit lang query parameter
	if lang := c.Query("lang"); lang != "" {
		return lang
	}

	// Then check Accept-Language header
	acceptLang := c.Get("Accept-Language")
	if acceptLang != "" {
		// Simple language detection - take first language code
		if strings.HasPrefix(acceptLang, "de") {
			return "de"
		}
		if strings.HasPrefix(acceptLang, "en") {
			return "en"
		}
	}

	// Default to English
	return "en"
}

// translateModuleCategory translates module category based on language
func translateModuleCategory(category, lang string) string {
	categoryTranslations := map[string]map[string]string{
		"Recovery & Restarts": {
			"en": "Recovery & Restarts",
			"de": "Wiederherstellung & Neustarts",
		},
		"System Diagnosis & Analysis": {
			"en": "System Diagnosis & Analysis",
			"de": "Systemdiagnose & Analyse",
		},
		"Maintenance & Security": {
			"en": "Maintenance & Security",
			"de": "Wartung & Sicherheit",
		},
		"Docker & Containers": {
			"en": "Docker & Containers",
			"de": "Docker & Container",
		},
		"Backup & Recovery": {
			"en": "Backup & Recovery",
			"de": "Backup & Wiederherstellung",
		},
	}

	if translations, exists := categoryTranslations[category]; exists {
		if translated, exists := translations[lang]; exists {
			return translated
		}
	}

	// Return original if no translation found
	return category
}

// translateModuleName translates module name based on language
func translateModuleName(name, lang string) string {
	nameTranslations := map[string]map[string]string{
		"Services & Desktop Restart Options": {
			"en": "Services & Desktop Restart Options",
			"de": "Dienste & Desktop Neustart-Optionen",
		},
		"Display System Information": {
			"en": "Display System Information",
			"de": "Systeminformationen anzeigen",
		},
		"Disk Tools": {
			"en": "Disk Tools",
			"de": "Festplatten-Tools",
		},
		"Log Analysis Tools": {
			"en": "Log Analysis Tools",
			"de": "Log-Analyse-Tools",
		},
		"Package Management & Updates": {
			"en": "Package Management & Updates",
			"de": "Paketmanagement & Updates",
		},
		"Security Checks": {
			"en": "Security Checks",
			"de": "Sicherheitsprüfungen",
		},
		"Energy Management": {
			"en": "Energy Management",
			"de": "Energieverwaltung",
		},
		"Docker Management": {
			"en": "Docker Management",
			"de": "Docker-Verwaltung",
		},
		"Complete System Backup": {
			"en": "Complete System Backup",
			"de": "Vollständige Systemsicherung",
		},
		"BTRFS Snapshot Backup": {
			"en": "BTRFS Snapshot Backup",
			"de": "BTRFS Snapshot-Backup",
		},
		"BTRFS System Restore": {
			"en": "BTRFS System Restore",
			"de": "BTRFS System-Wiederherstellung",
		},
		"Backup & Recovery": {
			"en": "Backup & Recovery",
			"de": "Backup & Wiederherstellung",
		},
		"BTRFS Backup": {
			"en": "BTRFS Backup",
			"de": "BTRFS Backup",
		},
		"BTRFS Restore": {
			"en": "BTRFS Restore",
			"de": "BTRFS Wiederherstellung",
		},
	}

	if translations, exists := nameTranslations[name]; exists {
		if translated, exists := translations[lang]; exists {
			return translated
		}
	}

	// Return original if no translation found
	return name
}

func getModules(c *fiber.Ctx) error {
	modules := []ModuleInfo{
		// Main modules
		{
			ID:             "restarts",
			Name:           "Services & Desktop Restart Options",
			Description:    "Restart system services, desktop environment, and power management",
			Path:           "modules/mod_restarts.sh",
			Category:       "Recovery & Restarts",
			SubmoduleCount: 7,
		},
		{
			ID:             "system_info",
			Name:           "Display System Information",
			Description:    "Show comprehensive system information and hardware details",
			Path:           "modules/mod_system_info.sh",
			Category:       "System Diagnosis & Analysis",
			SubmoduleCount: 9,
		},
		{
			ID:             "disk",
			Name:           "Disk Tools",
			Description:    "Disk utilities and storage analysis tools",
			Path:           "modules/mod_disk.sh",
			Category:       "System Diagnosis & Analysis",
			SubmoduleCount: 8,
		},
		{
			ID:             "logs",
			Name:           "Log Analysis Tools",
			Description:    "Analyze system logs and troubleshoot issues",
			Path:           "modules/mod_logs.sh",
			Category:       "System Diagnosis & Analysis",
			SubmoduleCount: 7,
		},
		{
			ID:             "packages",
			Name:           "Package Management & Updates",
			Description:    "Manage packages and system updates",
			Path:           "modules/mod_packages.sh",
			Category:       "Maintenance & Security",
			SubmoduleCount: 7,
		},
		{
			ID:             "security",
			Name:           "Security Checks",
			Description:    "Perform security audits and checks",
			Path:           "modules/mod_security.sh",
			Category:       "Maintenance & Security",
			SubmoduleCount: 7,
		},
		{
			ID:             "energy",
			Name:           "Energy Management",
			Description:    "Power management and energy optimization",
			Path:           "modules/mod_energy.sh",
			Category:       "Maintenance & Security",
			SubmoduleCount: 4,
		},

		// Docker modules
		{
			ID:             "docker",
			Name:           "Docker Functions",
			Description:    "Docker management and security tools",
			Path:           "modules/mod_docker.sh",
			Category:       "Docker & Containers",
			SubmoduleCount: 4,
		},

		// Backup parent module
		{
			ID:             "backup",
			Name:           "Backup & Recovery",
			Description:    "Backup and restore operations",
			Path:           "modules/backup/mod_backup.sh",
			Category:       "Backup & Recovery",
			SubmoduleCount: 7,
		},

		// Backup submodules
		{
			ID:             "btrfs_backup",
			Name:           "BTRFS Backup",
			Description:    "Advanced BTRFS snapshot-based backup system with maintenance tools",
			Path:           "modules/backup/mod_btrfs_backup.sh",
			Category:       "Backup & Recovery",
			Parent:         "backup",
			SubmoduleCount: 7,
		},
		{
			ID:             "btrfs_restore",
			Name:           "BTRFS Restore",
			Description:    "BTRFS snapshot restoration with dry-run support",
			Path:           "modules/backup/mod_btrfs_restore.sh",
			Category:       "Backup & Recovery",
			Parent:         "backup",
			SubmoduleCount: 6,
		},
	}

	return c.JSON(modules)
}

var documentationFiles = map[string]string{
	// Main modules (both with and without mod_ prefix)
	"restarts":        "mod/doc_restarts.md",
	"mod_restarts":    "mod/doc_restarts.md",
	"system_info":     "mod/doc_system_info.md",
	"mod_system_info": "mod/doc_system_info.md",
	"disk":            "mod/doc_disk.md",
	"mod_disk":        "mod/doc_disk.md",
	"logs":            "mod/doc_logs.md",
	"mod_logs":        "mod/doc_logs.md",
	"packages":        "mod/doc_packages.md",
	"mod_packages":    "mod/doc_packages.md",
	"security":        "mod/doc_security.md",
	"mod_security":    "mod/doc_security.md",
	"energy":          "mod/doc_energy.md",
	"mod_energy":      "mod/doc_energy.md",

	// Docker modules
	"docker":              "mod/doc_docker.md",
	"mod_docker":          "mod/doc_docker.md",
	"mod_docker_setup":    "mod/doc_docker_setup.md",
	"mod_docker_security": "mod/doc_docker_security.md",

	// Backup modules
	"backup":            "mod/doc_backup.md",
	"mod_backup":        "mod/doc_backup.md",
	"btrfs_backup":      "mod/doc_btrfs_backup.md",
	"mod_btrfs_backup":  "mod/doc_btrfs_backup.md",
	"btrfs_restore":     "mod/doc_btrfs_restore.md",
	"mod_btrfs_restore": "mod/doc_btrfs_restore.md",
	"mod_backup_tar":    "mod/doc_backup_tar.md",
	"mod_restore_tar":   "mod/doc_restore_tar.md",
	"mod_backup_rsync":  "mod/doc_backup_rsync.md",
	"mod_restore_rsync": "mod/doc_restore_rsync.md",

	// Other documentation
	"advanced_log_analyzer": "tools/doc_advanced_log_analyzer.md",

	// Library documentation
	"lib_btrfs":            "lib/doc_btrfs.md",
	"lib_common":           "lib/doc_common.md",
	"lib_colors":           "lib/doc_colors.md",
	"lib_config":           "lib/doc_config.md",
	"lib_filesystem":       "lib/doc_filesystem.md",
	"lib_i18n":             "lib/doc_i18n.md",
	"lib_logging":          "lib/doc_logging.md",
	"lib_notifications":    "lib/doc_notifications.md",
	"lib_package_mappings": "lib/doc_package_mappings.md",
	"lib_packages":         "lib/doc_packages.md",
	"lib_system":           "lib/doc_system.md",
	"lib_ui":               "lib/doc_ui.md",

	// Project documentation
	"DEVELOPER_GUIDE":     "CLI_DEVELOPER_GUIDE.md",
	"GUI_DEVELOPER_GUIDE": "GUI_DEVELOPER_GUIDE.md",
	"gui":                 "gui/doc_interface.md",

	// GUI specialized documentation
	"gui_backend_api":              "gui/doc_backend_api.md",
	"gui_frontend_react":           "gui/doc_frontend_react.md",
	"gui_i18n":                     "gui/doc_i18n.md",
	"gui_module_integration":       "gui/doc_module_integration.md",
	"gui_customization":            "gui/doc_customization.md",
	"gui_module_maintenance_guide": "gui/doc_module_maintenance_guide.md",
	"doc_gui_launcher":             "doc_gui_launcher.md",

	"README":     "../README.md",
	"README_DE":  "../README_DE.md",
	"gui_README": "../gui/README.md",

	"lib_btrfs_core":   "lib/doc_btrfs_core.md",
	"lib_btrfs_layout": "lib/doc_btrfs_layout.md",
}

var docCatalog = []DocMetadata{
	// System Administration
	{ID: "mod_system_info", Name: "System Information", Description: "Show comprehensive system information and hardware details", Filename: "mod/doc_system_info.md"},
	{ID: "mod_security", Name: "Security Analysis", Description: "Perform security audits and checks", Filename: "mod/doc_security.md"},
	{ID: "mod_disk", Name: "Disk Management", Description: "Disk utilities and storage analysis tools", Filename: "mod/doc_disk.md"},
	{ID: "mod_packages", Name: "Package Management", Description: "Manage packages and system updates", Filename: "mod/doc_packages.md"},
	{ID: "mod_energy", Name: "Energy Management", Description: "Power management and energy optimization", Filename: "mod/doc_energy.md"},

	// Backup & Recovery
	{ID: "mod_backup", Name: "General Backup", Description: "Backup and restore operations", Filename: "mod/doc_backup.md"},
	{ID: "mod_btrfs_backup", Name: "BTRFS Backup", Description: "Advanced BTRFS snapshot-based backup system", Filename: "mod/doc_btrfs_backup.md"},
	{ID: "mod_btrfs_restore", Name: "BTRFS Restore", Description: "BTRFS snapshot restoration with dry-run support", Filename: "mod/doc_btrfs_restore.md"},
	{ID: "mod_backup_tar", Name: "TAR Backup", Description: "Archive-based backups", Filename: "mod/doc_backup_tar.md"},
	{ID: "mod_restore_tar", Name: "TAR Restore", Description: "Restore from TAR archives", Filename: "mod/doc_restore_tar.md"},
	{ID: "mod_backup_rsync", Name: "RSYNC Backup", Description: "Incremental file-based backups", Filename: "mod/doc_backup_rsync.md"},
	{ID: "mod_restore_rsync", Name: "RSYNC Restore", Description: "Restore from RSYNC backups", Filename: "mod/doc_restore_rsync.md"},

	// Docker & Containers
	{ID: "mod_docker", Name: "Docker Management", Description: "Docker management and security tools", Filename: "mod/doc_docker.md"},
	{ID: "mod_docker_setup", Name: "Docker Setup", Description: "Install and configure Docker", Filename: "mod/doc_docker_setup.md"},
	{ID: "mod_docker_security", Name: "Docker Security", Description: "Security audit for Docker containers", Filename: "mod/doc_docker_security.md"},

	// Logs & Analysis
	{ID: "mod_logs", Name: "Log Analysis", Description: "Analyze system logs and troubleshoot issues", Filename: "mod/doc_logs.md"},
	{ID: "advanced_log_analyzer", Name: "Advanced Log Analyzer", Description: "Python-based log analysis tool", Filename: "tools/doc_advanced_log_analyzer.md"},

	// System Maintenance
	{ID: "mod_restarts", Name: "System Restarts", Description: "Restart system services and desktop environment components", Filename: "mod/doc_restarts.md"},

	// Development & Libraries
	{ID: "lib_btrfs", Name: "BTRFS Library", Description: "Advanced BTRFS operations and utilities", Filename: "lib/doc_btrfs.md"},
	{ID: "lib_common", Name: "Common Functions Library", Description: "Core shared functions and utilities", Filename: "lib/doc_common.md"},
	{ID: "lib_colors", Name: "Color Functions Library", Description: "Terminal color formatting and styling", Filename: "lib/doc_colors.md"},
	{ID: "lib_config", Name: "Configuration Library", Description: "Configuration file handling and management", Filename: "lib/doc_config.md"},
	{ID: "lib_filesystem", Name: "Filesystem Library", Description: "File system operations and utilities", Filename: "lib/doc_filesystem.md"},
	{ID: "lib_i18n", Name: "Internationalization Library", Description: "Multi-language support and message handling", Filename: "lib/doc_i18n.md"},
	{ID: "lib_logging", Name: "Logging Library", Description: "Structured logging and error handling", Filename: "lib/doc_logging.md"},
	{ID: "lib_notifications", Name: "Notifications Library", Description: "Desktop notification system integration", Filename: "lib/doc_notifications.md"},
	{ID: "lib_package_mappings", Name: "Package Mappings Library", Description: "Cross-distribution package name mappings", Filename: "lib/doc_package_mappings.md"},
	{ID: "lib_packages", Name: "Package Management Library", Description: "Distribution-agnostic package management", Filename: "lib/doc_packages.md"},
	{ID: "lib_system", Name: "System Information Library", Description: "System detection and hardware information", Filename: "lib/doc_system.md"},
	{ID: "lib_ui", Name: "User Interface Library", Description: "User interface functions and input handling", Filename: "lib/doc_ui.md"},
	{ID: "lib_btrfs_core", Name: "BTRFS Core Library", Description: "Core BTRFS helper functions and routines", Filename: "lib/doc_btrfs_core.md"},
	{ID: "lib_btrfs_layout", Name: "BTRFS Layout Reference", Description: "Reference for BTRFS snapshot and bundle layout", Filename: "lib/doc_btrfs_layout.md"},
	{ID: "DEVELOPER_GUIDE", Name: "CLI Developer Guide", Description: "CLI development guidelines and architecture documentation", Filename: "CLI_DEVELOPER_GUIDE.md"},
	{ID: "GUI_DEVELOPER_GUIDE", Name: "GUI Developer Guide", Description: "GUI development guidelines and architecture documentation", Filename: "GUI_DEVELOPER_GUIDE.md"},

	// GUI Specialized Documentation
	{ID: "gui_backend_api", Name: "GUI Backend API", Description: "Go backend development, API endpoints, and data structures", Filename: "gui/doc_backend_api.md"},
	{ID: "gui_frontend_react", Name: "GUI React Frontend", Description: "React component development and frontend architecture", Filename: "gui/doc_frontend_react.md"},
	{ID: "gui_i18n", Name: "GUI Internationalization", Description: "Internationalization system for frontend and backend", Filename: "gui/doc_i18n.md"},
	{ID: "gui_module_integration", Name: "GUI Module Integration", Description: "How CLI modules automatically integrate with GUI", Filename: "gui/doc_module_integration.md"},
	{ID: "gui_customization", Name: "GUI Customization", Description: "Theme customization, extensions, and advanced modifications", Filename: "gui/doc_customization.md"},
	{ID: "gui_module_maintenance_guide", Name: "GUI Module Maintenance", Description: "Checklist for keeping GUI module metadata in sync", Filename: "gui/doc_module_maintenance_guide.md"},

	// Project Information
	{ID: "gui", Name: "GUI Documentation", Description: "Web-based graphical interface documentation", Filename: "gui/doc_interface.md"},
	{ID: "doc_gui_launcher", Name: "GUI Launcher Guide", Description: "Usage guide for the GUI launcher script", Filename: "doc_gui_launcher.md"},
	{ID: "README", Name: "Project README", Description: "Main project overview, features, and usage guide", Filename: "../README.md"},
	{ID: "README_DE", Name: "Project README (German)", Description: "German project overview, features, and usage guide", Filename: "../README_DE.md"},
	{ID: "gui_README", Name: "GUI README", Description: "GUI-specific setup, development, and usage guide", Filename: "../gui/README.md"},
}

func getModuleDocs(c *fiber.Ctx) error {
	moduleId := c.Params("id")

	docFile, exists := documentationFiles[moduleId]
	if !exists {
		return c.Status(404).JSON(fiber.Map{"error": "Documentation not found"})
	}

	docPath := filepath.Join(lhRootDir, "docs", docFile)
	content, err := os.ReadFile(docPath)
	if err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Documentation file not found"})
	}

	return c.JSON(fiber.Map{"content": string(content)})
}

func getAllDocs(c *fiber.Ctx) error {
	docsDir := filepath.Join(lhRootDir, "docs")
	availableDocs := make([]DocMetadata, 0, len(docCatalog))

	for _, doc := range docCatalog {
		docPath := filepath.Join(docsDir, doc.Filename)
		if _, err := os.Stat(docPath); err == nil {
			availableDocs = append(availableDocs, doc)
		}
	}

	return c.JSON(availableDocs)
}

func getUnlinkedDocs(c *fiber.Ctx) error {
	docsDir := filepath.Join(lhRootDir, "docs")
	knownDocs := make(map[string]struct{})

	for _, doc := range docCatalog {
		knownDocs[filepath.ToSlash(filepath.Clean(doc.Filename))] = struct{}{}
	}
	for _, path := range documentationFiles {
		knownDocs[filepath.ToSlash(filepath.Clean(path))] = struct{}{}
	}

	unlinked := make([]string, 0)

	err := filepath.WalkDir(docsDir, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			return nil
		}
		if !strings.HasSuffix(strings.ToLower(d.Name()), ".md") {
			return nil
		}

		rel, err := filepath.Rel(docsDir, path)
		if err != nil {
			return err
		}
		rel = filepath.ToSlash(rel)

		if _, exists := knownDocs[rel]; !exists {
			unlinked = append(unlinked, rel)
		}
		return nil
	})

	if err != nil {
		log.Printf("Error scanning documentation directory: %v", err)
		return c.Status(500).JSON(fiber.Map{"error": "Failed to scan documentation"})
	}

	sort.Strings(unlinked)

	return c.JSON(unlinked)
}

func getSessions(c *fiber.Ctx) error {
	sessionManager.mutex.RLock()
	defer sessionManager.mutex.RUnlock()

	sessions := make([]SessionInfo, 0, len(sessionManager.sessions))
	for _, session := range sessionManager.sessions {
		sessions = append(sessions, SessionInfo{
			ID:         session.ID,
			Module:     session.Module,
			ModuleName: session.ModuleName,
			CreatedAt:  session.CreatedAt,
			Status:     session.Status,
		})
	}

	return c.JSON(sessions)
}

func startModule(c *fiber.Ctx) error {
	moduleId := c.Params("id")

	// Parse request body for language preference
	var req StartModuleRequest
	if err := c.BodyParser(&req); err != nil {
		// If parsing fails, default to English
		req.Language = "en"
	}

	// Validate language - fallback to English if invalid
	if req.Language == "" || (req.Language != "en" && req.Language != "de") {
		req.Language = "en"
	}

	// Generate session ID
	sessionId := fmt.Sprintf("%s_%d", moduleId, time.Now().Unix())

	// Map module ID to human-readable names
	moduleNames := map[string]string{
		"restarts":      "Services & Desktop Restart Options",
		"system_info":   "Display System Information",
		"disk":          "Disk Tools",
		"logs":          "Log Analysis Tools",
		"packages":      "Package Management & Updates",
		"security":      "Security Checks",
		"energy":        "Energy Management",
		"docker":        "Docker Functions",
		"backup":        "Backup & Recovery",
		"btrfs_backup":  "BTRFS Backup",
		"btrfs_restore": "BTRFS Restore",
	}

	// Map module ID to script path
	modulePaths := map[string]string{
		// Main modules
		"restarts":    "modules/mod_restarts.sh",
		"system_info": "modules/mod_system_info.sh",
		"disk":        "modules/mod_disk.sh",
		"logs":        "modules/mod_logs.sh",
		"packages":    "modules/mod_packages.sh",
		"security":    "modules/mod_security.sh",
		"energy":      "modules/mod_energy.sh",

		// Docker modules
		"docker": "modules/mod_docker.sh",

		// Backup modules
		"backup":        "modules/backup/mod_backup.sh",
		"btrfs_backup":  "modules/backup/mod_btrfs_backup.sh",
		"btrfs_restore": "modules/backup/mod_btrfs_restore.sh",
	}

	modulePath, exists := modulePaths[moduleId]
	if !exists {
		return c.Status(400).JSON(fiber.Map{"error": "Unknown module"})
	}

	moduleName, nameExists := moduleNames[moduleId]
	if !nameExists {
		moduleName = moduleId // Fallback to ID if name not found
	}

	scriptPath := filepath.Join(lhRootDir, modulePath)

	// Start the module process with PTY - disable buffering
	cmd := exec.Command("stdbuf", "-i0", "-o0", "-e0", "bash", scriptPath)
	cmd.Dir = lhRootDir

	// Set up environment variables
	cmd.Env = append(os.Environ(),
		"LH_ROOT_DIR="+lhRootDir,
		"LH_GUI_MODE=true",
		"LH_LANG="+req.Language,   // Set language for CLI modules
		"TERM=xterm-256color",     // Ensure color support
		"FORCE_COLOR=1",           // Force color output
		"COLUMNS=120",             // Set terminal width
		"LINES=40",                // Set terminal height
		"LANG="+os.Getenv("LANG"), // Preserve locale settings
		"PS1=$ ",                  // Simple prompt
	)

	// Start the process with a PTY
	ptmx, err := pty.Start(cmd)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to start module with PTY"})
	}

	// Set PTY size for better compatibility
	if err := pty.Setsize(ptmx, &pty.Winsize{
		Rows: 40,
		Cols: 120,
	}); err != nil {
		log.Printf("Failed to set PTY size: %v", err)
	}

	// Create session
	session := &ModuleSession{
		ID:         sessionId,
		Module:     moduleId,
		ModuleName: moduleName,
		CreatedAt:  time.Now(),
		Status:     "running",
		Process:    cmd,
		PTY:        ptmx,
		Done:       make(chan bool),
		Output:     make(chan string, 100),
		Buffer:     make([]string, 0, 200), // Buffer first 200 output messages
	}

	// Store session
	sessionManager.mutex.Lock()
	sessionManager.sessions[sessionId] = session
	sessionManager.mutex.Unlock()

	// Start output reader for PTY
	go readPTYOutput(session)

	// Wait for process completion
	go func() {
		cmd.Wait()
		ptmx.Close()

		// Update session status
		sessionManager.mutex.Lock()
		if s, exists := sessionManager.sessions[sessionId]; exists {
			s.Status = "stopped"
		}
		sessionManager.mutex.Unlock()

		session.Done <- true

		// Clean up session after a brief delay to allow status to be seen
		time.Sleep(1 * time.Second)
		sessionManager.mutex.Lock()
		delete(sessionManager.sessions, sessionId)
		sessionManager.mutex.Unlock()
	}()

	return c.JSON(fiber.Map{"sessionId": sessionId})
}

func sendInput(c *fiber.Ctx) error {
	sessionId := c.Params("sessionId")

	var input struct {
		Data string `json:"data"`
	}

	if err := c.BodyParser(&input); err != nil {
		log.Printf("Error parsing input: %v", err)
		return c.Status(400).JSON(fiber.Map{"error": "Invalid input"})
	}

	// Enforce a maximum input size to prevent abuse (bytes)
	const maxInputSize = 4096
	if len(input.Data) > maxInputSize {
		return c.Status(fiber.StatusRequestEntityTooLarge).JSON(fiber.Map{"error": fmt.Sprintf("Input too large (max %d bytes)", maxInputSize)})
	}

	log.Printf("Received input for session %s: '%s'", sessionId, input.Data)

	sessionManager.mutex.RLock()
	session, exists := sessionManager.sessions[sessionId]
	sessionManager.mutex.RUnlock()

	if !exists {
		log.Printf("Session %s not found", sessionId)
		return c.Status(404).JSON(fiber.Map{"error": "Session not found"})
	}

	// Send input to the PTY
	log.Printf("Sending input to PTY: '%s'", input.Data)

	// Send normal input with newline (including single digit menu choices)
	inputBytes := []byte(input.Data + "\n")
	log.Printf("Sending normal input: '%s' + newline", input.Data)

	_, err := session.PTY.Write(inputBytes)
	if err != nil {
		log.Printf("Error writing to PTY: %v", err)
		return c.Status(500).JSON(fiber.Map{"error": "Failed to send input"})
	}

	// Force flush the PTY buffer to ensure input is sent immediately
	session.PTY.Sync()

	log.Printf("Input sent successfully to session %s", sessionId)
	return c.JSON(fiber.Map{"status": "sent"})
}

func stopSession(c *fiber.Ctx) error {
	sessionId := c.Params("sessionId")

	sessionManager.mutex.Lock()
	session, exists := sessionManager.sessions[sessionId]
	if exists {
		session.Status = "stopped"
	}
	sessionManager.mutex.Unlock()

	if !exists {
		return c.Status(404).JSON(fiber.Map{"error": "Session not found"})
	}

	// Terminate the process and close PTY
	if session.PTY != nil {
		session.PTY.Close()
	}
	if session.Process != nil && session.Process.Process != nil {
		// Try graceful shutdown first
		_ = session.Process.Process.Signal(unix.SIGTERM)
		select {
		case <-session.Done:
			// Process exited gracefully
		case <-time.After(2 * time.Second):
			// Force kill if still running
			_ = session.Process.Process.Kill()
		}
	}

	// Clean up session after a brief delay
	go func() {
		time.Sleep(1 * time.Second)
		sessionManager.mutex.Lock()
		delete(sessionManager.sessions, sessionId)
		sessionManager.mutex.Unlock()
	}()

	return c.JSON(fiber.Map{"status": "stopped"})
}

// shutdownServer handles graceful server shutdown
func shutdownServer(c *fiber.Ctx) error {
	// Get current active sessions
	sessionManager.mutex.RLock()
	activeSessions := make([]SessionInfo, 0, len(sessionManager.sessions))
	for _, session := range sessionManager.sessions {
		if session.Status != "stopped" {
			activeSessions = append(activeSessions, SessionInfo{
				ID:         session.ID,
				Module:     session.Module,
				ModuleName: session.ModuleName,
				CreatedAt:  session.CreatedAt,
				Status:     session.Status,
			})
		}
	}
	sessionManager.mutex.RUnlock()

	// Return session information so frontend can show warnings
	response := fiber.Map{
		"activeSessions": activeSessions,
		"message":        "Server shutdown initiated",
	}

	// If there are active sessions, allow frontend to decide
	if len(activeSessions) > 0 {
		// Check if force shutdown is requested
		forceShutdown := c.QueryBool("force", false)
		if !forceShutdown {
			response["warning"] = "Active sessions will be terminated"
			return c.JSON(response)
		}
	}

	// Perform cleanup in a separate goroutine to allow response to be sent
	go func() {
		log.Println("Initiating graceful server shutdown...")

		// Stop all active sessions
		sessionManager.mutex.Lock()
		for sessionId, session := range sessionManager.sessions {
			if session.Status != "stopped" {
				log.Printf("Stopping session %s (%s)", sessionId, session.ModuleName)
				session.Status = "stopped"

				// Terminate the process and close PTY
				if session.PTY != nil {
					session.PTY.Close()
				}
				if session.Process != nil && session.Process.Process != nil {
					// Try graceful shutdown first
					_ = session.Process.Process.Signal(unix.SIGTERM)
					select {
					case <-session.Done:
						// Process exited gracefully
						log.Printf("Session %s stopped gracefully", sessionId)
					case <-time.After(2 * time.Second):
						// Force kill if still running
						_ = session.Process.Process.Kill()
						log.Printf("Session %s force-killed", sessionId)
					}
				}
			}
		}
		// Clear all sessions
		sessionManager.sessions = make(map[string]*ModuleSession)
		sessionManager.mutex.Unlock()

		log.Println("All sessions stopped. Exiting...")

		// Give a moment for the response to be sent
		time.Sleep(500 * time.Millisecond)

		// Exit the application
		os.Exit(0)
	}()

	return c.JSON(response)
}

func getHealth(c *fiber.Ctx) error {
	// Calculate uptime
	uptime := time.Since(appStartTime).Round(time.Second).Seconds()

	// Count sessions
	sessionManager.mutex.RLock()
	sCount := len(sessionManager.sessions)
	sessionManager.mutex.RUnlock()

	return c.JSON(fiber.Map{
		"status":   "ok",
		"uptime":   uptime,
		"sessions": sCount,
	})
}

func getVersion(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{
		"release": releaseVersion,
	})
}

func readPTYOutput(session *ModuleSession) {
	log.Printf("Starting PTY output reader for session %s", session.ID)
	buffer := make([]byte, 1024)

	for {
		n, err := session.PTY.Read(buffer)
		if err != nil {
			if err != io.EOF {
				log.Printf("PTY read error for session %s: %v", session.ID, err)
				select {
				case session.Output <- fmt.Sprintf("Error reading PTY: %v", err):
				default:
				}
			} else {
				log.Printf("PTY reached EOF for session %s", session.ID)
			}
			break
		}

		if n > 0 {
			output := string(buffer[:n])
			log.Printf("PTY output for session %s (%d bytes): %q", session.ID, n, output)

			// Store in buffer for late-connecting WebSocket clients
			session.BufferMutex.Lock()
			if len(session.Buffer) < 200 { // Keep last 200 messages
				session.Buffer = append(session.Buffer, output)
			} else {
				// Rotate buffer - remove first element, add new one
				session.Buffer = append(session.Buffer[1:], output)
			}
			session.BufferMutex.Unlock()

			// Send raw output to preserve formatting and colors
			select {
			case session.Output <- output:
			default:
				// Channel is full, skip this output
				log.Printf("Output channel full for session %s, skipping output", session.ID)
			}
		}
	}
	log.Printf("PTY output reader finished for session %s", session.ID)
}

func handleWebSocket(c *websocket.Conn) {
	defer c.Close()

	var sessionId string

	for {
		messageType, msg, err := c.ReadMessage()
		if err != nil {
			log.Println("WebSocket read error:", err)
			break
		}

		if messageType == websocket.TextMessage {
			var message Message
			if err := json.Unmarshal(msg, &message); err != nil {
				log.Println("JSON unmarshal error:", err)
				continue
			}

			switch message.Type {
			case "subscribe":
				if id, ok := message.Content.(string); ok {
					sessionId = id

					// Start streaming output for this session
					go func() {
						sessionManager.mutex.RLock()
						session, exists := sessionManager.sessions[sessionId]
						sessionManager.mutex.RUnlock()

						if !exists {
							return
						}

						// First, send buffered output to catch up on what was missed
						session.BufferMutex.RLock()
						for _, bufferedOutput := range session.Buffer {
							response := Message{
								Type:    "output",
								Content: bufferedOutput,
							}
							data, _ := json.Marshal(response)
							c.WriteMessage(websocket.TextMessage, data)
						}
						session.BufferMutex.RUnlock()

						// Drain any queued output from the channel to avoid duplicates
						drained := 0
					drainLoop:
						for {
							select {
							case <-session.Output:
								drained++
							default:
								break drainLoop
							}
						}
						if drained > 0 {
							log.Printf("Drained %d duplicate messages from channel for session %s", drained, sessionId)
						}

						// Then continue with live output
						for {
							select {
							case output := <-session.Output:
								response := Message{
									Type:    "output",
									Content: output,
								}
								data, _ := json.Marshal(response)
								c.WriteMessage(websocket.TextMessage, data)
							case <-session.Done:
								response := Message{
									Type:    "session_ended",
									Content: sessionId,
								}
								data, _ := json.Marshal(response)
								c.WriteMessage(websocket.TextMessage, data)
								return
							}
						}
					}()
				}
			}
		}
	}
}

// ConfigFile represents a configuration file
type ConfigFile struct {
	Filename     string    `json:"filename"`
	Content      string    `json:"content"`
	HasExample   bool      `json:"has_example"`
	LastModified time.Time `json:"last_modified"`
}

// ConfigFileInfo represents basic config file information
type ConfigFileInfo struct {
	Filename     string    `json:"filename"`
	DisplayName  string    `json:"display_name"`
	HasExample   bool      `json:"has_example"`
	LastModified time.Time `json:"last_modified"`
}

// ConfigBackup represents a backup file
type ConfigBackup struct {
	ID         string    `json:"id"`
	Filename   string    `json:"filename"`
	BackupFile string    `json:"backup_file"`
	CreatedAt  time.Time `json:"created_at"`
}

// getConfigFiles returns a list of available configuration files
func getConfigFiles(c *fiber.Ctx) error {
	configDir := filepath.Join(lhRootDir, "config")

	// List of config files we want to expose
	configFiles := []string{"general.conf", "backup.conf", "docker.conf"}
	var files []ConfigFileInfo

	for _, filename := range configFiles {
		configPath := filepath.Join(configDir, filename)
		examplePath := filepath.Join(configDir, filename+".example")

		// Check if config file exists
		var lastModified time.Time
		if info, err := os.Stat(configPath); err == nil {
			lastModified = info.ModTime()
		}

		// Check if example file exists
		hasExample := false
		if _, err := os.Stat(examplePath); err == nil {
			hasExample = true
		}

		// Create display name
		displayName := filename
		switch filename {
		case "general.conf":
			displayName = "General Configuration"
		case "backup.conf":
			displayName = "Backup Configuration"
		case "docker.conf":
			displayName = "Docker Configuration"
		}

		files = append(files, ConfigFileInfo{
			Filename:     filename,
			DisplayName:  displayName,
			HasExample:   hasExample,
			LastModified: lastModified,
		})
	}

	return c.JSON(files)
}

// getConfigFile returns the content of a specific configuration file
func getConfigFile(c *fiber.Ctx) error {
	filename := c.Params("filename")

	// Security check - only allow specific config files
	allowedFiles := map[string]bool{
		"general.conf": true,
		"backup.conf":  true,
		"docker.conf":  true,
	}

	if !allowedFiles[filename] {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid configuration file"})
	}

	configPath := filepath.Join(lhRootDir, "config", filename)
	examplePath := filepath.Join(lhRootDir, "config", filename+".example")

	// Check if example file exists
	hasExample := false
	if _, err := os.Stat(examplePath); err == nil {
		hasExample = true
	}

	// Read config file content
	var content string
	var lastModified time.Time

	if data, err := os.ReadFile(configPath); err == nil {
		content = string(data)
		if info, err := os.Stat(configPath); err == nil {
			lastModified = info.ModTime()
		}
	} else {
		// If config file doesn't exist, use empty content
		content = ""
	}

	return c.JSON(ConfigFile{
		Filename:     filename,
		Content:      content,
		HasExample:   hasExample,
		LastModified: lastModified,
	})
}

// saveConfigFile saves configuration file content with backup
func saveConfigFile(c *fiber.Ctx) error {
	filename := c.Params("filename")

	// Security check - only allow specific config files
	allowedFiles := map[string]bool{
		"general.conf": true,
		"backup.conf":  true,
		"docker.conf":  true,
	}

	if !allowedFiles[filename] {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid configuration file"})
	}

	var request struct {
		Content      string `json:"content"`
		CreateBackup bool   `json:"create_backup"`
	}

	if err := c.BodyParser(&request); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body"})
	}

	configPath := filepath.Join(lhRootDir, "config", filename)

	// Determine config type for validation
	configType := "general"
	switch filename {
	case "backup.conf":
		configType = "backup"
	case "docker.conf":
		configType = "docker"
	}

	// Use shell script to safely write the config with backup
	var backupFile string
	if request.CreateBackup {
		// Create backup using our GUI library
		cmd := exec.Command("bash", "-c", fmt.Sprintf(`
			source "%s/lib/lib_common.sh"
			source "%s/lib/lib_gui.sh"
			backup_file=$(lh_gui_create_config_backup "%s")
			echo "$backup_file"
		`, lhRootDir, lhRootDir, configPath))

		cmd.Env = append(os.Environ(), "LH_ROOT_DIR="+lhRootDir)

		if output, err := cmd.Output(); err == nil {
			backupFile = strings.TrimSpace(string(output))
		}
	}

	// Write config file using GUI library for validation and safety
	cmd := exec.Command("bash", "-c", fmt.Sprintf(`
		source "%s/lib/lib_common.sh"
		source "%s/lib/lib_gui.sh"
		lh_gui_write_config_file "%s" %s %s "%s" 2>&1
	`, lhRootDir, lhRootDir,
		configPath,
		shellescape(request.Content),
		fmt.Sprintf("%t", request.CreateBackup),
		configType))

	cmd.Env = append(os.Environ(), "LH_ROOT_DIR="+lhRootDir)

	if output, err := cmd.CombinedOutput(); err != nil {
		return c.Status(500).JSON(fiber.Map{
			"error":   "Failed to save configuration file",
			"details": string(output),
		})
	}

	result := fiber.Map{"status": "saved", "filename": filename}
	if backupFile != "" {
		result["backup_created"] = backupFile
	}

	return c.JSON(result)
}

// getConfigExample returns the content of a configuration example file
func getConfigExample(c *fiber.Ctx) error {
	filename := c.Params("filename")

	// Security check - only allow specific config files
	allowedFiles := map[string]bool{
		"general.conf": true,
		"backup.conf":  true,
		"docker.conf":  true,
	}

	if !allowedFiles[filename] {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid configuration file"})
	}

	examplePath := filepath.Join(lhRootDir, "config", filename+".example")

	// Read example file content
	data, err := os.ReadFile(examplePath)
	if err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Example file not found"})
	}

	var lastModified time.Time
	if info, err := os.Stat(examplePath); err == nil {
		lastModified = info.ModTime()
	}

	return c.JSON(ConfigFile{
		Filename:     filename + ".example",
		Content:      string(data),
		HasExample:   false, // Example files don't have examples
		LastModified: lastModified,
	})
}

// getConfigBackups returns a list of configuration backups
func getConfigBackups(c *fiber.Ctx) error {
	// Use shell script to list all GUI backups
	cmd := exec.Command("bash", "-c", fmt.Sprintf(`
		source "%s/lib/lib_common.sh"
		source "%s/lib/lib_gui.sh"
		lh_gui_list_all_config_backups
	`, lhRootDir, lhRootDir))

	cmd.Env = append(os.Environ(), "LH_ROOT_DIR="+lhRootDir)

	output, err := cmd.Output()
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to list backups"})
	}

	backupPaths := strings.Split(strings.TrimSpace(string(output)), "\n")
	var backups []ConfigBackup

	for _, backupPath := range backupPaths {
		backupPath = strings.TrimSpace(backupPath)
		if backupPath == "" {
			continue
		}

		// Parse backup file name to extract info
		backupFile := filepath.Base(backupPath)
		if !strings.Contains(backupFile, ".gui_backup_") {
			continue
		}

		// Extract original filename
		parts := strings.Split(backupFile, ".gui_backup_")
		if len(parts) != 2 {
			continue
		}

		originalFile := parts[0]
		timestamp := parts[1]

		// Parse timestamp
		var createdAt time.Time
		if t, err := time.Parse("20060102_150405", timestamp); err == nil {
			createdAt = t
		}

		// Get file info
		if info, err := os.Stat(backupPath); err == nil {
			createdAt = info.ModTime() // Use actual file modification time
		}

		backups = append(backups, ConfigBackup{
			ID:         fmt.Sprintf("%s_%s", originalFile, timestamp),
			Filename:   originalFile,
			BackupFile: backupFile,
			CreatedAt:  createdAt,
		})
	}

	return c.JSON(backups)
}

// deleteConfigBackup removes a configuration backup
func deleteConfigBackup(c *fiber.Ctx) error {
	backupId := c.Params("backupId")

	// Parse backup ID to get file path
	parts := strings.Split(backupId, "_")
	if len(parts) < 3 {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid backup ID"})
	}

	// Reconstruct filename and timestamp
	// For ID like "general.conf_20250824_175158", we need last 2 parts as timestamp
	timestamp := strings.Join(parts[len(parts)-2:], "_")
	filename := strings.Join(parts[:len(parts)-2], "_")

	backupFile := fmt.Sprintf("%s.gui_backup_%s", filename, timestamp)
	backupPath := filepath.Join(lhRootDir, "config", backupFile)

	// Use shell script to safely remove backup
	cmd := exec.Command("bash", "-c", fmt.Sprintf(`
		source "%s/lib/lib_common.sh"
		source "%s/lib/lib_gui.sh"
		lh_gui_remove_config_backup "%s"
	`, lhRootDir, lhRootDir, backupPath))

	cmd.Env = append(os.Environ(), "LH_ROOT_DIR="+lhRootDir)

	if output, err := cmd.CombinedOutput(); err != nil {
		return c.Status(500).JSON(fiber.Map{
			"error":   "Failed to remove backup",
			"details": string(output),
		})
	}

	return c.JSON(fiber.Map{"status": "deleted", "backup_id": backupId})
}

// shellescape escapes a string for safe use in shell commands
func shellescape(s string) string {
	return fmt.Sprintf("'%s'", strings.ReplaceAll(s, "'", "'\"'\"'"))
}
