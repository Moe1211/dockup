# DockUp Demo Script for VHS
# Usage: vhs scripts/demo.tape

Output demo.gif
Set FontSize 14
Set Width 1200
Set Height 700
Set Theme "Catppuccin Mocha"
Set TypingSpeed 50ms

# Title Screen - echo a title
Type "echo  "🚀 DockUp - Zero-Bloat PaaS Deme""
Enter
Sleep 2s
Type " clear"
Enter
Sleep 0.5s

# Step 1: Global Install
Type "curl -fsSL https://raw.githubusercontent.com/Moe1211/dockup/main/install-global.sh | bash"
Enter
Sleep 0.5s
Type " 🚀 Installing DockUp..."
Type " 📦 Downloading DockUp..."
Type " 📥 Installing to /Users/n1nja/.local/bin..."
Type " 📥 Installing main.go to /Users/n1nja/.local/share/dockup..."
Type " ✅ DockUp installed successfully!"
Type " You can now use "
Type " dockup"
Type " from anywhere:"
Type " dockup user@vps-ip deploy"
Type " dockup user@vps-ip setup"
Type " dockup user@vps-ip init"
Type " dockup"
Type " command is availabl"
Enter
Sleep 2s
Type " dockup version"
Enter
Sleep 0.5s
Type " DockUp v1.0.10"
Enter
Sleep 1s
Type " clear"
Enter
Sleep 0.5s

# Step 2: VPS Setup
Type "dockup user@vps-ip setup"
Enter
Sleep 0.5s
Type " DockUp v1.0.10"
Type " 🔨 Building Agent for Linux..."
Type " 🚀 Uploading Agent and Installer to user@vps-ip..."
Type " ⚙️  Running Remote Installer..."
Type " >> Installing Dependencies..."
Type " >> Setting up Directories..."
Type " >> Installing Agent..."
Type " >> Configuring Systemd..."
Type " >> GitHub App configuration required"
Type "    Run "
Type " dockup user@vps-ip configure-github-app"
Type "  to set up GitHub App credentials"
Type " ✅ VPS Setup Complete!"
Type " 📋 Important Next Steps:"
Type " 1. Configure GitHub App credentials:"
Type " Run: dockup user@vps-ip configure-github-app   See GITHUB_APP_SETUP.md for detailed instructions"
Type " 2. Make sure your VPS firewall allows port 8080:   The agent listens on port 8080 for webhooks"
Type " 3. Run "
Type " deploy"
Type "  command from your project directory:   cd /path/to/your-project   dockup user@vps-ip deploy'"
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
Type " DockUp v1.0.10"
Type " 🚀 Deploying "
Type " my-project"
Type "  to user@vps-ip..."
Type " 📋 Step 1: Checking DockUp installation..."
Type "    ✓ DockUp is installed"
Type " 📋 Step 2: Checking repository registration..."
Type "    Repository not registered. Registering..."
Type "    >> Cloning repository..."
Type "    >> Using GitHub App token for cloning...Cloning into "
Type " /opt/dockup/apps/my-project"
Type " ..."
Type "    >> Registering app in DockUp..."
Type "    >> Restarting DockUp agent..."
Type "    ✓ Repository registered"
Type " 📋 Step 3: Building and deploying..."
Type "    Triggering deployment..."
Type "    ✓ Deployment triggered successfully"
Type " ✅ Deployment in progress!"
Type " 💡 Monitor deployment logs:"
Type "   ssh user@vps-ip "
Type " journalctl -u dockup -f"
Type "
Type " 📋 Step 4: Setting up GitHub webhook..."
Type "    ✓ Webhook created via GitHub App (ID: 582253515)"
Type " 🎉 Deploy complete! Future pushes to main will auto-deploy."
Enter
Sleep 3s
Type "clear"
Enter
Sleep 0.5s

# Step 4: List registered apps
Type "dockup user@vps-ip list"
Enter
Sleep 0.5s
Type " DockUp v1.0.10"
Type " 📋 Registered Apps on user@vps-ip"
Type " Found 1 registered app(s):"
Type " 📦 my-project"
Type "    Path:        /opt/dockup/apps/my-project"
Type "    Branch:      main"
Type "    Compose File: docker-compose.yml"
Type "    Status:      Directory exists"
Type "    Containers:  2 running'"
Enter
Sleep 2s
Type " clear"
Enter
Sleep 0.5s

# Step 5: Disconnect
Type "dockup user@vps-ip disconnect"
Enter
Sleep 0.5s
Type " DockUp v1.0.10"
Type " 🔌 Disconnecting "
Type " my-project"
Type "  from DockUp on user@vps-ip..."
Type " 📋 Step 2: Removing from DockUp registry..."
Type "    >> Reloading DockUp agent..."
Type "    ✓ Removed from registry"
Type " ✅ Disconnected "
Type " my-project"
Type "  from DockUp"
Type " ℹ️  App directory and containers are still running"
Type "    Use "
Type " dockup user@vps-ip remove"
Type "  to completely delete the app"
Enter
Sleep 2s
Type " clear"
Enter
Sleep 0.5s

# Step 6: Remove
Type "dockup user@vps-ip remove"
Enter
Sleep 0.5s
Type " DockUp v1.0.10"
Type " 🗑️  Removing "
Type " my-project"
Type "  from DockUp on user@vps-ip..."
Type " ⚠️  This will:"
Type "   - Stop and remove all containers"
Type "   - Remove from DockUp registry"
Type "   - Delete app directory: /opt/dockup/apps/my-project"
Type "   - Remove GitHub webhook"
Type " Are you sure? (yes/no): "
Enter
Sleep 0.5s
Type " yes"
Enter
Sleep 0.5s
Type " 📋 Step 1: Stopping containers..."
Type "    >> No docker-compose.yml found, skipping container removal"
Type " 📋 Step 2: Removing GitHub webhook..."
Type "    ✓ Webhook removed from GitHub"
Type " 📋 Step 3: Removing from DockUp registry..."
Type "    >> Reloading DockUp agent..."
Type "    ✓ Removed from registry"
Type " 📋 Step 4: Deleting app directory..."
Type "    >> App directory deleted"
Type "    ✓ Directory removed"
Type " ✅ Completely removed my-project from DockUp"
Enter
Sleep 2s
Type " clear"
Enter
Sleep 0.5s

# Final message
Type " ✅ Demo Complete!"
Enter
Sleep 1s
