# DockUp - Zero-Bloat PaaS

A minimal, zero-dependency PaaS solution that automatically deploys your Docker Compose applications from GitHub to your VPS.

## Features

- **Zero Dependencies**: Single Go binary agent, no external dependencies
- **Automatic Deployments**: Push to GitHub, deploy automatically
- **Secure**: HMAC signature validation for webhooks
- **Simple CLI**: Two commands to get started
- **Multi-App Support**: Deploy multiple apps on a single VPS

## Architecture

1. **Agent (Server-side)**: Go binary running as systemd service, listens for webhooks
2. **CLI (Client-side)**: Bash script that provisions repos via SSH

## Quick Start

### Prerequisites

- A Linux VPS (Ubuntu/Debian recommended)
- Go installed on your local machine (for building the agent)
- SSH access to your VPS
- `jq` installed on VPS (auto-installed by setup)
- `gh` CLI (optional, for automatic webhook setup)

### Installation Methods

#### Option 1: Install DockUp Globally (Recommended)

Install DockUp as a global command (like `git` or `supabase`):

```bash
curl -fsSL https://raw.githubusercontent.com/Moe1211/dockup/main/install-global.sh | bash
```

Then use `dockup` from anywhere:

```bash
cd my-project
dockup deploy user@vps-ip
```

#### Option 2: One-Line Installer (Per-Project)

**Initial VPS Setup:**
```bash
curl -fsSL https://raw.githubusercontent.com/Moe1211/dockup/main/install.sh | bash -s -- setup user@vps-ip
```

**Initialize Your App:**
```bash
cd my-app
curl -fsSL https://raw.githubusercontent.com/Moe1211/dockup/main/install.sh | bash -s -- init user@vps-ip
```

#### Option 3: Manual Installation

## Command Reference

### When to Use Which Command

**`dockup deploy` (Recommended)**
- **Use when:** You want to deploy your app in one command
- **What it does:** 
  - Checks if DockUp is installed (sets up if needed)
  - Registers your repository (if not already registered)
  - Triggers immediate build and deploy
- **Example:** `dockup deploy user@vps-ip`
- **With rebuild:** `dockup deploy user@vps-ip --rebuild`

**`dockup setup`**
- **Use when:** First time setting up a new VPS
- **What it does:** Installs DockUp agent, Docker, and dependencies on your VPS
- **Example:** `dockup setup user@vps-ip`
- **Note:** Usually not needed - `deploy` handles this automatically

**`dockup init`**
- **Use when:** You only want to register a repository without deploying
- **What it does:** Clones repo and registers it with DockUp
- **Example:** `dockup init user@vps-ip`
- **Note:** Usually not needed - `deploy` handles this automatically

### 1. Initial VPS Setup (One-time per server)

```bash
./dockup setup user@vps-ip
```

This will:

- Install Docker and dependencies
- Build and upload the agent binary
- Configure systemd service
- Generate SSH key for GitHub

**Important**: After setup, add the displayed SSH public key to your GitHub repository as a Deploy Key.

### 2. Initialize Your App (Per repository)

Navigate to your project directory and run:

```bash
cd my-app
./dockup init user@vps-ip
```

This will:

- Clone your repository on the VPS
- Register the app in the agent's registry
- Generate a webhook secret
- Add GitHub webhook (if `gh` CLI is installed)

### 3. Deploy

Just push to your configured branch:

```bash
git push origin main
```

The agent will:

- Validate the webhook signature
- Pull the latest code
- Rebuild Docker images
- Restart containers

## Manual Deployment

You can trigger a manual deployment via HTTP:

```bash
curl -H "Authorization: Bearer YOUR_SECRET" \
  http://vps-ip:8080/webhook/manual?app=my-app
```

## Configuration

The agent reads from `/etc/dockup/registry.json` on the VPS:

```json
{
  "my-app": {
    "path": "/opt/dockup/apps/my-app",
    "branch": "main",
    "secret": "webhook-secret-key",
    "compose_file": "docker-compose.prod.yml"
  }
}
```

- `path`: Where the repository is cloned
- `branch`: Branch to watch for deployments
- `secret`: HMAC secret for webhook validation
- `compose_file`: Optional override (defaults to `docker-compose.yml`)

## Project Structure

```
dockup/
├── main.go           # Go agent source code
├── dockup            # CLI script
├── install.sh        # Bootstrap installer (one-liner)
├── index.html        # Documentation page for hosting
├── setup-domain.sh   # Helper script to configure domain
├── HOSTING.md        # Hosting instructions
├── README.md         # This file
└── .gitignore        # Build artifacts
```

## Monitoring

View agent logs:

```bash
ssh user@vps-ip "journalctl -u dockup -f"
```

Check agent status:

```bash
ssh user@vps-ip "systemctl status dockup"
```

## Security Notes

- The agent validates all GitHub webhooks using HMAC-SHA256
- Manual deployments require Bearer token authentication
- SSH keys should be added as Deploy Keys (read-only) unless you need write access
- The agent runs as root (required for Docker operations)

## Troubleshooting

### Agent not starting

Check logs:
```bash
ssh user@vps-ip "journalctl -u dockup -n 50"
```

### Deployment fails

1. Check that the repository name in GitHub matches the key in `registry.json`
2. Verify the branch name matches
3. Ensure Docker Compose file exists in the repository
4. Check that SSH key is added to GitHub as a Deploy Key

### Webhook not triggering

1. Verify webhook URL is correct: `http://vps-ip:8080/webhook/github`
2. Check webhook secret matches the one in `registry.json`
3. Ensure webhook is configured for "push" events
4. Check GitHub webhook delivery logs

## License

MIT

