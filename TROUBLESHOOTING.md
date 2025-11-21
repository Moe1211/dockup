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

### Repository Not Cloning

**Symptoms:** "Failed to clone repository" error

**Check:**
1. SSH key is added to GitHub as Deploy Key:
   ```bash
   ssh user@vps-ip "cat ~/.ssh/id_ed25519.pub"
   ```
   Add this key to GitHub: Repo → Settings → Deploy keys

2. Repository URL is correct:
   ```bash
   ssh user@vps-ip "jq -r '.\"your-app-name\"' /etc/dockup/registry.json"
   ```

## Quick Diagnostic Commands

```bash
# Full system check
ssh user@vps-ip "
  echo '=== DockUp Status ==='
  systemctl status dockup --no-pager
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

