# DockUp Interactive CLI Demo Script for VHS
# Usage: vhs scripts/interactive-cli.tape

Output interactive-cli.gif
Set FontSize 14
Set Width 1200
Set Height 800
Set Theme "Catppuccin Mocha"
Set TypingSpeed 40ms

# Title Screen
Type "echo '🚀 DockUp Interactive CLI Demo'"
Enter
Sleep 2s
Type "clear"
Enter
Sleep 0.5s

# Show version first (optional - can skip)
# Type "dockup version"
# Enter
# Sleep 1s
# Type "clear"
# Enter
# Sleep 0.5s

# Start Interactive Mode
Type "dockup"
Enter
Sleep 1.5s
Type "DockUp v1.0.26"
Enter
Enter
Type "🚀 DockUp Interactive CLI"
Enter
Enter
Type "Select a command:"
Enter
Enter
Type "1) deploy                  5) disconnect             9) help"
Enter
Type "2) setup                   6) remove                10) exit"
Enter
Type "3) init                    7) configure-github-app"
Enter
Type "4) list                    8) version"
Enter
Type "Select command (1-10): "
Sleep 1.5s
Type "1"
Enter
Sleep 0.5s
Type "Enter remote host"
Enter
Type "Remote host (user@host): "
Sleep 1.5s
Type "root@95.217.208.54"
Enter
Sleep 1s
Type "Force rebuild?"
Enter
Type "Rebuild images even if unchanged? (y/N): "
Sleep 1.5s
Type "n"
Enter
Sleep 0.5s
Type "DockUp v1.0.26"
Enter
Enter
Type "🚀 Deploying 'my-app' to root@95.217.208.54..."
Enter
Enter
Type "📋 Step 1: Checking DockUp installation..."
Type "   ✓ DockUp is installed"
Enter
Type "📋 Step 2: Checking repository registration..."
Type "   ✓ Repository already registered"
Enter
Type "📋 Step 3: Building and deploying..."
Type "   Triggering deployment..."
Type "   ✓ Deployment triggered successfully"
Enter
Enter
Type "✅ Deployment in progress!"
Enter
Enter
Type "💡 Monitor deployment logs:"
Type "   ssh root@95.217.208.54 'journalctl -u dockup -f'"
Enter
Enter
Type "🎉 Deploy complete! Future pushes to 'main' will auto-deploy."
Enter
Enter
Type "Press Enter to return to menu... "
Sleep 2s
Enter
Sleep 0.5s

# Show menu again
Type "DockUp v1.0.26"
Enter
Enter
Type "🚀 DockUp Interactive CLI"
Enter
Enter
Type "Select a command:"
Enter
Enter
Type "1) deploy                  5) disconnect             9) help"
Enter
Type "2) setup                   6) remove                10) exit"
Enter
Type "3) init                    7) configure-github-app"
Enter
Type "4) list                    8) version"
Enter
Type "Select command (1-10): "
Sleep 1s
Type "4"
Enter
Sleep 0.5s
Type "Enter remote host"
Enter
Type "Remote host (user@host): "
Sleep 1s
Type "root@95.217.208.54"
Enter
Sleep 0.5s
Type "DockUp v1.0.26"
Enter
Enter
Type "📋 Registered Apps on root@95.217.208.54"
Enter
Enter
Type "Found 2 registered app(s):"
Enter
Enter
Type "📦 my-app"
Type "   Path:        /opt/dockup/apps/my-app"
Type "   Branch:      main"
Type "   Compose File: docker-compose.yml"
Type "   Status:      Directory exists"
Type "   Containers:  2 running"
Enter
Enter
Type "📦 another-app"
Type "   Path:        /opt/dockup/apps/another-app"
Type "   Branch:      main"
Type "   Compose File: docker-compose.yml"
Type "   Status:      Directory exists"
Type "   Containers:  1 running"
Enter
Enter
Type "Press Enter to return to menu... "
Sleep 2s
Enter
Sleep 0.5s

# Show disconnect with app selection
Type "DockUp v1.0.26"
Enter
Enter
Type "🚀 DockUp Interactive CLI"
Enter
Enter
Type "Select a command:"
Enter
Enter
Type "1) deploy                  5) disconnect             9) help"
Enter
Type "2) setup                   6) remove                10) exit"
Enter
Type "3) init                    7) configure-github-app"
Enter
Type "4) list                    8) version"
Enter
Type "Select command (1-10): "
Sleep 1s
Type "5"
Enter
Sleep 0.5s
Type "Enter remote host"
Enter
Type "Remote host (user@host): "
Sleep 1s
Type "root@95.217.208.54"
Enter
Sleep 0.5s
Type ""
Enter
Type "Select an app:"
Enter
Enter
Type "1) my-app"
Enter
Type "2) another-app"
Enter
Type "3) Cancel"
Enter
Type "Select app (1-3): "
Sleep 1.5s
Type "1"
Enter
Sleep 0.5s
Type "DockUp v1.0.26"
Enter
Enter
Type "🔌 Disconnecting 'my-app' from DockUp on root@95.217.208.54..."
Enter
Enter
Type "📋 Step 1: Removing GitHub webhook..."
Type "   ✓ Webhook removed from GitHub"
Enter
Enter
Type "📋 Step 2: Removing from DockUp registry..."
Type "   >> Reloading DockUp agent..."
Type "   ✓ Removed from registry"
Enter
Enter
Type "✅ Disconnected 'my-app' from DockUp"
Type "ℹ️  App directory and containers are still running"
Type "   Use 'dockup root@95.217.208.54 remove' to completely delete the app"
Enter
Enter
Type "Press Enter to return to menu... "
Sleep 2s
Enter
Sleep 0.5s

# Show help menu
Type "DockUp v1.0.26"
Enter
Enter
Type "🚀 DockUp Interactive CLI"
Enter
Enter
Type "Select a command:"
Enter
Enter
Type "1) deploy                  5) disconnect             9) help"
Enter
Type "2) setup                   6) remove                10) exit"
Enter
Type "3) init                    7) configure-github-app"
Enter
Type "4) list                    8) version"
Enter
Type "Select command (1-10): "
Sleep 1s
Type "9"
Enter
Sleep 0.5s
Type ""
Enter
Type "Usage: dockup user@host {setup|init|deploy|disconnect|remove|list|configure-github-app|version} [options]"
Enter
Enter
Type "Commands:"
Enter
Enter
Type "  deploy     - Unified command (RECOMMENDED)"
Type "     Automatically handles: setup + init + deploy"
Enter
Enter
Type "  setup      - One-time VPS setup"
Type "     Installs DockUp agent on your VPS"
Enter
Enter
Type "  list        - List registered apps"
Type "     Shows all apps registered in DockUp registry"
Enter
Enter
Type "💡 Tip: Most users should use 'deploy' - it does everything!"
Enter
Enter
Type "Press Enter to return to menu... "
Sleep 2s
Enter
Sleep 0.5s

# Exit interactive mode
Type "DockUp v1.0.26"
Enter
Enter
Type "🚀 DockUp Interactive CLI"
Enter
Enter
Type "Select a command:"
Enter
Enter
Type "1) deploy                  5) disconnect             9) help"
Enter
Type "2) setup                   6) remove                10) exit"
Enter
Type "3) init                    7) configure-github-app"
Enter
Type "4) list                    8) version"
Enter
Type "Select command (1-10): "
Sleep 1s
Type "10"
Enter
Sleep 0.5s
Type "Goodbye!"
Enter
Sleep 1s
Type "clear"
Enter
Sleep 0.5s

# Final message
Type "echo '✅ Interactive CLI Demo Complete!'"
Enter
Sleep 1s

