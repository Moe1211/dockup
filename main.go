package main

import (
	"bytes"
	"crypto/hmac"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/hex"
	"encoding/json"
	"encoding/pem"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"strings"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// Version is set during build via -ldflags
var Version = "dev"

// Config structure matching registry.json
type AppConfig struct {
	Path    string `json:"path"`
	Branch  string `json:"branch"`
	Secret  string `json:"secret"`
	Compose string `json:"compose_file,omitempty"` // Optional, defaults to docker-compose.yml
}

// GitHubAppConfig structure for GitHub App credentials
type GitHubAppConfig struct {
	AppID          string `json:"app_id"`
	InstallationID string `json:"installation_id"`
	PrivateKey     string `json:"private_key"`
}

// MetricsConfig structure for metrics tracking
type MetricsConfig struct {
	N8NWebhookURL string `json:"n8n_webhook_url"`
	VPSID         string `json:"vps_id,omitempty"`
}

// Token cache for installation tokens
type tokenCache struct {
	token     string
	expiresAt time.Time
	mu        sync.RWMutex
}

// Global state
var (
	registry          map[string]AppConfig
	registryLock      sync.RWMutex
	deployLocks       sync.Map // Prevents overlapping deploys for the same app
	githubAppConfig   *GitHubAppConfig
	githubAppLock     sync.RWMutex
	installationToken tokenCache
	metricsConfig     *MetricsConfig
	metricsLock       sync.RWMutex
)

func main() {
	port := flag.String("port", "8080", "Port to listen on")
	configFile := flag.String("config", "/etc/dockup/registry.json", "Path to registry.json")
	showVersion := flag.Bool("version", false, "Show version and exit")
	flag.Parse()

	if *showVersion {
		fmt.Printf("DockUp Agent v%s\n", Version)
		os.Exit(0)
	}

	// Load Config
	if err := loadConfig(*configFile); err != nil {
		log.Fatalf("❌ Failed to load config: %v\n   Check that %s exists and contains valid JSON", err, *configFile)
	}

	// Load GitHub App config (optional, but recommended)
	loadGitHubAppConfig()

	// Load metrics config (optional)
	loadMetricsConfig()

	// Routes
	http.HandleFunc("/webhook/github", handleGithub)
	http.HandleFunc("/webhook/manual", handleManual)
	http.HandleFunc("/reload", handleReload)
	http.HandleFunc("/github/token-url", handleGitHubTokenURL)
	http.HandleFunc("/github/create-webhook", handleCreateWebhook)
	http.HandleFunc("/metrics/track", handleMetricsTrack)

	log.Printf("🚀 DockUp Agent v%s running on :%s, watching %d apps", Version, *port, len(registry))
	if githubAppConfig != nil {
		log.Printf("✅ GitHub App configured (App ID: %s)", githubAppConfig.AppID)
	} else {
		log.Printf("⚠️  GitHub App not configured - repository cloning may fail")
		log.Printf("   Run: dockup configure-github-app user@vps-ip")
	}

	// Start server - http.ListenAndServe will fail immediately if port is in use
	// No separate port check needed as it would create a race condition
	log.Fatal(http.ListenAndServe(":"+*port, nil))
}

func loadConfig(path string) error {
	file, err := os.Open(path)
	if err != nil {
		return fmt.Errorf("failed to open config file %s: %v", path, err)
	}
	defer file.Close()

	registryLock.Lock()
	defer registryLock.Unlock()

	// Decode generic map
	if err := json.NewDecoder(file).Decode(&registry); err != nil {
		return fmt.Errorf("failed to parse JSON config file %s: %v", path, err)
	}

	// Ensure registry is initialized (handle empty file case)
	if registry == nil {
		registry = make(map[string]AppConfig)
	}

	return nil
}

func loadGitHubAppConfig() {
	configPath := "/etc/dockup/github-app.json"
	file, err := os.Open(configPath)
	if err != nil {
		// GitHub App config is optional
		return
	}
	defer file.Close()

	var config GitHubAppConfig
	if err := json.NewDecoder(file).Decode(&config); err != nil {
		log.Printf("⚠️  Failed to parse GitHub App config: %v", err)
		return
	}

	if config.AppID == "" || config.InstallationID == "" || config.PrivateKey == "" {
		log.Printf("⚠️  GitHub App config incomplete")
		return
	}

	githubAppLock.Lock()
	githubAppConfig = &config
	githubAppLock.Unlock()
}

// generateVPSID generates a VPS ID from system snapshot (runs on the VPS)
func generateVPSID() string {
	// Get OS distribution
	osName := "unknown"
	if data, err := os.ReadFile("/etc/os-release"); err == nil {
		lines := strings.Split(string(data), "\n")
		for _, line := range lines {
			if strings.HasPrefix(line, "ID=") {
				osName = strings.Trim(strings.TrimPrefix(line, "ID="), "\"")
				osName = strings.ToLower(osName)
				break
			}
		}
	} else {
		// Fallback to uname
		if out, err := exec.Command("uname", "-s").Output(); err == nil {
			osName = strings.ToLower(strings.TrimSpace(string(out)))
		}
	}

	// Get RAM in GB
	ramGB := "unknown"
	if data, err := os.ReadFile("/proc/meminfo"); err == nil {
		lines := strings.Split(string(data), "\n")
		for _, line := range lines {
			if strings.HasPrefix(line, "MemTotal:") {
				fields := strings.Fields(line)
				if len(fields) >= 2 {
					ramKB := 0
					fmt.Sscanf(fields[1], "%d", &ramKB)
					if ramKB > 0 {
						ramGB = fmt.Sprintf("%d", (ramKB+1024*1024-1)/(1024*1024)) // Round up
					}
				}
				break
			}
		}
	}

	// Get location/region (try metadata services)
	location := "unknown"

	// Try Hetzner metadata
	if resp, err := http.Get("http://169.254.169.254/hetzner/v1/metadata/datacenter"); err == nil {
		if body, err := io.ReadAll(resp.Body); err == nil {
			location = strings.ToLower(strings.TrimSpace(string(body)))
		}
		resp.Body.Close()
	}

	// Try DigitalOcean metadata
	if location == "unknown" {
		if resp, err := http.Get("http://169.254.169.254/metadata/v1/region"); err == nil {
			if body, err := io.ReadAll(resp.Body); err == nil {
				location = strings.ToLower(strings.TrimSpace(string(body)))
			}
			resp.Body.Close()
		}
	}

	// Try AWS metadata
	if location == "unknown" {
		if resp, err := http.Get("http://169.254.169.254/latest/meta-data/placement/availability-zone"); err == nil {
			if body, err := io.ReadAll(resp.Body); err == nil {
				location = strings.ToLower(strings.TrimSpace(string(body)))
			}
			resp.Body.Close()
		}
	}

	// Fallback: use hostname
	if location == "unknown" {
		if hostname, err := os.Hostname(); err == nil {
			hostname = strings.ToLower(hostname)
			// Try to extract location pattern (e.g., fsn1, nyc1)
			if matched := strings.Contains(hostname, "fsn") || strings.Contains(hostname, "nyc") || strings.Contains(hostname, "fra"); matched {
				// Extract first 4 chars as location
				if len(hostname) >= 4 {
					location = hostname[:4]
				} else {
					location = hostname
				}
			} else {
				location = "vps"
			}
		}
	}

	return fmt.Sprintf("%s-%sgb-%s", osName, ramGB, location)
}

func loadMetricsConfig() {
	configPath := "/etc/dockup/metrics.json"

	// Default webhook URL (can be overridden by environment variable or config file)
	defaultWebhookURL := "https://n8n2.drninja.net/webhook/dockup"
	if envURL := os.Getenv("DOCKUP_N8N_WEBHOOK_URL"); envURL != "" {
		defaultWebhookURL = envURL
	}

	file, err := os.Open(configPath)
	if err != nil {
		// Config file doesn't exist - auto-configure with defaults
		if os.IsNotExist(err) {
			// Ensure directory exists
			if err := os.MkdirAll("/etc/dockup", 0755); err != nil {
				log.Printf("⚠️  Failed to create /etc/dockup directory: %v", err)
				return
			}

			// Auto-generate VPS ID
			vpsID := generateVPSID()

			// Create default config
			config := MetricsConfig{
				N8NWebhookURL: defaultWebhookURL,
				VPSID:         vpsID,
			}

			// Save config file
			configJSON, err := json.MarshalIndent(config, "", "  ")
			if err != nil {
				log.Printf("⚠️  Failed to marshal metrics config: %v", err)
				return
			}

			if err := os.WriteFile(configPath, configJSON, 0600); err != nil {
				log.Printf("⚠️  Failed to create metrics config: %v", err)
				return
			}

			// Set the config
			metricsLock.Lock()
			metricsConfig = &config
			metricsLock.Unlock()

			log.Printf("📊 Metrics tracking auto-configured (VPS ID: %s)", vpsID)
			return
		}

		// Other error opening file
		log.Printf("⚠️  Failed to open metrics config: %v", err)
		return
	}
	defer file.Close()

	var config MetricsConfig
	if err := json.NewDecoder(file).Decode(&config); err != nil {
		log.Printf("⚠️  Failed to parse metrics config: %v", err)
		return
	}

	// Use default webhook URL if not set
	if config.N8NWebhookURL == "" {
		config.N8NWebhookURL = defaultWebhookURL
	}

	// Auto-generate VPS ID if missing
	if config.VPSID == "" {
		config.VPSID = generateVPSID()

		// Save the generated VPS ID back to config file
		if updatedJSON, err := json.MarshalIndent(config, "", "  "); err == nil {
			if err := os.WriteFile(configPath, updatedJSON, 0600); err == nil {
				log.Printf("💾 Saved auto-generated VPS ID to config")
			}
		}
	}

	metricsLock.Lock()
	metricsConfig = &config
	metricsLock.Unlock()

	log.Printf("📊 Metrics tracking enabled (VPS ID: %s)", config.VPSID)
}

// --- Metrics Tracking ---

// trackMetric sends a metric event to the n8n webhook asynchronously
func trackMetric(eventType string, appName string, data map[string]interface{}) {
	// Check if metrics are configured
	metricsLock.RLock()
	config := metricsConfig
	metricsLock.RUnlock()

	if config == nil || config.N8NWebhookURL == "" {
		// Metrics not configured, silently skip (only log once per startup to avoid spam)
		return
	}

	// Run in goroutine to avoid blocking
	go func() {
		payload := map[string]interface{}{
			"event_type": eventType,
			"timestamp":  time.Now().UTC().Format(time.RFC3339),
			"app_name":   appName,
			"data":       data,
		}

		// Add VPS ID if configured
		if config.VPSID != "" {
			payload["vps_id"] = config.VPSID
		}

		jsonData, err := json.Marshal(payload)
		if err != nil {
			log.Printf("⚠️  Failed to marshal metrics payload: %v", err)
			return
		}

		req, err := http.NewRequest("POST", config.N8NWebhookURL, bytes.NewBuffer(jsonData))
		if err != nil {
			log.Printf("⚠️  Failed to create metrics request: %v", err)
			return
		}

		req.Header.Set("Content-Type", "application/json")

		client := &http.Client{Timeout: 5 * time.Second}
		resp, err := client.Do(req)
		if err != nil {
			log.Printf("⚠️  Failed to send metrics: %v", err)
			return
		}
		defer resp.Body.Close()

		if resp.StatusCode < 200 || resp.StatusCode >= 300 {
			body, _ := io.ReadAll(resp.Body)
			log.Printf("⚠️  Metrics webhook returned error (status %d): %s", resp.StatusCode, string(body))
		}
	}()
}

// --- GitHub App Token Generation ---

// generateJWT generates a JWT token for GitHub App authentication
func generateJWT() (string, error) {
	githubAppLock.RLock()
	appID := githubAppConfig.AppID
	privateKeyStr := githubAppConfig.PrivateKey
	githubAppLock.RUnlock()

	if appID == "" || privateKeyStr == "" {
		return "", fmt.Errorf("GitHub App not configured")
	}

	// Parse private key
	block, _ := pem.Decode([]byte(privateKeyStr))
	if block == nil {
		return "", fmt.Errorf("failed to parse private key PEM")
	}

	key, err := x509.ParsePKCS1PrivateKey(block.Bytes)
	if err != nil {
		// Try PKCS8 format
		parsedKey, err2 := x509.ParsePKCS8PrivateKey(block.Bytes)
		if err2 != nil {
			return "", fmt.Errorf("failed to parse private key: %v (tried PKCS1 and PKCS8)", err)
		}
		var ok bool
		key, ok = parsedKey.(*rsa.PrivateKey)
		if !ok {
			return "", fmt.Errorf("private key is not RSA")
		}
	}

	// Create JWT claims
	now := time.Now()
	claims := jwt.MapClaims{
		"iat": now.Add(-60 * time.Second).Unix(), // Issued at (allow 60s clock skew)
		"exp": now.Add(10 * time.Minute).Unix(),  // Expires in 10 minutes
		"iss": appID,                             // Issuer (App ID)
	}

	token := jwt.NewWithClaims(jwt.SigningMethodRS256, claims)
	tokenString, err := token.SignedString(key)
	if err != nil {
		return "", fmt.Errorf("failed to sign JWT: %v", err)
	}

	return tokenString, nil
}

// getInstallationToken gets an installation access token from GitHub API
func getInstallationToken() (string, error) {
	// Check cache first
	installationToken.mu.RLock()
	if installationToken.token != "" && time.Now().Before(installationToken.expiresAt) {
		token := installationToken.token
		installationToken.mu.RUnlock()
		return token, nil
	}
	installationToken.mu.RUnlock()

	// Generate JWT
	jwtToken, err := generateJWT()
	if err != nil {
		return "", fmt.Errorf("failed to generate JWT: %v", err)
	}

	githubAppLock.RLock()
	installationID := githubAppConfig.InstallationID
	githubAppLock.RUnlock()

	// Request installation token
	url := fmt.Sprintf("https://api.github.com/app/installations/%s/access_tokens", installationID)
	req, err := http.NewRequest("POST", url, nil)
	if err != nil {
		return "", fmt.Errorf("failed to create request: %v", err)
	}

	req.Header.Set("Authorization", "Bearer "+jwtToken)
	req.Header.Set("Accept", "application/vnd.github.v3+json")

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return "", fmt.Errorf("failed to request token: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusCreated {
		body, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("GitHub API error (status %d): %s", resp.StatusCode, string(body))
	}

	var tokenResp struct {
		Token     string    `json:"token"`
		ExpiresAt time.Time `json:"expires_at"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&tokenResp); err != nil {
		return "", fmt.Errorf("failed to decode token response: %v", err)
	}

	// Cache the token (subtract 5 minutes for safety margin)
	installationToken.mu.Lock()
	installationToken.token = tokenResp.Token
	installationToken.expiresAt = tokenResp.ExpiresAt.Add(-5 * time.Minute)
	installationToken.mu.Unlock()

	return tokenResp.Token, nil
}

// getGitHubTokenURL converts a GitHub URL to use token authentication
func getGitHubTokenURL(repoURL string) (string, error) {
	// Check if URL already has a token embedded - return early
	// Format: https://x-access-token:TOKEN@github.com/user/repo.git
	// Also handle URLs that were already processed
	if strings.Contains(repoURL, "x-access-token:") {
		// URL already has our token format, return as-is
		return repoURL, nil
	}

	token, err := getInstallationToken()
	if err != nil {
		return "", err
	}

	// Convert various GitHub URL formats to HTTPS with token
	// git@github.com:user/repo.git -> https://x-access-token:TOKEN@github.com/user/repo.git
	// https://github.com/user/repo.git -> https://x-access-token:TOKEN@github.com/user/repo.git

	// Handle SSH URLs first (before credential cleanup)
	if strings.HasPrefix(repoURL, "git@github.com:") {
		repoURL = strings.Replace(repoURL, "git@github.com:", "https://github.com/", 1)
	}

	// Remove existing credentials if present (for HTTPS URLs with user:pass or other tokens)
	// This only applies to HTTPS URLs, not SSH (which we already converted above)
	if strings.HasPrefix(repoURL, "https://") && strings.Contains(repoURL, "@github.com") {
		// Extract just the repo path part (remove user:pass@ or token@)
		parts := strings.Split(repoURL, "@github.com")
		if len(parts) > 1 {
			repoURL = "https://github.com" + parts[1]
		}
	}

	// Handle clean HTTPS URLs
	if strings.HasPrefix(repoURL, "https://github.com/") {
		// Insert token into URL
		repoURL = strings.Replace(repoURL, "https://github.com/",
			fmt.Sprintf("https://x-access-token:%s@github.com/", token), 1)
		return repoURL, nil
	}

	if strings.HasPrefix(repoURL, "http://github.com/") {
		repoURL = strings.Replace(repoURL, "http://github.com/",
			fmt.Sprintf("https://x-access-token:%s@github.com/", token), 1)
		return repoURL, nil
	}

	return "", fmt.Errorf("unsupported repository URL format: %s", repoURL)
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
	go runDeploy(payload.Repository.Name, config, "github")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("Deploy triggered"))

	// Track webhook received
	trackMetric("webhook_received", payload.Repository.Name, map[string]interface{}{
		"webhook_type": "github",
	})
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

	go runDeploy(appName, config, "manual")
	w.Write([]byte("Manual deploy triggered"))

	// Track webhook received
	trackMetric("webhook_received", appName, map[string]interface{}{
		"webhook_type": "manual",
	})
}

func handleReload(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", 405)
		return
	}

	// Simple auth - check for a reload token or allow from localhost
	// For security, we'll require a simple token or localhost
	configFile := "/etc/dockup/registry.json" // Default, could be made configurable

	if err := loadConfig(configFile); err != nil {
		log.Printf("❌ Failed to reload config: %v", err)
		http.Error(w, fmt.Sprintf("Failed to reload: %v", err), 500)
		return
	}

	// Also reload GitHub App config
	loadGitHubAppConfig()

	// Also reload metrics config
	loadMetricsConfig()

	// Safely read githubAppConfig with proper locking
	githubAppLock.RLock()
	appID := ""
	if githubAppConfig != nil {
		appID = githubAppConfig.AppID
	}
	githubAppLock.RUnlock()

	if appID != "" {
		log.Printf("✅ GitHub App config reloaded (App ID: %s)", appID)
	} else {
		log.Printf("⚠️  GitHub App config not found or invalid")
	}

	// Safely read metricsConfig with proper locking
	metricsLock.RLock()
	vpsID := ""
	if metricsConfig != nil {
		vpsID = metricsConfig.VPSID
	}
	metricsLock.RUnlock()

	if vpsID != "" {
		log.Printf("✅ Metrics config reloaded (VPS ID: %s)", vpsID)
	} else if metricsConfig != nil {
		log.Printf("✅ Metrics config reloaded")
	}

	log.Printf("♻️  Registry reloaded, now watching %d apps", len(registry))
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(fmt.Sprintf("Registry reloaded. Now watching %d apps", len(registry))))
}

func handleGitHubTokenURL(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", 405)
		return
	}

	repoURL := r.URL.Query().Get("repo")
	if repoURL == "" {
		http.Error(w, "Missing ?repo= parameter", 400)
		return
	}

	if githubAppConfig == nil {
		http.Error(w, "GitHub App not configured", 503)
		return
	}

	tokenURL, err := getGitHubTokenURL(repoURL)
	if err != nil {
		log.Printf("❌ Failed to get token URL: %v", err)
		http.Error(w, fmt.Sprintf("Failed to get token URL: %v", err), 500)
		return
	}

	w.Header().Set("Content-Type", "text/plain")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(tokenURL))
}

func handleCreateWebhook(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", 405)
		return
	}

	// Parse request body
	var req struct {
		Repo   string `json:"repo"`   // owner/repo format
		URL    string `json:"url"`    // webhook URL
		Secret string `json:"secret"` // webhook secret
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid JSON", 400)
		return
	}

	if req.Repo == "" || req.URL == "" || req.Secret == "" {
		http.Error(w, "Missing required fields: repo, url, secret", 400)
		return
	}

	if githubAppConfig == nil {
		http.Error(w, "GitHub App not configured", 503)
		return
	}

	// Get installation token
	token, err := getInstallationToken()
	if err != nil {
		log.Printf("❌ Failed to get installation token for webhook creation: %v", err)
		http.Error(w, fmt.Sprintf("Failed to get token: %v", err), 500)
		return
	}

	// Create webhook via GitHub API
	apiURL := fmt.Sprintf("https://api.github.com/repos/%s/hooks", req.Repo)

	webhookConfig := map[string]interface{}{
		"url":          req.URL,
		"content_type": "json",
		"secret":       req.Secret,
		"insecure_ssl": "0",
	}

	payload := map[string]interface{}{
		"name":   "web",
		"active": true,
		"events": []string{"push"},
		"config": webhookConfig,
	}

	jsonData, err := json.Marshal(payload)
	if err != nil {
		http.Error(w, "Failed to encode payload", 500)
		return
	}

	httpReq, err := http.NewRequest("POST", apiURL, bytes.NewBuffer(jsonData))
	if err != nil {
		http.Error(w, "Failed to create request", 500)
		return
	}

	httpReq.Header.Set("Authorization", "Bearer "+token)
	httpReq.Header.Set("Accept", "application/vnd.github+json")
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("X-GitHub-Api-Version", "2022-11-28")

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(httpReq)
	if err != nil {
		log.Printf("❌ Failed to create webhook: %v", err)
		http.Error(w, fmt.Sprintf("Failed to create webhook: %v", err), 500)
		return
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)

	if resp.StatusCode == 201 {
		var hookResp struct {
			ID int `json:"id"`
		}
		if err := json.Unmarshal(body, &hookResp); err == nil {
			log.Printf("✅ Webhook created for %s (ID: %d)", req.Repo, hookResp.ID)
			// Track webhook created
			trackMetric("webhook_created", "", map[string]interface{}{
				"repo_name":    req.Repo,
				"webhook_id":   hookResp.ID,
				"webhook_type": "github",
			})
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusCreated)
			w.Write([]byte(fmt.Sprintf(`{"id": %d, "status": "created"}`, hookResp.ID)))
			return
		}
	}

	// Check if webhook already exists (422 or 400 with specific message)
	if resp.StatusCode == 422 || resp.StatusCode == 400 {
		// Try to find existing webhook
		listURL := fmt.Sprintf("https://api.github.com/repos/%s/hooks", req.Repo)
		listReq, _ := http.NewRequest("GET", listURL, nil)
		listReq.Header.Set("Authorization", "Bearer "+token)
		listReq.Header.Set("Accept", "application/vnd.github+json")
		listReq.Header.Set("X-GitHub-Api-Version", "2022-11-28")

		listResp, err := client.Do(listReq)
		if err == nil {
			defer listResp.Body.Close()
			var hooks []struct {
				ID     int `json:"id"`
				Config struct {
					URL string `json:"url"`
				} `json:"config"`
			}
			if json.NewDecoder(listResp.Body).Decode(&hooks) == nil {
				for _, hook := range hooks {
					if hook.Config.URL == req.URL {
						log.Printf("✅ Webhook already exists for %s (ID: %d)", req.Repo, hook.ID)
						// Track webhook created (already exists)
						trackMetric("webhook_created", "", map[string]interface{}{
							"repo_name":    req.Repo,
							"webhook_id":   hook.ID,
							"webhook_type": "github",
						})
						w.Header().Set("Content-Type", "application/json")
						w.WriteHeader(http.StatusOK)
						w.Write([]byte(fmt.Sprintf(`{"id": %d, "status": "exists"}`, hook.ID)))
						return
					}
				}
			}
		}
	}

	// Return error
	log.Printf("❌ Failed to create webhook for %s: HTTP %d - %s", req.Repo, resp.StatusCode, string(body))
	http.Error(w, fmt.Sprintf("GitHub API error (status %d): %s", resp.StatusCode, string(body)), resp.StatusCode)
}

func handleMetricsTrack(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", 405)
		return
	}

	var payload struct {
		EventType string                 `json:"event_type"`
		AppName   string                 `json:"app_name"`
		Data      map[string]interface{} `json:"data"`
	}

	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		http.Error(w, "Invalid JSON", 400)
		return
	}

	if payload.EventType == "" {
		http.Error(w, "Missing event_type", 400)
		return
	}

	// Track the metric
	trackMetric(payload.EventType, payload.AppName, payload.Data)

	w.WriteHeader(http.StatusOK)
	w.Write([]byte("Metric tracked"))
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

func runDeploy(appName string, config AppConfig, deploymentType string) {
	// Mutex for this specific app to prevent race conditions
	lock, _ := deployLocks.LoadOrStore(appName, &sync.Mutex{})
	mtx := lock.(*sync.Mutex)

	if !mtx.TryLock() {
		log.Printf("⏳ Deploy already in progress for %s, skipping...", appName)
		return
	}
	defer mtx.Unlock()

	// Track deployment start
	startTime := time.Now()
	trackMetric("deployment_started", appName, map[string]interface{}{
		"deployment_type": deploymentType,
	})

	log.Printf("♻️  Starting deploy for %s...", appName)

	composeFile := "docker-compose.yml"
	if config.Compose != "" {
		composeFile = config.Compose
	}

	// Get repository URL and convert to token-authenticated URL
	var gitCommands []string

	// Get the remote URL from git config
	getRemoteCmd := exec.Command("git", "config", "--get", "remote.origin.url")
	getRemoteCmd.Dir = config.Path
	remoteURLBytes, err := getRemoteCmd.Output()
	if err != nil {
		log.Printf("❌ Deploy FAILED for %s: failed to get remote URL: %v", appName, err)
		return
	}
	remoteURL := strings.TrimSpace(string(remoteURLBytes))

	// Get token-authenticated URL if GitHub App is configured
	if githubAppConfig != nil {
		tokenURL, err := getGitHubTokenURL(remoteURL)
		if err != nil {
			log.Printf("⚠️  Failed to get GitHub token for %s: %v", appName, err)
			log.Printf("   Falling back to existing git credentials")
			// Fall through to use existing git config
		} else {
			// Temporarily update remote URL to use token, then fetch
			gitCommands = []string{
				fmt.Sprintf("git remote set-url origin %s", tokenURL),
				"git fetch origin " + config.Branch,
				"git reset --hard origin/" + config.Branch,
				fmt.Sprintf("git remote set-url origin %s", remoteURL), // Restore original URL
			}
		}
	}

	// If we didn't set up token URL, use standard git commands
	if len(gitCommands) == 0 {
		gitCommands = []string{
			"git fetch origin " + config.Branch,
			"git reset --hard origin/" + config.Branch,
		}
	}

	// Build full command
	commands := append(gitCommands,
		fmt.Sprintf("docker compose -f %s build --pull", composeFile),
		fmt.Sprintf("docker compose -f %s up -d --remove-orphans", composeFile),
		"docker system prune -f", // Clean up old images
	)

	fullCmd := strings.Join(commands, " && ")
	cmd := exec.Command("/bin/sh", "-c", fullCmd)
	cmd.Dir = config.Path // Run in the app directory

	output, err := cmd.CombinedOutput()
	duration := time.Since(startTime)
	durationSeconds := int(duration.Seconds())

	if err != nil {
		log.Printf("❌ Deploy FAILED for %s:\n%s", appName, string(output))
		// Track deployment failure
		trackMetric("deployment_failure", appName, map[string]interface{}{
			"deployment_type":  deploymentType,
			"duration_seconds": durationSeconds,
			"error_message":    strings.TrimSpace(string(output)),
		})
	} else {
		log.Printf("✅ Deploy SUCCESS for %s", appName)
		// Track deployment success
		trackMetric("deployment_success", appName, map[string]interface{}{
			"deployment_type":  deploymentType,
			"duration_seconds": durationSeconds,
			"minutes_saved":    20, // Fixed estimate per successful deployment
		})
	}
}
