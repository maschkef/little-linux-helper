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
	"fmt"
	"io"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/creack/pty"
	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
	"github.com/gofiber/fiber/v2/middleware/logger"
	"github.com/gofiber/websocket/v2"
)

type ModuleInfo struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Description string `json:"description"`
	Path        string `json:"path"`
	Category    string `json:"category"`
	Parent      string `json:"parent,omitempty"` // Parent module ID for submodules
	SubmoduleCount int    `json:"submodule_count,omitempty"` // Number of available submodules
}

type SessionManager struct {
	sessions map[string]*ModuleSession
	mutex    sync.RWMutex
}

type ModuleSession struct {
	ID      string
	Module  string
	Process *exec.Cmd
	PTY     *os.File
	Done    chan bool
	Output  chan string
	Buffer  []string
	BufferMutex sync.RWMutex
}

type Message struct {
	Type    string      `json:"type"`
	Content interface{} `json:"content"`
}

var (
	sessionManager = &SessionManager{
		sessions: make(map[string]*ModuleSession),
	}
	lhRootDir string
)

func init() {
	// Get the Little Linux Helper root directory
	executable, err := os.Executable()
	if err != nil {
		log.Fatal("Could not determine executable path:", err)
	}
	
	// Assume GUI is in gui/ subdirectory of the main project
	lhRootDir = filepath.Dir(filepath.Dir(executable))
	
	// If running from source (go run), use current directory structure
	if strings.Contains(executable, "/tmp/") {
		wd, _ := os.Getwd()
		lhRootDir = filepath.Dir(wd)
	}
	
	// Set environment variable for the scripts
	os.Setenv("LH_ROOT_DIR", lhRootDir)
	
	log.Printf("Little Linux Helper root directory: %s", lhRootDir)
}

func main() {
	app := fiber.New(fiber.Config{
		AppName: "Little Linux Helper GUI",
	})

	// Middleware
	app.Use(logger.New())
	app.Use(cors.New())

	// Serve static files (React build)
	app.Static("/", "./web/build", fiber.Static{
		Index: "index.html",
	})

	// API routes
	api := app.Group("/api")
	
	// Get available modules
	api.Get("/modules", getModules)
	
	// Get module documentation
	api.Get("/modules/:id/docs", getModuleDocs)
	
	// Start a module session
	api.Post("/modules/:id/start", startModule)
	
	// Send input to module
	api.Post("/sessions/:sessionId/input", sendInput)
	
	// Stop module session
	api.Delete("/sessions/:sessionId", stopSession)

	// WebSocket for real-time communication
	app.Use("/ws", websocket.New(handleWebSocket))

	log.Println("Starting Little Linux Helper GUI on :3000")
	log.Fatal(app.Listen(":3000"))
}

func getModules(c *fiber.Ctx) error {
	modules := []ModuleInfo{
		// Main modules
		{
			ID:          "restarts",
			Name:        "Services & Desktop Restart Options",
			Description: "Restart system services and desktop environment components (8 options available)",
			Path:        "modules/mod_restarts.sh",
			Category:    "Recovery & Restarts",
			SubmoduleCount: 8,
		},
		{
			ID:          "system_info",
			Name:        "Display System Information",
			Description: "Show comprehensive system information and hardware details (14 options available)",
			Path:        "modules/mod_system_info.sh",
			Category:    "System Diagnosis & Analysis",
			SubmoduleCount: 14,
		},
		{
			ID:          "disk",
			Name:        "Disk Tools",
			Description: "Disk utilities and storage analysis tools (11 options available)",
			Path:        "modules/mod_disk.sh",
			Category:    "System Diagnosis & Analysis",
			SubmoduleCount: 11,
		},
		{
			ID:          "logs",
			Name:        "Log Analysis Tools",
			Description: "Analyze system logs and troubleshoot issues (7 options available)",
			Path:        "modules/mod_logs.sh",
			Category:    "System Diagnosis & Analysis",
			SubmoduleCount: 7,
		},
		{
			ID:          "packages",
			Name:        "Package Management & Updates",
			Description: "Manage packages and system updates (13 options available)",
			Path:        "modules/mod_packages.sh",
			Category:    "Maintenance & Security",
			SubmoduleCount: 13,
		},
		{
			ID:          "security",
			Name:        "Security Checks",
			Description: "Perform security audits and checks (7 options available)",
			Path:        "modules/mod_security.sh",
			Category:    "Maintenance & Security",
			SubmoduleCount: 7,
		},
		{
			ID:          "energy",
			Name:        "Energy Management",
			Description: "Power management and energy optimization (4 options available)",
			Path:        "modules/mod_energy.sh",
			Category:    "Maintenance & Security",
			SubmoduleCount: 4,
		},
		
		// Docker modules
		{
			ID:          "docker",
			Name:        "Docker Functions",
			Description: "Docker management and security tools (4 options available)",
			Path:        "modules/mod_docker.sh",
			Category:    "Docker & Containers",
			SubmoduleCount: 4,
		},
		
		// Backup parent module
		{
			ID:          "backup",
			Name:        "Backup & Recovery",
			Description: "Backup and restore operations (7 options available)",
			Path:        "modules/backup/mod_backup.sh",
			Category:    "Backup & Recovery",
			SubmoduleCount: 7,
		},
		
		// Backup submodules (only BTRFS ones remain as direct options)
		{
			ID:          "btrfs_backup",
			Name:        "BTRFS Backup",
			Description: "Advanced BTRFS snapshot-based backup system (7 options available)",
			Path:        "modules/backup/mod_btrfs_backup.sh",
			Category:    "Backup & Recovery",
			Parent:      "backup",
			SubmoduleCount: 7,
		},
		{
			ID:          "btrfs_restore",
			Name:        "BTRFS Restore",
			Description: "BTRFS snapshot restoration with dry-run support (6 options available)",
			Path:        "modules/backup/mod_btrfs_restore.sh",
			Category:    "Backup & Recovery",
			Parent:      "backup",
			SubmoduleCount: 6,
		},
	}

	return c.JSON(modules)
}

func getModuleDocs(c *fiber.Ctx) error {
	moduleId := c.Params("id")
	
	// Map module IDs to documentation files
	docFiles := map[string]string{
		// Main modules
		"restarts":       "mod_restarts.md",
		"system_info":    "mod_system_info.md", 
		"disk":           "mod_disk.md",
		"logs":           "mod_logs.md",
		"packages":       "mod_packages.md",
		"security":       "mod_security.md",
		"energy":         "mod_energy.md",
		
		// Docker modules
		"docker":         "mod_docker.md",
		
		// Backup modules
		"backup":         "mod_backup.md",
		"btrfs_backup":   "mod_btrfs_backup.md",
		"btrfs_restore":  "mod_btrfs_restore.md",
	}
	
	docFile, exists := docFiles[moduleId]
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

func startModule(c *fiber.Ctx) error {
	moduleId := c.Params("id")
	
	// Generate session ID
	sessionId := fmt.Sprintf("%s_%d", moduleId, time.Now().Unix())
	
	// Map module ID to script path
	modulePaths := map[string]string{
		// Main modules
		"restarts":       "modules/mod_restarts.sh",
		"system_info":    "modules/mod_system_info.sh",
		"disk":           "modules/mod_disk.sh", 
		"logs":           "modules/mod_logs.sh",
		"packages":       "modules/mod_packages.sh",
		"security":       "modules/mod_security.sh",
		"energy":         "modules/mod_energy.sh",
		
		// Docker modules
		"docker":         "modules/mod_docker.sh",
		
		// Backup modules
		"backup":         "modules/backup/mod_backup.sh",
		"btrfs_backup":   "modules/backup/mod_btrfs_backup.sh",
		"btrfs_restore":  "modules/backup/mod_btrfs_restore.sh",
	}
	
	modulePath, exists := modulePaths[moduleId]
	if !exists {
		return c.Status(400).JSON(fiber.Map{"error": "Unknown module"})
	}
	
	scriptPath := filepath.Join(lhRootDir, modulePath)
	
	// Start the module process with PTY - disable buffering
	cmd := exec.Command("stdbuf", "-i0", "-o0", "-e0", "bash", scriptPath)
	cmd.Dir = lhRootDir
	
	// Set up environment variables
	cmd.Env = append(os.Environ(),
		"LH_ROOT_DIR="+lhRootDir,
		"LH_GUI_MODE=true",
		"TERM=xterm-256color",      // Ensure color support
		"FORCE_COLOR=1",            // Force color output
		"COLUMNS=120",              // Set terminal width
		"LINES=40",                 // Set terminal height
		"LANG="+os.Getenv("LANG"),  // Preserve locale settings
		"PS1=$ ",                   // Simple prompt
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
		ID:      sessionId,
		Module:  moduleId,
		Process: cmd,
		PTY:     ptmx,
		Done:    make(chan bool),
		Output:  make(chan string, 100),
		Buffer:  make([]string, 0, 200), // Buffer first 200 output messages
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
		session.Done <- true
		
		// Clean up session
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
	
	var inputBytes []byte
	// Check if this is a "press any key" marker
	if input.Data == "__PRESS_ANY_KEY__" {
		// Send just a single space character without newline for "press any key" prompts
		inputBytes = []byte(" ")
		log.Printf("Sending 'press any key' input: space character (no newline)")
	} else {
		// Send normal input with newline (including single digit menu choices)
		inputBytes = []byte(input.Data + "\n")
		log.Printf("Sending normal input: '%s' + newline", input.Data)
	}
	
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
		delete(sessionManager.sessions, sessionId)
	}
	sessionManager.mutex.Unlock()
	
	if !exists {
		return c.Status(404).JSON(fiber.Map{"error": "Session not found"})
	}
	
	// Terminate the process and close PTY
	if session.PTY != nil {
		session.PTY.Close()
	}
	if session.Process != nil {
		session.Process.Process.Kill()
	}
	
	return c.JSON(fiber.Map{"status": "stopped"})
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

func readOutput(session *ModuleSession, reader io.ReadCloser, source string) {
	scanner := bufio.NewScanner(reader)
	for scanner.Scan() {
		output := scanner.Text()
		
		// Clean up the output but preserve some formatting
		cleanOutput := output
		
		// Send to output channel (for WebSocket clients)
		select {
		case session.Output <- cleanOutput:
		default:
			// Channel is full, skip this output
		}
	}
	
	// When the scanner is done, check for errors
	if err := scanner.Err(); err != nil {
		select {
		case session.Output <- fmt.Sprintf("[%s] Error reading output: %v", source, err):
		default:
		}
	}
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
