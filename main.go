package main

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"strings"
	"sync"
)

// Config structure matching registry.json
type AppConfig struct {
	Path    string `json:"path"`
	Branch  string `json:"branch"`
	Secret  string `json:"secret"`
	Compose string `json:"compose_file,omitempty"` // Optional, defaults to docker-compose.yml
}

// Global state
var (
	registry     map[string]AppConfig
	registryLock sync.RWMutex
	deployLocks  sync.Map // Prevents overlapping deploys for the same app
)

func main() {
	port := flag.String("port", "8080", "Port to listen on")
	configFile := flag.String("config", "/etc/dockup/registry.json", "Path to registry.json")
	flag.Parse()

	// Load Config
	if err := loadConfig(*configFile); err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	// Routes
	http.HandleFunc("/webhook/github", handleGithub)
	http.HandleFunc("/webhook/manual", handleManual)

	log.Printf("🚀 DockUp Agent running on :%s, watching %d apps", *port, len(registry))
	log.Fatal(http.ListenAndServe(":"+*port, nil))
}

func loadConfig(path string) error {
	file, err := os.Open(path)
	if err != nil {
		return err
	}
	defer file.Close()

	registryLock.Lock()
	defer registryLock.Unlock()

	// Decode generic map
	return json.NewDecoder(file).Decode(&registry)
}

// --- Handlers ---

func handleGithub(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", 405)
		return
	}

	// 1. Read Body
	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "Bad request", 400)
		return
	}
	defer r.Body.Close()

	// 2. Parse Payload to get Repo Name
	var payload struct {
		Ref        string `json:"ref"` // e.g., "refs/heads/main"
		Repository struct {
			Name string `json:"name"`
		} `json:"repository"`
	}
	if err := json.Unmarshal(body, &payload); err != nil {
		http.Error(w, "Invalid JSON", 400)
		return
	}

	// 3. Lookup App
	registryLock.RLock()
	config, exists := registry[payload.Repository.Name]
	registryLock.RUnlock()

	if !exists {
		log.Printf("⚠️  Received webhook for unknown repo: %s", payload.Repository.Name)
		http.Error(w, "Repo not registered", 404)
		return
	}

	// 4. Validate Signature (Security)
	signature := r.Header.Get("X-Hub-Signature-256")
	if !validateSignature(body, config.Secret, signature) {
		log.Printf("⛔ Invalid signature for %s", payload.Repository.Name)
		http.Error(w, "Forbidden", 403)
		return
	}

	// 5. Check Branch
	expectedRef := "refs/heads/" + config.Branch
	if payload.Ref != expectedRef {
		log.Printf("ℹ️  Ignored push to %s (watching %s)", payload.Ref, config.Branch)
		w.Write([]byte("Ignored branch"))
		return
	}

	// 6. Trigger Async Deploy
	go runDeploy(payload.Repository.Name, config)
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("Deploy triggered"))
}

func handleManual(w http.ResponseWriter, r *http.Request) {
	appName := r.URL.Query().Get("app")
	if appName == "" {
		http.Error(w, "Missing ?app= parameter", 400)
		return
	}

	registryLock.RLock()
	config, exists := registry[appName]
	registryLock.RUnlock()

	if !exists {
		http.Error(w, "App not found", 404)
		return
	}

	// Simple Bearer Auth
	authHeader := r.Header.Get("Authorization")
	if authHeader != "Bearer "+config.Secret {
		http.Error(w, "Unauthorized", 401)
		return
	}

	go runDeploy(appName, config)
	w.Write([]byte("Manual deploy triggered"))
}

// --- Helpers ---

func validateSignature(payload []byte, secret, signatureHeader string) bool {
	if !strings.HasPrefix(signatureHeader, "sha256=") {
		return false
	}

	// Calculate HMAC
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write(payload)
	expectedMAC := mac.Sum(nil)
	expectedSig := "sha256=" + hex.EncodeToString(expectedMAC)

	// Constant time comparison to prevent timing attacks
	return hmac.Equal([]byte(signatureHeader), []byte(expectedSig))
}

func runDeploy(appName string, config AppConfig) {
	// Mutex for this specific app to prevent race conditions
	lock, _ := deployLocks.LoadOrStore(appName, &sync.Mutex{})
	mtx := lock.(*sync.Mutex)

	if !mtx.TryLock() {
		log.Printf("⏳ Deploy already in progress for %s, skipping...", appName)
		return
	}
	defer mtx.Unlock()

	log.Printf("♻️  Starting deploy for %s...", appName)

	composeFile := "docker-compose.yml"
	if config.Compose != "" {
		composeFile = config.Compose
	}

	// The Update Script
	// We use 'git reset' to ensure exact state match and avoid merge conflicts
	commands := []string{
		"git fetch origin " + config.Branch,
		"git reset --hard origin/" + config.Branch,
		fmt.Sprintf("docker compose -f %s build --pull", composeFile),
		fmt.Sprintf("docker compose -f %s up -d --remove-orphans", composeFile),
		"docker system prune -f", // Clean up old images
	}

	fullCmd := strings.Join(commands, " && ")
	cmd := exec.Command("/bin/sh", "-c", fullCmd)
	cmd.Dir = config.Path // Run in the app directory

	output, err := cmd.CombinedOutput()
	if err != nil {
		log.Printf("❌ Deploy FAILED for %s:\n%s", appName, string(output))
	} else {
		log.Printf("✅ Deploy SUCCESS for %s", appName)
	}
}

