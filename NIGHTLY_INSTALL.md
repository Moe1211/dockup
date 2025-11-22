# DockUp Nightly Build Installation

This guide explains how to install the nightly build of DockUp from the `feature/interactive-cli` branch, which includes the new interactive CLI feature.

## ⚠️ Important Notes

- **Nightly builds are experimental** - They may contain bugs or incomplete features
- **Not recommended for production** - Use the stable release from `main` branch for production deployments
- **Interactive CLI is in development** - Feedback and bug reports are welcome!

## Installation Methods

### Option 1: Global Installation (Recommended)

Install DockUp as a global command available system-wide:

```bash
curl -fsSL https://raw.githubusercontent.com/Moe1211/dockup/feature/interactive-cli/install-global-nightly.sh | bash
```

After installation, you can use `dockup` from anywhere:

```bash
# Use interactive mode (new feature!)
dockup

# Or use traditional command-line mode
dockup user@vps-ip deploy
```

### Option 2: Per-Project Installation

Install DockUp for a specific project:

```bash
# Deploy directly
curl -fsSL https://raw.githubusercontent.com/Moe1211/dockup/feature/interactive-cli/install-nightly.sh | bash -s -- deploy user@vps-ip

# Or setup first
curl -fsSL https://raw.githubusercontent.com/Moe1211/dockup/feature/interactive-cli/install-nightly.sh | bash -s -- setup user@vps-ip
```

## New Feature: Interactive CLI

The nightly build includes an interactive CLI mode. Simply run `dockup` with no arguments:

```bash
dockup
```

This will launch an interactive menu where you can:
- Select commands from a numbered menu
- Enter remote host information when prompted
- Select apps from a list (for disconnect/remove commands)
- Get help and version information

### Example Interactive Flow

```
🚀 DockUp Interactive CLI

Select a command:

1) deploy
2) setup
3) init
4) list
5) disconnect
6) remove
7) configure-github-app
8) version
9) help
10) exit

Select command (1-10): 1
Enter remote host (user@host): user@vps-ip
...
```

## Switching Back to Stable

If you want to switch back to the stable release:

```bash
# Uninstall nightly build
rm ~/.local/bin/dockup  # or /usr/local/bin/dockup if installed as root
rm -rf ~/.local/share/dockup

# Install stable release
curl -fsSL https://raw.githubusercontent.com/Moe1211/dockup/main/install-global.sh | bash
```

## Feedback

Found a bug or have suggestions? Please open an issue on GitHub or provide feedback on the interactive CLI experience!

## What's New in Nightly Build

- ✨ **Interactive CLI Mode** - Run `dockup` with no arguments for a guided experience
- 🎯 **Context-Aware App Selection** - Automatically detects apps from git context
- 📋 **Menu-Driven Interface** - Easy navigation through all commands
- 🔄 **Backward Compatible** - All existing command-line usage still works

