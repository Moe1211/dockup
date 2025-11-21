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
- **GitHub App** - See [GITHUB_APP_SETUP.md](GITHUB_APP_SETUP.md) for setup instructions

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

**`dockup disconnect`**

- **Use when:** You want to stop auto-deployments but keep the app running
- **What it does:** Removes GitHub webhook and registry entry, keeps app directory and containers
- **Example:** `dockup disconnect user@vps-ip` (from git repo) or `dockup disconnect user@vps-ip my-app`

**`dockup remove`**

- **Use when:** You want to completely remove an app from your VPS
- **What it does:** Stops containers, removes webhook, deletes app directory and registry entry
- **Example:** `dockup remove user@vps-ip` (from git repo) or `dockup remove user@vps-ip my-app`
- **Warning:** This permanently deletes the app directory and all its data

**`dockup configure-github-app`**

- **Use when:** First time setup or updating GitHub App credentials
- **What it does:** Configures GitHub App credentials on your VPS for repository access
- **Example:** `dockup configure-github-app user@vps-ip`
- **Note:** Required before deploying repositories. See [GITHUB_APP_SETUP.md](GITHUB_APP_SETUP.md)

### 1. Set Up GitHub App (One-time)

Before deploying, you need to create and configure a GitHub App:

1. **Create a GitHub App** - Follow the guide in [GITHUB_APP_SETUP.md](GITHUB_APP_SETUP.md)
2. **Install the app** on your repositories or organization
3. **Configure DockUp** with your GitHub App credentials:

```bash
dockup configure-github-app user@vps-ip
```

You'll need:

- App ID (from GitHub App settings)
- Installation ID (from installation URL)
- Private key (the `.pem` file downloaded from GitHub)

### 2. Initial VPS Setup (One-time per server)

```bash
./dockup setup user@vps-ip
```

This will:

- Install Docker and dependencies
- Build and upload the agent binary
- Configure systemd service

**Important**: After setup, configure your GitHub App credentials (see step 1 above).

### 3. Initialize Your App (Per repository)

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

### 4. Deploy

Just push to your configured branch:

```bash
git push origin main
```

The agent will:

- Validate the webhook signature
- Pull the latest code
- Rebuild Docker images (handles both Dockerfile-based builds and pre-built images)
- Restart containers

**Note:** DockUp works with both:

- Projects using `docker-compose.yml` with pre-built images (e.g., `image: nginx:latest`)
- Projects using `docker-compose.yml` with `Dockerfile` builds (Docker Compose will build automatically)

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

**Docker Compose Support:**
DockUp works with any standard Docker Compose setup:

- Projects with only `docker-compose.yml` using pre-built images
- Projects with `docker-compose.yml` + `Dockerfile` (Compose will build automatically)
- Projects with custom compose file names (use `compose_file` in registry)

## Managing Apps

### Disconnect an App

Stop auto-deployments but keep the app running:

```bash
# From inside the project directory
dockup disconnect user@vps-ip

# Or specify app name
dockup disconnect user@vps-ip my-app
```

This will:

- Remove the GitHub webhook (if GitHub CLI is available)
- Remove the app from DockUp registry
- Keep the app directory and containers running

### Remove an App Completely

Permanently delete an app from your VPS:

```bash
# From inside the project directory
dockup remove user@vps-ip

# Or specify app name
dockup remove user@vps-ip my-app
```

This will:

- Stop and remove all containers
- Remove the GitHub webhook
- Remove the app from DockUp registry
- Delete the app directory (`/opt/dockup/apps/my-app`)

**Warning:** This permanently deletes all app data. You'll be prompted to confirm before deletion.

## Project Structure

```txt
dockup/
├── main.go           # Go agent source code
├── dockup            # CLI script
├── install.sh        # Bootstrap installer (one-liner)
├── index.html           # Documentation page for hosting
├── setup-domain.sh      # Helper script to configure domain
├── HOSTING.md           # Hosting instructions
├── GITHUB_APP_SETUP.md  # GitHub App setup guide
├── README.md            # This file
└── .gitignore           # Build artifacts
```

## Monitoring

### View Real-time Logs

Watch live deployment logs:

```bash
ssh user@vps-ip "journalctl -u dockup -f"
```

### View Recent Logs

See last 50 log entries:

```bash
ssh user@vps-ip "journalctl -u dockup -n 50"
```

### Check Agent Status

```bash
ssh user@vps-ip "systemctl status dockup"
```

### Verify Registered Apps

Check what apps are registered:

```bash
ssh user@vps-ip "jq 'keys' /etc/dockup/registry.json"
```

### Check App Configuration

View configuration for a specific app:

```bash
ssh user@vps-ip "jq '.\"your-app-name\"' /etc/dockup/registry.json"
```

## Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for detailed troubleshooting guide.

**Quick checks if auto-deploy isn't working:**

1. **Check if webhook is configured on GitHub:**
   - Go to your repo → Settings → Webhooks
   - Verify webhook URL: `http://your-vps-ip:8080/webhook/github`
   - Check "Recent Deliveries" for failed attempts

2. **Check DockUp logs:**

   ```bash
   ssh user@vps-ip "journalctl -u dockup -n 100"
   ```

3. **Verify app is registered:**

   ```bash
   ssh user@vps-ip "cat /etc/dockup/registry.json"
   ```

   - App name must match GitHub repo name exactly
   - Branch must match the branch you're pushing to
   - Secret must match webhook secret on GitHub

## Security Notes

- The agent validates all GitHub webhooks using HMAC-SHA256
- Manual deployments require Bearer token authentication
- GitHub App uses short-lived tokens (1 hour) that are automatically rotated
- Private keys are stored securely on the VPS at `/etc/dockup/github-app.json` with restricted permissions (600)
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
4. Verify GitHub App is configured: `ssh user@vps-ip "test -f /etc/dockup/github-app.json && echo 'configured'"`
5. Check that GitHub App is installed on the repository
6. See [GITHUB_APP_SETUP.md](GITHUB_APP_SETUP.md) for GitHub App troubleshooting

### Webhook not triggering

1. Verify webhook URL is correct: `http://vps-ip:8080/webhook/github`
2. Check webhook secret matches the one in `registry.json`
3. Ensure webhook is configured for "push" events
4. Check GitHub webhook delivery logs

## Roadmap & Features

- **[ROADMAP.md](ROADMAP.md)** - Detailed roadmap with upcoming features and contribution guide
- **[FEATURES.md](FEATURES.md)** - Comprehensive list of all current features

## Contributing

DockUp is open-source and free to use. We welcome contributions from the community!

See [ROADMAP.md](ROADMAP.md) for:
- Current feature status
- Upcoming phases and tasks
- How to contribute
- Contribution guidelines

## License

MIT
