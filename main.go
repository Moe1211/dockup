package main

import (
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

// Token cache for installation tokens
type tokenCache struct {
	token      string
	expiresAt  time.Time
	mu         sync.RWMutex
}

// Global state
var (
	registry         map[string]AppConfig
	registryLock     sync.RWMutex
	deployLocks      sync.Map // Prevents overlapping deploys for the same app
	githubAppConfig  *GitHubAppConfig
	githubAppLock    sync.RWMutex
	installationToken tokenCache
)

func main() {
	port := flag.String("port", "8080", "Port to listen on")
	configFile := flag.String("config", "/etc/dockup/registry.json", "Path to registry.json")
	flag.Parse()

	// Load Config
	if err := loadConfig(*configFile); err != nil {
		log.Fatalf("❌ Failed to load config: %v\n   Check that %s exists and contains valid JSON", err, *configFile)
	}

	// Load GitHub App config (optional, but recommended)
	loadGitHubAppConfig()

	// Routes
	http.HandleFunc("/webhook/github", handleGithub)
	http.HandleFunc("/webhook/manual", handleManual)
	http.HandleFunc("/reload", handleReload)
	http.HandleFunc("/github/token-url", handleGitHubTokenURL)

	log.Printf("🚀 DockUp Agent running on :%s, watching %d apps", *port, len(registry))
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
		"exp": now.Add(10 * time.Minute).Unix(),   // Expires in 10 minutes
		"iss": appID,                              // Issuer (App ID)
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
	token, err := getInstallationToken()
	if err != nil {
		return "", err
	}

	// Convert various GitHub URL formats to HTTPS with token
	// git@github.com:user/repo.git -> https://x-access-token:TOKEN@github.com/user/repo.git
	// https://github.com/user/repo.git -> https://x-access-token:TOKEN@github.com/user/repo.git
	
	if strings.HasPrefix(repoURL, "git@github.com:") {
		repoURL = strings.Replace(repoURL, "git@github.com:", "https://github.com/", 1)
	}
	
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
	if err != nil {
		log.Printf("❌ Deploy FAILED for %s:\n%s", appName, string(output))
	} else {
		log.Printf("✅ Deploy SUCCESS for %s", appName)
	}
}
