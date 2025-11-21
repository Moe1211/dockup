# DockUp Demo Script for VHS
# Usage: vhs scripts/demo.tape

Output demo.gif
Set FontSize 14
Set Width 1200
Set Height 700
Set Theme "Catppuccin Mocha"
Set TypingSpeed 50ms

# Title Screen - echo a title
Type "echo '🚀 DockUp - Zero-Bloat PaaS Demo'"
Enter
Sleep 2s
Type "clear"
Enter
Sleep 0.5s

# Step 1: Global Install
Type "curl -fsSL https://raw.githubusercontent.com/Moe1211/dockup/main/install-global.sh | bash"
Enter
Sleep 0.5s
Type "printf '%s\n' '🚀 Installing DockUp...' '' '📦 Downloading DockUp...' '' '📥 Installing to /Users/n1nja/.local/bin...' '' '📥 Installing main.go to /Users/n1nja/.local/share/dockup...' '' '✅ DockUp installed successfully!' '' 'You can now use '\''dockup'\'' from anywhere:' '' '  dockup user@vps-ip deploy' '' '  dockup user@vps-ip setup' '' '  dockup user@vps-ip init' '' '✓ '\''dockup'\'' command is available'"
Enter
Sleep 2s
Type "dockup version"
Enter
Sleep 0.5s
Type "printf '%s\n' 'DockUp v1.0.10'"
Enter
Sleep 1s
Type "clear"
Enter
Sleep 0.5s

# Step 2: VPS Setup
Type "dockup user@vps-ip setup"
Enter
Sleep 0.5s
Type "printf '%s\n' 'DockUp v1.0.10' '' '' '🔨 Building Agent for Linux...' '' '🚀 Uploading Agent and Installer to user@vps-ip...' '' '⚙️  Running Remote Installer...' '' '>> Installing Dependencies...' '' '>> Setting up Directories...' '' '>> Installing Agent...' '' '>> Configuring Systemd...' '' '>> GitHub App configuration required' '' '   Run '\''dockup user@vps-ip configure-github-app'\'' to set up GitHub App credentials' '' '' '✅ VPS Setup Complete!' '' '' '📋 Important Next Steps:' '' '' '1. Configure GitHub App credentials:' '' '   Run: dockup user@vps-ip configure-github-app' '   See GITHUB_APP_SETUP.md for detailed instructions' '' '' '2. Make sure your VPS firewall allows port 8080:' '   The agent listens on port 8080 for webhooks' '' '' '3. Run '\''deploy'\'' command from your project directory:' '   cd /path/to/your-project' '   dockup user@vps-ip deploy'"
Enter
Sleep 3s
Type "clear"
Enter
Sleep 0.5s

# Step 3: Navigate to project and deploy
Type "cd my-project"
Enter
Sleep 0.5s
Type "dockup user@vps-ip deploy"
Enter
Sleep 0.5s
Type "printf '%s\n' 'DockUp v1.0.10' '' '' '🚀 Deploying '\''my-project'\'' to user@vps-ip...' '' '' '📋 Step 1: Checking DockUp installation...' '' '   ✓ DockUp is installed' '' '📋 Step 2: Checking repository registration...' '' '   Repository not registered. Registering...' '' '   >> Cloning repository...' '' '   >> Using GitHub App token for cloning...' 'Cloning into '\''/opt/dockup/apps/my-project'\''...' '' '   >> Registering app in DockUp...' '' '   >> Restarting DockUp agent...' '' '   ✓ Repository registered' '' '📋 Step 3: Building and deploying...' '' '   Triggering deployment...' '' '   ✓ Deployment triggered successfully' '' '' '✅ Deployment in progress!' '' '' '💡 Monitor deployment logs:' '   ssh user@vps-ip '\''journalctl -u dockup -f'\''' '' '' '📋 Step 4: Setting up GitHub webhook...' '' '   ✓ Webhook created via GitHub App (ID: 582253515)' '' '🎉 Deploy complete! Future pushes to '\''main'\'' will auto-deploy.'"
Enter
Sleep 3s
Type "clear"
Enter
Sleep 0.5s

# Step 4: List registered apps
Type "dockup user@vps-ip list"
Enter
Sleep 0.5s
Type "printf '%s\n' 'DockUp v1.0.10' '' '' '📋 Registered Apps on user@vps-ip' '' '' 'Found 1 registered app(s):' '' '' '📦 my-project' '' '   Path:        /opt/dockup/apps/my-project' '' '   Branch:      main' '' '   Compose File: docker-compose.yml' '' '   Status:      Directory exists' '' '   Containers:  2 running'"
Enter
Sleep 2s
Type "clear"
Enter
Sleep 0.5s

# Step 5: Disconnect
Type "dockup user@vps-ip disconnect"
Enter
Sleep 0.5s
Type "printf '%s\n' 'DockUp v1.0.10' '' '' '🔌 Disconnecting '\''my-project'\'' from DockUp on user@vps-ip...' '' '' '📋 Step 2: Removing from DockUp registry...' '' '   >> Reloading DockUp agent...' '' '   ✓ Removed from registry' '' '' '✅ Disconnected '\''my-project'\'' from DockUp' '' 'ℹ️  App directory and containers are still running' '' '   Use '\''dockup user@vps-ip remove'\'' to completely delete the app'"
Enter
Sleep 2s
Type "clear"
Enter
Sleep 0.5s

# Step 6: Remove
Type "dockup user@vps-ip remove"
Enter
Sleep 0.5s
Type "printf '%s\n' 'DockUp v1.0.10' '' '' '🗑️  Removing '\''my-project'\'' from DockUp on user@vps-ip...' '' '' '⚠️  This will:' '' '  - Stop and remove all containers' '' '  - Remove from DockUp registry' '' '  - Delete app directory: /opt/dockup/apps/my-project' '' '  - Remove GitHub webhook' '' '' 'Are you sure? (yes/no): '"
Enter
Sleep 0.5s
Type "yes"
Enter
Sleep 0.5s
Type "printf '%s\n' '📋 Step 1: Stopping containers...' '' '   >> No docker-compose.yml found, skipping container removal' '' '' '📋 Step 2: Removing GitHub webhook...' '' '   ✓ Webhook removed from GitHub' '' '' '📋 Step 3: Removing from DockUp registry...' '' '   >> Reloading DockUp agent...' '' '   ✓ Removed from registry' '' '' '📋 Step 4: Deleting app directory...' '' '   >> App directory deleted' '' '   ✓ Directory removed' '' '' '✅ Completely removed '\''my-project'\'' from DockUp'"
Enter
Sleep 2s
Type "clear"
Enter
Sleep 0.5s

# Final message
Type "echo '✅ Demo Complete!'"
Enter
Sleep 1s
