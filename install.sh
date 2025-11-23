#!/bin/bash
# DockUp Bootstrap Installer
# This script downloads DockUp and runs the specified command
# Usage: curl -fsSL https://your-domain.com/install.sh | bash -s -- init user@vps-ip

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration - Update these URLs to point to your hosted files
# You can override these with environment variables:
#   DOCKUP_REPO_URL=https://raw.githubusercontent.com/Moe1211/dockup/main curl -fsSL ... | bash
DOCKUP_REPO_URL="${DOCKUP_REPO_URL:-https://raw.githubusercontent.com/Moe1211/dockup/main}"
DOCKUP_SCRIPT_URL="${DOCKUP_SCRIPT_URL:-$DOCKUP_REPO_URL/dockup}"
MAIN_GO_URL="${MAIN_GO_URL:-$DOCKUP_REPO_URL/main.go}"

# Extract branch name from URL for display
# URL format: https://raw.githubusercontent.com/user/repo/branch
BRANCH_NAME=$(echo "$DOCKUP_REPO_URL" | sed -n 's|.*/\([^/]*\)$|\1|p')
if [ -z "$BRANCH_NAME" ]; then
    BRANCH_NAME="main"
fi

# Save the original working directory (where the user ran the command)
# When piping to bash, we need to capture pwd before any cd operations
# Try multiple methods to ensure we get the correct directory
if [ -n "$PWD" ]; then
    ORIGINAL_DIR="$PWD"
elif command -v pwd > /dev/null 2>&1; then
    ORIGINAL_DIR=$(pwd)
else
    # Fallback: use current directory
    ORIGINAL_DIR="."
fi
# Convert to absolute path to avoid any issues with relative paths
ORIGINAL_DIR=$(cd "$ORIGINAL_DIR" 2>/dev/null && pwd) || {
    echo -e "${RED}❌ Error: Could not determine current working directory${NC}"
    exit 1
}

# Temporary directory
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

cd "$TMP_DIR"

echo -e "${BLUE}🚀 DockUp Bootstrap Installer${NC}"
echo -e "${BLUE}Installing from branch: ${YELLOW}$BRANCH_NAME${NC}"
echo -e "${BLUE}Downloading DockUp...${NC}"

# Download dockup script
if ! curl -fsSL "$DOCKUP_SCRIPT_URL" -o dockup; then
    echo -e "${RED}❌ Failed to download dockup script${NC}"
    echo "Please check your internet connection and try again."
    exit 1
fi

chmod +x dockup

# Download main.go (needed for setup command)
if ! curl -fsSL "$MAIN_GO_URL" -o main.go; then
    echo -e "${RED}❌ Failed to download main.go${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Download complete${NC}"
echo ""

# Execute the command passed as arguments
if [ $# -eq 0 ]; then
    echo -e "${YELLOW}Usage:${NC}"
    echo "  curl -fsSL https://raw.githubusercontent.com/Moe1211/dockup/main/install.sh | bash -s -- deploy user@vps-ip"
    echo ""
    echo "  # Or use individual commands:"
    echo "  curl -fsSL https://raw.githubusercontent.com/Moe1211/dockup/main/install.sh | bash -s -- setup user@vps-ip"
    echo "  curl -fsSL https://raw.githubusercontent.com/Moe1211/dockup/main/install.sh | bash -s -- init user@vps-ip"
    echo ""
    echo -e "${GREEN}Recommended: Use 'deploy' - it handles everything automatically!${NC}"
    exit 1
fi

# For 'setup' command, we need main.go in the current directory
# For 'init' and 'deploy' commands, we need to be in the user's project directory
if [ "$1" = "setup" ]; then
    # Stay in temp dir for setup (needs main.go to build)
    cd "$TMP_DIR"
    exec ./dockup "$@"
else
    # Change back to original directory for init/deploy (needs git context)
    if [ ! -d "$ORIGINAL_DIR" ]; then
        echo -e "${RED}❌ Error: Original directory no longer exists: $ORIGINAL_DIR${NC}"
        exit 1
    fi
    cd "$ORIGINAL_DIR" || {
        echo -e "${RED}❌ Error: Failed to change to directory: $ORIGINAL_DIR${NC}"
        exit 1
    }
    # Verify we're in a git repo (for better error message)
    if [ "$1" = "init" ] || [ "$1" = "deploy" ]; then
        if ! git rev-parse --show-toplevel > /dev/null 2>&1; then
            echo -e "${RED}❌ Error: Not a Git repository in: $(pwd)${NC}"
            echo -e "${YELLOW}Make sure you're running this command from inside your project's Git repository.${NC}"
            exit 1
        fi
    fi
    exec "$TMP_DIR/dockup" "$@"
fi

