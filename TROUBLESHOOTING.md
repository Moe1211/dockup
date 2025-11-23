# DockUp Troubleshooting Guide

## Checking Logs

### View Real-time Agent Logs

```bash
ssh user@vps-ip "journalctl -u dockup -f"
```

This shows live logs from the DockUp agent. You'll see:

- Webhook received messages
- Deployment start/completion
- Any errors during deployment

### View Recent Logs (Last 50 lines)

```bash
ssh user@vps-ip "journalctl -u dockup -n 50"
```

### View Logs Since Today

```bash
ssh user@vps-ip "journalctl -u dockup --since today"
```

### Check Agent Status

```bash
ssh user@vps-ip "systemctl status dockup"
```

## Common Issues

### Auto-Deploy Not Working After Git Push

**Symptoms:** You push to GitHub but nothing happens on the VPS.

**Diagnosis Steps:**

1. **Check if webhook is configured:**

   ```bash
   # On GitHub: Go to Settings → Webhooks
   # Verify webhook URL points to: http://your-vps-ip:8080/webhook/github
   ```

2. **Check webhook deliveries on GitHub:**
   - Go to your repo → Settings → Webhooks
   - Click on your webhook
   - Check "Recent Deliveries" tab
   - Look for failed deliveries (red X)

3. **Check DockUp agent logs:**

   ```bash
   ssh user@vps-ip "journalctl -u dockup -n 100"
   ```

   Look for:
   - "Received webhook for unknown repo" - means repo name doesn't match
   - "Invalid signature" - webhook secret mismatch
   - "Ignored branch" - wrong branch pushed

4. **Verify registry configuration:**

   ```bash
   ssh user@vps-ip "cat /etc/dockup/registry.json"
   ```

   Check:
   - App name matches your GitHub repo name exactly
   - Branch matches the branch you're pushing to
   - Secret matches the webhook secret on GitHub

5. **Test webhook manually:**

   ```bash
   # Get the secret from registry
   SECRET=$(ssh user@vps-ip "jq -r '.\"your-app-name\".secret' /etc/dockup/registry.json")
   
   # Trigger manual deploy
   curl -H "Authorization: Bearer $SECRET" \
     http://your-vps-ip:8080/webhook/manual?app=your-app-name
   ```

### Agent Service Failing to Start

**Symptoms:** `systemctl status dockup` shows "failed" or "exit-code"

**Diagnosis:**

```bash
# Check detailed logs
ssh user@vps-ip "journalctl -u dockup -n 50 --no-pager"

# Check if registry.json is valid
ssh user@vps-ip "jq . /etc/dockup/registry.json"

# Check if port 8080 is in use
ssh user@vps-ip "netstat -tuln | grep 8080 || ss -tuln | grep 8080"

# Test binary manually
ssh user@vps-ip "/usr/local/bin/dockup-agent -port 8080 -config /etc/dockup/registry.json"
```

**Common fixes:**

1. **Invalid JSON in registry.json:**

   ```bash
   # Fix empty or invalid JSON
   ssh user@vps-ip "echo '{}' > /etc/dockup/registry.json"
   ssh user@vps-ip "systemctl restart dockup"
   ```

2. **Port 8080 already in use:**

   ```bash
   # Find what's using the port
   ssh user@vps-ip "lsof -i :8080 || netstat -tulpn | grep 8080 || ss -tulpn | grep 8080"
   
   # If it's an old dockup-agent process, kill it:
   ssh user@vps-ip "pkill -f dockup-agent; sleep 2; systemctl restart dockup"
   
   # Or find and kill the specific process:
   ssh user@vps-ip "kill \$(lsof -t -i:8080) 2>/dev/null || true"
   ssh user@vps-ip "systemctl restart dockup"
   
   # Alternative: Change port in systemd service
   ssh user@vps-ip "sed -i 's/-port 8080/-port 8081/' /etc/systemd/system/dockup.service"
   ssh user@vps-ip "systemctl daemon-reload && systemctl restart dockup"
   ```

3. **Missing registry.json:**

   ```bash
   ssh user@vps-ip "mkdir -p /etc/dockup && echo '{}' > /etc/dockup/registry.json"
   ssh user@vps-ip "systemctl restart dockup"
   ```

4. **Binary issue - rebuild and reinstall:**

   ```bash
   # On your local machine, rebuild and redeploy
   dockup setup user@vps-ip
   ```

### HTTP 404 Error When Triggering Manual Deploy

**Possible causes:**

1. App name doesn't match what's in registry
2. Registry file is corrupted or not loaded
3. Agent needs to be restarted

**Fix:**

```bash
# Check what apps are registered
ssh user@vps-ip "jq 'keys' /etc/dockup/registry.json"

# Restart agent to reload registry
ssh user@vps-ip "systemctl restart dockup"

# Check if agent is running
ssh user@vps-ip "systemctl status dockup"
```

### Webhook Secret Mismatch

**Symptoms:** GitHub shows webhook delivery failed with 403 Forbidden

**Fix:**

1. Get the secret from VPS:

   ```bash
   ssh user@vps-ip "jq -r '.\"your-app-name\".secret' /etc/dockup/registry.json"
   ```

2. Update GitHub webhook:
   - Go to repo → Settings → Webhooks
   - Edit webhook
   - Update "Secret" field with the value from step 1
   - Save

### Wrong Branch Being Watched

**Symptoms:** Pushes to some branches work, others don't

**Check:**

```bash
ssh user@vps-ip "jq -r '.\"your-app-name\".branch' /etc/dockup/registry.json"
```

**Fix:** Update the branch in registry or push to the correct branch

### Docker Compose Build Fails

**Check deployment logs:**

```bash
ssh user@vps-ip "journalctl -u dockup -n 200 | grep -A 20 'Deploy FAILED'"
```

**Common issues:**

- Missing `docker-compose.yml` file
- Docker Compose syntax errors
- Missing dependencies in Dockerfile
- Port conflicts
- Dockerfile not found (if docker-compose.yml references a build context with Dockerfile)

**Note:** DockUp handles both:

- Projects using pre-built images (no Dockerfile needed)
- Projects with Dockerfile (Docker Compose will build it automatically)

### Go Version Compatibility Issues

**Symptoms:** Build works locally but fails on VPS, or you need to downgrade Go version for deployment

**Possible causes:**

1. **Dockerfile specifies a different Go version** than what you're using locally
2. **Go module requirements** differ between local and Docker build environments
3. **Docker build cache** using an older Go version

**Diagnosis:**

1. Check your Dockerfile for Go version:

   ```bash
   grep -i "FROM.*golang" Dockerfile
   ```

2. Check your `go.mod` file for Go version requirement:

   ```bash
   grep "^go " go.mod
   ```

3. Compare with local Go version:

   ```bash
   go version
   ```

**Solutions:**

1. **Update Dockerfile to match your Go version:**

   ```dockerfile
   # Instead of: FROM golang:1.20
   # Use: FROM golang:1.21 (or your required version)
   FROM golang:1.21-alpine AS builder
   ```

2. **Ensure go.mod specifies correct Go version:**

   ```go
   // go.mod
   module your-module
   
   go 1.21  // Match your Dockerfile version
   ```

3. **Clear Docker build cache if needed:**

   ```bash
   # On VPS
   ssh user@vps-ip "cd /opt/dockup/apps/your-app && docker compose build --no-cache"
   ```

4. **Use multi-stage builds** to ensure consistent Go versions:

   ```dockerfile
   FROM golang:1.21-alpine AS builder
   WORKDIR /app
   COPY go.mod go.sum ./
   RUN go mod download
   COPY . .
   RUN go build -o /app/your-app
   
   FROM alpine:latest
   COPY --from=builder /app/your-app /app/your-app
   CMD ["/app/your-app"]
   ```

**Note:** DockUp doesn't control Go versions - it uses whatever your Dockerfile specifies. Ensure your Dockerfile's Go version matches your project's requirements.

### Repository Not Cloning

**Symptoms:** "Failed to clone repository" error

**Check:**

1. **GitHub App is configured:**

   ```bash
   ssh user@vps-ip "test -f /etc/dockup/github-app.json && echo 'configured' || echo 'not configured'"
   ```

   If not configured, run: `dockup configure-github-app user@vps-ip`

2. **GitHub App is installed on the repository:**
   - Go to your repository → Settings → GitHub Apps (or Installations)
   - Verify your GitHub App is listed and has access
   - If not installed, go to your GitHub App settings → Install App → Select repository

3. **Verify GitHub App credentials:**

   ```bash
   ssh user@vps-ip "jq '.app_id, .installation_id' /etc/dockup/github-app.json"
   ```

   Both should be present and non-empty

4. **Check agent can generate tokens:**

   ```bash
   # Test token generation endpoint
   ssh user@vps-ip "curl -s 'http://localhost:8080/github/token-url?repo=https://github.com/user/repo.git'"
   ```

   Should return a token-authenticated URL, not an error

5. **Repository URL is correct:**

   ```bash
   ssh user@vps-ip "jq -r '.\"your-app-name\"' /etc/dockup/registry.json"
   ```

### GitHub App Issues

#### Error: "GitHub App not configured"

**Symptoms:** Agent logs show "GitHub App not configured" or cloning fails

**Fix:**

```bash
# Configure GitHub App
dockup configure-github-app user@vps-ip

# Verify configuration
ssh user@vps-ip "cat /etc/dockup/github-app.json | jq '.app_id, .installation_id'"
```

See [GITHUB_APP_SETUP.md](GITHUB_APP_SETUP.md) for detailed setup instructions.

#### Error: "Failed to generate installation token"

**Symptoms:** Agent logs show token generation errors

**Possible causes:**

- Invalid App ID
- Invalid Installation ID
- Malformed private key
- Private key doesn't match App ID

**Fix:**

1. Verify credentials are correct:

   ```bash
   ssh user@vps-ip "jq '.' /etc/dockup/github-app.json"
   ```

2. Check private key format (should include BEGIN/END markers):

   ```bash
   ssh user@vps-ip "jq -r '.private_key' /etc/dockup/github-app.json | head -1"
   ```

   Should start with `-----BEGIN`

3. Re-configure with correct values:

   ```bash
   dockup configure-github-app user@vps-ip
   ```

#### Error: "Installation not found" or "Repository access denied"

**Symptoms:** Token generation succeeds but git operations fail with 404/403

**Possible causes:**

- Installation ID is incorrect
- GitHub App is not installed on the repository
- App doesn't have access to the repository

**Fix:**

1. Verify Installation ID:
   - Go to your GitHub App → Install App
   - Check the installation URL: `https://github.com/settings/installations/INSTALLATION_ID`
   - The number at the end is your Installation ID

2. Verify app is installed on repository:
   - Go to repository → Settings → GitHub Apps (or Installations)
   - Your app should be listed
   - If not, install it: GitHub App settings → Install App → Select repository

3. Check app permissions:
   - Go to GitHub App settings → Permissions
   - Ensure "Repository contents" is set to "Read-only" (or higher if needed)

#### Token Expiration Issues

**Symptoms:** Intermittent failures, works sometimes but not others

**Note:** Installation tokens expire after 1 hour. DockUp automatically caches and regenerates tokens. If you see expiration errors:

1. **Check agent is running:**

   ```bash
   ssh user@vps-ip "systemctl status dockup"
   ```

2. **Restart agent to clear cache:**

   ```bash
   ssh user@vps-ip "systemctl restart dockup"
   ```

3. **Check logs for token errors:**

   ```bash
   ssh user@vps-ip "journalctl -u dockup -n 50 | grep -i token"
   ```

## Quick Diagnostic Commands

```bash
# Full system check
ssh user@vps-ip "
  echo '=== DockUp Status ==='
  systemctl status dockup --no-pager
  echo ''
  echo '=== GitHub App Config ==='
  if [ -f /etc/dockup/github-app.json ]; then
    jq '.app_id, .installation_id' /etc/dockup/github-app.json
  else
    echo 'NOT CONFIGURED - Run: dockup configure-github-app user@vps-ip'
  fi
  echo ''
  echo '=== Registered Apps ==='
  jq 'keys' /etc/dockup/registry.json
  echo ''
  echo '=== Recent Logs ==='
  journalctl -u dockup -n 20 --no-pager
"
```

## Getting Help

If issues persist:

1. Check all logs: `journalctl -u dockup -n 200`
2. Verify registry: `cat /etc/dockup/registry.json`
3. Test webhook manually (see above)
4. Check GitHub webhook delivery logs
